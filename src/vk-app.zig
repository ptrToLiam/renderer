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
      .api_version = u32_(vk.API_VERSION_1_4),
    };

    const instance_info: vk.InstanceCreateInfo = .{
      .p_application_info = &app_info,
    };
    instance = vkb.createInstance(&instance_info, null) catch @panic("uh oh!");
    vki = .load(instance, vk_get_instance_proc_addr);
  }
  defer vki.destroyInstance(instance, null);

  // NEXT UP:
  // - Allocate GPU memory through Vulkan
  // - Get FileDescriptor of allocated GPU memory
  // - Create Images backed by this memory
  // - Create draw buffers (wl_buffer on wayland) with this memory for presentation to surface

  const vk_required_device_extensions = [_][*:0]const u8{
    vk.extensions.khr_external_memory.name,
    vk.extensions.khr_external_memory_fd.name,
    vk.extensions.ext_external_memory_dma_buf.name,
    vk.extensions.ext_image_drm_format_modifier.name,
  };
  const vk_pdev: *vk.PhysicalDevice = arena.create(vk.PhysicalDevice);

  // Physical Device Selection
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


  // vk physical device enumeration
  var vk_pdev_candidate: VkDeviceCandidate = .{ .pdev = undefined, .properties = undefined, .score = 0 };
  for (vk_pdevs) |vk_pdev_opt| {

    // NOTE: vk1.4 props => SIGSEGV from drivers on desktop and laptop
    //       stick to vk1.3 properties
    var pdev_props13: vk.PhysicalDeviceVulkan13Properties = undefined;
    pdev_props13.s_type = .physical_device_vulkan_1_3_properties;
    pdev_props13.p_next = null;

    var pdev_props2: vk.PhysicalDeviceProperties2 = .{
      .p_next = &pdev_props13,
      .properties = undefined,
    };

    _ = vki.getPhysicalDeviceProperties2(vk_pdev_opt, &pdev_props2);

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

        if (!found_ext) break :ext_support false;
      }
      break :ext_support true;
    };

    if (supports_desired_extensions and score > vk_pdev_candidate.score) {
      vk_pdev_candidate = .{
        .pdev = vk_pdev_opt,
        .properties = pdev_props2.properties,
        .score = score,
      };
    }
  }

  vk_pdev.* = vk_pdev_candidate.pdev;

  vk_pdev_selection_scratch.end();

  std.log.debug(
    "Selected GPU: {s}, type: {s}",
    .{
      vk_pdev_candidate.properties.device_name,
      @tagName(vk_pdev_candidate.properties.device_type),
    },
  );
  var vk_dev_create_scratch = Thread.Context.get_scratch(1, .{arena}).?;
  const vk_dev_create_arena = vk_dev_create_scratch.arena;
  // Logical Device Creation
  const vk_dev, const queue_family_index = vk_dev: {
    const queue_family_index = qfi: {
      var queue_family_count: u32 = 0;
      vki.getPhysicalDeviceQueueFamilyProperties(
        vk_pdev.*,
        &queue_family_count,
        null,
      );
      const queue_families = vk_dev_create_arena.push(
        vk.QueueFamilyProperties,
        queue_family_count
      );

      vki.getPhysicalDeviceQueueFamilyProperties(
        vk_pdev.*,
        &queue_family_count,
        queue_families.ptr,
      );

      for (queue_families, 0..) |queue_family_props, index| {
        if (queue_family_props.queue_flags.graphics_bit) {
          break :qfi base.u32_(index);
        }
      }
      @panic("Unable to find suitable graphics queue for device!");
    };

    var queue_priority: f32 = 1;
    const queue_info: vk.DeviceQueueCreateInfo = .{
      .queue_family_index = queue_family_index,
      .queue_count = 1,
      .p_queue_priorities = @ptrCast(&queue_priority),
    };

    const device_info: vk.DeviceCreateInfo = .{
      .p_queue_create_infos = &.{
        queue_info,
      },
      .queue_create_info_count = 1,
      .p_enabled_features = null,

      .enabled_extension_count = @intCast(vk_required_device_extensions.len),
      .pp_enabled_extension_names = &vk_required_device_extensions,
    };

    break :vk_dev .{
      vki.createDevice(
        vk_pdev.*,
        &device_info,
        null,
      ) catch unreachable,
      queue_family_index,
    };
  };

  var vkd: vk.DeviceWrapper = .load(
    vk_dev,
    vki.dispatch.vkGetDeviceProcAddr.?,
  );
  defer vkd.destroyDevice(vk_dev, null);
  vk_dev_create_scratch.end();

  const vkd_queue = vkd.getDeviceQueue(
    vk_dev,
    queue_family_index,
    0,
  );

  _ = vkd_queue;

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
  var want_exit = false;

  var shm_pool = create_shm_pool(
    &platform_conn.handle,
    platform_conn.handle.client_state.wl_shm,
    surface.width,
    surface.height,
  );

  platform_conn.handle.flush() catch unreachable;

  const buffer = shm_pool.create_buffer(
    surface.width,
    surface.height,
    .xrgb8888,
  );

  var want_attach = false;
  var attached = false;

  _ = &want_exit;
  while (!want_exit) {
    var frame_scratch = Thread.Context.get_scratch(1, .{arena}).?;
    defer frame_scratch.end();
    const frame_arena = frame_scratch.arena;
    events = platform_conn.get_events(frame_arena, &surface);
    var event_opt = events.first;
    while (event_opt) |ev| : (event_opt = ev.next) {
      // event handling loop
      switch (ev.type) {
        .surface_close => {
          want_exit = true;
        },
        else => {
          std.log.debug("app-level ev :: {any}", .{ev});
        },
      }
    }

    if (want_attach and !attached) {
      log.debug("attempting to attach buffer now!", .{});
      surface.handle.wl_surface.attach(
        &shm_pool.proxy,
        buffer,
        0,
        0,
      );
      surface.handle.wl_surface.damage_buffer(
        &shm_pool.proxy,
        0,
        0,
        surface.width,
        surface.height,
      );
      surface.handle.wl_surface.commit(
        &shm_pool.proxy,
      );
      attached = true;
    }

    if (!want_attach and surface.handle.ready()) {
      log.debug("surface ready :: setting want_attach to true", .{});
      want_attach = true;
      platform_conn.handle.flush() catch unreachable;
    }

    surface.handle.wl_surface.damage(&shm_pool.proxy, 0, 0, surface.width, surface.height );
    surface.handle.wl_surface.commit(&shm_pool.proxy);
    platform_conn.handle.flush() catch unreachable;

    update();
    draw();
  }
}

