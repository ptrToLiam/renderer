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
    return conn.handle.acquire_surface(
      arena,
      params.title,
      params.class,
      params.width,
      params.height,
      params.flags,
    );
  }

  pub fn check_surface_formats(
    conn: *Connection,
    surface: Surface,
  ) void {
    conn.handle.check_surface_formats(surface.handle);
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
  none = 0,
};

pub const Event = struct {
  next: ?*Event = null,
  prev: ?*Event = null,
  timestamp_us: u64,
  type: EventType = .none,
  surface_handle: Surface.Handle,
  modifiers: Modifiers = .none,
  key: Key = .none,
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

    pub const none: Modifiers = .{};
  };
};

pub const Surface = struct {
  handle: Handle,
  width: i32,
  height: i32,
  flags: Flags = .{},

  pub fn release(surface: *Surface) void {
    _ = surface;
  }

  pub const nil: Surface = .{ .handle = .nil, .dimensions = undefined };

  pub const Flags = packed struct (u32) {
    fullscreen: bool = false,
    maximized: bool = false,
    minimized: bool = false,
    resize: bool = false,

    __reserved_bits: u28 = 0,
  };

  const Handle = Impl.SurfaceHandle;
};

pub const OffscreenBuffer = struct {
  image: vk.Image,
  device_memory: vk.DeviceMemory,
  memory_fd: i32,
  drm_modifier: drm.Modifier = .fromInt(0),
  width: u32,
  height: u32,
  format: vk.Format,
  stride: u32,
  offset: u32,

  pub fn create(
    dev_wrapper: vk.DeviceWrapper,
    dev: vk.Device,
    vki: vk.InstanceWrapper,
    pdev: vk.PhysicalDevice,
    width: u32,
    height: u32,
    format: vk.Format,
    mod: drm.Modifier,
  ) OffscreenBuffer {
    const ext_mem_image_info: vk.ExternalMemoryImageCreateInfo = .{
      .handle_types = .{ .dma_buf_bit_ext = true },
    };

    const image_info: vk.ImageCreateInfo = .{
      .p_next = &ext_mem_image_info,
      .flags = .{},
      .image_type = .@"2d",
      .format = format,
      .extent = .{
        .width = width,
        .height = height,
        .depth = 1,
      },
      .mip_levels = 1,
      .array_layers = 1,
      .samples = .{ .@"1_bit" = true },
      .tiling = .optimal,
      .usage = .{
        .color_attachment_bit = true,
        .transfer_src_bit = true,
      },
      .sharing_mode = .exclusive,
      .initial_layout = .undefined,
    };

    const image = dev_wrapper.createImage(
      dev,
      &image_info,
      null,
    ) catch unreachable;

    const mem_reqs = dev_wrapper.getImageMemoryRequirements(
      dev,
      image,
    );
    const mem_props = vki.getPhysicalDeviceMemoryProperties(pdev);

    var mem_image_type_idx: u32 = math.maxInt(u32);
    for (0..mem_props.memory_type_count) |i| {
        if ((mem_reqs.memory_type_bits & (base.u32_(1) << cast(u5, i))) != 0 and
            mem_props.memory_types[i].property_flags.device_local_bit) {
            // or host_visible for testing
            mem_image_type_idx = base.u32_(i);
            break;
        }
    }
    if (mem_image_type_idx == std.math.maxInt(u32))
      @panic("no suitable memory type");

    const dedicated_alloc_info: vk.MemoryDedicatedAllocateInfo = .{
      .image = image,
    };

    const export_info: vk.ExportMemoryAllocateInfo = .{
      .handle_types = .{ .dma_buf_bit_ext = true },
      .p_next = @ptrCast(&dedicated_alloc_info),
    };

    const alloc_info: vk.MemoryAllocateInfo = .{
      .p_next = @ptrCast(&export_info),
      .allocation_size = mem_reqs.size,
      .memory_type_index = mem_image_type_idx,
    };

    const device_mem = dev_wrapper.allocateMemory(
      dev,
      &alloc_info,
      null,
    ) catch unreachable;

    dev_wrapper.bindImageMemory(
      dev,
      image,
      device_mem,
      0,
    ) catch unreachable;

    const fd_info: vk.MemoryGetFdInfoKHR = .{
      .memory = device_mem,
      .handle_type = .{ .dma_buf_bit_ext = true },
    };

    const fd = dev_wrapper.getMemoryFdKHR(
      dev,
      &fd_info,
    ) catch unreachable;

    // var mod_props: vk.ImageDrmFormatModifierPropertiesEXT = .{
    //   .drm_format_modifier = mod.toInt(),
    // };

    // dev_wrapper.getImageDrmFormatModifierPropertiesEXT(
    //   dev,
    //   image,
    //   &mod_props
    // ) catch unreachable;

    const sub: vk.ImageSubresource = .{
      .aspect_mask = .{ .color_bit = true },
      .mip_level = 0,
      .array_layer = 0,
    };
    
    const layout = dev_wrapper.getImageSubresourceLayout(
      dev,
      image,
      &sub,
    );

    return .{
      .image = image,
      .device_memory = device_mem,
      .memory_fd = fd,
      .drm_modifier = mod,
      .width = width,
      .height = height,
      .format = format,
      .stride = base.u32_(layout.row_pitch),
      .offset = base.u32_(layout.offset),
    };
  }
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

const cast = casts.cast;
const tramsute = casts.transmute;

const linux = os.linux;
const casts = base.casts;
const math = base.math;
const drm = gfx.Drm;

pub const win32 = @import("win32.zig");
pub const wayland = @import("wayland.zig");
pub const gfx = @import("gfx/gfx.zig");

const os = @import("os");
const base = @import("base");
const vk = @import("vulkan");

const std = @import("std");
const builtin = @import("builtin");
