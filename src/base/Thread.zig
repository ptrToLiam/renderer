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

pub inline fn lane_idx() u64 {
    return tctx.lane_ctx.lane_idx;
}

pub inline fn lane_count() u64 {
    return tctx.lane_ctx.lane_count;
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
            const gen = barrier.generation.load(.monotonic);
            if (barrier.counter.fetchAdd(1, .release) + 1 == barrier.expected) {
                barrier.generation.store(gen + 1, .release);
                Futex.wait(&barrier.counter.raw, barrier.expected);
                barrier.counter.store(0, .monotonic);
            } else {
                while (barrier.generation.load(.acquire) == gen) {
                    Futex.wait(&barrier.counter.raw, barrier.expected - 1);
                }
            }
        }
        const Futex = std.Thread.Futex;
    };
};


// File Imports
const Arena = @import("Arena.zig");

// Internal Module Imports
const linux = @import("linux");

// 3rd-Party Module Imports
const builtin = @import("builtin");
const std = @import("std");
