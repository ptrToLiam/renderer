const std = @import("std");
const renderer = @import("renderer");
const Arena = @import("arena");
const Wayland = @import("wayland.zig");

pub fn main() !void {
    const arena: *Arena = .init(.default);
    defer arena.release();

    var conn: Wayland.Connection = try .init(arena);
    defer conn.close();

    log.debug("connection handle :: {d}", .{conn.handle});
    log.debug("wl_display  :: id :: {d}", .{conn.display.toInt()});

    var proxy = conn.proxy();

    const wl_registry = try conn.display.get_registry(&proxy);
    log.debug("wl_registry :: id :: {d}", .{wl_registry.toInt()});
    try conn.flush();
    conn.objects[1] = conn.display.object();
    conn.objects[2] = wl_registry.object();

    // Bind interfaces
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
                    if (std.mem.eql(u8, Wayland.Protocols.Wayland.Seat.InterfaceName, global.interface)) {
                        log.debug("Binding interface :: {s}", .{global.interface});
                        const wl_seat = try wl_registry.bind(&proxy, Wayland.Protocols.Wayland.Seat, .{
                            .name = global.name,
                            .interface_version = global.version,
                        });
                        log.debug("Bound wl_seat with :: {{ .name={d}, .id={d}, .version={d} }}", .{
                            global.name,
                            wl_seat.toInt(),
                            global.version,
                        });
                        conn.objects[wl_seat.toInt()] = wl_seat.object();
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

    // general event handling
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
        .wl_seat => |seat_event| switch (seat_event) {
            .capabilities => |seat_capabilities| {
                log.debug("wl_seat capabilities :: {{ .pointer={s}, .keyboard={s}, .touch={s} }}", .{
                    if (seat_capabilities.capabilities.pointer) "true" else "false",
                    if (seat_capabilities.capabilities.keyboard) "true" else "false",
                    if (seat_capabilities.capabilities.touch) "true" else "false",
                });
            },
            .name => |seat_name| {
                log.debug("wl_seat name :: {s}", .{seat_name.name});
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
