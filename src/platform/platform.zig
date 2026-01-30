/// Needed for wayland and X11... Unsure yet as to Win32/Cocoa
pub const Connection = struct {
  handle: Handle,

  pub fn open(arena: *Arena, env: os.Environ) Connection {
    return .{
      .handle = .open(arena, env),
    };
  }

  pub fn close(conn: *Connection) void {
    conn.handle.close();
  }

  /// Poll/load in available events
  pub fn poll_events(conn: *Connection) void {
    _ = conn;
  }

  /// Fetch next available event
  pub fn get_event(conn: *Connection) ?Event {
    _ = conn;
  }

  const Handle = Impl.ConnectionHandle;
};

pub const Event = union (enum) {

};

pub const Surface = struct {
  handle: Handle,
  dimensions: math.Vec2i32,

  const Handle = Impl.SurfaceHandle;
};

pub const TargetOptions = enum {
  wayland,
  win32, // Not Yet Implemented...
};

pub const Target = switch (os.Target.tag) {
  .linux => .wayland,
  .windows => .win32,
  else => os.UnsupportedPlatformError(),
};

const Impl = switch (Target) {
  .wayland => struct {
    pub const ConnectionHandle = wayland.Connection;
    pub const SurfaceHandle = wayland.Surface;
  },
  .win32 => struct {
    pub const ConnectionHandle = win32.Connection;
    pub const SurfaceHandle = win32.Window;
  },
  else => os.UnsupportedPlatformError(),
};

const Arena = base.Arena;

const linux = os.linux;
const math = base.math;

const win32 = @import("win32.zig");
const wayland = @import("wayland.zig");

const os = @import("os");
const base = @import("base");

const std = @import("std");
const builtin = @import("builtin");
