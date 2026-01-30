/// Needed for wayland and X11... Unsure yet as to Win32/Cocoa
pub const Connection = struct {
  handle: Handle,

  pub const Handle =
};

pub const Surface = struct {
  handle: Handle,
  dimensions:
};

pub const TargetPlatformOptions = enum {
  wayland,
  win32, // Not Yet Implemented...
};

pub const TargetPlatform = switch (builtin.target.os) {
  .linux => .wayland,
  .windows => .win32,
  else => os.UnsupportedPlatformError(),
};

const linux = os.linux;
const Arena = base.Arena;

const wayland = @import("wayland.zig");

const os = @import("os");
const base = @import("base");

const std = @import("std");
const builtin = @import("builtin");
