const std = @import("std");
const Arena = @import("arena");

const Protocols = @import("generated/wayland_protocols.zig");
const linux = @import("linux.zig");

pub const WireEvent = struct {
    header: Header,
    data: []const u8,

    const Header = packed struct(u64) {
        id: u32,
        op: u16,
        len: u16,
    };
};

pub const Connection = struct {
    handle: posix.fd_t = 0,
    addr: posix.sockaddr.un = .{ .path = @splat(0) },
    display: Protocols.Wayland.Display = .fromInt(0),
    ev_queue_in: EventQueue = .{},
    fd_queue_in: FdQueue = .{},
    idx_free_queue: IndexFreeQueue = .{},
    cur_idx: u32 = 2,
    objects: []Protocols.Object,
    in_buf: [2048]u8 = @splat(0),
    out_buf: [2048]u8 = @splat(0),
    out_buf_idx: usize = 0,
    fd_out_buf: [256]u8 = @splat(0),
    fd_out_buf_idx: usize = 0,
    fd_in_buf: [256]u8 = @splat(0),
    fd_in_buf_idx: usize = 0,

    pub fn init(arena: *Arena) !Connection {
        const temp = arena.temp();
        defer temp.end();
        const xdg_runtime_dir = posix.getenv("XDG_RUNTIME_DIR").?;
        const wayland_display = posix.getenv("WAYLAND_DISPLAY").?;

        const sock_path = try std.mem.join(temp.arena.allocator(), "/", &[_][]const u8{ xdg_runtime_dir, wayland_display });

        const opt_non_block = 0;
        const sockfd = try posix.socket(
            posix.AF.UNIX,
            posix.SOCK.STREAM | posix.SOCK.CLOEXEC | opt_non_block,
            0,
        );

        var addr: posix.sockaddr.un = addr: {
            var sock_addr: posix.sockaddr.un = .{
                .family = posix.AF.UNIX,
                .path = undefined,
            };

            if (sock_path.len + 1 > sock_addr.path.len) return error.SocketPathTooLong;

            @memset(&sock_addr.path, 0);
            @memcpy(sock_addr.path[0..sock_path.len], sock_path);
            break :addr sock_addr;
        };

        posix.connect(
            sockfd,
            @ptrCast(&addr),
            @as(posix.socklen_t, @intCast(@sizeOf(posix.sockaddr.un))),
        ) catch |err| {
            log.err("Failed to connect to Wayland Socket with err :: {s}", .{@errorName(err)});
            return err;
        };

        return .{
            .handle = sockfd,
            .addr = addr,
            .display = .fromInt(1),
            .objects = arena.push(Protocols.Object, 128),
        };
    }

    pub fn close(conn: *Connection) void {
        posix.close(conn.handle);
    }

    pub fn proxy(conn: *Connection) Proxy {
        return .{
            .ctx = @ptrCast(conn),
            .vtable = .{
                .msg_parse_fn = msg_parse,
                .msg_write_fn = msg_write,
                .next_id_fn = next_id,
                .obj_push_fn = push_object,
                .obj_destroy_fn = destroy_object,
            },
        };
    }

    pub fn event(conn: *Connection) ?Event {
        return conn.ev_queue_in.next();
    }

    pub fn flush(connection: *Connection) !void {
        if (connection.out_buf_idx > 0) {
            defer {
                @memset(connection.out_buf[0..], 0);
                connection.out_buf_idx = 0;
                @memset(connection.fd_out_buf[0..], 0);
                connection.fd_out_buf_idx = 0;
            }
            const iov = [_]posix.iovec_const{
                .{
                    .base = connection.out_buf[0..].ptr,
                    .len = connection.out_buf_idx,
                },
            };

            const msg: posix.msghdr_const = .{
                .name = null,
                .namelen = 0,
                .iov = &iov,
                .iovlen = iov.len,
                .control = @ptrCast(connection.fd_out_buf[0..].ptr),
                .controllen = connection.fd_out_buf_idx,
                .flags = 0,
            };

            _ = try posix.sendmsg(connection.handle, &msg, 0);
        }
    }

    pub fn load_events(conn: *Connection) !void {
        var iov = [_]posix.iovec{
            .{
                .base = conn.in_buf[0..].ptr,
                .len = conn.in_buf[0..].len,
            },
        };

        var message: posix.msghdr = .{
            .name = null,
            .namelen = 0,
            .iov = &iov,
            .iovlen = @intCast(iov.len),
            .control = conn.fd_in_buf[0..].ptr,
            .controllen = conn.fd_in_buf[conn.fd_in_buf_idx..].len,
            .flags = 0,
        };

        const rc = std.os.linux.recvmsg(
            conn.handle,
            &message,
            0,
        );

        if (rc > iov[0].len) {
            const err = std.posix.errno(rc);
            log.debug("rc :: {d}", .{@as(isize, @bitCast(rc))});
            log.err("Socket read failed with err :: {s}", .{@tagName(err)});
            return error.SocketReadFailed;
        } else {
            const bytes_read: u32 = @intCast(rc);
            log.debug("load_events :: bytes read :: {d}", .{bytes_read});
            // Control messages
            {
                log.debug("message controllen={d}", .{message.controllen});
                var cmsg_iter = linux.cmsghdr.iter(
                    conn.fd_in_buf[conn.fd_in_buf_idx..][0..message.controllen],
                );

                while (cmsg_iter.next()) |cmsg_header| {
                    if (cmsg_header.type == posix.SOL.SOCKET and
                        cmsg_header.level == linux.SCM_RIGHTS) {
                        log.debug("Found file descriptor of value :: {d}", .{cmsg_header.data(posix.fd_t).*});
                        conn.fd_queue_in.push(cmsg_header.data(posix.fd_t).*);
                    }
                }
            }

            // Standard wire events
            {
                var idx: u32 = 0;
                const event_buf = conn.in_buf[0..bytes_read];
                while (idx < bytes_read) {
                    const event_bytes = event_buf[idx..];

                    log.debug("idx :: {d}", .{idx});
                    if (event_bytes.len < @sizeOf(WireEvent.Header)) {
                        log.debug("Not enough space for header", .{});
                        break;
                    }

                    const header: WireEvent.Header = std.mem.bytesToValue(WireEvent.Header, event_bytes[0..@sizeOf(WireEvent.Header)]);

                    log.debug("Event header :: {{ .id={d}, .op={d}, .len={d} }}", .{
                        header.id,
                        header.op,
                        header.len,
                    });

                    const msg_size = header.len;
                    const data_end = idx + msg_size;

                    defer idx += msg_size;
                    if (data_end >= event_bytes.len) {
                        log.debug("Not enough space for data", .{});
                        break;
                    } else {
                        const parsed_event = try conn.objects[header.id].parse_msg(&conn.proxy(), header.op, event_bytes[@sizeOf(WireEvent.Header)..data_end]);
                        switch (parsed_event) {
                            .wl_registry => |registry_event| switch (registry_event) {
                                .global => |global| {
                                    log.debug("Received registry global :: {{ .name={d}, .interface={s}, .version={d} }}", .{
                                        global.name, global.interface, global.version,
                                    });
                                },
                                else => {},
                            },
                            else => {},
                        }
                    }
                }
            }
        }
    }

    fn next_id(noalias ctx: *anyopaque) u32 {
        const connection: *Connection = @ptrCast(@alignCast(ctx));
        return if (connection.idx_free_queue.next()) |free_idx|
            free_idx
        else idx: {
            defer connection.cur_idx += 1;
            break :idx connection.cur_idx;
        };
    }

    fn push_object(noalias ctx: *anyopaque, id: u32, noalias object: *Protocols.Object) void {
        const connection: *Connection = @ptrCast(@alignCast(ctx));
        connection.objects[id] = object.*;
    }

    fn destroy_object(noalias ctx: *anyopaque, id: u32) void {
        const connection: *Connection = @ptrCast(@alignCast(ctx));
        connection.idx_free_queue.push(id);
        connection.objects[id] = undefined;
    }

    fn msg_parse(noalias ctx: *anyopaque, args_out: []MessageArg, data: []const u8) !void {
        const connection: *Connection = @ptrCast(@alignCast(ctx));
        var offset: u32 = 0;
        for (args_out) |*arg| {
            switch (arg.*) {
                .fd => |*arg_fd| {
                    arg_fd.* = connection.fd_queue_in.next().?;
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

    fn msg_write(noalias ctx: *anyopaque, id: u32, op: u16, noalias args: []const ?MessageArg) Protocols.WriteError!void {
        const connection: *Connection = @ptrCast(@alignCast(ctx));
        var msg_len: u16 = @sizeOf(WireEvent.Header);
        for (args) |arg_opt| {
            if (arg_opt) |arg| switch (arg) {
                .int, .uint, .fixed, .object, .new_id, .@"enum" => msg_len += @sizeOf(u32),
                .string => |string_arg| msg_len += msg_str_len(string_arg),
                .array => |array_arg| msg_len += msg_arr_len(array_arg),
                .fd => {},
            } else {
                msg_len += @sizeOf(u32);
            }
        }

        if (connection.out_buf[connection.out_buf_idx..].len < msg_len) {
            connection.flush() catch |err| {
                log.err("Connection flush failed due to err :: {s}", .{@errorName(err)});
                return Protocols.WriteError.WriteFailed;
            };
        }

        const header: WireEvent.Header = .{
            .id = id,
            .op = op,
            .len = msg_len,
        };

        @memcpy(connection.out_buf[connection.out_buf_idx..][0..@sizeOf(WireEvent.Header)], std.mem.asBytes(&header));
        connection.out_buf_idx += @sizeOf(WireEvent.Header);
        for (args) |arg_opt| {
            if (arg_opt) |arg| arg: switch (arg) {
                .uint, .new_id, .object => |uint_arg| {
                    @memcpy(connection.out_buf[connection.out_buf_idx..][0..@sizeOf(u32)], std.mem.asBytes(&uint_arg));
                    connection.out_buf_idx += @sizeOf(u32);
                },
                .int => |int_arg| {
                    continue :arg .{ .uint = @bitCast(int_arg) };
                },
                .@"enum" => |*enum_arg| {
                    const u32_val: *const u32 = @ptrCast(enum_arg);
                    continue :arg .{ .uint = u32_val.* };
                },
                .fixed => |float_arg| {
                    const val: i32 = @intFromFloat(float_arg * 256);
                    continue :arg .{ .uint = @bitCast(val) };
                },
                .string => |string_arg| {
                    continue :arg .{ .array = string_arg[0 .. string_arg.len + 1] };
                },
                .array => |array_arg| {
                    const len: u32 = @intCast(msg_arr_len(array_arg));
                    @memcpy(connection.out_buf[connection.out_buf_idx..][0..@sizeOf(u32)], std.mem.asBytes(&len));
                    connection.out_buf_idx += @sizeOf(u32);
                    @memcpy(connection.out_buf[connection.out_buf_idx..][0..array_arg.len], array_arg);
                    const padding_byte_count = len - array_arg.len;
                    if (padding_byte_count > 0) {
                        @memset(connection.out_buf[connection.out_buf_idx..][0..padding_byte_count], 0);
                    }
                    connection.out_buf_idx += (len - @sizeOf(u32));
                },
                .fd => |fd_arg| {
                    const fd_cmsg: linux.cmsg(posix.fd_t) = .init(
                        posix.SOL.SOCKET,
                        linux.SCM_RIGHTS,
                        fd_arg,
                    );
                    @memcpy(connection.fd_out_buf[connection.fd_out_buf_idx..][0..@sizeOf(@TypeOf(fd_cmsg))], std.mem.asBytes(&fd_cmsg));
                    connection.fd_out_buf_idx += @sizeOf(@TypeOf(fd_cmsg));
                },
            } else {
                @memset(connection.out_buf[connection.out_buf_idx..][0..4], 0);
            }
        }
    }

    inline fn msg_str_len(str: [:0]const u8) u16 {
        return msg_arr_len(str[0 .. str.len + 1]);
    }

    inline fn msg_arr_len(arr: []const u8) u16 {
        return @intCast(round_up(@sizeOf(u32) + arr.len, @sizeOf(u32)));
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

    const EventQueue = struct {
        buf: [Size]Event = undefined,
        read: u32 = 0,
        write: u32 = 0,

        pub fn push(noalias queue: *EventQueue, ev: Event) void {
            const write_idx = queue.write % queue.buf.len;
            queue.buf[write_idx] = ev;
            queue.write += 1;
        }

        pub fn next(noalias queue: *EventQueue) ?Event {
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

    const FdQueue = struct {
        buf: [Size]posix.fd_t = @splat(0),
        read: u32 = 0,
        write: u32 = 0,

        pub fn push(noalias queue: *FdQueue, fd: posix.fd_t) void {
            const write_idx = queue.write % queue.buf.len;
            queue.buf[write_idx] = fd;
            queue.write += 1;
        }

        pub fn next(noalias queue: *FdQueue) ?posix.fd_t {
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

    const IndexFreeQueue = struct {
        buf: [QueueSize]u32 = [_]u32{0} ** QueueSize,
        first: usize = 0,
        last: usize = 0,

        const QueueSize = 32;

        pub fn push(q: *IndexFreeQueue, idx: u32) void {
            q.buf[(q.last % QueueSize)] = idx;
            q.last += 1;
        }
        pub fn next(q: *IndexFreeQueue) ?u32 {
            const res = blk: {
                if ((q.first == q.last) or
                    (q.buf[(q.first % QueueSize)] == 0))
                {
                    break :blk null;
                } else {
                    defer q.first += 1;
                    defer q.buf[(q.first % QueueSize)] = 0;
                    break :blk q.buf[(q.first % QueueSize)];
                }
            };
            return res;
        }
    };

    const MessageArg = Protocols.MessageArg;
    const Proxy = Protocols.Proxy;

    const log = std.log.scoped(.WaylandConnection);
};

pub const Event = Protocols.Event;

const posix = std.posix;
// Begin Tests
test "Proxied Event Parse" {
    var conn: Connection = .{};

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
    const registry: Protocols.Wayland.Registry = .fromInt(2);
    const registry_object = registry.object();
    const event = try registry_object.parse_msg(
        &proxy,
        wire_event.header.op,
        wire_event.data,
    );
    switch (event) {
        .wl_registry => |registry_event| switch (registry_event) {
            .global => |global| {
                try testing.expectEqual(@as(u32, 3), global.name);
                try testing.expect(std.mem.eql(u8, global.interface, "wl_seat"));
                try testing.expectEqual(@as(u32, 1), global.version);
            },
            else => {},
        },
        else => {},
    }
}

const testing = std.testing;
