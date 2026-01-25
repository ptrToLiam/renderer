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

const std = @import("std");
const builtin = @import("builtin");