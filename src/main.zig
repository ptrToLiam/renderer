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
    _ = &proxy;

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
}

const log = std.log.scoped(.App);

// Begin tests
test {
    _ = Wayland;
}
