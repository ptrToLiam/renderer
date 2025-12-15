const AppName = "Renderer";

pub var app_state: AppState = undefined;

pub fn app_main_entry() !void {
  const app_name = "LmDev-" ++ AppName;
  const arena: *Arena = .init(.default);
  defer arena.release();

  const initial_width = 400;
  const initial_height = 400;

  var window: gfx.Window = try .create(
    arena,
    .{
      .title = app_name,
      .class = "Liam.Games.Renderer",
      .width = initial_width,
      .height = initial_height,
    },
  );
  defer window.destroy();

  var swapchain: Wayland.ShmImageQueue = try .create(
    window.handle.conn,
    window.handle.shm,
    2560,
    1440,
  );

  try swapchain.resize(initial_width, initial_height);
  defer swapchain.destroy() catch |err| {
    app_log.err("failed to destroy shm_pool swapchain :: {s}", .{@errorName(err)});
  };

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
  app_state.wayland_state = &wayland_state;
  app_state.swapchain = swapchain;

  const thread_count = std.Thread.getCpuCount() catch 1;
  app_log.info("available thread count :: {d}", .{thread_count});

  var app_threads = arena.push(Thread, thread_count);
  var app_thread_lctxs = arena.push(Thread.LaneContext, thread_count);
  const app_threads_barrier: *Thread.Barrier = arena.create(Thread.Barrier);
  app_threads_barrier.* = .init(@intCast(thread_count));
  var app_lane_broadcast_val: usize = 0;

  var draw_threads = arena.push(Thread, thread_count);
  var draw_thread_lctxs = arena.push(Thread.LaneContext, thread_count);
  const draw_threads_barrier: *Thread.Barrier = arena.create(Thread.Barrier);
  draw_threads_barrier.* = .init(@intCast(thread_count));
  var render_lane_broadcast_val: usize = 0;

  for (0..thread_count) |idx| {
    app_thread_lctxs[idx] = .{
      .lane_idx = idx,
      .lane_count = thread_count,
      .barrier = app_threads_barrier,
      .broadcast_memory = &app_lane_broadcast_val,
    };
    draw_thread_lctxs[idx] = .{
      .lane_idx = idx,
      .lane_count = thread_count,
      .barrier = draw_threads_barrier,
      .broadcast_memory = &render_lane_broadcast_val,
    };

    app_threads[idx] = try .launch(app_thread_entry, &app_thread_lctxs[idx]);
    draw_threads[idx] = try .launch(draw_thread_entry, &draw_thread_lctxs[idx]);
  }

  for (app_threads) |app_thread| {
    app_thread.join();
  }
  app_log.info("all app threads joined", .{});

  for (draw_threads) |draw_thread| {
    draw_thread.join();
  }
  std.log.info("all render threads joined", .{});
}

fn app_thread_entry(lctx: *Thread.LaneContext) void {
  Thread.ctx_init();
  defer Thread.ctx_release();

  Thread.lane_ctx(lctx.*);
  Thread.set_namef("app_lane_{d}", .{Thread.lane_idx()});
  const connection = app_state.wayland_state.connection;

  while (true) {
    if (Thread.lane_idx() == 0) {
      var attempts: u16 = 0;
      while (attempts < 5) : (attempts += 1) {
        connection.load_events() catch |err| {
          switch (err) {
            error.NoData => {},
            error.SocketReadFailed => {},
            else => {
              std.log.err("Failed to load wayland events :: {s}", .{@errorName(err)});
              break;
            },
          }
        };
        while (connection.event()) |event| {
          handle_wl_event(app_state.wayland_state, &event) catch |err| {
            std.log.err("Failed to handle wayland event :: {s}", .{@errorName(err)});
          };
        }
        app_state.wayland_state.connection.flush() catch |err| {
          std.log.err("Failed to flush Wayland Event responses :: {s}", .{@errorName(err)});
          app_state.signal_exit();
        };
      }
    }

    Thread.lane_sync();

    if (Thread.lane_idx() == 0) {
      if (app_state.swapchain.present_idx) |active_frame_idx| {
        const wl_surface = app_state.wayland_state.wl_surface;
        const proxy = app_state.wayland_state.proxy;
        const width = app_state.swapchain.width;
        const height = app_state.swapchain.height;
        wl_surface.attach(proxy, .{
          .buffer = app_state.swapchain.buffers[active_frame_idx],
          .x = 0,
          .y = 0,
        }) catch unreachable;
        wl_surface.damage_buffer(proxy, .{
          .x = 0,
          .y = 0,
          .width = @intCast(width),
          .height = @intCast(height),
        }) catch unreachable;
        wl_surface.commit(proxy) catch unreachable;
        app_state.wayland_state.connection.flush() catch |err| {
          app_log.err("App quitting due to error :: {s}", .{
            @errorName(err),
          });
          app_state.signal_exit();
        };
      }
    }

    Thread.lane_sync();
    var need_exit: bool = false;
    if (Thread.lane_idx() == 0) {
      need_exit = app_state.should_exit();
    }
    Thread.lane_sync_u64(bool, &need_exit, 0);
    if (need_exit) {
      break;
    }
  }
}

