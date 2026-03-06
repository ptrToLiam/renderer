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
    const surface = conn.handle.acquire_surface(
      arena,
      params.title,
      params.class,
      params.width,
      params.height,
      params.flags,
    );
    return surface;
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
  width: i32,
  height: i32,
  flags: Flags = .{},

  pub fn release(surface: *const Surface) void {
    _ = surface;
  }

  pub fn attach_image(noalias surface: *const Surface, noalias image: *const Image) void {
    surface.handle.attach_image(image);
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

pub const Swapchain = struct {
  handle: Handle,

  surface: *Surface,
  buffers: []SwapchainBuffer,
  buffer_states: []SwapchainBuffer.State,
  submit_queue: []u32,
  submit_head: u32,
  submit_tail: u32,
  acquired_image: ?u32,
  pending_resize: ?math.Vec2u32,

  pub fn create(
    vk_ctx: *VkContext,
    surface: *Surface,
  ) Swapchain {
  }

  const Handle = Impl.SwapchainHandle;
};

pub const SwapchainBuffer = struct {
  handle: Handle,
  image: VkContext.Image,

  const Handle = Impl.SwapchainBufferHandle;
};
pub const Swapchain = struct {
  image_states: []Image.State,
  surface: *Surface,
  acquired_image: ?u32,
  pending_resize: ?math.Vec2u32,

  submit_queue: []u32,
  submit_head: u32 = 0,
  submit_tail: u32 = 0,

  pub fn create(
    arena: *Arena,
    surface: *Surface,
    vk_ctx: *VkContext,
    width: u32,
    height: u32,
    format: gfx.Format,
    image_count: usize,
  ) Swapchain {
    var images = arena.push(Image, image_count);
    var image_states = arena.push(Image.State, image_count);
    const submit_queue = arena.push(u32, image_count);

    const drm_modifier = surface.handle.connection.select_drm_modifier_for_format(format);
    for (0..image_count) |idx| {
      images[idx] = .alloc(
        vki,
        vkd,
        vk_pdev,
        surface,
        width,
        height,
        format,
        .{
          .fd = -1,
          .drm_modifier = drm_modifier,
          .surface = undefined,
          .create_info = .{
            .drm_modifier = drm_modifier,
            .format_list_create_info = .{
              .view_format_count = 1,
              .p_view_formats = &.{ format.toVk() },
            },
            .ext_mem_image_create_info = .{
              .handle_types = .{
                .dma_buf_bit_ext = true,
              },
            },
            .image_drm_format_mod_info = .{
              .drm_format_modifier_count = 1,
              .p_drm_format_modifiers = &.{ drm_modifier.toInt() },
            },
          },
        },
      );
      images[idx].platform_specific.prepare_image(surface);
      image_states[idx] = .available;
    }

    return .{
      .surface = surface,
      .images = images,
      .image_states = image_states,
      .acquired_image = null,
      .pending_resize = null,
      .submit_queue = submit_queue,
    };
  }

  pub fn recreate(
    sc: *Swapchain,
    vki: vk.InstanceProxy,
    vkd: vk.DeviceProxy,
    vk_pdev: vk.PhysicalDevice,
    width: u32,
    height: u32,
  ) void {
    defer {
      sc.surface.width = i32_(width);
      sc.surface.height = i32_(height);
      sc.pending_resize = null;
      sc.acquired_image = null;
      @memset(sc.submit_queue, 0);
    }
    const format = sc.images[0].format;
    const surface = sc.images[0].platform_specific.surface;
    const drm_modifier = sc.images[0].platform_specific.drm_modifier;
    for (0..sc.images.len) |idx| {
      sc.images[idx].release(vkd);
      sc.images[idx] = .alloc(
        vki,
        vkd,
        vk_pdev,
        surface,
        width,
        height,
        format,
        .{
          .fd = -1,
          .drm_modifier = drm_modifier,
          .surface = undefined,
          .create_info = .{
            .drm_modifier = drm_modifier,
            .format_list_create_info = .{
              .view_format_count = 1,
              .p_view_formats = &.{ format.toVk() },
            },
            .ext_mem_image_create_info = .{
              .handle_types = .{
                .dma_buf_bit_ext = true,
              },
            },
            .image_drm_format_mod_info = .{
              .drm_format_modifier_count = 1,
              .p_drm_format_modifiers = &.{ drm_modifier.toInt() },
            },
          },
        },
      );
      sc.images[idx].platform_specific.prepare_image(surface);
      sc.image_states[idx] = .available;
    }
  }

  pub fn destroy(sc: *Swapchain, vkd: vk.DeviceProxy) void {
    for (sc.images) |image| {
      image.release(vkd);
    }
  }

  pub fn mark_outdated(sc: *Swapchain, width: u32, height: u32) void {
    sc.pending_resize = .{ .x = width, .y = height };
  }

  pub fn acquire_image(sc: *Swapchain) ?*Image {
    for (sc.image_states, 0..) |state, idx| {
      if (state == .available) {
        sc.image_states[idx] = .busy;
        sc.acquired_image = u32_(idx);
        return &sc.images[idx];
      }
    }
    return null;
  }

  pub fn present(sc: *Swapchain) void {
    const idx = sc.acquired_image orelse return;
    sc.surface.attach_image(&sc.images[idx]);
    sc.image_states[idx] = .submitted;
    sc.acquired_image = null;

    sc.submit_queue[sc.submit_tail % sc.images.len] = idx;
    sc.submit_tail +%= 1;
  }
  pub fn release_image(sc: *Swapchain) void {
    if (sc.submit_tail == sc.submit_head) return;
    const idx = sc.submit_queue[sc.submit_head % sc.images.len];
    sc.submit_head +%= 1;
    sc.image_states[idx] = .available;
  }
};

pub const Image = struct {
  vk_image: vk.Image,
  vk_image_view: vk.ImageView,
  vk_device_memory: vk.DeviceMemory,
  width: u32,
  height: u32,
  format: gfx.Format,
  stride: u32,
  offset: u32,
  platform_specific: PlatformSpecificData,

  pub fn alloc(
    vki: vk.InstanceProxy,
    vkd: vk.DeviceProxy,
    pdev: vk.PhysicalDevice,
    surface: *Surface,
    width: u32,
    height: u32,
    format: gfx.Format,
    platform_specific_data: PlatformSpecificData,
  ) Image {
    const p_next = platform_specific_data.create_info.p_next();
    const image = vkd.createImage(
      &.{
        .p_next = p_next,
        .flags = .{},
        .image_type = .@"2d",
        .format = format.toVk(),
        .extent = .{
          .width = width,
          .height = height,
          .depth = 1,
        },
        .mip_levels = 1,
        .array_layers = 1,
        .samples = .{ .@"1_bit" = true },
        .tiling = platform_specific_data.create_info.tiling,
        .usage = .{
          .storage_bit = true,
          .color_attachment_bit = true,
          .transfer_dst_bit = true,
        },
        .sharing_mode = .exclusive,
        .initial_layout = .general,
      },
      null,
    ) catch |err|{
      std.log.err("vkImage create failed with error :: {s}", .{@errorName(err)});
      @panic("vkImage creation failed");
    };

    const mem_reqs = vkd.getImageMemoryRequirements(
      image,
    );
    const mem_props = vki.getPhysicalDeviceMemoryProperties(pdev);

    var mem_image_type_idx: u32 = math.maxInt(u32);
    for (0..mem_props.memory_type_count) |i| {
        if ((mem_reqs.memory_type_bits & (u32_(1) << cast(u5, i))) != 0 and
            mem_props.memory_types[i].property_flags.device_local_bit) {
            mem_image_type_idx = u32_(i);
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
      .p_next = &dedicated_alloc_info,
    };

    const alloc_info: vk.MemoryAllocateInfo = .{
      .p_next = &export_info,
      .allocation_size = mem_reqs.size,
      .memory_type_index = mem_image_type_idx,
    };

    const device_memory = vkd.allocateMemory(
      &alloc_info,
      null,
    ) catch |err| {
      std.log.err("vkDevice.allocateMemory failed :: {s}", .{@errorName(err)});
      @panic("Failed to allocate device memory!");
    };

    vkd.bindImageMemory(
      image,
      device_memory,
      0,
    ) catch unreachable;

    const layout = vkd.getImageSubresourceLayout(
      image,
      &.{
        .aspect_mask = .{ .memory_plane_0_bit_ext = true },
        .mip_level = 0,
        .array_layer = 0,
      },
    );

    const fd = vkd.getMemoryFdKHR(
      &.{
        .memory = device_memory,
        .handle_type = .{ .dma_buf_bit_ext = true },
      },
    ) catch unreachable;

    var mod_props: vk.ImageDrmFormatModifierPropertiesEXT = .{
      .drm_format_modifier = platform_specific_data.drm_modifier.toInt(),
    };

    vkd.getImageDrmFormatModifierPropertiesEXT(
      image,
      &mod_props
    ) catch |err| {
      std.log.err(
        "Failed to get image drm format modifiers :: {s}",
        .{ @errorName(err) },
      );
      @panic("vkGetImageDrmFormatModifierPropertiesEXT Failed!");
    };

    const image_view = vkd.createImageView(
      &.{
        .image = image,
        .view_type = .@"2d",
        .components = .{
          .r = .identity,
          .g = .identity,
          .b = .identity,
          .a = .identity,
        },
        .format = format.toVk(),
        .subresource_range = .{
          .aspect_mask = .{ .color_bit = true },
          .base_mip_level = 0,
          .level_count = 1,
          .base_array_layer = 0,
          .layer_count = 1,
        },
      },
      null,
    ) catch unreachable;

    return .{
      .vk_image = image,
      .vk_image_view = image_view,
      .vk_device_memory = device_memory,
      .width = width,
      .height = height,
      .format = format,
      .stride = u32_(layout.row_pitch),
      .offset = u32_(layout.offset),
      .platform_specific = .{
        .surface = surface,
        .fd = fd,
        .drm_modifier = .fromInt(mod_props.drm_format_modifier),
        .create_info = undefined,
      },
    };
  }

  pub fn release(
    image: *const Image,
    vkd: vk.DeviceProxy,
  ) void {
    vkd.freeMemory(image.vk_device_memory, null);
    vkd.destroyImageView(image.vk_image_view, null);
    vkd.destroyImage(image.vk_image, null);
    image.platform_specific.release();
  }

  pub const State = enum (u32) {
    available,
    busy,
    submitted,
  };

  const PlatformSpecificData = switch (Target) {
    .wayland => struct {
      fd: i32,
      drm_modifier: Drm.Modifier,
      surface: *Surface,
      wl_buffer: wayland.WaylandBuffer = undefined,
      create_info: ImageExtraCreateInfo,

      pub fn image_extra_create_info(conn: *wayland.Connection, format: gfx.Format) ImageExtraCreateInfo {
        const drm_modifier = conn.select_drm_modifier_for_format(format);
        return .{
          .drm_modifier = drm_modifier,
          .format_list_create_info = .{
            .view_format_count = 1,
            .p_view_formats = &.{ format.toVk() },
          },
          .ext_mem_image_create_info = .{
            .handle_types = .{
              .dma_buf_bit_ext = true,
            },
          },
          .image_drm_format_mod_info = .{
            .drm_format_modifier_count = 1,
            .p_drm_format_modifiers = &.{ drm_modifier.toInt() },
          },
        };
      }

      pub fn prepare_image(psd: *PlatformSpecificData, surface: *Surface) void {
        const image: *Image = @fieldParentPtr("platform_specific", psd);
        surface.handle.prepare_image(image);
      }

      pub fn release(psd: *const PlatformSpecificData) void {
        const image: *const Image = @fieldParentPtr("platform_specific", psd);
        const surface = psd.surface;
        surface.handle.release_image(image);
      }

      const ImageExtraCreateInfo = struct {
        format_list_create_info: vk.ImageFormatListCreateInfo,
        ext_mem_image_create_info: vk.ExternalMemoryImageCreateInfo,
        image_drm_format_mod_info: vk.ImageDrmFormatModifierListCreateInfoEXT,
        tiling: vk.ImageTiling = .drm_format_modifier_ext,
        drm_modifier: Drm.Modifier,

        pub fn set_next_pointers(ieci: *ImageExtraCreateInfo) void {
          ieci.ext_mem_image_create_info.p_next = &ieci.format_list_create_info;
          ieci.image_drm_format_mod_info.p_next = &ieci.ext_mem_image_create_info;
        }
        pub fn p_next(ieci: *const ImageExtraCreateInfo) *const anyopaque {
          return &ieci.image_drm_format_mod_info;
        }
      };
    },
    else => @compileError("Win32 not implemented yet!"),
  };
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
    pub const SwapchainHandle = wayland.Swapchain;
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
