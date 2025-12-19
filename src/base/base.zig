pub const Arena = @import("Arena.zig");
pub const math = @import("math.zig");
pub const Thread = @import("Thread.zig");


/// Requires backing buffer to be of a power of 2 length.
pub const RingBuffer = struct {
  buf: []u8,
  read: u32 = 0,
  write: u32 = 0,
  
  pub fn read_idx(rb: *RingBuffer) u32 {
    return (rb.read & rb.buf.len);
  }
  
  pub fn write_idx(rb: *RingBuffer) u32 {
    return (rb.write & rb.buf.len);
  }
  pub fn inc_read(rb: *RingBuffer) void {
    rb.read +%= 1;
  }
  pub fn inc_write(rb: *RingBuffer) void {
    rb.write +%= 1;
  }
};

pub const ShiftBuffer = struct {
  buf: []u8,
  read: u32 = 0,
  write: u32 = 0,
  
  pub fn shift_back(sb: *ShiftBuffer) void {
    defer sb.read = 0;
    
    DebugAssert(!(sb.read > sb.write), "ShiftBuffer illegal indices on shift");
    
    const new_write_idx = sb.write - sb.read;
    @memmove(sb.buf[sb.read..sb.write], sb.buf[0..new_write_idx]);
    sb.write = new_write_idx;
  }
};

pub inline fn StaticAssert(cond: bool, msg: []const u8) void {
  comptime {
    if (!cond)
      @compileError(msg);
  }
}

pub inline fn DebugAssert(cond: bool, msg: []const u8) void {
  switch (builtin.mode) {
    .Debug, .ReleaseSafe => {
      if (!cond)
        @panic(msg);
    },
    else => {},
  }
}

const builtin = @import("builtin");