pub threadlocal var tctx: *Context = undefined;
pub threadlocal var is_async: bool = false;

handle: ThreadHandle,

pub fn launch(entrypoint: anytype, params: anytype) !Thread {
    return .{ .handle = try Impl.launch(entrypoint, params) };
}

pub fn join(thread: *const Thread) void {
    thread.handle.join();
}

// pub inline fn set_name(name: []const u8) void {
//     const this = std.Thread.getCpuCount
//     thread.handle.setName(name) catch |err| {
//         std.log.err("failed to set thread name ({s}) :: {s}", .{
//             name,
//             @errorName(err),
//         });
//     };
// }

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

pub fn lane_range(count: u64) struct { min: u64, max: u64 } {
    const per_lane = count / lane_count();
    const leftovers = count % lane_count();
    const has_leftover = lane_idx() < leftovers;
    const before = if (has_leftover) lane_idx() else leftovers;
    const min = per_lane * lane_idx() + before;
    const max = min + per_lane + @intFromBool(has_leftover);
    return .{ .min = min, .max = max };
}

pub inline fn lane_sync() void {
    tctx.lane_ctx.barrier.wait();
}

pub const sleep = Impl.sleep;

pub const Context = struct {
    arenas: [2]*Arena,

    name: [32]u8,
    name_len: u64,

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
        }

        return result;
    }
};

pub const LaneContext = struct {
    lane_idx: u64,
    lane_count: u64,
    barrier: *Barrier,
};

pub const Barrier = Impl.Barrier;

const Thread = @This();
const ThreadHandle = Impl.Handle;

const Impl = struct {
    pub fn launch(entrypoint: anytype, args: anytype) !Handle {
        return try std.Thread.spawn(.{}, entrypoint, .{args});
    }

    pub fn sleep(ns: u64) void {
        std.Thread.sleep(ns);
    }

    pub const Handle = std.Thread;

    pub const Barrier = struct {
        counter: std.atomic.Value(u32) = .{ .raw = 0 },
        generation: std.atomic.Value(u32) = .{ .raw = 0 },
        expected: u32,

        pub fn init(expected: u32) Impl.Barrier {
            return .{ .expected = expected };
        }

        pub fn wait(barrier: *Impl.Barrier) void {
            const gen = @atomicLoad(u32, &barrier.generation.raw, .acquire);
            const old_counter = @atomicRmw(u32, &barrier.counter.raw, .Add, 1, .acq_rel);

            if (old_counter + 1 >= barrier.expected) {
                @atomicStore(u32, &barrier.generation.raw, gen+1, .release);
                @atomicStore(u32, &barrier.counter.raw, 0, .release);
                Futex.wake(&barrier.counter, barrier.expected);
            } else {
                var generation_current: u32 = gen;
                generation_current = @atomicLoad(u32, &barrier.generation.raw, .acquire);

                while (generation_current == gen) {
                    generation_current = @atomicLoad(u32, &barrier.generation.raw, .acquire);
                    Futex.wait(&barrier.counter, barrier.expected);
                }
            }
        }

        const Futex = std.Thread.Futex;
    };
};

const log = std.log.scoped(.Thread);

// File Imports
const Arena = @import("Arena.zig");

// Internal Module Imports
const linux = @import("linux");

// 3rd-Party Module Imports
const builtin = @import("builtin");
const std = @import("std");
