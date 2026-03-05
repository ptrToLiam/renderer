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

  pub fn create_swapchain(surface: *Surface) Swapchain {
    // TODO
    _  = surface;
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
  surface: *Surface,
  images: []Image,
  image_states: []Image.State,
  current_image: u32,

  pub fn create(
    arena: *Arena,
    surface: *Surface,
    vki: vk.InstanceProxy,
    vkd: vk.DeviceProxy,
    vk_pdev: vk.PhysicalDevice,
    width: u32,
    height: u32,
    format: gfx.Format,
    image_count: usize,
  ) Swapchain {
    var images = arena.push(Image, image_count);
    var image_states = arena.push(Image.State, image_count);

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
      .current_image = 0,
    };
  }

  // SWAPCHAIN RECREATION
  //  - On want_resize:
  //    - RenderCurrent Frame
  //    - Set new swapchain dimensions
  //    - Wait for IDLE
  //    - Free Images/Views
  //    - Alloc new Images/Views
  pub fn recreate(width: u32, height: u32) void {
    _ = width; _ = height;
    @panic("TODO!");
  }

  pub fn release_image(sc: *Swapchain) void {
    for (0..sc.images.len) |idx| {
      if (sc.image_states[idx] == .submitted) {
        sc.image_states[idx] = .available;
        break;
      }
    }
  }

  pub fn acquire_image(sc: *Swapchain) ?*Image {
    const idx = sc.current_image % sc.images.len;
    if (sc.image_states[idx] == .available) {
      sc.image_states[idx] = .busy;
      return &sc.images[idx];
    }
    return null;
  }

  pub fn present(sc: *Swapchain) void {
    const idx = sc.current_image % sc.images.len;
    sc.surface.attach_image(&sc.images[idx]);
    sc.image_states[idx] = .submitted;
    sc.current_image +%= 1;
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
    _ = surface;
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
          .color_attachment_bit = true,
          .transfer_src_bit = true,
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
        .fd = fd,
        .drm_modifier = .fromInt(mod_props.drm_format_modifier),
        .create_info = undefined,
      },
    };
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
  },
  .win32 => struct {
    pub const ConnectionHandle = win32.Connection;
    pub const SurfaceHandle = win32.Window;
  },
  else => os.UnsupportedPlatformError(),
};

const Arena = base.Arena;

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

const os = @import("os");
const base = @import("base");
const vk = @import("vulkan");

const std = @import("std");
const builtin = @import("builtin");
