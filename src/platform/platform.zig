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
      flags: Surface.Flags = .{},
    },
  ) Surface {
    const surface_handle = conn.handle.acquire_surface(
      arena,
      params.title,
      params.class,
      params.width,
      params.height,
      params.flags,
    );

    return .{
      .handle = surface_handle,
      .connection = conn,
      .width = params.width,
      .height = params.height,
      .flags = params.flags,
    };
  }

  /// Select Physical Vulkan Device
  pub fn select_vk_physical_device(
    conn: *Connection,
    vki: vk.InstanceProxy,
    required_extensions: []const [*:0]const u8,
  ) vk.PhysicalDevice {
    return conn.handle.select_vk_physical_device(
      vki,
      required_extensions,
    );
  }

  /// Create Vulkan Logical Device
  pub fn create_vk_logical_device(
    conn: *Connection,
    vki: vk.InstanceProxy,
    pdev: vk.PhysicalDevice,
    required_extensions: []const [*:0]const u8,
  ) struct { vk.Device, u32 } {
    return conn.handle.create_vk_logical_device(
      vki,
      pdev,
      required_extensions,
    );
  }

  pub fn flush(conn: *Connection) !void {
    return try conn.handle.flush();
  }

  const Handle = Impl.ConnectionHandle;
};

pub const EventList = struct {
  first: ?*Event,
  last: ?*Event,
  count: usize,

  pub fn push(noalias list: *EventList, noalias event: *Event) void {
    defer list.count += 1;
    if (list.last) |tail| {
      tail.next = event;
      list.last = event;
    } else {
      list.first = event;
      list.last = event;
    }
  }

  pub const empty: EventList = .{
    .first = null,
    .last = null,
    .count = 0,
  };
};

pub const Key = enum (u32) {
  invalid = math.maxInt(u32),
  none = 0,
  a,
  b,
  c,
  d,
  e,
  f,
  g,
  h,
  i,
  j,
  k,
  l,
  m,
  n,
  o,
  p,
  q,
  r,
  s,
  t,
  u,
  v,
  w,
  x,
  y,
  z,
  _,

  pub fn fromXkb(sym: wayland.Xkb.KeySym) Key {
    return switch (sym) {
      .a => .a,
      .b => .b,
      .c => .c,
      .d => .d,
      .e => .e,
      .f => .f,
      .g => .g,
      .h => .h,
      .i => .i,
      .j => .j,
      .k => .k,
      .l => .l,
      .m => .m,
      .n => .n,
      .o => .o,
      .p => .p,
      .q => .q,
      .r => .r,
      .s => .s,
      .t => .t,
      .u => .u,
      .v => .v,
      .w => .w,
      .x => .x,
      .y => .y,
      .z => .z,
      else => .invalid,
    };
  }
  pub fn fromInt(n: u32) Key {
    return @enumFromInt(n);
  }
};

pub const MouseButton = enum (u32) {
  none = 0,
  _,

  pub fn fromInt(n: u32) MouseButton {
    return @enumFromInt(n);
  }
};

pub const ButtonState = enum(u32) {
  release = 0,
  press = 1,
  repeat = 2,

  invalid = 1024,
  pub fn fromInt(n: u32) ButtonState {
    return @enumFromInt(n);
  }
};

pub const Event = struct {
  next: ?*Event = null,
  prev: ?*Event = null,
  timestamp_us: u64,
  type: EventType = .none,
  surface_handle: Surface.Handle,
  modifiers: Modifiers = .none,
  key: Key = .none,
  button: MouseButton = .none,
  repeat_count: u32 = 0,
  pos: math.Vec2f32 = .{ .x = 0 , .y = 0 },
  delta: math.Vec2f32 = .{ .x = 0, .y = 0 },

  pub const nil: Event = .{
    .next = null,
    .prev = null,
    .timestamp_us = undefined,
    .type = .none,
    .surface_handle = .nil,
    .modifiers = .{},
    .key = .none,
    .repeat_count = undefined,
    .pos = undefined,
    .delta = undefined,
  };

  const EventType = enum {
    none,
    press,
    release,
    text,
    mouse_move,
    mouse_scroll,
    surface_unfocus,
    surface_focus,
    surface_close,
    surface_resize,
    buffer_release,
  };

  const Modifiers = packed struct (u32) {
    ctrl: bool = false,
    shift: bool = false,
    alt: bool = false,
    __reserved_bits: u29 = 0,

    pub const none: Modifiers = .{};
  };
};

pub const Surface = struct {
  handle: Handle,
  connection: *Connection,
  width: i32,
  height: i32,
  flags: Flags = .{},

  pub fn release(surface: *const Surface) void {
    _ = surface;
  }

  pub const nil: Surface = .{ .handle = .nil, .width = 0, .height = 0 };

  pub const Flags = packed struct (u32) {
    fullscreen: bool = false,
    maximized: bool = false,
    minimized: bool = false,
    resize: bool = false,

    __reserved_bits: u28 = 0,
  };

  const Handle = Impl.SurfaceHandle;
};

