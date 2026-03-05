base_wrapper: vk.BaseWrapper,
instance: vk.InstanceWrapper,
instance_proxy: vk.InstanceProxy,
physical_device: vk.PhysicalDevice,
device: vk.DeviceWrapper,
device_proxy: vk.DeviceProxy,
compute_queue: vk.Queue,
compute_pipeline: vk.Pipeline,
descriptor_set: vk.DescriptorSet,
command_pool: vk.CommandPool,
command_buffer: vk.CommandBuffer,

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

pub fn init_full(ctx: *VkContext) void {
  _ = ctx;
}

pub fn destroy(ctx: *const VkContext) void {
  defer ctx.instance_proxy.destroyInstance(null);
  defer ctx.device_proxy.destroyDevice(null);
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

const base = @import("base");
const os = @import("os");

const vk = @import("vulkan");
const std = @import("std");
const builtin = @import("builtin");
