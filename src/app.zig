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

  const vk_pdev: *vk.PhysicalDevice = arena.create(vk.PhysicalDevice);
  var vkd: vk.DeviceWrapper = undefined;
  var vk_dev: vk.Device = undefined;
  var queue_family_index: u32 = undefined;
  _ = &vk_dev; _ = &queue_family_index;
  _ = &vkd;

  defer vkd.destroyDevice(vk_dev, null);
  var ofb: [2]OffscreenBuffer = undefined;

  //---------------------------------------------------------------------------
  // END VULKAN STATE INIT
  //---------------------------------------------------------------------------

  const vk_state_init_end_us = time.us();
  const vk_state_init_us = vk_state_init_end_us - vk_state_init_start_us;
  log.debug(
    "vulkan instance init complete in {d}us ({d}ms)!",
    .{ vk_state_init_us, vk_state_init_us / time.us_per_ms },
  );

  const initial_width = 540;
  const initial_height = 360;

  //---------------------------------------------------------------------------
  // BEGIN PLATFORM STATE INIT
  //---------------------------------------------------------------------------

  const platform_init_start_us = time.us();
  var platform_conn: platform.Connection = .open(arena, env);

  defer platform_conn.close();

  var surface = platform_conn.acquire_surface(
    arena,
    .{
      .title = app_name,
      .class = app_class,
      .width = initial_width,
      .height = initial_height,
      .flags = .{ .resize = true },
    },
  );
  defer surface.release();

  const platform_init_end_us = time.us();
  const platform_init_us = platform_init_end_us - platform_init_start_us;

  //---------------------------------------------------------------------------
  // END PLATFORM STATE INIT
  //---------------------------------------------------------------------------

  log.debug(
    "platform state init complete in {d}us ({d:.2}ms)!",
    .{ platform_init_us, base.f64_(platform_init_us) / base.f64_(time.us_per_ms) },
  );

  var events: platform.EventList = .empty;
  var want_exit = false;

  platform_conn.handle.flush() catch unreachable;

  var ofb_wlbuf: [2]platform.wayland.WaylandBuffer = undefined;
  var want_attach = false;

  const time_target = time.us_per_s / 120;
  var buf_idx: u32 = 0;
  _ = &buf_idx;
  while (!want_exit) {
    var wl_connection_proxy = platform_conn.handle.proxy();
    const frame_time_start = time.us();
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
          log.debug("app-level ev :: {any}", .{ev});
        },
      }
    }

    if (want_attach) {
      log.debug("attaching buffer :: {} (wl_object_id={}, fd={})", .{ buf_idx, u32_(ofb_wlbuf[buf_idx]), ofb[buf_idx].memory_fd});
      surface.handle.wl_surface.attach(
        &wl_connection_proxy,
        ofb_wlbuf[buf_idx],
        0,
        0,
      );
      surface.handle.wl_surface.damage_buffer(
        &wl_connection_proxy,
        0,
        0,
        surface.width,
        surface.height,
      );
      // platform_conn.handle.flush() catch unreachable;
      // const drm_mod = selectWaylandModFromFmt(&platform_conn.handle, .rgba32);

      // ofb[1] = .create(
      //     vkd,
      //     vk_dev,
      //     vki,
      //     vk_pdev.*,
      //     u32_(surface.width),
      //     u32_(surface.height),
      //     .rgba32,
      //     drm_mod,
      //   );
      //   ofb_wlbuf[1] = platform_conn.handle.wl_buffer(
      //     ofb[1],
      //   );
      // _ = &buf_idx;
      // buf_idx += 1;
      // buf_idx %= 2;
    }

    if (!want_attach and surface.handle.ready()) {
      _ = platform_conn.handle.client_state.linux_dmabuf.get_surface_feedback(
        &wl_connection_proxy,
        surface.handle.wl_surface,
      );

      log.debug("surface ready :: setting want_attach to true", .{});
      want_attach = true;

      if (!platform_conn.handle.client_state.dmabuf_feedback.done) {
        want_attach = false;
      } else {
        vk_dev, queue_family_index = selectWaylandVkDevice(
          platform_conn.handle,
          instance,
          vki,
          vk_pdev,
        );
        vkd = .load(
          vk_dev,
          vki.dispatch.vkGetDeviceProcAddr.?,
        );
        const drm_mod = selectWaylandModFromFmt(&platform_conn.handle, .rgba32);
        ofb[0] = .create(
          vkd,
          vk_dev,
          vki,
          vk_pdev.*,
          u32_(surface.width),
          u32_(surface.height),
          .rgba32,
          drm_mod,
        );
        ofb_wlbuf[0] = platform_conn.handle.wl_buffer(
          ofb[0],
        );
      }
    }

    if (surface.handle.ready()) surface.handle.wl_surface.commit(&wl_connection_proxy);
    // surface.handle.wl_surface.damage(&wl_connection_proxy, 0, 0, surface.width, surface.height );
    platform_conn.handle.flush() catch unreachable;

    update();
    draw();

    const frame_time_end = time.us();
    const frame_elapsed_us = frame_time_end - frame_time_start;
    if (frame_elapsed_us < time_target) {
      Thread.sleep((time_target - frame_elapsed_us) * time.ns_per_us);
    }
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
    @memset(pool.buffer, 0xefefefef);
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
    base.usize_(img_size),
    .{ .READ = true, .WRITE = true },
    .{ .TYPE = .SHARED },
    shm_fd,
    0
  );

  const irc = transmute(isize, rc);
  if (irc < 0) {
    log.err("failed to map in shmfile memory!", .{});
  }

  const ptr: []u8 = transmute([*]u8, rc)[0..base.usize_(img_size)];
  const img_buffer = transmute([]u32, ptr);

  const shm_pool = shm.create_pool(
    &proxy,
    shm_fd,
    img_size,
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
    byte.* = base.u8_((
      'A' + (timestamp & 15) + ((timestamp & 16) * 2)
    ));
  }

  const fd = linux.open(
    transmute(CString, name),
    .{
      .ACCMODE = .RDWR,
      .CREAT = true,
      .EXCL = true,
      .CLOEXEC = true,
    },
    0o600,
  );

  _ = linux.unlink(transmute(CString, name));
  return base.i32_(transmute(isize, fd));
}

