/// Needed for wayland and X11... Unsure yet as to Win32/Cocoa
pub const Connection = struct {
  handle: Handle,

  /// Open client connection to graphics server
  pub fn open(arena: *Arena, env: os.Environ) Connection {
    return .{
      .handle = .open(arena, env),
    };
  }

  /// Close client connection to graphics server
  pub fn close(conn: *Connection) void {
    conn.handle.close();
  }

  /// Fetch available platform events
  pub fn get_events(conn: *Connection, arena: *Arena, surface: *Surface) EventList {
    return conn.handle.get_events(arena, &surface.handle);
  }

  /// Obtain a graphical surface to draw on
  pub fn acquire_surface(
    conn: *Connection,
    arena: *Arena,
    params: struct {
      title: [:0]const u8,
      class: [:0]const u8,
      width: i32,
      height: i32,
    },
  ) Surface {
    return conn.handle.acquire_surface(
      arena,
      params.title,
      params.class,
      params.width,
      params.height,
    );
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
  delta: math.Vec2f32,

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

  pub fn release(surface: *Surface) void {
    _ = surface;
  }

  pub const nil: Surface = .{ .handle = .nil, .dimensions = undefined };
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
