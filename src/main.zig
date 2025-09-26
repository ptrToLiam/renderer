const std = @import("std");
const renderer = @import("renderer");
const Arena = @import("arena");
const Wayland = @import("wayland.zig");
const linux = @import("linux.zig");

pub fn main() !void {
    Thread.ctx_init();
    const arena: *Arena = .init(.default);
    defer arena.release();

    var conn: Wayland.Connection = try .init(arena);
    defer conn.close();

    app_log.debug("connection handle :: {d}", .{conn.handle});
    app_log.debug("wl_display  :: id :: {d}", .{conn.display.toInt()});

    var proxy = conn.proxy();

    const wl_registry = try conn.display.get_registry(&proxy);
    app_log.debug("wl_registry :: id :: {d}", .{wl_registry.toInt()});
    try conn.flush();
    conn.objects[1] = conn.display.object();
    conn.objects[2] = wl_registry.object();

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
                            conn.objects[seat.toInt()] = seat.object();
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
                            conn.objects[compositor.toInt()] = compositor.object();
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
                            conn.objects[wm_base.toInt()] = wm_base.object();
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
                            conn.objects[shm.toInt()] = shm.object();
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
    conn.objects[wl_surface.toInt()] = wl_surface.object();

    const xdg_surface = try xdg_wm_base.get_xdg_surface(&proxy, .{ .surface = wl_surface });
    conn.objects[xdg_surface.toInt()] = xdg_surface.object();
    const xdg_toplevel = try xdg_surface.get_toplevel(&proxy);
    conn.objects[xdg_toplevel.toInt()] = xdg_toplevel.object();
    try xdg_toplevel.set_title(&proxy, .{ .title = "LmRenderer" });

    try wl_surface.commit(&proxy);
    try conn.flush();

    var wayland_state: WaylandState = .{
        // connection
        .connection = &conn,
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

    const handle = try Thread.spawn(.{}, event_loop, .{&wayland_state});
    defer handle.join();

    var swapchain: ImageQueue = try .init(arena, 960, 540);
    const swapchain_shm_pool = try wl_shm.create_pool(&proxy, .{
        .fd = swapchain.fd,
        .size = @intCast(swapchain.imgs[0].len * 3),
    });

    var wl_bufs: [3]Wayland.Protocols.Wayland.Buffer = @splat(.fromInt(0));
    for (swapchain.imgs, 0..) |_, idx| {
        const stride = swapchain.width * 4;
        const size = stride * swapchain.height;
        wl_bufs[idx] = try swapchain_shm_pool.create_buffer(&proxy, .{
            .format = .argb8888,
            .width = @intCast(swapchain.width),
            .height = @intCast(swapchain.height),
            .stride = @intCast(stride),
            .offset = @intCast(size * idx),
        });
        conn.objects[wl_bufs[idx].toInt()] = wl_bufs[idx].object();
    }

    const StepType = enum {
        up,
        down,
    };

    var step: StepType = .down;
    var frame_idx: usize = 0;
    var blue: u8 = 255;
    const green: u8 = 128;
    const red: u8 = 0;

    while (!wayland_state.should_close) : (frame_idx += 1) {
        app_log.debug("Begin frame #{d}", .{frame_idx});
        const frame_time_us = (std.time.us_per_ms * 32); // 32 ms per frame
        const frame_start_us = std.time.microTimestamp();

        if (blue == 255) step = .down;
        if (blue == 0) step = .up;
        blue = switch (step) { 
            .up => blue + 5,
            .down => blue - 5,
        };

        // clear background
        if (swapchain.next_img()) |img| {
            var img_idx: usize = 0;
            while (img_idx < img.len) : (img_idx += 4) {
                // B
                img[img_idx] = blue;
                // G
                img[img_idx + 1] = green;
                // R
                img[img_idx + 2] = red;
                // A
                img[img_idx + 3] = 255;
            }

            try wl_surface.attach(&proxy, .{
                .buffer = wl_bufs[frame_idx % 3],
                .x = 0,
                .y = 0,
            });
            try wl_surface.damage(&proxy, .{
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
    const us_delay = 500;
    while (!wayland_state.should_close) loop: {
        const us_start = std.time.microTimestamp();
        var attempts: u16 = 0;
        while (attempts < 5) : (attempts += 1) {
            connection.load_events() catch |err| {
                switch (err) {
                    error.NoData => {
                        // event_log.err("connection::load_events() returned {s}", .{@errorName(err)});
                    },
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
            // event_log.debug("Event Thread sleeping for {d}ns ({d}us)", .{ (diff) * std.time.ns_per_us, diff });
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
            .delete_id => |delete_id| {
                event_log.debug("Display Delete ID :: {d}", .{delete_id.id});
            },
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
            .release => {
                event_log.debug("wl_buffer released", .{});
            },
        },
        .xdg_surface => |xdg_surface_event| switch (xdg_surface_event) {
            .configure => |configure| {
                event_log.debug("xdg_configure_event :: {{ .serial={d} }}", .{
                    configure.serial,
                });
                try state.xdg_surface.ack_configure(state.proxy, .{ .serial = configure.serial });
            },
        },
        .xdg_toplevel => |xdg_toplevel_event| switch (xdg_toplevel_event) {
            .configure => |configure| {
                event_log.debug("xdg_toplevel :: configure :: {{ .width={d}, .height={d} }}", .{
                    configure.width,
                    configure.height,
                });
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

const ImageQueue = struct {
    fd: std.posix.fd_t,
    imgs: [3][]u8,
    buffer: []u8,
    width: u32,
    height: u32,
    active: [3]bool,
    write: u32,
    read: u32,

    pub fn init(arena: *Arena, width: u32, height: u32) !ImageQueue {
        const tmp = arena.temp();
        defer tmp.end();
        const shm_fd = try alloc_shm_file(tmp.arena);
        const img_stride = width * 4;
        const img_size = height * img_stride;
        const size = img_size * 3;

        try std.posix.ftruncate(shm_fd, size);
        const buffer = try std.posix.mmap(
            null,
            size,
            std.posix.PROT.READ | std.posix.PROT.WRITE,
            .{ .TYPE = .SHARED },
            shm_fd,
            0,
        );

        const imgs: [3][]u8 = blk: {
            const img_1 = buffer[0..img_size];
            const img_2 = buffer[img_size..][0..img_size];
            const img_3 = buffer[img_size * 2..][0..img_size];

            break :blk .{ img_1, img_2, img_3 };
        };

        return .{
            .fd = shm_fd,
            .buffer = buffer,
            .imgs = imgs,
            .width = width,
            .height = height,
            .active = @splat(false),
            .write = 0,
            .read = 0,
        };
    }

    pub fn next_img(queue: *ImageQueue) ?Image {
        if (!queue.active[queue.write % queue.active.len]) {
            defer queue.write += 1;
            return queue.imgs[queue.write % queue.active.len];
        } else return null;
    }

    inline fn alloc_shm_file(arena: *Arena) !std.posix.fd_t {
        const timestamp = std.time.nanoTimestamp();
        const name_template = "/dev/wl_shm-XXXXXX";
        var name = try arena.allocator().dupe(u8, name_template);
        for (name[(name.len - 6)..], 0..) |_, idx| {
            name[idx] = @intCast(('A' +
                (timestamp & 15) +
                ((timestamp & 16) * 2)));
        }

        const fd = try std.posix.open(
            name,
            .{
                .ACCMODE = .RDWR,
                .CREAT = true,
                .EXCL = true,
            },
            0o600,
        );
        try std.posix.unlink(name);
        return fd;
    }
};

const Image = []u8;

const Thread = linux.Thread;
const app_log = std.log.scoped(.App);
const event_log = std.log.scoped(.EventThread);

// Begin tests
test {
    _ = Wayland;
}