pub const Swapchain = struct {
  handle: Handle,

  vk_ctx: *VkContext,
  surface: *Surface,
  buffers: []SwapchainBuffer,
  buffer_states: []SwapchainBuffer.State,
  submit_queue: []u32,
  submit_head: u32 = 0,
  submit_tail: u32 = 0,
  acquired_image: ?u32 = null,
  pending_resize: ?math.Vec2u32 = null,

  pub fn alloc(
    arena: *Arena,
    vk_ctx: *VkContext,
    surface: *Surface,
    width: u32,
    height: u32,
    format: gfx.Format,
    buffer_count: u32,
  ) !Swapchain {
    const connection_handle = &surface.connection.handle;
    const submit_queue = arena.push(u32, buffer_count);
    const buffers = arena.push(SwapchainBuffer, buffer_count);
    const buffer_states = arena.push(SwapchainBuffer.State, buffer_count);
    @memset(buffer_states, .available);

    const handle: Handle = try .alloc(
      connection_handle,
      vk_ctx,
      width,
      height,
      format,
      buffers,
    );

    return .{
      .handle = handle,
      .vk_ctx = vk_ctx,
      .surface = surface,
      .buffers = buffers,
      .buffer_states = buffer_states,
      .submit_queue = submit_queue,
    };
  }

  /// Recreate Swapchain
  pub fn recreate(
    sc: *Swapchain,
    width: u32,
    height: u32,
    format: gfx.Format,
  ) !void {
    try sc.handle.recreate(
      sc.vk_ctx,
      width,
      height,
      format,
      sc.buffers,
    );
  }

  /// Mark Swapchain In Need Of Recreation
  pub fn mark_outdated(sc: *Swapchain, width: u32, height: u32) void {
    sc.pending_resize = .{ .x = width, .y = height };
  }

  /// Acquire Image For Use
  pub fn acquire_image(sc: *Swapchain) ?*VkContext.Image {
    for (sc.buffer_states, 0..) |state, idx| {
      if (state == .available) {
        sc.buffer_states[idx] = .busy;
        sc.acquired_image = u32_(idx);
        return &sc.buffers[idx].image;
      }
    }
    return null;
  }

  /// Present Acquired Buffer To Surface
  pub fn present(sc: *Swapchain) void {
    const idx = sc.acquired_image orelse return;
    sc.handle.present(&sc.surface.handle, &sc.buffers[idx]);
    sc.buffer_states[idx] = .submitted;
    sc.acquired_image = null;

    sc.submit_queue[sc.submit_tail % sc.buffers.len] = idx;
    sc.submit_tail +%= 1;
  }

  /// Make Released Buffer Available For Reuse
  pub fn release_buffer(sc: *Swapchain) void {
    if (sc.submit_tail == sc.submit_head) return;
    const idx = sc.submit_queue[sc.submit_head % sc.buffers.len];
    sc.submit_head +%= 1;
    sc.buffer_states[idx] = .available;
  }

  /// Destroy Swapchain Data
  pub fn release(sc: *Swapchain) void {
    sc.handle.destroy_buffers(sc.vk_ctx, sc.buffers);
  }

  const Handle = Impl.SwapchainHandle;
};

pub const SwapchainBuffer = struct {
  handle: Handle,
  image: VkContext.Image,

  pub const State = enum (u32) {
    available,
    busy,
    submitted,
  };
  const Handle = Impl.SwapchainBufferHandle;
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

/// Per-Platform implementaions of platform-layer operations
const Impl = switch (Target) {
  .wayland => struct {
    pub const ConnectionHandle = wayland.Connection;
    pub const SurfaceHandle = wayland.Surface;
    pub const SwapchainHandle = wayland.Swapchain;
    pub const SwapchainBufferHandle = wayland.SwapchainBuffer;
  },
  .win32 => struct {
    pub const ConnectionHandle = win32.Connection;
    pub const SurfaceHandle = win32.Window;
    pub const SwapchainHandle = win32.Swapchain;
  },
  else => os.UnsupportedPlatformError(),
};

const Arena = base.Arena;

const i32_ = base.i32_;
const u32_ = base.u32_;
const cast = casts.cast;
const tramsute = casts.transmute;

const linux = os.linux;
const casts = base.casts;
const math = base.math;
const Drm = gfx.Drm;

pub const win32 = @import("win32.zig");
pub const wayland = @import("wayland.zig");
pub const gfx = @import("gfx/gfx.zig");
pub const VkContext = @import("VkContext.zig");

const os = @import("os");
const base = @import("base");
const vk = @import("vulkan");

const std = @import("std");
const builtin = @import("builtin");
