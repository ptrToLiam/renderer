var ray_tracer_cur_img: ?gfx.Image = null;
pub fn thread_entry(lctx: *Thread.LaneContext) void {
    Thread.ctx_init();
    defer Thread.ctx_release();

    Thread.lane_ctx(lctx.*);
    Thread.set_namef("app_lane_{d}", .{Thread.lane_idx()});

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
        .{ .center = .{ 0, -1, 4 }, .radius = 1, .color = .red, .specular = 500, .reflective = 0.2 },
        .{ .center = .{ 2, 0, 4 }, .radius = 1, .color = .blue, .specular = 500, .reflective = 0.3 },
        .{ .center = .{ -2, 0, 4 }, .radius = 1, .color = .green, .specular = 10, .reflective = 0.4 },
        .{ .center = .{ 0, -5001, 0 }, .radius = 5000, .color = .yellow, .specular = 1000, .reflective = 0.5 },
    };

    while (true) {
        const target_ms = 64;
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
            app_state.wayland_state.connection.flush() catch |err| {
                std.log.err("Events Flush Failed :: {s}", .{@errorName(err)});
                app_state.should_close = true;
            };

            if (app_state.swapchain.next_img()) |img| {
                ray_tracer_cur_img = img;
            }
        }

        Thread.lane_sync();
        if (app_state.should_close) {
            break;
        }

        const width = app_state.swapchain.width;
        const height = app_state.swapchain.height;
        const half_width = @divFloor(width, 2);
        const half_height = @divFloor(height, 2);
        if (ray_tracer_cur_img) |img| {
            const rng = Thread.lane_range(img.len);

            @memset(img[rng.min..rng.max], @bitCast(bg_color));
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
                    1,
                );

                const color = col_opt orelse bg_color;
                img[idx] = @bitCast(color);
            }

        }

        // Thread.lane_sync();
        const frame_end_us = std.time.microTimestamp();
        const frame_time_us = frame_end_us - frame_start_us;

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
                .width = @intCast(width),
                .height = @intCast(height),
            }) catch unreachable;
            wl_surface.commit(proxy) catch unreachable;
            app_state.wayland_state.connection.flush() catch |err| {
                app_log.err("App quitting due to error :: {s}", .{
                    @errorName(err),
                });
                app_state.should_close = true;
            };
            app_log.info("frame time :: {d}us -- ({d} FPS)", .{
                frame_time_us,
                @divFloor(std.time.us_per_s, frame_time_us),
            });
        }
        if (frame_time_us < target_us) {
            const diff = target_us - frame_time_us;
            Thread.sleep(@intCast(diff * std.time.ns_per_us));
        }
    }
    app_log.info("{s} exiting", .{Thread.get_name()});
}

const app_state = &main_app_entry.app_state;
const handle_event = main_app_entry.handle_wl_event;

const Light = gfx.Light;
const Sphere = gfx.Sphere;

const Arena = base.Arena;
const Thread = base.Thread;
const Vec3f32 = math.Vec3f32;

const math = base.math;

const app_log = std.log.scoped(.App);
const event_log = std.log.scoped(.Event);

// File Imports
const main_app_entry = @import("app_entry.zig");

// Internal Module Imports
const gfx = @import("gfx");
const base = @import("base");
const Wayland = @import("wayland");

// 3rd-Party Module Imports
const std = @import("std");
const builtin = @import("builtin");
