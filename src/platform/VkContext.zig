base_wrapper: vk.BaseWrapper,
instance: vk.InstanceWrapper,
instance_proxy: vk.InstanceProxy,
physical_device: vk.PhysicalDevice,
device: vk.DeviceWrapper,
device_proxy: vk.DeviceProxy,
queue: vk.Queue,
command_pool: vk.CommandPool,

pub fn init_instance(
  noalias ctx: *VkContext,
  noalias app_info: *const AppInfo,
) InstanceInitError!void {
  if (libvk_handle == null) try load_lib();
  ctx.base_wrapper = .load(get_instance_proc_addr.?);

  const vk_app_info: vk.ApplicationInfo = .{
    .p_application_name = app_info.name.ptr,
    .application_version = u32_(app_info.app_version),
    .p_engine_name = app_info.engine_name.ptr,
    .engine_version = u32_(app_info.engine_version),
    .api_version = u32_(app_info.api_version),
  };

  const instance = try ctx.base_wrapper.createInstance(
    &.{
      .p_application_info = &vk_app_info,
    },
    null,
  );
  ctx.instance = .load(
    instance,
    get_instance_proc_addr.?,
  );
  ctx.instance_proxy = .init(instance, &ctx.instance);

  ctx.physical_device = .null_handle;
  ctx.device = undefined;
  ctx.device_proxy = undefined;
}

pub fn init_device(
  ctx: *VkContext,
  physical_device: vk.PhysicalDevice,
  required_extensions: []const [*:0]const u8,
  command_pool_create_flags: vk.CommandPoolCreateFlags,
) !void {
  var scratch = Thread.Context.get_scratch(0, .{}).?;
  defer scratch.end();

  defer ctx.physical_device = physical_device;
  const device, const queue_family_index = dev_qfi: {
    const qfi = qfi: {
      var queue_family_count: u32 = 0;
      ctx.instance_proxy.getPhysicalDeviceQueueFamilyProperties(
        physical_device,
        &queue_family_count,
        null,
      );

      const queue_families = scratch.arena.push(
        vk.QueueFamilyProperties,
        queue_family_count,
      );

      ctx.instance_proxy.getPhysicalDeviceQueueFamilyProperties(
        physical_device,
        &queue_family_count,
        queue_families.ptr,
      );

      for (queue_families, 0..) |queue_family_properties, idx| {
        if (queue_family_properties.queue_flags.graphics_bit and
            queue_family_properties.queue_flags.compute_bit)
        {
          break :qfi u32_(idx);
        }
      }
      // No suitable devices
      break :dev_qfi .{ .null_handle, undefined };
    };

    const vk_13_features: vk.PhysicalDeviceVulkan13Features = .{
      .synchronization_2 = .true, // Enabled for now, but not sure I'll use
      .dynamic_rendering = .true, // Enabled for now, but not sure I'll use
    };
    const queue_priority = 1;
    const device = ctx.instance_proxy.createDevice(
      physical_device,
      &.{
        .p_next = &vk_13_features,
        .p_queue_create_infos = &.{
          .{
            .queue_family_index = qfi,
            .queue_count = 1,
            .p_queue_priorities = &.{ queue_priority },
          },
        },
        .queue_create_info_count = 1,
        .p_enabled_features = null,
        .enabled_extension_count = u32_(required_extensions.len),
        .pp_enabled_extension_names = required_extensions.ptr,
      },
      null,
    ) catch .null_handle;
    break :dev_qfi .{ device, qfi };
  };

  if (device != .null_handle) {
    log.info(
      "Creating Logical Device :: Physical Device = 0x{x}",
      .{ physical_device },
    );

    ctx.device = .load(
      device,
      ctx.instance.dispatch.vkGetDeviceProcAddr.?,
    );
    ctx.device_proxy = .init(device, &ctx.device);
    ctx.queue = ctx.device_proxy.getDeviceQueue(queue_family_index, 0);

    ctx.command_pool = try ctx.device_proxy.createCommandPool(
      &.{
        .flags = command_pool_create_flags,
        .queue_family_index = queue_family_index,
      },
      null,
    );
  } else {
    return error.NoSuitableDeviceFound;
  }
}

pub fn init(
  noalias ctx: *VkContext,
  noalias app_info: *const AppInfo,
  physical_device: vk.PhysicalDevice,
  noalias required_extensions: []const [*:0]const u8,
  command_pool_create_flags: vk.CommandPoolCreateFlags,
) !void {
  try ctx.init_instance(app_info);
  try ctx.init_device(
    physical_device,
    required_extensions,
    command_pool_create_flags,
  );
}

