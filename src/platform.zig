const builtin = @import("builtin");
const std = @import("std");

const base = @import("base");
const wayland = @import("wayland");
const linux = @import("linux");

pub fn Window(comptime Target: std.Target.Os) type {
    const handle_t, const software_swapchain_t = target_types: switch (Target.tag) {
        .linux => {
            break :target_types .{
                wayland.Connection,
                wayland.ShmImageQueue,
            };
        },
        else => @compileError("Unsupported Platform :: " ++ @tagName(Target.tag)),
    };
    const window_create_fn, const window_destroy_fn = target_functions: switch (Target.tag) {
        .linux => {
            break :target_functions .{
                wayland.Connection.open,
                wayland.Connection.close,
            };
        },
        else => @compileError("Unsupported Platform :: " ++ @tagName(Target.tag)),
    };
    return struct {
        handle: handle_t,
        swapchain: software_swapchain_t,

        const window_t = @This();
        pub fn create(arena: *Arena) !window_t {
            return .{
                .handle = try window_create_fn(arena),
                .swapchain = undefined,
            };
        }

        pub fn destroy(window: *window_t) void {
            window_destroy_fn(&window.handle);
        }
    };
}

const Arena = base.Arena;
