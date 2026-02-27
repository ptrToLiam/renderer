//-----------------------------------------------------------------------------
// Module Re-Exports
//-----------------------------------------------------------------------------

pub const Arena = @import("Arena.zig");
pub const Thread = @import("Thread.zig");

pub const entry = @import("entry.zig");
pub const math = @import("math.zig");
pub const time = @import("time.zig");
pub const casts = @import("casts.zig");

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

test "Ringbuffer" {
}

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

//-----------------------------------------------------------------------------
// Value-preserving cast quick helpers
//-----------------------------------------------------------------------------

pub inline fn u8_(v: anytype) u8 {
  return cast(u8, v);
}

pub inline fn i8_(v: anytype) i8 {
  return cast(i8, v);
}

pub inline fn u16_(v: anytype) u16 {
  return cast(u16, v);
}

pub inline fn i16_(v: anytype) i16 {
  return cast(i16, v);
}

pub inline fn u32_(v: anytype) u32 {
  return cast(u32, v);
}

pub inline fn i32_(v: anytype) i32 {
  return cast(i32, v);
}

pub inline fn u64_(v: anytype) u64 {
  return cast(u64, v);
}

pub inline fn i64_(v: anytype) i64 {
  return cast(i64, v);
}

pub inline fn u128_(v: anytype) u128 {
  return cast(u128, v);
}

pub inline fn i128_(v: anytype) i128 {
  return cast(i128, v);
}

pub inline fn usize_(v: anytype) usize {
  return cast(usize, v);
}

pub inline fn isize_(v: anytype) isize {
  return cast(isize, v);
}

pub inline fn f32_(v: anytype) f32 {
  return cast(f32, v);
}

pub inline fn f64_(v: anytype) f64 {
  return cast(f64, v);
}

//-----------------------------------------------------------------------------

comptime {
  // _ = @import("Arena.zig"); // should write some of my own tests for this
  _ = @import("Thread.zig");

  _ = @import("entry.zig");
  _ = @import("math.zig");
  _ = @import("time.zig");
  _ = @import("casts.zig");

  // @import("std").testing.refAllDecls(@This());
}

const cast = casts.cast;
const transmute = casts.transmute;

const os = @import("os");
const builtin = @import("builtin");