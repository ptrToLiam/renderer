const std = @import("std");
const renderer = @import("renderer");
const Arena = @import("arena");
const Wayland = @import("wayland.zig");

pub fn main() !void {
    const arena: *Arena = .init(.default);
    defer arena.release();

    var conn: Wayland.Connection = try .init(arena);
    defer conn.close();
    var interfaces = [_]Interface{ .{ .name = "wl_seat" } };

    log.debug("connection handle :: {d}", .{conn.handle});
    log.debug("wl_display  :: id :: {d}", .{conn.display.toInt()});

    var proxy = conn.proxy();

    const wl_registry = try conn.display.get_registry(&proxy);
    log.debug("wl_registry :: id :: {d}", .{wl_registry.toInt()});
    try conn.flush();
    conn.objects[1] = conn.display.object();
    conn.objects[2] = wl_registry.object();

    try conn.load_events();
    while (conn.event()) |event| {
        switch (event) {
            .wl_registry => |registry| switch (registry) {
                .global => |global| {
                    log.debug("Registry Global :: {{ .name={d}, .interface={s}, .ver={d} }}", .{
                        global.name,
                        global.interface,
                        global.version,
                    });
                    for (&interfaces) |*desired_interface| {
                        if (std.mem.eql(u8, desired_interface.name, global.interface)) {
                            log.debug("Binding interface :: {s}", .{global.interface});
                            desired_interface.interface = try wl_registry.bind(&proxy, .{
                                .name = global.name,
                                .interface = global.interface,
                                .interface_version = global.version,
                            });
                        }
                    }
                },
                .global_remove => |remove| {
                    log.debug("Received Unexpected global_remove during bind phase :: {any}", .{remove});
                },
            },
            else => {
                log.warn("Unexpected event during bind phase :: {any}", .{event});
            },
        }
    }
    try conn.flush();

    try conn.load_events();
    while (conn.event()) |event| switch (event) {
        .wl_display => |display_event| switch (display_event) {
            .@"error" => |err| {
                log.debug("Display Error :: {{ .object_id={d}, .code={d}, .message=\"{s}\"", .{
                    err.object_id, err.code, err.message,
                });
            },
            .delete_id => |delete_id| {
                log.debug("Display Delete ID :: {d}", .{delete_id.id});
            },
        },
        else => {
            log.debug("event :: {any}", .{event});
        },
    };
}

const Interface = struct {
    interface: ?u32 = null,
    name: []const u8,
};

const log = std.log.scoped(.App);

// Begin tests
test {
    _ = Wayland;
}
