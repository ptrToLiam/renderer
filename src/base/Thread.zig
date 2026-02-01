pub threadlocal var tctx: *Context = undefined;
pub threadlocal var is_async: bool = false;

handle: ThreadHandle,

pub fn launch(entrypoint: anytype, params: anytype) !Thread {
  return .{ .handle = try Impl.launch(entrypoint, params) };
}

pub fn join(thread: *const Thread) void {
  thread.handle.join();
}

pub inline fn set_name(name: []const u8) void {
  @memcpy(tctx.name[0..name.len], name);
  tctx.name_len = name.len;

  Impl.set_name(name);
}

pub inline fn set_namef(fmt: []const u8, args: anytype) void {
  const N = Impl.ThreadNameLength;
  var buf: [N]u8 = undefined;
  const name = std.fmt.bufPrint(buf[0..], fmt, args) catch unreachable;
  set_name(name);
}

pub inline fn get_name() []const u8 {
  return tctx.name[0..tctx.name_len];
}

pub inline fn ctx_init() void {
  tctx = .init();
}

pub inline fn ctx_release() void {
  tctx.release();
}

pub inline fn lane_ctx(lctx: LaneContext) void {
  tctx.lane_ctx = lctx;
}
pub inline fn lane_idx() u64 {
  return tctx.lane_ctx.lane_idx;
}

pub inline fn lane_count() u64 {
  return tctx.lane_ctx.lane_count;
}
pub inline fn get_cpu_count() u64 {
}

pub fn lane_range(count: u64) math.Rng2u64 {
  const per_lane = count / lane_count();
  const leftovers = count % lane_count();
  const has_leftover = lane_idx() < leftovers;
  const before = if (has_leftover) lane_idx() else leftovers;
  const min = per_lane * lane_idx() + before;
  const max = min + per_lane + @intFromBool(has_leftover);
  return .{ .min = min, .max = max };
}

pub inline fn lane_sync() void {
  Context.lane_barrier_wait(0, 0, 0);
}
pub inline fn lane_sync_u64(comptime T: type, broadcast_ptr: *T, src_lane_idx: u64) void {
  Context.lane_barrier_wait(@intFromPtr(broadcast_ptr), @sizeOf(T), src_lane_idx);
}
// micro-second precision timed lane sync
pub inline fn lane_sync_us_timed() void {
  const ts_start = std.time.microTimestamp();
  Context.lane_barrier_wait(0, 0, 0);
  const ts_end = std.time.microTimestamp();
  const ts_elapsed = ts_end - ts_start;
  log.debug("lane#{d} waited {d}us for lane sync", .{lane_idx(), ts_elapsed});
}

pub const sleep = Impl.sleep;
pub const yield = Impl.yield;

pub const Context = struct {
  arenas: [2]*Arena,

  name: [32]u8 = @splat(0),
  name_len: u64 = 0,

  lane_ctx: LaneContext,

  pub fn init() *Context {
    const arena: *Arena = .init(.default);
    const ctx: *Context = arena.create(Context);
    ctx.* = .{
      .arenas = .{
      arena,
      .init(.default),
      },
      .name = undefined,
      .name_len = undefined,
      .lane_ctx = .{
      .lane_idx = undefined,
      .lane_count = 1,
      .barrier = undefined,
      .broadcast_memory = undefined,
      },
    };

    return ctx;
  }

  pub fn release(ctx: *Context) void {
    ctx.arenas[1].release();
    ctx.arenas[0].release();
  }

  pub fn get_lane_ctx() LaneContext {
    return tctx.lane_ctx;
  }

  pub fn lane_barrier_wait(broadcast_ptr: usize, broadcast_size: u64, broadcast_src_lane_idx: u64) void {
  const broadcast_size_clamped = @min(broadcast_size, @sizeOf(@TypeOf(tctx.lane_ctx.broadcast_memory.*)));
  if (broadcast_ptr != 0 and lane_idx() == broadcast_src_lane_idx) {
    const ptr: [*]u8 = @ptrFromInt(broadcast_ptr);
    const broadcast_memory_ptr: [*]u8 = @alignCast(@ptrCast(tctx.lane_ctx.broadcast_memory));
    @memcpy(broadcast_memory_ptr[0..broadcast_size_clamped], ptr[0..broadcast_size_clamped]);
  }

  tctx.lane_ctx.barrier.wait();

  if (broadcast_ptr != 0 and lane_idx() != broadcast_src_lane_idx) {
    const ptr: [*]u8 = @ptrFromInt(broadcast_ptr);
    const broadcast_memory_ptr: [*]u8 = @alignCast(@ptrCast(tctx.lane_ctx.broadcast_memory));
    @memcpy(ptr[0..broadcast_size_clamped], broadcast_memory_ptr[0..broadcast_size_clamped]);
  }

  if (broadcast_ptr != 0)
    tctx.lane_ctx.barrier.wait();
  }

  pub fn get_scratch(comptime N: comptime_int, conflicts: [N]*Arena) ?Arena.Temp {
    var result: ?Arena.Temp = null;
    outer: for (tctx.arenas) |arena| {
      result = arena.temp();
      for (conflicts) |conflict| {
        if (arena == conflict) {
          result = null;
          continue :outer;
        }
      }
      if (result != null)
        break;
    }
    return result;
  }
};

