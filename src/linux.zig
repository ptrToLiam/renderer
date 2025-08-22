const std = @import("std");

const Arena = @import("arena");

pub const Context = struct {
    scratch_arenas: [2]*Arena = undefined,

    pub fn init() Context {
    }

    pub fn deinit(ctx: *const Context) void {
        for (ctx.scratch_arenas) |scratch| {
            scratch.release();
        }
    }
};

pub const Thread = struct {
    pub threadlocal var scratch_arenas: [2]*Arena = undefined;
    thread: std.Thread,

    pub fn spawn(config: SpawnConfig, function: anytype, args: anytype) SpawnError!Thread {
        return .{
            .thread = try std.Thread.spawn(config, thread_entry, .{ function, args }),
        };
    }

    pub fn join(thread: *const Thread) void {
        ctx_deinit();
        thread.thread.join();
    }

    pub fn scratch_begin(comptime N: comptime_int, conflicts: [N]*Arena) ?Arena.Temp {
        var result: ?Arena.Temp = null;
        outer: for (scratch_arenas) |scratch| {
            result = scratch.temp();
            for (conflicts) |conflict| {
                if (scratch == conflict) {
                    result = null;
                    break :outer;
                }
            }
        }

        return result;
    }

    pub fn ctx_init() void {
        for (0..scratch_arenas.len) |idx| {
            scratch_arenas[idx] = .init(.default);
        }
    }
    pub fn ctx_deinit() void {
        for (scratch_arenas) |scratch| {
            scratch.release();
        }
    }

    fn thread_entry(function: anytype, args: anytype) void {
        ctx_init();

        @call(.auto, function, args);
    }

    const SpawnError = std.Thread.SpawnError;
    const SpawnConfig = std.Thread.SpawnConfig;
};

/// Create container type for control messages
pub fn cmsg(comptime T: type) type {
    const msg_len = cmsghdr.msg_len(@sizeOf(T));
    const padded_bit_count = cmsghdr.padding_bits(msg_len, @bitSizeOf(T));

    return packed struct {
        /// Control message header
        header: cmsghdr,
        /// Data we actually want
        data: T,

        /// padding to reach data alignment
        __padding: @Type(.{
            .int = .{
                .bits = padded_bit_count,
                .signedness = .unsigned,
            },
        }) = 0,

        pub fn init(level: i32, @"type": i32, data: T) cmsg_t {
            return .{
                .header = .{
                    .len = msg_len,
                    .level = level,
                    .type = @"type",
                },
                .data = data,
            };
        }

        pub const Size = @sizeOf(cmsg_t);

        const cmsg_t = @This();
    };
}

const CmsgIterator = struct {
    buf: []const u8,
    idx: usize,

    const Iterator = @This();

    pub fn first(iter: *Iterator) ?cmsghdr {
        const result: ?cmsghdr = if (iter.buf[iter.idx..].len > @sizeOf(cmsghdr))
            std.mem.bytesToValue(cmsghdr, iter.buf[iter.idx..][0..@sizeOf(cmsghdr)])
        else
            null;

        return result;
    }

    pub fn next(iter: *Iterator) ?cmsghdr {
        const result: ?cmsghdr = if (iter.buf[iter.idx..].len > @sizeOf(cmsghdr)) hdr: {
            const hdr = std.mem.bytesToValue(cmsghdr, iter.buf[iter.idx..][0..@sizeOf(cmsghdr)]);
            iter.idx += cmsghdr.__msg_len(&hdr);

            if (iter.idx >= iter.buf.len)
                iter.idx = iter.buf.len - 1;

            break :hdr hdr;
        } else null;

        return result;
    }

    pub fn reset(iter: *Iterator) void {
        iter.idx = 0;
    }
};

pub const cmsghdr = packed struct {
    /// Data byte count, including header
    len: usize,
    /// Originating protocol
    level: i32,
    /// Protocol-specific type
    type: i32,

    pub fn iter(buf: []const u8) CmsgIterator {
        return .{
            .buf = buf,
            .idx = 0,
        };
    }

    pub fn data(ptr: *const cmsghdr, comptime T: type) *const T {
        const buf: [*]const u8 = @ptrCast(@alignCast(ptr));

        return @ptrCast(@alignCast(buf[Size..][0..@sizeOf(T)].ptr));
    }

    /// Calculate length of control message given data of length `len`
    ///
    /// Port of musl libc's CMSG_LEN macro
    ///
    /// Macro Definition:
    /// #define CMSG_LEN(len)   (CMSG_ALIGN (sizeof (struct cmsghdr)) + (len))
    pub inline fn msg_len(len: usize) usize {
        return msg_align(cmsghdr.Size + len);
    }

    pub inline fn __msg_len(msg: *const cmsghdr) usize {
        return ((msg.len + @sizeOf(c_ulong) - 1) & ~@as(usize, (@sizeOf(c_ulong) - 1)));
    }

    /// Get the number of bits needed to pad out the message
    pub inline fn padding_bits(len: usize, data_t_size: usize) usize {
        return (8 * len) - (@bitSizeOf(cmsghdr) + data_t_size);
    }

    /// Calculate alignment of control message of length `len` to cmsghdr size
    ///
    /// Port of musl libc's CMSG_ALIGN macro
    ///
    /// Macro Definition:
    /// #define CMSG_ALIGN(len) (((len) + sizeof (size_t) - 1) & (size_t) ~(sizeof (size_t) - 1))
    inline fn msg_align(len: usize) usize {
        return (((len) + @sizeOf(size_t) - 1) & ~@as(usize, (@sizeOf(size_t) - 1)));
    }

    const size_t = usize;
    const Size = @sizeOf(@This());
};

pub const SCM_RIGHTS = 0x01;
pub const SCM_CREDENTIALS = 0x02;
