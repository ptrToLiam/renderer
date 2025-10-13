const AppName = "Renderer";

var app_state: AppState = undefined;
pub fn main() !void {
    Thread.ctx_init();
    defer Thread.ctx_release();

    const app_name = "LmDev-" ++ AppName;
    const arena: *Arena = .init(.default);
    defer arena.release();

    var window: platform.Window(builtin.target.os) = try .create(arena);
    defer window.destroy();
    var conn: *Wayland.Connection = @ptrCast(@alignCast(&window.handle));
    // var conn: Wayland.Connection = try .open(arena);
    // defer conn.close();

    app_log.debug("connection handle :: {d}", .{conn.handle});
    app_log.debug("wl_display  :: id :: {d}", .{conn.display.toInt()});
    var proxy = conn.proxy();

    const wl_registry = try conn.display.get_registry(&proxy);
    app_log.debug("wl_registry :: id :: {d}", .{wl_registry.toInt()});
    try conn.flush();

    // Bind interfaces
    const wl_seat, const wl_compositor, const xdg_wm_base, const wl_shm = bind: {
        var read_success = false;
        while (!read_success) load_loop: {
            conn.load_events() catch |err| {
                switch (err) {
                    error.NoData => {
                        std.Thread.sleep(std.time.ns_per_us);
                        break :load_loop;
                    },
                    error.SocketReadFailed => {
                        std.Thread.sleep(std.time.ns_per_us);
                        break :load_loop;
                    },
                    else => return err,
                }
            };
            read_success = true;
        }

        var seat: Wayland.Protocols.Wayland.Seat = undefined;
        var compositor: Wayland.Protocols.Wayland.Compositor = undefined;
        var wm_base: Wayland.Protocols.XdgShell.WmBase = undefined;
        var shm: Wayland.Protocols.Wayland.Shm = undefined;
        while (conn.event()) |event| {
            switch (event) {
                .wl_registry => |registry| switch (registry) {
                    .global => |global| {
                        if (std.mem.eql(u8, @TypeOf(seat).InterfaceName, global.interface)) {
                            app_log.debug("Binding interface :: {s}", .{global.interface});
                            seat = try wl_registry.bind(&proxy, @TypeOf(seat), .{
                                .name = global.name,
                                .interface_version = global.version,
                            });
                            app_log.debug("Bound {s} with :: {{ .name={d}, .id={d}, .version={d} }}", .{
                                global.interface,
                                global.name,
                                seat.toInt(),
                                global.version,
                            });
                        } else if (std.mem.eql(u8, @TypeOf(compositor).InterfaceName, global.interface)) {
                            app_log.debug("Binding interface :: {s}", .{global.interface});
                            compositor = try wl_registry.bind(&proxy, @TypeOf(compositor), .{
                                .name = global.name,
                                .interface_version = global.version,
                            });
                            app_log.debug("Bound {s} with :: {{ .name={d}, .id={d}, .version={d} }}", .{
                                global.interface,
                                global.name,
                                compositor.toInt(),
                                global.version,
                            });
                        } else if (std.mem.eql(u8, @TypeOf(wm_base).InterfaceName, global.interface)) {
                            app_log.debug("Binding interface :: {s}", .{global.interface});
                            wm_base = try wl_registry.bind(&proxy, @TypeOf(wm_base), .{
                                .name = global.name,
                                .interface_version = global.version,
                            });
                            app_log.debug("Bound {s} with :: {{ .name={d}, .id={d}, .version={d} }}", .{
                                global.interface,
                                global.name,
                                wm_base.toInt(),
                                global.version,
                            });
                        } else if (std.mem.eql(u8, @TypeOf(shm).InterfaceName, global.interface)) {
                            app_log.debug("Binding interface :: {s}", .{global.interface});
                            shm = try wl_registry.bind(&proxy, @TypeOf(shm), .{
                                .name = global.name,
                                .interface_version = global.version,
                            });
                            app_log.debug("Bound {s} with :: {{ .name={d}, .id={d}, .version={d} }}", .{
                                global.interface,
                                global.name,
                                shm.toInt(),
                                global.version,
                            });
                        }
                    },
                    .global_remove => |remove| {
                        app_log.debug("Received Unexpected global_remove during bind phase :: {any}", .{remove});
                    },
                },
                else => {
                    app_log.warn("Unexpected event during bind phase :: {any}", .{event});
                },
            }
        }
        try conn.flush();

        break :bind .{ seat, compositor, wm_base, shm };
    };

    const wl_surface = try wl_compositor.create_surface(&proxy);

    const xdg_surface = try xdg_wm_base.get_xdg_surface(&proxy, .{ .surface = wl_surface });
    const xdg_toplevel = try xdg_surface.get_toplevel(&proxy);

    try xdg_toplevel.set_title(&proxy, .{ .title = app_name });

    try wl_surface.commit(&proxy);
    try conn.flush();

    var wayland_state: WaylandState = .{
        // connection
        .connection = conn,
        .proxy = &proxy,

        // globals
        .display = conn.display,
        .seat = wl_seat,
        .shm = wl_shm,
        .wm_base = xdg_wm_base,

        // objects
        .wl_surface = wl_surface,
        .xdg_surface = xdg_surface,
        .xdg_toplevel = xdg_toplevel,
    };

    // const wl_event_thread_handle = try Thread.launch(event_loop, &wayland_state);
    // defer wl_event_thread_handle.join();

    app_state.wayland_state = &wayland_state;

    const initial_width = 400;
    const initial_height = 400;

    var swapchain: Wayland.ShmImageQueue = try .create(conn, wl_shm, 2560, 1440);
    try swapchain.resize(initial_width, initial_height);
    defer swapchain.destroy() catch |err| {
        app_log.err("failed to destroy shm_pool swapchain :: {s}", .{@errorName(err)});
    };

    app_state.swapchain = swapchain;

    const thread_count = 8;

    var app_threads = arena.push(Thread, thread_count);
    var app_thread_lctxs = arena.push(Thread.LaneContext, thread_count);
    var barrier: Thread.Barrier = .init(thread_count);

    for (0..thread_count) |idx| {
        app_thread_lctxs[idx] = .{
            .lane_idx = idx,
            .lane_count = thread_count,
            .barrier = &barrier,
        };
        app_threads[idx] = try .launch(app_thread_entry, &app_thread_lctxs[idx]);
        app_log.debug("Launched app thread#{d} with LaneContext :: {{ .lane_idx={d}, .lane_count={d}, .barrier=0x{d} }}", .{
            idx,
            app_thread_lctxs[idx].lane_idx,
            app_thread_lctxs[idx].lane_count,
            @intFromPtr(app_thread_lctxs[idx].barrier),
        });
    }

    for (app_threads) |app_thread| {
        app_thread.join();
    }
}

