//-----------------------------------------------------------------------------
// Module Re-Exports
//-----------------------------------------------------------------------------

pub const Arena = @import("Arena.zig");
pub const Thread = @import("Thread.zig");

pub const entry = @import("entry.zig");
pub const math = @import("math.zig");
pub const time = @import("time.zig");

//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Module Toplevel Types
//-----------------------------------------------------------------------------

/// Requires backing buffer to be of a power of 2 length.
pub const RingBuffer = struct {
  buf: []u8,
  read: u32 = 0,
  write: u32 = 0,

  pub fn init_mmap(buf_size: usize) ?RingBuffer {
    const buffer_size = math.align_pow2(buf_size);
    const buffer = os.mem_reserve(buffer_size);

    if (os.mem_commit(buffer))
      return .{ .buf = buffer }
    else
      return null;
  }

  /// Assumes provided buffer to be of pow2 length
  pub fn init_backing(bytes: []u8) RingBuffer {
    AssertMsg(
      (bytes.len < MAX_SIZE) and
      math.is_pow2(bytes.len),
      "Buffer size must be power of 2, and fit within 2^31",
    );
    return .{ .buf = bytes };
  }

  pub fn size(rb: *RingBuffer) u32 {
    return rb.write -% rb.read;
  }

  pub fn empty(rb: *RingBuffer) bool {
    return rb.write == rb.read;
  }

  pub fn mask(rb: *RingBuffer, idx: u32) u32 {
    return idx & u32_(rb.buf.len - 1);
  }

  pub fn put(rb: *RingBuffer, bytes: []const u8) void {
    const write_idx = rb.mask(rb.write);
    defer rb.write +%= u32_(bytes.len);

    if (rb.buf[write_idx..].len > bytes.len) {
      @memcpy(
        rb.buf[write_idx..][0..bytes.len],
        bytes,
      );
    } else {
      const dst1 = rb.buf[write_idx..];
      @memcpy(
        dst1,
        bytes[0..dst1.len],
      );

      const remainder = bytes.len - dst1.len;
      @memcpy(
        rb.buf[0..remainder],
        bytes[dst1.len..][0..remainder],
      );
    }
  }

  const MAX_SIZE = math.maxInt(u31);
};

pub const ShiftBuffer = struct {
  buf: []u8,
  read: u32 = 0,
  write: u32 = 0,

  pub fn shift_back(sb: *ShiftBuffer) void {
    defer sb.read = 0;

    DebugAssert(!(sb.read > sb.write), "ShiftBuffer illegal indices on shift");

    const new_write_idx = sb.write - sb.read;
    @memmove(sb.buf[0..new_write_idx], sb.buf[sb.read..sb.write]);
    @memset(sb.buf[new_write_idx..], 0);
    sb.write = new_write_idx;
  }
};
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Module Toplevel Functions
//-----------------------------------------------------------------------------

pub inline fn StaticAssert(cond: bool, msg: []const u8) void {
  comptime {
    if (!cond)
      @compileError(msg);
  }
}

pub inline fn Assert(cond: bool) void {
  if (!cond)
    @trap();
}

pub inline fn AssertMsg(cond: bool, msg: []const u8) void {
  if (!cond)
    @panic(msg);
}

pub inline fn DebugAssert(cond: bool, msg: []const u8) void {
  switch (builtin.mode) {
    .Debug, .ReleaseSafe => {
      AssertMsg(cond, msg);
    },
    else => {},
  }
}

pub inline fn u32_(v: anytype) u32 {
  return switch (@typeInfo(@TypeOf(v))) {
    .int => @intCast(v),
    .comptime_int => @as(u32, v),
    .float, .comptime_float => @intFromFloat(v),
    .@"struct" => |struct_t| v: {
      if (struct_t.layout == .@"packed" and struct_t.backing_integer == u32)
        break :v @bitCast(v);
    },
    else => @compileError("Invalid type for u32"),
  };
}

pub inline fn u64_(v: anytype) u64 {
  return switch (@typeInfo(@TypeOf(v))) {
    .int => @intCast(v),
    .comptime_int => @as(u64, v),
    .float, .comptime_float => @intFromFloat(v),
    .@"struct" => |struct_t| v: {
      if (struct_t.layout == .@"packed" and struct_t.backing_integer == u64)
        break :v @bitCast(v);
    },
    .@"enum" => v: {
      break :v @intFromEnum(v);
    },
    else => @compileError("Invalid type for u64"),
  };
}

pub inline fn i32_(v: anytype) i32 {
  return switch (@typeInfo(@TypeOf(v))) {
    .int => @intCast(v),
    .comptime_int => @as(i32, v),
    .float, .comptime_float => @intFromFloat(v),
    else => @compileError("Invalid type for i32"),
  };
}

pub inline fn i64_(v: anytype) i64 {
  return switch (@typeInfo(@TypeOf(v))) {
    .int => @intCast(v),
    .comptime_int => @as(i64, v),
    .float, .comptime_float => @intFromFloat(v),
    else => @compileError("Invalid type for i64"),
  };
}

pub inline fn f32_(v: anytype) f32 {
  return switch (@typeInfo(@TypeOf(v))) {
    .int, .comptime_int => @floatFromInt(v),
    .float => @floatCast(v),
    .comptime_float => @as(f32, v),
    else => @compileError("Invalid type for f32"),
  };
}

pub inline fn f64_(v: anytype) f64 {
  return switch (@typeInfo(@TypeOf(v))) {
    .int, .comptime_int => @floatFromInt(v),
    .float => @floatCast(v),
    .comptime_float => @as(f64, v),
    else => @compileError("Invalid type for f64"),
  };
}

//-----------------------------------------------------------------------------

const os = @import("os");
const builtin = @import("builtin");