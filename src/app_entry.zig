const AppName = "Renderer";

pub var app_state: AppState = undefined;

pub fn app_main_entry() !void {
    const app_name = "LmDev-" ++ AppName;
    const arena: *Arena = .init(.default);
    defer arena.release();

    const initial_width = 400;
    const initial_height = 400;

    var window: gfx.Window = try .create(
        arena,
        .{
            .title = app_name,
            .class = "Liam.Games.Renderer",
            .width = initial_width,
            .height = initial_height,
        },
    );
    defer window.destroy();

    var swapchain: Wayland.ShmImageQueue = try .create(
        window.handle.conn,
        window.handle.shm,
        2560,
        1440,
    );

    try swapchain.resize(initial_width, initial_height);
    defer swapchain.destroy() catch |err| {
        app_log.err("failed to destroy shm_pool swapchain :: {s}", .{@errorName(err)});
    };

    var wayland_state: WaylandState = .{
        .connection = window.handle.conn,
        .proxy = @constCast(&window.handle.conn.proxy()),

        // globals
        .display = window.handle.display,
        .seat = window.handle.seat,
        .shm = window.handle.shm,
        .wm_base = window.handle.wm_base,

        // objects
        .wl_surface = window.handle.wl_surface,
        .xdg_surface = window.handle.xdg_surface,
        .xdg_toplevel = window.handle.xdg_toplevel,
    };
    app_state.wayland_state = &wayland_state;
    app_state.swapchain = swapchain;

    const thread_count = std.Thread.getCpuCount() catch 1;
    app_log.info("available thread count :: {d}", .{thread_count});

    var app_threads = arena.push(Thread, thread_count);
    var app_thread_lctxs = arena.push(Thread.LaneContext, thread_count);
    const barrier: *Thread.Barrier = arena.create(Thread.Barrier);
    barrier.* = .init(@intCast(thread_count));

    for (0..thread_count) |idx| {
        app_thread_lctxs[idx] = .{
            .lane_idx = idx,
            .lane_count = thread_count,
            .barrier = barrier,
        };
        app_threads[idx] = try .launch(raytracer.thread_entry, &app_thread_lctxs[idx]);
    }

    for (app_threads) |app_thread| {
        app_thread.join();
    }
}

fn app_thread_entry(lctx: *Thread.LaneContext) void {
    Thread.ctx_init();
    defer Thread.ctx_release();

    Thread.lane_ctx(lctx.*);
    Thread.set_namef("app_lane_{d}", .{Thread.lane_idx()});
}

fn wl_event_loop(noalias wayland_state: *WaylandState) void {
    const connection = wayland_state.connection;
    const us_delay = 100;
    while (!app_state.should_close) loop: {
        const us_start = std.time.microTimestamp();
        var attempts: u16 = 0;
        while (attempts < 5) : (attempts += 1) {
            connection.load_events() catch |err| {
                switch (err) {
                    error.NoData => {},
                    error.SocketReadFailed => {},
                    else => {
                        event_log.err("Failed to load Wayland events :: {s}", .{
                            @errorName(err),
                        });
                        break;
                    },
                }
            };
        }

        while (connection.event()) |event| {
            handle_wl_event(wayland_state, &event) catch |err| {
                event_log.err("Failed to handle event :: {s}", .{
                    @errorName(err),
                });
                break :loop;
            };
        }

        const us_end = std.time.microTimestamp();
        const us_elapsed = us_end - us_start;
        if (us_elapsed < us_delay) {
            const diff = us_delay - us_elapsed;
            std.Thread.sleep(@intCast(diff * std.time.ns_per_us));
        }
    }
}

