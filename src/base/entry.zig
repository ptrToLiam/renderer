pub fn primary(@"fn": anytype, args: anytype) void {
  // setup
  Thread.ctx_init();
  defer Thread.ctx_release();
  Thread.set_name("main_thread");
  // TODO: Add OS/System info init here

  base.program_start_time = time.microTimestamp();

  @call(.auto, @"fn", args);
}

pub fn supplementary(@"fn": anytype, args: anytype) void {
  Thread.ctx_init();
  defer Thread.ctx_release();
  @call(.auto, @"fn", args);
}

const Thread = @import("Thread.zig");
const time = @import("time.zig");
const base = @import("base.zig");

const std = @import("std");
