const AppName = "Renderer";

pub var app_state: AppState = undefined;
pub var allow_resize: bool = true;

pub fn main_entry() !void {
  const app_name = "LmDev-" ++ AppName;
  const arena: *Arena = .init(.default);
  defer arena.release();

  const initial_width = 540;
  const initial_height = 360;

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
  const fixed_time_target = std.time.us_per_ms * 10;
  const connection = app_state.wayland_state.connection;

  const update_tick_begin_time = std.time.microTimestamp();

  defer {
    const update_tick_end_time = std.time.microTimestamp();
    const elapsed_us = update_tick_end_time - update_tick_begin_time;
    const elapsed_to_target_diff = fixed_time_target - elapsed_us;
    if (elapsed_to_target_diff > 0) {
      const sleep_target_ns = elapsed_to_target_diff * std.time.ns_per_us;
      Thread.sleep(@intCast(sleep_target_ns));
    }
  }

  connection.load_events() catch {};

  while (connection.event()) |event| {
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

    // commit new frame for present
    {
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
}

const Point = struct { x: i32, y: i32 };

pub var point0: Point = .{ .x = 200, .y = 100 };
pub var point1: Point = .{ .x = 100, .y = 400 };
pub var point2: Point = .{ .x = 300, .y = 400 };

fn sw_render_thread_entry(lctx: *Thread.LaneContext) void {
  Thread.ctx_init();
  defer Thread.ctx_release();

  Thread.lane_ctx(lctx.*);
  Thread.set_namef("render_lane_{d}", .{Thread.lane_idx()});

  var img: []gfx.Pixel = undefined;
  var frame_number: u32 = 0;
  const target_frame_time_us: i64 = std.time.us_per_ms * 16;

  while (true) : (frame_number +%= 1) {
    const frame_time_begin_us: i64 = std.time.microTimestamp();
    defer {
      const frame_time_end_us: i64 = std.time.microTimestamp();
      const frame_time_diff_us = frame_time_end_us - frame_time_begin_us;

      const sleep_time: i64 = @max(target_frame_time_us - frame_time_diff_us, 0);
      Thread.sleep(@intCast(sleep_time));
    }

    const sc_len = app_state.swapchain.images.len;
    const mod_frame_idx = frame_number % sc_len;

    img = app_state.swapchain.images[mod_frame_idx];

    const img_width = app_state.swapchain.width;
    const img_height = app_state.swapchain.height;

    const rng = Thread.lane_range(img.len);

    // Clear screen
    @memset(img[rng.min..rng.max], @bitCast(gfx.Color.black));
    Thread.lane_sync();

    tri_wireframe(
      point0,
      point1,
      point2,
      img,
      img_width,
      img_height,
      @intCast(rng.min),
      @intCast(rng.max),
      .white,
    );
    tri_fill(
      point0,
      point1,
      point2,
      img,
      img_width,
      .green,
    );


    Thread.lane_sync();

    var need_exit: bool = false;
    if (Thread.lane_idx() == 0) {
      need_exit = app_state.should_exit();
    }
    Thread.lane_sync_u64(bool, &need_exit, 0);
    if (need_exit) {
      break;
    }

    if (Thread.lane_idx() == 0) {
      app_state.swapchain.active[mod_frame_idx] = true;
      app_state.swapchain.present_idx = @intCast(mod_frame_idx);
    }
  }
}

fn draw_line(
  p0: Point,
  p1: Point,
  img: []u32,
  img_width: i32,
  img_height: i32,
  min_idx: u32,
  max_idx: u32,
  color: gfx.Color,
  ) void
{
  const x0: i32 = @intCast(p0.x);
  const y0: i32 = @intCast(p0.y);
  const x1: i32 = @intCast(p1.x);
  const y1: i32 = @intCast(p1.y);

  const dx: i32 = @intCast(@abs(x1 - x0));
  const dy: i32 = @intCast(@abs(y1 - y0));
  var err: i64 = @as(i64, dx) - @as(i64, dy);

  const sx: i32 = if (x0 < x1) 1 else -1;
  const sy: i32 = if (y0 < y1) 1 else -1;

  var pix_x: i32 = x0;
  var pix_y: i32 = y0;

  while (true) {
    if (pix_x >= 0 and pix_x < @as(i32, img_width) and pix_y >= 0 and pix_y < @as(i32, img_height)) {
      const idx_calc: i64 = @as(i64, pix_y) * @as(i64, img_width) + @as(i64, pix_x);
      const img_idx: usize = @intCast(idx_calc);
      if (img_idx >= min_idx and img_idx < max_idx) {
        img[img_idx] = @bitCast(color);
      }
    }

    if (pix_x == x1 and pix_y == y1) break;

    const e2: i64 = 2 * err;
    if (e2 > -@as(i64, dy)) { err -= @as(i64, dy); pix_x += sx; }
    if (e2 < @as(i64, dx)) { err += @as(i64, dx); pix_y += sy; }
  }
}

fn tri_wireframe(
  p0: Point,
  p1: Point,
  p2: Point,
  img: []u32,
  img_width: i32,
  img_height: i32,
  min_idx: u32,
  max_idx: u32,
  color: gfx.Color,
) void
{
  draw_line(
    p0,
    p1,
    img,
    img_width,
    img_height,
    min_idx,
    max_idx,
    color,
  );

  draw_line(
    p1,
    p2,
    img,
    img_width,
    img_height,
    min_idx,
    max_idx,
    color,
  );

  draw_line(
    p2,
    p0,
    img,
    img_width,
    img_height,
    min_idx,
    max_idx,
    color,
  );
}

fn signed_tri_area(p0: Point, p1: Point, p2: Point) f64 {
  return f64_(0.5) * f64_(
    (p1.y - p0.y) * (p1.x + p0.x) +
    (p2.y - p1.y) * (p2.x + p1.x) +
    (p0.y - p2.y) * (p0.x + p2.x)
  );
}

pub fn tri_fill(
  p0: Point,
  p1: Point,
  p2: Point,
  img: []u32,
  img_width: i32,
  color: gfx.Color,
) void
{
  const bb_min_x = @min(@min(p0.x, p1.x), p2.x);
  const bb_min_y = @min(@min(p0.y, p1.y), p2.y);
  const bb_max_x = @max(@max(p0.x, p1.x), p2.x);
  const bb_max_y = @max(@max(p0.y, p1.y), p2.y);

  const total_area = signed_tri_area(p0, p1, p2);
  const x_rng = Thread.lane_range(@intCast(bb_max_x - bb_min_x + 1));

  for (x_rng.min..x_rng.max) |x| {
    const pix_x = @as(i32, @intCast(x)) + bb_min_x;
    for (@intCast(bb_min_y)..@intCast(bb_max_y)) |pix_y| {
      const p_cur: Point = .{ .x = @intCast(pix_x), .y = @intCast(pix_y) };
      const alpha = signed_tri_area(
        p_cur,
        p1,
        p2
      ) / total_area;
      const beta = signed_tri_area(
        p_cur,
        p2,
        p0,
      ) / total_area;
      const gamma = signed_tri_area(
        p_cur,
        p0,
        p1,
      ) / total_area;

      if (alpha < 0 or beta < 0 or gamma < 0) continue;
      const idx_calc: i64 = (@as(i64, @intCast(pix_y)) * @as(i64, img_width)) + (@as(i64, @intCast(pix_x)));
      const img_idx: usize = @intCast(idx_calc);
      if (img_idx > img.len) {
        @branchHint(.cold);
        std.log.debug("[lane#{d}] exceeded buffer bounds with idx: {d}", .{ Thread.lane_idx(), img_idx });
        continue;
      }
      img[img_idx] = @bitCast(color);
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
    .wl_registry => |registry_event| switch (registry_event) {
      .global => |registry_global| {
        event_log.debug(
          "Registry Global :: {{ .interface={s}, .name={d}, .version = {d} }}",
          .{ registry_global.interface, registry_global.name, registry_global.version, }
        );
      },
      .global_remove => |global_remove| {
        event_log.debug(
          "Registry Global Remove :: {{ .name={d} }}",
          .{ global_remove.name }
        );
      },
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
        if (configure.width > 0 and allow_resize) {
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

fn f64_(v: anytype) f64 {
   return switch (@typeInfo(@TypeOf(v))) {
    .int, .comptime_int => @floatFromInt(v),
    .float => @floatCast(v),
    .comptime_float => @as(f64, v),
    else => @compileError("Invalid type for f64"),
  };
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