pub const LaneContext = struct {
  lane_idx: u64,
  lane_count: u64,
  barrier: *Barrier,
  broadcast_memory: *u64,
};

pub const Barrier = Impl.Barrier;

const Thread = @This();
const ThreadHandle = Impl.Handle;

const Impl = struct {
  pub fn launch(entrypoint: anytype, args: anytype) !Handle {
    return try std.Thread.spawn(.{}, entry.supplementary, .{entrypoint, args});
  }

  pub fn sleep(ns: u64) void {
    os.sleep(ns);
  }
  pub fn yield() !void {
    try std.Thread.yield();
  }

  pub fn set_name(name: []const u8) void {
    switch (TargetOs.tag) {
      .linux => {
        _ = linux.prctl(@intFromEnum(linux.PR.SET_NAME), @intFromPtr(name.ptr), 0, 0, 0);
      },
      else => @compileError("Thread::set_name unsupported target -- " ++ @tagName(TargetOs.tag)),
    }
  }

  pub const Handle = std.Thread;

  pub const Barrier = struct {
    counter: u32 = 0,
    generation: u32 = 0,
    expected: u32,

    pub fn init(expected: u32) Impl.Barrier {
      return .{ .expected = expected };
    }

    pub fn wait(barrier: *Impl.Barrier) void {
      const gen = @atomicLoad(u32, &barrier.generation, .acquire);
      const old_counter = @atomicRmw(u32, &barrier.counter, .Add, 1, .acq_rel);

      if (old_counter + 1 == barrier.expected) {
        @atomicStore(u32, &barrier.generation, gen+1, .release);
        @atomicStore(u32, &barrier.counter, 0, .release);
        Futex.wake(&barrier.counter, barrier.expected);
      } else {
        var generation_current: u32 = gen;
        generation_current = @atomicLoad(u32, &barrier.generation, .acquire);

        while (generation_current == gen) {
          generation_current = @atomicLoad(u32, &barrier.generation, .acquire);
          Futex.wait(&barrier.counter, barrier.expected);
          Impl.yield() catch unreachable;
        }
      }
    }

    const Futex = std.Thread.Futex;
  };

  pub const ThreadNameLength = switch (TargetOs.tag) {
    .linux => 15,
    else => @compileError("Thread::set_name unsupported target -- " ++ @tagName(TargetOs.tag)),
  };
  const TargetOs = builtin.target.os;
};

const linux = os.linux;
const log = std.log.scoped(.Thread);

// File Imports
const Arena = @import("Arena.zig");
const entry = @import("entry.zig");
const math = @import("math.zig");

// Internal Module Imports
const os = @import("os");

// 3rd-Party Module Imports
const builtin = @import("builtin");
const std = @import("std");