var cur_img: ?gfx.Image = null;
fn app_thread_entry(lctx: *Thread.LaneContext) void {
    Thread.ctx_init();
    defer Thread.ctx_release();

    Thread.lane_ctx(lctx.*);

    const connection = app_state.wayland_state.connection;

    const bg_color: gfx.Color = .black;
    const vp_size = 1;
    const proj_plane_z: f32 = 1;
    const cam_pos: Vec3f32 = @splat(0);
    const lights: [3]Light = .{
        .{ .kind = .ambient, .intensity = 0.2, .position = undefined, .direction = undefined },
        .{ .kind = .point, .intensity = 0.6, .position = .{ 2, 1, 0 }, .direction = undefined },
        .{ .kind = .directional, .intensity = 0.2, .position = undefined, .direction = .{ 1, 4, 4 } },
    };
    const spheres: [4]Sphere = .{
        .{ .center = .{ 0, -1, 4 }, .radius = 1, .color = .red, .specular = 500 },
        .{ .center = .{ -2, 0, 4 }, .radius = 1, .color = .green, .specular = 10 },
        .{ .center = .{ 2, 0, 4 }, .radius = 1, .color = .blue, .specular = 500 },
        .{ .center = .{ 0, -5001, 0 }, .radius = 5000, .color = .yellow, .specular = 1000 },
    };

    while (true) {
        const target_ms = 32;
        const target_us = target_ms * std.time.us_per_ms;
        const frame_start_us = std.time.microTimestamp();
        if (Thread.lane_idx() == 0) {
            app_state.frame_idx += 1;
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
                handle_event(app_state.wayland_state, &event) catch |err| {
                    event_log.err("Failed to handle event :: {s}", .{
                        @errorName(err),
                    });
                };
            }

            if (app_state.swapchain.next_img()) |img| {
                cur_img = img;
            }
        }

        Thread.lane_sync();
        if (app_state.should_close) break;

        const width = app_state.swapchain.width;
        const height = app_state.swapchain.height;
        const half_width = @divFloor(width, 2);
        const half_height = @divFloor(height, 2);
        if (cur_img) |img| {
            const rng = Thread.lane_range(img.len);

            for (rng.min..rng.max) |idx| {
                if (idx > img.len) break;
                const idxi32: i32 = @intCast(idx);
                const x: i32 = @mod(idxi32, width) - half_width;
                const y: i32 = half_height - @divFloor(idxi32, width) - 1;
                const dir = gfx.canvas_to_viewport(
                    &.{
                        .width = vp_size,
                        .height = vp_size,
                        .x = 0,
                        .y = 0,
                    },
                    &.{
                        .width = width,
                        .height = height,
                    },
                    x,
                    y,
                    proj_plane_z,
                );

                const col_opt = gfx.trace_ray(
                    cam_pos,
                    dir,
                    &spheres,
                    &lights,
                    1,
                    1000,
                );

                const color = col_opt orelse bg_color;
                img[idx] = @bitCast(color);
            }
        }

        Thread.lane_sync();

        if (Thread.lane_idx() == 0) {
            const wl_surface = app_state.wayland_state.wl_surface;
            const proxy = app_state.wayland_state.proxy;
            wl_surface.attach(proxy, .{
                .buffer = app_state.swapchain.buffers[app_state.frame_idx % 3],
                .x = 0,
                .y = 0,
            }) catch unreachable;
            wl_surface.damage_buffer(proxy, .{
                .x = 0,
                .y = 0,
                .width = @intCast(app_state.swapchain.width),
                .height = @intCast(app_state.swapchain.height),
            }) catch unreachable;
            wl_surface.commit(proxy) catch unreachable;
            app_state.wayland_state.connection.flush() catch |err| {
                app_log.err("App quitting due to error :: {s}", .{
                    @errorName(err),
                });
                app_state.should_close = true;
            };
            const frame_end_us = std.time.microTimestamp();
            const frame_time_us = frame_end_us - frame_start_us;
            _ = target_us;
            app_log.info("frame time :: {d}us -- ({d} FPS)", .{
                frame_time_us,
                @divFloor(std.time.us_per_s, frame_time_us),
            });
        }
    }
    app_log.info("App thread #{d} exiting", .{Thread.lane_idx()});
}

fn event_loop(noalias wayland_state: *WaylandState) void {
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
            handle_event(wayland_state, &event) catch |err| {
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

fn handle_event(noalias state: *WaylandState, noalias event: *const Wayland.Protocols.Event) !void {
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

const Arena = base.Arena;
const Thread = base.Thread;
const Vec3f32 = math.Vec3f32;

const math = base.math;

const gfx = @import("gfx");
const base = @import("base");
const Wayland = @import("wayland");
const platform = @import("platform.zig");

const app_log = std.log.scoped(.App);
const event_log = std.log.scoped(.Event);

const std = @import("std");
const builtin = @import("builtin");
