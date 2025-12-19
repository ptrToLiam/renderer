const AppName = "Renderer";

pub var app_state: AppState = undefined;

pub fn main_entry() !void {
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

  var sw_render_threads = arena.push(Thread, thread_count);
  var sw_render_thread_lctxs = arena.push(Thread.LaneContext, thread_count);
  const sw_render_threads_barrier: *Thread.Barrier = arena.create(Thread.Barrier);
  sw_render_threads_barrier.* = .init(@intCast(thread_count));
  var sw_render_lane_broadcast_val: usize = 0;

  for (0..thread_count) |idx| {
    sw_render_thread_lctxs[idx] = .{
      .lane_idx = idx,
      .lane_count = thread_count,
      .barrier = sw_render_threads_barrier,
      .broadcast_memory = &sw_render_lane_broadcast_val,
    };

    sw_render_threads[idx] = try .launch(sw_render_thread_entry, &sw_render_thread_lctxs[idx]);
  }

  while (!app_state.should_exit()) {
    update();
  }

  for (sw_render_threads) |sw_render_thread| {
    sw_render_thread.join();
  }
  app_log.info("Software render threads joined", .{});
}

fn update() void {
  const fixed_time_target = std.time.ns_per_us * 100;
  const connection = app_state.wayland_state.connection;
  
  const update_tick_begin_time = std.time.microTimestamp();
  
  defer {
    const update_tick_end_time = std.time.microTimestamp();
    const elapsed_us = update_tick_end_time - update_tick_begin_time;
    app_log.info("update step duration :: {d}us", .{elapsed_us});
    const elapsed_ns = elapsed_us * std.time.ns_per_us;
    const elapsed_to_target_diff = fixed_time_target - elapsed_ns;
    if (elapsed_to_target_diff > 0) {
      Thread.sleep(@intCast(elapsed_to_target_diff));
    }
  }
  
  connection.load_events() catch {};
  
  while (connection.event()) |event| {
    std.log.debug("received event :: {any}", .{event});
    handle_wl_event(app_state.wayland_state, &event) catch |err| {
      std.log.err("Failed to wayland event :: {s}", .{@errorName(err)});
    };
  }

  app_state.wayland_state.connection.flush() catch |err| {
    std.log.err("Failed to flush Wayland Event responses :: {s}", .{@errorName(err)});
    app_state.signal_exit();
  };

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

fn sw_render_thread_entry(lctx: *Thread.LaneContext) void {
  Thread.ctx_init();
  defer Thread.ctx_release();

  Thread.lane_ctx(lctx.*);
  Thread.set_namef("render_lane_{d}", .{Thread.lane_idx()});

  var img: []gfx.Pixel = undefined;
  var frame_idx: u64 = 0;
  while (true) : (frame_idx += 1) {
    const sc_len = app_state.swapchain.images.len;
    const mod_frame_idx = frame_idx % sc_len;
    
    img = app_state.swapchain.images[mod_frame_idx];
  
    const rng = Thread.lane_range(img.len);
    for (rng.min..rng.max) |idx| {
      img[idx] = @bitCast(gfx.Color.black);
    }
    if (Thread.lane_idx() == 0) {
      app_state.swapchain.active[mod_frame_idx] = true;
      app_state.swapchain.present_idx = @intCast(mod_frame_idx);
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