const ShmPool = struct {
  proxy: platform.wayland.Proxy,
  wl_shm_pool: platform.wayland.ShmPool,
  buffer: []u32,
  fd: c_int,

  pub fn create_buffer(
    pool: *ShmPool,
    width: i32,
    height: i32,
    format: platform.wayland.Shm.Format,
  ) platform.wayland.WaylandBuffer {
    defer @memset(pool.buffer, 0xefefefef);
    return pool.wl_shm_pool.create_buffer(
      &pool.proxy,
      0,
      width,
      height,
      width*4,
      format,
    );
  }
};

fn create_shm_pool(
  conn: *platform.wayland.Connection,
  shm: platform.wayland.Shm,
  width: i32,
  height:i32,
) ShmPool {
  const scratch = Thread.Context.get_scratch(0, .{}).?;
  defer scratch.end();
  const shm_fd = open_shmfile(scratch.arena);
  var proxy = conn.proxy();

  const img_stride = width * 4;
  const img_size = height * img_stride;
  _ = os.linux.ftruncate(
    shm_fd,
    img_size,
  );

  const rc = os.linux.mmap(
    null,
    @intCast(img_size),
    .{ .READ = true, .WRITE = true },
    .{ .TYPE = .SHARED },
    shm_fd,
    0
  );

  if (@as(isize, @bitCast(rc)) < 0) {
    log.err("failed to map in shmfile memory!", .{});
  }

  const ptr: []u8 = @as([*]u8, @ptrFromInt(rc))[0..@intCast(img_size)];
  const img_buffer: []u32 = @alignCast(@ptrCast(ptr));

  const shm_pool = shm.create_pool(
    &proxy,
    shm_fd,
    @intCast(img_size),
  );

  return .{
    .proxy = proxy,
    .fd = shm_fd,
    .buffer = img_buffer,
    .wl_shm_pool = shm_pool,
  };
}

fn open_shmfile(arena: *Arena) c_int {
  const linux = os.linux;
  const timestamp = time.us();
  const name_template = "/var/tmp/vkRender-XXXXXX";

  var name = arena.push(u8, name_template.len + 1);
  @memcpy(name[0..name.len-1], name_template);
  for (name[(name.len - 7)..][0..6]) |*byte| {
    byte.* = @intCast((
      'A' + (timestamp & 15) + ((timestamp & 16) * 2)
    ));
  }

  log.debug("opening shmfile with name {s}", .{name});

  const fd = linux.open(
    @ptrCast(name.ptr),
    .{
      .ACCMODE = .RDWR,
      .CREAT = true,
      .EXCL = true,
      .CLOEXEC = true,
    },
    0o600,
  );

  log.debug("shmfile handle :: {}", .{@as(isize, @bitCast(fd))});
  _ = linux.unlink(@ptrCast(name.ptr));
  return @intCast(@as(isize, @bitCast(fd)));
}

fn update() void {
}

fn draw() void {
}

const VkDeviceCandidate = struct {
  pdev: vk.PhysicalDevice,
  properties: vk.PhysicalDeviceProperties,
  score: u32,
};

const OffscreenBuffer = platform.OffscreenBuffer;

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

const drm = gfx.Drm;
const gfx = platform.gfx;

const base = @import("base");
const os = @import("os");
const vk = @import("vulkan");
const platform = @import("platform");

const log = std.log.scoped(.App);

const std = @import("std");
const builtin = @import("builtin");