pub fn handle_wl_event(noalias state: *WaylandState, noalias event: *const Wayland.Protocols.Event) !void {
    switch (event.*) {
        .wl_display => |display_event| switch (display_event) {
            .@"error" => |err| {
                event_log.debug("Display Error :: {{ .object_id={d}, .code={d}, .message=\"{s}\"", .{
                    err.object_id, err.code, err.message,
                });
            },
            .delete_id => {},
        },
        .wl_seat => |seat_event| switch (seat_event) {
            .capabilities => |seat_capabilities| {
                event_log.debug("wl_seat capabilities :: {{ .pointer={s}, .keyboard={s}, .touch={s} }}", .{
                    if (seat_capabilities.capabilities.pointer) "true" else "false",
                    if (seat_capabilities.capabilities.keyboard) "true" else "false",
                    if (seat_capabilities.capabilities.touch) "true" else "false",
                });
            },
            .name => |seat_name| {
                event_log.debug("wl_seat name :: {s}", .{seat_name.name});
            },
        },
        .wl_surface => |surface_event| switch (surface_event) {
            else => event_log.debug("wl_surface_event :: {any}", .{surface_event}),
        },
        .wl_buffer => |buffer_event| switch (buffer_event) {
            .release => {},
        },
        .xdg_wm_base => |xdg_wm_base_event| switch (xdg_wm_base_event) {
            .ping => |ping| {
                try state.wm_base.pong(state.proxy, .{ .serial = ping.serial });
            },
        },
        .xdg_surface => |xdg_surface_event| switch (xdg_surface_event) {
            .configure => |configure| {
                try state.xdg_surface.ack_configure(state.proxy, .{ .serial = configure.serial });
            },
        },
        .xdg_toplevel => |xdg_toplevel_event| switch (xdg_toplevel_event) {
            .configure => |configure| {
                if (configure.width > 0) {
                    try app_state.swapchain.resize(configure.width, configure.height);
                }
            },
            .wm_capabilities => |wm_capabilities| {
                const Capability = Wayland.Protocols.XdgShell.Toplevel.Enum.WmCapabilities;
                var iter = std.mem.window(
                    u8,
                    wm_capabilities.capabilities,
                    @sizeOf(Capability),
                    @sizeOf(Capability),
                );

                while (iter.next()) |cap_bytes| {
                    const capability = std.mem.bytesToValue(Capability, cap_bytes);
                    event_log.debug("xdg_toplevel :: wm_capability :: {s}", .{
                        @tagName(capability),
                    });
                }
            },
            .close => {
                event_log.debug("xdg_toplevel :: received close event", .{});
                app_state.should_close = true;
            },
            else => {
                event_log.debug("xdg_toplevel :: unhandled event :: {any}", .{event});
            },
        },
        else => {
            event_log.debug("event :: {any}", .{event});
        },
    }
}

pub var new_swapchain: ?struct { width: i32, height: i32 } = null;
const AppState = struct {
    wayland_state: *WaylandState,
    swapchain: Wayland.ShmImageQueue,
    should_close: bool = false,
    frame_idx: u64 = 0,
};

const WaylandState = struct {
    connection: *Wayland.Connection,
    proxy: *Wayland.Protocols.Proxy,
    // globals
    display: Wayland.Protocols.Wayland.Display,
    seat: Wayland.Protocols.Wayland.Seat,
    shm: Wayland.Protocols.Wayland.Shm,
    wm_base: Wayland.Protocols.XdgShell.WmBase,

    // objects
    wl_surface: Wayland.Protocols.Wayland.Surface,
    xdg_surface: Wayland.Protocols.XdgShell.Surface,
    xdg_toplevel: Wayland.Protocols.XdgShell.Toplevel,
};

const Light = gfx.Light;
const Sphere = gfx.Sphere;
const Wayland = gfx.Wayland;

const Arena = base.Arena;
const Thread = base.Thread;
const Vec3f32 = math.Vec3f32;

const math = base.math;

const app_log = std.log.scoped(.App);
const event_log = std.log.scoped(.Event);

// File Imports
const raytracer = @import("raytracer.zig");

// Internal Module Imports
const gfx = @import("gfx");
const base = @import("base");

// 3rd-Party Module Imports
const std = @import("std");
const builtin = @import("builtin");
