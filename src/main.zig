const std = @import("std");
const builtin = @import("builtin");

const Wayland = @import("wayland");
const base = @import("base");
const gfx = @import("gfx");

const platform = @import("platform.zig");

const AppName = "Renderer";

pub fn main() !void {
    Thread.ctx_init();
    const arena: *Arena = .init(.default);
    defer arena.release();

    const app_name = "LmDev-" ++ AppName;

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

    const handle = try Thread.launch(event_loop, &wayland_state);
    defer handle.join();

    const initial_width = 400;
    const initial_height = 400;

    var swapchain: Wayland.ShmImageQueue = try .create(conn, wl_shm, 2560, 1440);
    try swapchain.resize(initial_width, initial_height);
    defer swapchain.destroy() catch |err| {
        app_log.err("failed to destroy shm_pool swapchain :: {s}", .{@errorName(err)});
    };
    try conn.flush();

    var frame_idx: usize = 0;
    const cam_pos: Vec3f32 = @splat(0);

    while (!wayland_state.should_close) : (frame_idx += 1) {
        const frame_time_us = (std.time.us_per_ms * 16); // 16 ms per frame -- 60fps
        const frame_start_us = std.time.microTimestamp();

        if (new_swapchain) |new_sc| if (new_sc.width != swapchain.width or
            new_sc.height != swapchain.height)
        {
            try swapchain.resize(new_sc.width, new_sc.height);
        };

        // Draw Frame
        if (swapchain.next_img()) |img| {
            const width = swapchain.width;
            const height = swapchain.height;
            const stride = width * 4;
            const size = height * stride;
            _ = size;

            const bg_color: gfx.Color = .black;

            const vp_size = 1;
            const proj_plane_z: f32 = 1;
            const lights: [3]Light = .{
                .{ .kind = .ambient, .intensity = 0.2, .position = undefined, .direction = undefined },
                .{ .kind = .point, .intensity = 0.6, .position = .{2, 1, 0}, .direction = undefined },
                .{ .kind = .directional, .intensity = 0.2, .position = undefined, .direction = .{1, 4, 4} },
            };
            const spheres: [4]Sphere = .{
                .{ .center = .{ 0, -1, 4 }, .radius = 1, .color = .red, .specular = 500 },
                .{ .center = .{ -2, 0, 4 }, .radius = 1, .color = .green, .specular = 10  },
                .{ .center = .{ 2, 0, 4 }, .radius = 1, .color = .blue, .specular = 500  },
                .{ .center = .{ 0, -5001, 0 }, .radius = 5000, .color = .yellow, .specular = 1000  },
            };

            const draw_start = std.time.microTimestamp();

            @memset(img, @bitCast(bg_color));

            // Draw Scene
            {
                const half_width = @divFloor(width, 2);
                const half_height = @divFloor(height, 2);
                var x: i32 = 0;
                var y: i32 = 0;

                x = -half_width;
                while (x < half_width) : (x += 1) {
                    var height_idx: i32 = 0;
                    while (height_idx < height) : (height_idx += 1) {
                        y = @as(i32, @intCast(height_idx)) - half_height;
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
                        const idx: usize = idx: {
                            const idx_x = half_width + x;
                            const idx_y = half_height - y - 1;
                            if (idx_x < 0 or
                                idx_x >= width or
                                idx_y < 0 or
                                idx_y >= height)
                            {
                                continue;
                            }

                            break :idx @intCast(idx_y * width + idx_x);
                        };

                        img[idx] = @bitCast(color);
                    }
                }
            }

            const draw_end = std.time.microTimestamp();
            const draw_time = draw_end - draw_start;
            app_log.info("total frame draw time  :: {d}us ({d}ms) -- ({d} FPS)", .{ draw_time, @divFloor(draw_time, std.time.us_per_ms), @divFloor(std.time.us_per_s, draw_time) });

            try wl_surface.attach(&proxy, .{
                .buffer = swapchain.buffers[frame_idx % 3],
                .x = 0,
                .y = 0,
            });
            try wl_surface.damage_buffer(&proxy, .{
                .x = 0,
                .y = 0,
                .width = @intCast(swapchain.width),
                .height = @intCast(swapchain.height),
            });
            try wl_surface.commit(&proxy);
        }

        try conn.flush();

        const frame_end_us = std.time.microTimestamp();
        const frame_elapsed_us = frame_end_us - frame_start_us;
        if (frame_elapsed_us < frame_time_us) {
            const diff = frame_time_us - frame_elapsed_us;
            std.Thread.sleep(@intCast(diff * std.time.ns_per_us));
        }
    }
}

fn event_loop(noalias wayland_state: *WaylandState) void {
    const connection = wayland_state.connection;
    const us_delay = 100;
    while (!wayland_state.should_close) loop: {
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
                if (configure.width > 0) new_swapchain = .{
                    .width = configure.width,
                    .height = configure.height,
                };
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
                state.should_close = true;
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
inline fn draw_line(
    img: struct {
        pixels: []gfx.Pixel,
        width: i32,
        height: i32,
    },
    a: Point,
    b: Point,
    color: gfx.Pixel,
) void {
    const width: u32 = @intCast(img.width);
    const height: u32 = @intCast(img.height);
    const x0 = a[0];
    const y0 = a[1];
    const x1 = b[0];
    const y1 = b[1];

    const dx: i32 = @intCast(@abs(x1 - x0));
    const dy: i32 = @intCast(@abs(y1 - y0));

    var sx: i32 = 0;
    var sy: i32 = 0;
    sx = if (x0 < x1) 1 else -1;
    sy = if (y0 < y1) 1 else -1;

    var err: i32 = 0;
    if (dx > dy) err = dx else err = -dy;
    err = @divFloor(err, 2);

    var xc = x0;
    var yc = y0;

    while (true) {
        // Bounds checking
        if (xc >= 0 and xc < width and yc >= 0 and yc < height) {
            const x: u32 = @intCast(xc);
            const y: u32 = @intCast(yc);
            img.pixels[y * width + x] = color;
        }

        if (xc == x1 and yc == y1) break;

        const e2 = err;
        if (e2 > -dx) {
            err -= dy;
            xc += sx;
        }
        if (e2 < dy) {
            err += dx;
            yc += sy;
        }
    }
}

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

    // flags
    should_close: bool = false,
};

const Vec3f32 = gfx.Vec3f32;
const Position = gfx.Position;
const Sphere = gfx.Sphere;
const Light = gfx.Light;
const Point = @Vector(2, i32);

const Thread = base.Thread;
const Arena = base.Arena;

const app_log = std.log.scoped(.App);
const event_log = std.log.scoped(.EventThread);

// Begin tests
test {
    _ = Wayland;
}
