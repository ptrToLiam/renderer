pub fn app(env: std.process.Environ) void {
  const app_name = "LmDev-" ++ AppName;
  const arena: *Arena = .init(.default);
  defer arena.release();

  const initial_width = 540;
  const initial_height = 360;

  const wayland_init_start_us = time.us();
  var window = gfx.Window.create(
    env,
    arena,
    .{
      .title = app_name,
      .class = "Liam.Games.Renderer",
      .width = initial_width,
      .height = initial_height,
    },
  ) catch |err| {
    std.log.err("Failed to create window :: {s}", .{@errorName(err)});
    return;
  };

  defer window.destroy();

  var wayland_state: WaylandState = .{
    .connection = window.handle.conn,
    .proxy = @constCast(&window.handle.conn.proxy()),

    // globals
    .display = window.handle.display,
    .seat = window.handle.seat,
    .shm = window.handle.shm,
    .wm_base = window.handle.wm_base,

    // objects
    .wl_surface = window.handle.wl_surface,
    .xdg_surface = window.handle.xdg_surface,
    .xdg_toplevel = window.handle.xdg_toplevel,
  };

  _ = &wayland_state;
  const wayland_init_end_us = time.us();
  const wayland_init_us = wayland_init_end_us - wayland_init_start_us;

  std.log.debug(
    "wayland state init complete in {d}us! (conn_id={d})",
    .{ wayland_init_us, wayland_state.connection.handle },
  );

  const vk_state_init_start_us = time.us();

  // TODO: Minimal Vulkan Init
  // -- tried dlopen cos std.DynLib wasn't working... no difference though
  const vk_handle = std.c.dlopen("libvulkan.so.1", .{ .NOW = true }) orelse {
    if (std.c.dlerror()) |dl_err| { std.debug.print("dl_err :: {s}\n", .{dl_err}); }
    @panic("Failed to load libvulkan.so.1");
  };
  defer _ = std.c.dlclose(vk_handle);
  const vk_get_instance_proc_addr: Vk.PfnGetInstanceProcAddr = @ptrCast(std.c.dlsym(
    vk_handle,
    "VkGetInstanceProcAddr",
  ) orelse @panic("Failed to locate VkGetInstanceProcAddr!"));

  // var vk_handle = std.DynLib.open("libvulkan.so.1") catch @panic("Failed to load libvulkan.so.1");
  // defer vk_handle.close();
  // const vk_get_instance_proc_addr = vk_handle.lookup(
  //   Vk.PfnGetInstanceProcAddr,
  //   "vkGetInstanceProcAddr",
  // ) orelse @panic("Failed to locate vkGetInstanceProcAddr");
  const vkb = Vk.BaseWrapper.load(vk_get_instance_proc_addr);
  var instance: Vk.Instance = undefined;
  var instance_wrapper: Vk.InstanceWrapper = undefined;
  {

    const app_info = Vk.ApplicationInfo{
      .p_application_name = app_name,
      .application_version = @bitCast(Vk.makeApiVersion(0, 1, 0, 0)),
      .p_engine_name = "custom",
      .engine_version = @bitCast(Vk.makeApiVersion(0, 1, 0, 0)),
      .api_version = @bitCast(Vk.API_VERSION_1_3),
    };

    const instance_info = Vk.InstanceCreateInfo{
      .p_application_info = &app_info,
    };
    instance = vkb.createInstance(&instance_info, null) catch @panic("uh oh!");
    instance_wrapper = .load(instance, vk_get_instance_proc_addr);
  }

  defer instance_wrapper.destroyInstance(instance, null);

  const vk_state_init_end_us = time.us();
  const vk_state_init_us = vk_state_init_end_us - vk_state_init_start_us;
  std.log.debug(
    "vulkan state init complete in {d}us ({d}ms)!",
    .{ vk_state_init_us, vk_state_init_us / time.us_per_ms },
  );
}

fn update() void {
}

fn draw() void {
}

const AppName = "VkRender";
const Swapchain = struct {
};
//----------------------------------------------------------------
// TODO: GET RID OF THIS SECTION
//----------------------------------------------------------------
const AppState = struct {
  wayland_state: *WaylandState,
  swapchain: Swapchain,
  frame_idx: u64 = 0,
  exit_flag: u32 = 0,

  pub fn should_exit(state: *AppState) bool {
    return (@atomicLoad(u32, &state.exit_flag, .seq_cst) == 1);
  }
  pub fn signal_exit(state: *AppState) void {
    @atomicStore(u32, &state.exit_flag, 1, .seq_cst);
  }
};

const WaylandState = struct {
  connection: *Wayland.Connection,
  proxy: *Wayland.Protocols.Proxy,

  // globals
  display: Wayland.Protocols.Wayland.Display,
  seat: Wayland.Protocols.Wayland.Seat,
  shm: Wayland.Protocols.Wayland.Shm,
  wm_base: Wayland.Protocols.XdgShell.WmBase,

  // objects
  wl_surface: Wayland.Protocols.Wayland.Surface,
  xdg_surface: Wayland.Protocols.XdgShell.Surface,
  xdg_toplevel: Wayland.Protocols.XdgShell.Toplevel,
};
const Wayland = gfx.Wayland;
//----------------------------------------------------------------
const program_start_time = @import("main.zig").start_time;

const Arena = base.Arena;
const Thread = base.Thread;
const math = base.math;
const time = base.time;

const base = @import("base");
const os = @import("os");
const gfx = @import("gfx");
const Vk = @import("vulkan");

const std = @import("std");
const builtin = @import("builtin");