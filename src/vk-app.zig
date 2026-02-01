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

  //---------------------------------------------------------------------------
  // BEGIN VULKAN STATE INIT
  //---------------------------------------------------------------------------

  const vk_state_init_start_us = time.us();

  // TODO: Minimal Vulkan Init
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

  const vk_state_init_end_us = time.us();
  const vk_state_init_us = vk_state_init_end_us - vk_state_init_start_us;

  //---------------------------------------------------------------------------
  // END VULKAN STATE INIT
  //---------------------------------------------------------------------------

  std.log.debug(
    "vulkan state init complete in {d}us ({d}ms)!",
    .{ vk_state_init_us, vk_state_init_us / time.us_per_ms },
  );

  const mod: drm.Modifier = .invalid;
  const modval = mod.toModVal();
  std.log.debug("drm mod invalid :: {{ .mod={s}, .vendor={s} }}", .{ @tagName(mod), @tagName(modval.vendor) });

  var want_exit = true;
  _ = &want_exit;
  while (!want_exit) {
    update();
    draw();
  }
}

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