pub fn alloc_image(
  ctx: *VkContext,
  width: u32,
  height: u32,
  format: vk.Format,
  usage: vk.ImageUsageFlags,
  tiling: ?vk.ImageTiling,
  image_create_p_next: ?*const anyopaque,
  export_handle_types: ?vk.ExternalMemoryHandleTypeFlags,
) !Image {
  const image = try ctx.device_proxy.createImage(&.{
    .p_next = image_create_p_next,
    .flags = .{},
    .format = format,
    .image_type = .@"2d",
    .extent = .{
      .width = width,
      .height = height,
      .depth = 1,
    },
    .mip_levels = 1,
    .array_layers = 1,
    .samples = .{ .@"1_bit" = true },
    .tiling = tiling orelse .optimal,
    .usage = usage,
    .sharing_mode = .exclusive,
    .initial_layout = .general,
  }, null);

  const memory_requirements =
    ctx.device_proxy.getImageMemoryRequirements(image);
  const memory_properties =
    ctx.instance_proxy.getPhysicalDeviceMemoryProperties(ctx.physical_device);

  var mem_image_type_idx: u32 = math.maxInt(u32);
  for (0..memory_properties.memory_type_count) |i| {
    if ((memory_requirements.memory_type_bits & (u32_(1) << cast(u5, i))) != 0
         and memory_properties.memory_types[i].property_flags.device_local_bit)
    {
      mem_image_type_idx = u32_(i);
      break;
    }
  }

  const dedicated_alloc_info: vk.MemoryDedicatedAllocateInfo = .{
    .image = image,
  };

  const export_info_opt: ?vk.ExportMemoryAllocateInfo =
    if (export_handle_types) |handle_types|
      .{ .handle_types = handle_types, .p_next = &dedicated_alloc_info }
    else null;

  const alloc_info_p_next: ?*const anyopaque =
    if (export_info_opt) |export_info| &export_info
    else &dedicated_alloc_info;

  const alloc_info: vk.MemoryAllocateInfo = .{
    .p_next = alloc_info_p_next,
    .allocation_size = memory_requirements.size,
    .memory_type_index = mem_image_type_idx,
  };

  const device_memory = try ctx.device_proxy.allocateMemory(
    &alloc_info,
    null,
  );

  try ctx.device_proxy.bindImageMemory(
    image,
    device_memory,
    0
  );

  const image_view = try ctx.device_proxy.createImageView(
    &.{
      .image = image,
      .view_type = .@"2d",
      .components = .{
        .r = .identity,
        .g = .identity,
        .b = .identity,
        .a = .identity
      },
      .format = format,
      .subresource_range = .{
        .aspect_mask = .{ .color_bit = true },
        .base_mip_level = 0,
        .level_count = 1,
        .base_array_layer = 0,
        .layer_count = 1,
      },
    },
    null,
  );

  return .{
    .image = image,
    .view = image_view,
    .memory = device_memory,
    .width = width,
    .height = height,
  };
}

pub fn destroy_image(
  ctx: *const VkContext,
  image: Image,
) void {
  ctx.device_proxy.freeMemory(image.memory, null);
  ctx.device_proxy.destroyImageView(image.view, null);
  ctx.device_proxy.destroyImage(image.image, null);
}

pub fn alloc_render_image(
  ctx: *VkContext,
  width: u32,
  height: u32,
  format: vk.Format,
) Image {
  const render_image = ctx.alloc_image(
    width,
    height,
    format,
    .{ .storage_bit = true, .transfer_src_bit = true },
    null,
    null,
    null,
  );

  return render_image;
}

pub fn destroy(ctx: *const VkContext) void {
  defer ctx.instance_proxy.destroyInstance(null);
  defer ctx.device_proxy.destroyDevice(null);
  defer ctx.device_proxy.destroyCommandPool(ctx.command_pool, null);
}

pub fn load_lib() LoadLibError!void {
  libvk_handle = try std.DynLib.open(dynlib_name);
  get_instance_proc_addr = libvk_handle.?.lookup(
    vk.PfnGetInstanceProcAddr,
    "vkGetInstanceProcAddr",
  ) orelse return LoadLibError.GetInstanceProcAddrNotFound;
}

pub fn close_lib() void {
  libvk_handle.close();
}

pub const Image = struct {
  image: vk.Image,
  view: vk.ImageView,
  memory: vk.DeviceMemory,
  width: u32,
  height: u32,
};

pub const AppInfo = struct {
  name: [:0]const u8,
  app_version: vk.Version,
  engine_name: [:0]const u8,
  engine_version: vk.Version,
  api_version: vk.Version,
};

pub const InstanceCreateError = vk.BaseWrapper.CreateInstanceError;
pub const InstanceInitError = LoadLibError
  || InstanceCreateError
  || error{FailedToLoadVkInstance}
;
pub const LoadLibError = std.DynLib.Error || error{GetInstanceProcAddrNotFound};

const dynlib_name = switch(os.Target.tag) {
  .linux => "libvulkan.so.1",
  .windows => "vulkan-1.dll",
  else => @panic("Unsupported platform!"),
};

pub var get_instance_proc_addr: ?vk.PfnGetInstanceProcAddr = null;
pub var libvk_handle: ?std.DynLib = null;

const VkContext = @This();

const u32_ = base.u32_;
const cast = base.casts.cast;
const transmute = base.casts.transmute;

const math = base.math;

const Thread = base.Thread;
const base = @import("base");
const os = @import("os");

const log = std.log.scoped(.VkContext);
const vk = @import("vulkan");
const std = @import("std");
const builtin = @import("builtin");