fn draw_thread_entry(lctx: *Thread.LaneContext) void {
  Thread.ctx_init();
  defer Thread.ctx_release();

  Thread.lane_ctx(lctx.*);
  Thread.set_namef("render_lane_{d}", .{Thread.lane_idx()});

  var img: []gfx.Pixel = undefined;
  var frame_idx: u64 = 0;
  while (true) : (frame_idx += 1) {
    img = app_state.swapchain.images[frame_idx % app_state.swapchain.images.len];
    const rng = Thread.lane_range(img.len);
    for (rng.min..rng.max) |idx| {
      img[idx] = @bitCast(gfx.Color.black);
    }
    if (Thread.lane_idx() == 0) {
      app_state.swapchain.active[frame_idx % 3] = true;
      app_state.swapchain.present_idx = @intCast(frame_idx % 3);
    }

    Thread.lane_sync();
    var need_exit: bool = false;
    if (Thread.lane_idx() == 0) {
      need_exit = app_state.should_exit();
    }
    Thread.lane_sync_u64(bool, &need_exit, 0);
    if (need_exit) {
      break;
    }
  }
}

pub fn handle_wl_event(noalias state: *WaylandState, noalias event: *const Wayland.Protocols.Event) !void {
  switch (event.*) {
    .wl_display => |display_event| switch (display_event) {
      .@"error" => |err| {
        event_log.debug("Display Error :: {{ .object_id={d}, .code={d}, .message=\"{s}\"", .{
          err.object_id, err.code, err.message,
        });
      },
      .delete_id => {},
    },
    .wl_seat => |seat_event| switch (seat_event) {
      .capabilities => |seat_capabilities| {
        event_log.debug("wl_seat capabilities :: {{ .pointer={s}, .keyboard={s}, .touch={s} }}", .{
          if (seat_capabilities.capabilities.pointer) "true" else "false",
          if (seat_capabilities.capabilities.keyboard) "true" else "false",
          if (seat_capabilities.capabilities.touch) "true" else "false",
        });
      },
      .name => |seat_name| {
        event_log.debug("wl_seat name :: {s}", .{seat_name.name});
      },
    },
    .wl_surface => |surface_event| switch (surface_event) {
      else => event_log.debug("wl_surface_event :: {any}", .{surface_event}),
    },
    .wl_buffer => |buffer_event| switch (buffer_event) {
      .release => {},
    },
    .xdg_wm_base => |xdg_wm_base_event| switch (xdg_wm_base_event) {
      .ping => |ping| {
        try state.wm_base.pong(state.proxy, .{ .serial = ping.serial });
      },
    },
    .xdg_surface => |xdg_surface_event| switch (xdg_surface_event) {
      .configure => |configure| {
        try state.xdg_surface.ack_configure(state.proxy, .{ .serial = configure.serial });
      },
    },
    .xdg_toplevel => |xdg_toplevel_event| switch (xdg_toplevel_event) {
      .configure => |configure| {
        if (configure.width > 0) {
          try app_state.swapchain.resize(configure.width, configure.height);
        }
      },
      .wm_capabilities => |wm_capabilities| {
        const Capability = Wayland.Protocols.XdgShell.Toplevel.Enum.WmCapabilities;
        var iter = std.mem.window(
          u8,
          wm_capabilities.capabilities,
          @sizeOf(Capability),
          @sizeOf(Capability),
        );

        while (iter.next()) |cap_bytes| {
          const capability = std.mem.bytesToValue(Capability, cap_bytes);
          event_log.debug("xdg_toplevel :: wm_capability :: {s}", .{
            @tagName(capability),
          });
        }
      },
      .close => {
        event_log.debug("xdg_toplevel :: received close event", .{});
        app_state.signal_exit();
      },
      else => {
        event_log.debug("xdg_toplevel :: unhandled event :: {any}", .{event});
      },
    },
    else => {
      event_log.debug("event :: {any}", .{event});
    },
  }
}

pub var new_swapchain: ?struct { width: i32, height: i32 } = null;

const AppState = struct {
  wayland_state: *WaylandState,
  swapchain: Wayland.ShmImageQueue,
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

const Light = gfx.Light;
const Sphere = gfx.Sphere;
const Wayland = gfx.Wayland;

const Arena = base.Arena;
const Thread = base.Thread;
const Vec3f32 = math.Vec3f32;

const math = base.math;

const app_log = std.log.scoped(.App);
const event_log = std.log.scoped(.Event);

// File Imports
const raytracer = @import("raytracer.zig");

// Internal Module Imports
const gfx = @import("gfx");
const base = @import("base");

// 3rd-Party Module Imports
const std = @import("std");
const builtin = @import("builtin");