fn update() void {
}

fn draw() void {
}

fn selectWaylandVkDevice(
  wayland_conn: platform.wayland.Connection,
  instance: vk.Instance,
  vki: vk.InstanceWrapper,
  pdev: *vk.PhysicalDevice,
) struct { vk.Device, u32 } {
  // Physical Device Selection
  var vk_pdev_count: u32 = 0;
  _ = vki.enumeratePhysicalDevices(
    instance,
    &vk_pdev_count,
    null,
  ) catch unreachable;

  var scratch = Thread.Context.get_scratch(0, .{}).?;
  defer scratch.end();
  const vk_pdev_arena = scratch.arena;
  var vk_pdevs = vk_pdev_arena.push(vk.PhysicalDevice, vk_pdev_count);

  _ = vki.enumeratePhysicalDevices(
    instance,
    &vk_pdev_count,
    vk_pdevs.ptr,
  ) catch unreachable;
  if (vk_pdevs.len == 0) @panic("no vk physical devices available")
  else log.debug("found {} vk physical devices!!", .{vk_pdevs.len});

  const main_device = wayland_conn.client_state.dmabuf_feedback.main_device;
  // vk physical device enumeration
  var vk_pdev_candidate: VkDeviceCandidate = .{ .pdev = undefined, .properties = undefined, .score = 0 };
  for (vk_pdevs) |vk_pdev_opt| {
    var pdev_drm: vk.PhysicalDeviceDrmPropertiesEXT = .{
      .has_primary = .false,
      .has_render = .false,
      .primary_major = 0,
      .primary_minor = 0,
      .render_major = 0,
      .render_minor = 0,
    };

    var pdev_props13: vk.PhysicalDeviceVulkan13Properties = undefined;
    pdev_props13.s_type = .physical_device_vulkan_1_3_properties;
    pdev_props13.p_next = &pdev_drm;

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
      if (pdev_drm.has_primary == .true) {
        if (pdev_drm.primary_major == major(main_device) and pdev_drm.primary_minor == minor(main_device)) {
          log.debug("correct GPU found (primary)!", .{});
          vk_pdev_candidate = .{
            .pdev = vk_pdev_opt,
            .properties = pdev_props2.properties,
            .score = score,
          };
        }
      }

      if (pdev_drm.has_render == .true) {
        if (pdev_drm.render_major == major(main_device) and pdev_drm.render_minor == minor(main_device)) {
          log.debug("correct GPU found (render)!", .{});
          vk_pdev_candidate = .{
            .pdev = vk_pdev_opt,
            .properties = pdev_props2.properties,
            .score = score,
          };
        }
      }
    }
  }

  pdev.* = vk_pdev_candidate.pdev;


  log.debug(
    "Selected GPU: {s}",
    .{
      vk_pdev_candidate.properties.device_name,
    },
  );
  const vk_dev_create_arena = scratch.arena;
  // Logical Device Creation
  const vk_dev, const queue_family_index = vk_dev: {
    const queue_family_index = qfi: {
      var queue_family_count: u32 = 0;
      vki.getPhysicalDeviceQueueFamilyProperties(
        pdev.*,
        &queue_family_count,
        null,
      );
      const queue_families = vk_dev_create_arena.push(
        vk.QueueFamilyProperties,
        queue_family_count
      );

      vki.getPhysicalDeviceQueueFamilyProperties(
        pdev.*,
        &queue_family_count,
        queue_families.ptr,
      );

      for (queue_families, 0..) |queue_family_props, index| {
        if (queue_family_props.queue_flags.graphics_bit) {
          break :qfi u32_(index);
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

      .enabled_extension_count = u32_(vk_required_device_extensions.len),
      .pp_enabled_extension_names = &vk_required_device_extensions,
    };

    break :vk_dev .{
      vki.createDevice(
        pdev.*,
        &device_info,
        null,
      ) catch unreachable,
      queue_family_index,
    };
  };
  return .{ vk_dev, queue_family_index };
}

fn major(dev: u64) u64 {
  return ((dev >> 8) & 0xfff);
}
fn minor(dev: u64) u64 {
    return ((dev & 0xff) | ((dev >> 12) & 0xffffff00));
}

fn selectWaylandModFromFmt(
  connection: *platform.wayland.Connection,
  format: gfx.Format,
) Drm.Modifier {
  const desired_fmt = u32_(format.toDrm());
  const format_table = connection.client_state.dmabuf_feedback.fmt_table;
  const res = os.linux.mmap(
    null,
    format_table.size,
    .{ .READ = true },
    .{ .TYPE = .PRIVATE },
    format_table.fd,
    0,
  );

  const rc = transmute(isize, res);
  if (rc < 0) {
    log.err("failed to map format table :: err={}", .{rc});
    return .invalid;
  }
  const bytes = transmute([*]u8, res)[0..format_table.size];
  defer _ = os.linux.munmap(
    bytes.ptr,
    bytes.len,
  );

  var iter = std.mem.window(u8, bytes, 16, 16);
  while (iter.next()) |entry| {
    const fmt = std.mem.bytesToValue(u32, entry[0..4]);
    const mod = std.mem.bytesToValue(u64, entry[8..]);
    if (fmt == desired_fmt) return cast(Drm.Modifier, mod);
  }
  return .invalid;
}

const vk_required_device_extensions = [_][*:0]const u8{
  vk.extensions.khr_external_memory.name,
  vk.extensions.khr_external_memory_fd.name,
  vk.extensions.ext_external_memory_dma_buf.name,
  vk.extensions.ext_image_drm_format_modifier.name,
};

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

const cast = base.casts.cast;
const transmute = base.casts.transmute;

const u32_ = base.u32_;
const u64_ = base.u64_;

const f32_ = base.f32_;
const f64_ = base.f64_;

const CString = [*:0]const u8;

const Arena = base.Arena;
const Thread = base.Thread;
const math = base.math;
const time = base.time;

const Drm = gfx.Drm;
const gfx = platform.gfx;

const base = @import("base");
const os = @import("os");
const vk = @import("vulkan");
const platform = @import("platform");

const log = std.log.scoped(.App);

const std = @import("std");
const builtin = @import("builtin");