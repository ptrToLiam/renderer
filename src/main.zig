const std = @import("std");
const renderer = @import("renderer");

const WaylandProtocols = @import("generated/wayland_protocols.zig");
const WaylandHeader = packed struct(u64) {
    id: u32,
    op: u16,
    msg_len: u16,
};

const WireEvent = struct {
    header: WaylandHeader,
    data: []const u8,
};

const Connection = struct {
    fd_queue: FdQueue = .{},

    pub fn proxy(conn: *const Connection) WaylandProtocols.Proxy {
        return .{
            .ctx = @ptrCast(conn),
            .vtable = .{
                .msg_parse_fn = msg_parse,
                .msg_write_fn = undefined,
            },
        };
    }

    fn msg_parse(noalias ctx: *const anyopaque, args_out: []WaylandProtocols.MessageArg, data: []const u8) !void {
        const connection: *Connection = @constCast(@ptrCast(@alignCast(ctx)));
        var offset: u32 = 0;
        for (args_out) |*arg| {
            switch (arg.*) {
                .fd => |*arg_fd| {
                    arg_fd.* = connection.fd_queue.next().?;
                },
                .uint, .object, .new_id => |*uint_arg| {
                    uint_arg.* = std.mem.bytesToValue(u32, data[offset..][0..4]);
                    offset += 4;
                },
                .int => |*int_arg| {
                    int_arg.* = std.mem.bytesToValue(i32, data[offset..][0..4]);
                    offset += 4;
                },
                .@"enum" => |*enum_arg| {
                    const int_ptr: *u32 = @ptrCast(enum_arg);
                    int_ptr.* = std.mem.bytesToValue(u32, data[offset..][0..4]);
                    offset += 4;
                },
                .fixed => |*fixed_arg| {
                    const int_val = std.mem.bytesToValue(i32, data[offset..][0..4]);
                    offset += 4;
                    fixed_arg.* = @as(f32, @floatFromInt(int_val)) / 256;
                },
                .string => |*string_arg| {
                    const str_len = std.mem.bytesToValue(u32, data[offset..][0..4]);
                    offset += 4;
                    const rounded_len = round_up(str_len, 4);
                    string_arg.* = @ptrCast(data[offset..][0 .. str_len - 1 :0]);
                    offset += rounded_len;
                },
                .array => |*array_arg| {
                    const arr_len = std.mem.bytesToValue(u32, data[offset..][0..4]);
                    offset += 4;
                    const rounded_len = round_up(arr_len, 4);
                    array_arg.* = data[offset..][0..arr_len];
                    offset += rounded_len;
                },
            }
        }
    }

    fn msg_write(ctx: *anyopaque, id: u32, op: u16, args: []WaylandProtocols.MessageArg) !void {
        _ = ctx;
        _ = id;
        _ = op;
        _ = args;
    }

    inline fn round_up(val: anytype, mul: @TypeOf(val)) @TypeOf(val) {
        if (val == 0)
            return 0
        else
            return if (val % mul == 0)
                val
            else
                val + (mul - (val % mul));
    }

    const FdQueue = struct {
        buf: [Size]std.posix.fd_t = @splat(0),
        read: u32 = 0,
        write: u32 = 0,

        pub fn push(noalias queue: *FdQueue, fd: std.posix.fd_t) void {
            const write_idx = queue.write % queue.buf.len;
            queue.buf[write_idx] = fd;
            queue.write += 1;
        }

        pub fn next(noalias queue: *FdQueue) ?std.posix.fd_t {
            if (queue.read != queue.write) {
                defer queue.read += 1;

                const read_idx = queue.read % queue.buf.len;
                return queue.buf[read_idx];
            } else {
                return null;
            }
        }

        pub const Size = 64;
    };
};

pub fn main() !void {
    const conn: Connection = .{};

    const name: u32 = 3;
    const name_bytes = std.mem.asBytes(&name);
    const strlen: u32 = 8;
    const strlen_bytes = std.mem.asBytes(&strlen);
    const ver: u32 = 1;
    const ver_bytes = std.mem.asBytes(&ver);

    const wire_event = .{
        .header = .{
            .id = 2,
            .op = 0,
            .msg_len = 9,
        },
        .data = &.{
            name_bytes[0],   name_bytes[1],   name_bytes[2],   name_bytes[3],
            strlen_bytes[0], strlen_bytes[1], strlen_bytes[2], strlen_bytes[3],
            'w',             'l',             '_',             's',
            'e',             'a',             't',             '\x00',
            ver_bytes[0],    ver_bytes[1],    ver_bytes[2],    ver_bytes[3],
        },
    };

    const proxy = conn.proxy();
    const registry: WaylandProtocols.Wayland.Registry = .{ .id = 2 };
    const registry_object = registry.object();
    const event = try registry_object.parse_msg(
        &proxy,
        wire_event.header.op,
        wire_event.data,
    );
    switch (event) {
        .wl_registry => |registry_event| switch (registry_event) {
            .global => |global| {
                std.log.info("global {{ .name={d}, .interface={s}, .version={d} }}", .{
                    global.name,
                    global.interface,
                    global.version,
                });
            },
            else => {},
        },
        else => {},
    }
}
