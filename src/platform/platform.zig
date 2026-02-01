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

  pub fn acquire_surface(conn: *Connection) Surface {
    _ = conn;
  }

  pub fn get_events(conn: *Connection, arena: *Arena) EventList {
    return conn.handle.get_events(arena);
  }

  const Handle = Impl.ConnectionHandle;
};

pub const EventList = struct {
  first: ?*Event,
  last: ?*Event,
  count: usize,

  pub const empty: EventList = .{
    .first = null,
    .last = null,
    .count = 0,
  };
};

pub const Key = enum {
};

pub const Event = struct {
  next: ?*Event,
  prev: ?*Event,
  timestamp_us: u64,
  type: EventType = .none,
  surface_handle: Surface.Handle,
  modifiers: Modifiers,
  key: Key,
  repeat_count: u32,
  pos: math.Vec2f32,
  delta: math.Vec2f23,

  pub const nil: Event = .{
    .next = null,
    .prev = null,
    .timestamp_us = undefined,
    .type = .none,
    .surface_handle = .nil,
    .modifiers = .{},
    .key = .nil,
    .repeat_count = undefined,
    .pos = undefined,
    .delta = undefined,
  };

  const EventType = enum {
    none,
    press,
    release,
    mouse_move,
    text,
    scroll,
    surface_unfocus,
    surface_focus,
    surface_close,
  };

  const Modifiers = packed struct (u32) {
    ctrl: bool = false,
    shift: bool = false,
    alt: bool = false,
    __reserved_bits: u29 = 0,
  };
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
