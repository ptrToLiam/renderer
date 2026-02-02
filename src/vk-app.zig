pub fn app(env: std.process.Environ) void {
  const app_name = "LmDev-" ++ AppName;
  const app_class = "LmDev-" ++ AppClass;

  const arena: *Arena = .init(.default);
  defer arena.release();

  var vk_handle = std.DynLib.open("libvulkan.so.1") catch @panic("Failed to load libvulkan.so.1");
  defer vk_handle.close();
  const vk_get_instance_proc_addr = vk_handle.lookup(
    vk.PfnGetInstanceProcAddr,
    "vkGetInstanceProcAddr",
  ) orelse @panic("Failed to locate vkGetInstanceProcAddr");

  const initial_width = 540;
  const initial_height = 360;

  //---------------------------------------------------------------------------
  // BEGIN PLATFORM STATE INIT
  //---------------------------------------------------------------------------

  const platform_init_start_us = time.us();
  var platform_conn: platform.Connection = .open(arena, env);

  defer platform_conn.close();

  // TODO: Implement
  var surface = platform_conn.acquire_surface(
    arena,
    .{
      .title = app_name,
      .class = app_class,
      .width = initial_width,
      .height = initial_height,
    },
  );
  defer surface.release();

  const platform_init_end_us = time.us();
  const platform_init_us = platform_init_end_us - platform_init_start_us;

  //---------------------------------------------------------------------------
  // END PLATFORM STATE INIT
  //---------------------------------------------------------------------------

  std.log.debug(
    "platform state init complete in {d}us ({d:.2}ms)!",
    .{ platform_init_us, base.f64_(platform_init_us) / base.f64_(time.us_per_ms) },
  );

  const vk_state_init_start_us = time.us();

  //---------------------------------------------------------------------------
  // BEGIN VULKAN STATE INIT
  //---------------------------------------------------------------------------

  const vkb: vk.BaseWrapper = .load(vk_get_instance_proc_addr);
  var instance: vk.Instance = undefined;
  var vki: vk.InstanceWrapper = undefined;
  {
    const app_info: vk.ApplicationInfo = .{
      .p_application_name = app_name,
      .application_version = u32_(vk.makeApiVersion(0, 1, 0, 0)),
      .p_engine_name = "custom",
      .engine_version = u32_(vk.makeApiVersion(0, 1, 0, 0)),
      .api_version = u32_(vk.API_VERSION_1_3),
    };

    const instance_info: vk.InstanceCreateInfo = .{
      .p_application_info = &app_info,
    };
    instance = vkb.createInstance(&instance_info, null) catch @panic("uh oh!");
    vki = .load(instance, vk_get_instance_proc_addr);
  }
  defer vki.destroyInstance(instance, null);

  const vkGetPhysicalDeviceProperties2 = vk_handle.lookup(
    vk.PfnGetPhysicalDeviceProperties2,
    "vkGetPhysicalDeviceProperties2",
  ).?;

  if (vki.dispatch.vkGetPhysicalDeviceProperties2) |_| {
    std.log.debug("Successfully located vkGetPhysicalDeviceProperties2 in libvulkan.so.1", .{});
  } else {
    std.log.err("Could not locate vkGetPhysicalDeviceProperties2 in libvulkan.so.1", .{});
  }


  // NEXT UP:
  // - Allocate GPU memory through Vulkan
  // - Get FileDescriptor of allocated GPU memory
  // - Create Images backed by this memory
  // - Create draw buffers (wl_buffer on wayland) with this memory for presentation to surface
  const vk_required_device_extensions = [_][*:0]const u8{
    vk.extensions.khr_external_memory.name,
    vk.extensions.khr_external_memory_fd.name,
    vk.extensions.ext_external_memory_dma_buf.name,
  };
  const vk_pdev: *vk.PhysicalDevice = arena.create(vk.PhysicalDevice);

  // get vk device
  var vk_pdev_count: u32 = 0;
  _ = vki.enumeratePhysicalDevices(
    instance,
    &vk_pdev_count,
    null,
  ) catch unreachable;

  var vk_pdev_selection_scratch = Thread.Context.get_scratch(1, .{arena}).?;
  const vk_pdev_arena = vk_pdev_selection_scratch.arena;
  var vk_pdevs = vk_pdev_arena.push(vk.PhysicalDevice, vk_pdev_count);

  _ = vki.enumeratePhysicalDevices(
    instance,
    &vk_pdev_count,
    vk_pdevs.ptr,
  ) catch unreachable;
  if (vk_pdevs.len == 0) @panic("no vk physical devices available")
    else std.log.debug("found {} vk physical devices!!", .{vk_pdevs.len});

  var vk_pdev_candidate: VkDeviceCandidate = .{ .pdev = undefined, .score = 0 };
  // vk physical device enumeration
  for (vk_pdevs) |vk_pdev_opt| {
    var pdev_props14: vk.PhysicalDeviceVulkan14Properties = undefined;
    pdev_props14.s_type = .physical_device_vulkan_1_4_properties;
    pdev_props14.p_next = null;

    var pdev_props2: vk.PhysicalDeviceProperties2 = .{
      .p_next = &pdev_props14,
      .properties = undefined,
    };
    
    vkGetPhysicalDeviceProperties2(vk_pdev_opt, &pdev_props2);
    // vki.getPhysicalDeviceProperties2(vk_pdev_opt, &pdev_props2);

    var score: u32 = 0;

    const props = pdev_props2.properties;
    if (props.device_type == .discrete_gpu)
      score += 1000;

    score += props.limits.max_image_dimension_2d;

    var vk_pdev_ext_prop_count: u32 = 0;
    _ = vki.enumerateDeviceExtensionProperties(
      vk_pdev_opt,
      null,
      &vk_pdev_ext_prop_count,
      null,
    ) catch unreachable;

    const vk_pdev_ext_props = vk_pdev_arena.push(vk.ExtensionProperties, vk_pdev_ext_prop_count);

    _ = vki.enumerateDeviceExtensionProperties(
      vk_pdev_opt,
      null,
      &vk_pdev_ext_prop_count,
      vk_pdev_ext_props.ptr,
    ) catch unreachable;

    const supports_desired_extensions = ext_support: {
      for (vk_required_device_extensions) |ext| {
        const found_ext = found: {
          for (vk_pdev_ext_props) |ext_prop| {
            const ext_prop_name = ext_prop_name: {
              var name_end_idx: usize = 0;
              while (ext_prop.extension_name[name_end_idx] != 0) {
                name_end_idx += 1;
              }
              break :ext_prop_name ext_prop.extension_name[0..name_end_idx+1];
            };

            const ext_name = ext_name: {
              var name_end_idx: usize = 0;
              while (ext[name_end_idx] != 0) {
                name_end_idx += 1;
              }
              break :ext_name ext[0..name_end_idx+1];
            };

            if (std.mem.eql(u8, ext_name, ext_prop_name)) {
              break :found true;
            }
          }

          break :found false;
        };

        std.log.debug(
          "{s} {s}",
          .{
            ext,
            if (found_ext)
              "found!"
            else
              "not found!",
          },
        );
        if (!found_ext) break :ext_support false;
      }
      break :ext_support true;
    };

    if (supports_desired_extensions and score > vk_pdev_candidate.score) {
      vk_pdev_candidate = .{
        .pdev = vk_pdev_opt,
        .score = score,
      };
    }
  }
  vk_pdev.* = vk_pdev_candidate.pdev;

  vk_pdev_selection_scratch.end();

  //---------------------------------------------------------------------------
  // END VULKAN STATE INIT
  //---------------------------------------------------------------------------

  const vk_state_init_end_us = time.us();
  const vk_state_init_us = vk_state_init_end_us - vk_state_init_start_us;
  std.log.debug(
    "vulkan state init complete in {d}us ({d}ms)!",
    .{ vk_state_init_us, vk_state_init_us / time.us_per_ms },
  );

  var events: platform.EventList = .empty;
  var want_exit = true;
  _ = &want_exit;
  while (!want_exit) {
    var frame_scratch = Thread.Context.get_scratch(1, .{arena}).?;
    defer frame_scratch.end();
    const frame_arena = frame_scratch.arena;
    events = platform_conn.get_events(frame_arena, &surface);
    var event_opt = events.first;
    while (event_opt) |ev| : (event_opt = ev.next) {
      // event handling loop
    }

    update();
    draw();
  }
}

const VkDeviceCandidate = struct {
  pdev: vk.PhysicalDevice,
  score: u32,
};

fn update() void {
}

fn draw() void {
}

const AppName = "vkRender";
const AppClass = "Liam.Games.vkRender";
const Swapchain = struct {
};

const u32_ = base.u32_;
const u64_ = base.u64_;

const f32_ = base.f32_;
const f64_ = base.f64_;

const Arena = base.Arena;
const Thread = base.Thread;
const math = base.math;
const time = base.time;

const drm = @import("drm.zig");

const base = @import("base");
const os = @import("os");
const gfx = @import("gfx");
const vk = @import("vulkan");
const platform = @import("platform");

const std = @import("std");
const builtin = @import("builtin");