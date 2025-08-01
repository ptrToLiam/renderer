const std = @import("std");

const Arena = @import("Arena.zig");

pub const Context = struct {
    scratch_arenas: [2]*Arena = undefined,

    pub fn init() Context {
    }

    pub fn deinit(ctx: *const Context) void {
        for (ctx.scratch_arenas) |scratch| {
            scratch.release();
        }
    }
};

pub const Thread = struct {
    pub threadlocal var scratch_arenas: [2]*Arena = undefined;
    thread: std.Thread,

    pub fn spawn(config: SpawnConfig, function: anytype, args: anytype) SpawnError!Thread {
        return .{
            .thread = try std.Thread.spawn(config, thread_entry, .{ function, args }),
        };
    }

    pub fn join(thread: *const Thread) void {
        ctx_deinit();
        thread.thread.join();
    }

    pub fn scratch_begin(comptime N: comptime_int, conflicts: [N]*Arena) ?Arena.Temp {
        var result: ?Arena.Temp = null;
        outer: for (scratch_arenas) |scratch| {
            result = scratch.temp();
            for (conflicts) |conflict| {
                if (scratch == conflict) {
                    result = null;
                    break :outer;
                }
            }
        }

        return result;
    }

    pub fn ctx_init() void {
        for (0..scratch_arenas.len) |idx| {
            scratch_arenas[idx] = .init(.default);
        }
    }
    pub fn ctx_deinit() void {
        for (scratch_arenas) |scratch| {
            scratch.release();
        }
    }

    fn thread_entry(function: anytype, args: anytype) void {
        ctx_init();

        @call(.auto, function, args);
    }

    const SpawnError = std.Thread.SpawnError;
    const SpawnConfig = std.Thread.SpawnConfig;
};
