pub const Connection = struct {
  fd: i32 = 0,
  want_flush: u32 = 0,

  /// Inbound event queue
  in: RingBuffer,
  /// Outbound event queue
  out: RingBuffer,
  /// Inbound fd queue
  fd_in: RingBuffer,
  /// Outbound fd queue
  fd_out: RingBuffer,

  /// Client-side state
  client_state: *ClientState,

  //---------------------------------------------------------------------------
  // Platform API Surface
  //---------------------------------------------------------------------------

  /// Open client connection to host wayland compositor
  pub fn open(arena: *Arena, env: os.Environ) Connection {
    //-------------------------------------------------------------------------
    // Allocate & Initialize Ring Buffers
    //-------------------------------------------------------------------------

    Xkb.load_lib(env) catch @panic("failed to load libxkbcommon.so!");

    // Allocating 3 pages -- 1 each for standard in/out, 1/2 each for fd in/out
    var ringbuffers: [4]RingBuffer = undefined;
    const ringbuffer_bytes = os.mem_reserve(ring_buffers_mmap_size);

    if (!os.mem_commit(ringbuffer_bytes))
      @panic("Failed to map pages for ring buffers!");

    inline for (0..2) |i| {
      const backing_bytes_rng_start = (i * ring_buffer_size);
      const backing_bytes =
        ringbuffer_bytes[backing_bytes_rng_start..][0..ring_buffer_size];

      @memset(backing_bytes, 0);
      ringbuffers[i] = .init_backing(backing_bytes);

      const fd_backing_bytes_rng_start = (2 * ring_buffer_size) +
                                            (i * fd_ring_buffer_size);
      const fd_backing_bytes =
        ringbuffer_bytes[fd_backing_bytes_rng_start..][0..fd_ring_buffer_size];
      @memset(fd_backing_bytes, 0);
      ringbuffers[i+2] = .init_backing(fd_backing_bytes);
    }

    //-------------------------------------------------------------------------

    //-------------------------------------------------------------------------
    // Retrieve Path & Connect to Socket
    //-------------------------------------------------------------------------

    const scratch = Thread.Context.get_scratch(0, .{}).?;
    const scratch_arena = scratch.arena;
    defer scratch.end();

    const xdg_runtime_dir = env.getPosix("XDG_RUNTIME_DIR").?;
    const wayland_display = env.getPosix("WAYLAND_DISPLAY").?;
    const socket_path = socket_path: {
      const socket_path_len = xdg_runtime_dir.len + wayland_display.len + 1;
      var joint_path_bytes = scratch_arena.push(u8, socket_path_len);
      var joint_path_offset: usize = 0;
      @memcpy(
        joint_path_bytes[joint_path_offset..][0..xdg_runtime_dir.len],
        xdg_runtime_dir,
      );
      joint_path_offset += xdg_runtime_dir.len;
      joint_path_bytes[joint_path_offset] = '/';
      joint_path_offset += 1;
      @memcpy(
        joint_path_bytes[joint_path_offset..][0..wayland_display.len],
        wayland_display,
      );
      break :socket_path joint_path_bytes;
    };

    const socket_fd = i32_(linux.socket(
      posix.AF.UNIX,
      posix.SOCK.STREAM | posix.SOCK.CLOEXEC | 0,
      0,
    ));

    const socket_addr = socket_addr: {
      var addr: posix.sockaddr.un = .{
        .family = posix.AF.UNIX,
        .path = @splat(0),
      };

      if (socket_path.len + 1 > addr.path.len) @panic("Socket Path Too Long");
      @memcpy(addr.path[0..socket_path.len], socket_path);
      break :socket_addr addr;
    };

    const connect_rc = linux.connect(
      socket_fd,
      &socket_addr,
      u32_(@sizeOf(@TypeOf(socket_addr))),
    );
    if (transmute(isize, connect_rc) < 0) {
      @panic("Failed to connec to wayland socket!");
    }

    //-------------------------------------------------------------------------

    //-------------------------------------------------------------------------
    // Bind Registry & Globals, Initialize Client-Side Registry
    //-------------------------------------------------------------------------

    const client_state = arena.create(ClientState);
    const client_objects = arena.push(Object, 512);
    const client_object_indices = arena.push(u32, 512);
    const client_object_index_list: FreeIdxList = .init_backing(client_object_indices);
    client_state.object_pool = .{
      .objects = client_objects,
      .free_idx_list = client_object_index_list,
    };

    var connection: Connection = .{
      // Base Wayland Connection
      .fd = socket_fd,

      // Base Wayland Connection I/O Management
      .in = ringbuffers[0],
      .out = ringbuffers[1],
      .fd_in = ringbuffers[2],
      .fd_out = ringbuffers[3],

      // Wayland State Management
      .client_state = client_state,
    };
    var conn_proxy = connection.proxy();

    client_state.display = .fromInt(client_state.object_pool.next_object_id());
    client_state.object_pool.push_object(client_state.display.object());
    client_state.registry = client_state.display.get_registry(&conn_proxy);

    connection.flush() catch @panic("failed to write to wayland socket");

    const GlobalsBound = packed struct (u8) {
      wl_seat: bool = false,
      wl_compositor: bool = false,
      xdg_wm_base: bool = false,
      linux_dmabuf: bool = false,
      wl_shm: bool = false,
      xdg_decoration_manager: bool = false,
      pointer_constraints: bool = false,
      relative_pointer_manager: bool = false,

      pub fn match(a: @This(), b: @This()) bool {
        return transmute(u8, a) == transmute(u8, b);
      }

      pub const desired: @This() = .{
        .wl_seat = true,
        .wl_compositor = true,
        .xdg_wm_base = true,
        .linux_dmabuf = true,
        .xdg_decoration_manager = true,
        .pointer_constraints = true,
        .relative_pointer_manager = true,
      };
    };

    var globals_bound: GlobalsBound = .{};
    // Loop until all desired globals are bound OR no more globals are available
    while (true) {
      const event = connection.peek_event(scratch_arena) orelse {
        if (globals_bound.match(.desired))
          break;

        connection.flush() catch unreachable;
        connection.load_events();

        continue;
      };
      switch (event) {
        .wl_registry_global => |registry_global| {
          defer connection.consume_event();

          if (std.mem.eql(u8, Seat.Name, registry_global.interface)) {
            connection.client_state.seat = connection.client_state.registry.bind(
              &conn_proxy,
              registry_global.name,
              Seat,
              registry_global.version,
            );
            globals_bound.wl_seat = true;
          } else if (std.mem.eql(u8, Compositor.Name, registry_global.interface)) {
            connection.client_state.compositor = connection.client_state.registry.bind(
              &conn_proxy,
              registry_global.name,
              Compositor,
              registry_global.version,
            );
            globals_bound.wl_compositor = true;
          } else if (std.mem.eql(u8, XdgWmBase.Name, registry_global.interface)) {
            connection.client_state.xdg_wm_base = connection.client_state.registry.bind(
              &conn_proxy,
              registry_global.name,
              XdgWmBase,
              registry_global.version,
            );
            globals_bound.xdg_wm_base = true;
          } else if (std.mem.eql(u8, LinuxDmabuf.Name, registry_global.interface)) {
            connection.client_state.linux_dmabuf = connection.client_state.registry.bind(
              &conn_proxy,
              registry_global.name,
              LinuxDmabuf,
              registry_global.version,
            );
            globals_bound.linux_dmabuf = true;
          } else if (std.mem.eql(u8, XdgDecorationManager.Name, registry_global.interface)) {
            connection.client_state.xdg_decoration_manager = connection.client_state.registry.bind(
              &conn_proxy,
              registry_global.name,
              XdgDecorationManager,
              registry_global.version,
            );
            globals_bound.xdg_decoration_manager = true;
          } else if (std.mem.eql(u8, RelativePointerManager.Name, registry_global.interface)) {
            connection.client_state.relative_pointer_manager = connection.client_state.registry.bind(
              &conn_proxy,
              registry_global.name,
              RelativePointerManager,
              registry_global.version,
            );
            globals_bound.relative_pointer_manager = true;
          } else if (std.mem.eql(u8, PointerConstraints.Name, registry_global.interface)) {
            connection.client_state.pointer_constraints = connection.client_state.registry.bind(
              &conn_proxy,
              registry_global.name,
              PointerConstraints,
              registry_global.version,
            );
            globals_bound.pointer_constraints = true;
          }
        },
        .wl_display_error => |display_error| {
          defer connection.consume_event();
          log.err(
            "display error :: {{ obj_id={}, code={}, message=\"{s}\" }}",
            .{ display_error.object_id, display_error.code, display_error.message },
          );
        },
        .wl_display_delete_id => |delete_id| {
          defer connection.consume_event();
          log.debug("display requested delete_id :: {{ id={} }} ", .{delete_id.id});
        },
        else => { break; },
      }
    }

    //-------------------------------------------------------------------------

    return connection;
  }

  /// Close connection to host compositor and free ringbuffer memory
  pub fn close(conn: *Connection) void {
    //-------------------------------------------------------------------------
    //  Retrieve & Free Ring Buffer Backing Pages
    //-------------------------------------------------------------------------

    const ring_buffer_bytes_len = ring_buffers_mmap_size;
    const ring_buffer_bytes = transmute(
      []align(os.page_size_min) u8,
      conn.in.buf.ptr[0..ring_buffer_bytes_len]
    );

    os.mem_release(ring_buffer_bytes);

    //-------------------------------------------------------------------------

    // Disconnect from compositor
    posix.close(conn.fd);
  }

  /// Construct DLL queue of available platform events from received wayland events
  pub fn get_events(
    noalias conn: *Connection,
    noalias arena: *Arena,
    noalias surface: *Surface,
  ) platform.EventList {
    var conn_proxy = conn.proxy();
    var event_list: platform.EventList = .empty;
    conn.load_events();

    var current_event: ?*platform.Event = null;
    while (conn.get_event(arena)) |wayland_event| {
      switch (wayland_event) {
        .wl_display_error => |display_error| {
          log.err(
            "Wayland display error :: {{ object: {}, code: {}, message: \"{s}\"  }}",
            .{ display_error.object_id, display_error.code, display_error.message },
          );
        },
        .wl_display_delete_id => |delete_id| {
          conn.client_state.object_pool.release_object(delete_id.id);
        },
        .wl_registry_global => |registry_global| {
          log.debug(
            "Compositor advertising new global :: {{ name={}, interface={s}, version={} }}",
            .{ registry_global.name, registry_global.interface, registry_global.version },
          );
        },
        .wl_registry_global_remove => |global_remove| {
          log.warn(
            "compositor notifying removal of global with name={}",
            .{ global_remove.name },
          );
        },
        .wl_seat_capabilities => |wl_seat_capabilities| {
          const seat_capabilities = wl_seat_capabilities.capabilities;
          // log.debug(
          //   "setting wl_seat_capabilities :: {{ pointer: {s}, touch: {s}, keyboard: {s} }}",
          //   .{
          //     if (seat_capabilities.pointer) "true" else "false",
          //     if (seat_capabilities.touch) "true" else "false",
          //     if (seat_capabilities.keyboard) "true" else "false",
          //   },
          // );
          conn.client_state.seat_info.capabilities = seat_capabilities;
        },
        .wl_seat_name => |wl_seat_name| {
          const seat_name = wl_seat_name.name;
          log.debug(
            "setting wayland client seat name to: {s}",
            .{ seat_name },
          );
          @memcpy(
            conn.client_state.seat_info.name[0..seat_name.len],
            seat_name,
          );
          conn.client_state.seat_info.name[seat_name.len] = 0;
        },
        .wl_keyboard_keymap => |wl_keymap| {
          const fmt = wl_keymap.format;
          const fd = wl_keymap.fd;
          const size = wl_keymap.size;
          const keymap = transmute(
            [*:0]const u8,
            linux.mmap(
              null,
              size,
              .{ .READ = true, .WRITE = true },
              .{ .TYPE = .PRIVATE },
              fd,
              0,
            ),
          )[0..size];

          if (conn.client_state.keymap.len > 0) {
            log.warn("previous keymap exists", .{});
            _ = linux.munmap(conn.client_state.keymap.ptr, conn.client_state.keymap.len);
          }

          conn.client_state.xkb_ctx = Xkb.ctx_new(.{});

          const xkb_keymap = Xkb.keymap_from_buffer(
            conn.client_state.xkb_ctx,
            keymap.ptr,
            keymap.len,
            .text_v1,
            .none,
          ) orelse @panic("XKB Keymap Creation Failed!");
          conn.client_state.xkb_state = Xkb.state_new(xkb_keymap);
          log.debug(
            "WL_KEYBOARD_KEYMAP :: {{ fmt={}, fd={}, size={} }}",
            .{ fmt, fd, size },
          );
        },
        .wl_keyboard_key => |key| {
          const keyboard_key = arena.create(platform.Event);

          const xkb_keysym = Xkb.keysym(
            conn.client_state.xkb_state,
            .fromInt(key.key + 8) // Key value -> xkb_keycode requires + 8...
          );

          keyboard_key.* = .{
            .type = switch (key.state) {
              .pressed => .press,
              .released => .release,
              .repeated => .press,
            },
            .key = .fromXkb(xkb_keysym),
            .timestamp_us = time.us(),
            .surface_handle = surface.*,
          };
          current_event = keyboard_key;
        },
        .wl_pointer_button => |mouse_button| {
          const mouse_button_event = arena.create(platform.Event);
          mouse_button_event.* = .{
            .type = switch (mouse_button.state) {
              .pressed => .press,
              .released => .release,
            },
            .button = .fromLinuxInputCode(mouse_button.button),
            .timestamp_us = time.us(),
            .surface_handle = surface.*,
          };
          current_event = mouse_button_event;
        },
        .wl_pointer_motion => |mouse_move| {
          const mouse_move_event = arena.create(platform.Event);
          mouse_move_event.* = .{
            .timestamp_us = time.us(),
            .type = .mouse_move,
            .pos = .{ .x = mouse_move.surface_x, .y = mouse_move.surface_y },
            .surface_handle = surface.*,
          };
          current_event = mouse_move_event;
        },
        .wl_pointer_axis => |mouse_scroll| {
          const scroll_event = arena.create(platform.Event);
          scroll_event.* = .{
            .timestamp_us = time.us(),
            .type = .mouse_scroll,
            .delta = .{
              .x =
                if (mouse_scroll.axis == .horizontal_scroll)
                  mouse_scroll.value
                else 0,
              .y =
                if (mouse_scroll.axis == .vertical_scroll)
                  mouse_scroll.value
                else 0,
            },
            .surface_handle = surface.*,
          };
          current_event = scroll_event;
        },
        .zwp_relative_pointer_v1_relative_motion => |relative_motion| {
          const relative_motion_event = arena.create(platform.Event);
          relative_motion_event.* = .{
            .timestamp_us = time.us(),
            .type = .mouse_move,
            .delta = .{ .x = relative_motion.dx, .y = relative_motion.dy },
            .surface_handle = surface.*,
          };
          current_event = relative_motion_event;
        },
        .wl_buffer_release => {
          const swapchain_image_release_event = arena.create(platform.Event);
          swapchain_image_release_event.* = .{
            .timestamp_us = time.us(),
            .type = .buffer_release,
            .surface_handle = surface.*,
          };
          current_event = swapchain_image_release_event;
        },
        .wl_callback_done => |done| {
          log.debug(
            "received wl_callback with data: {}",
            .{ done.callback_data },
          );
        },
        .xdg_surface_configure => |xdg_surface_configure| {
          const config = xdg_surface_configure;

          surface.xdg_surface.ack_configure(&conn_proxy, config.serial);
          surface.is_ready = true;
        },
        .xdg_toplevel_configure => |xdg_toplevel_configure| {
          const config = xdg_toplevel_configure;

          const platform_surface: *platform.Surface = @fieldParentPtr("handle", surface);
          if (platform_surface.flags.resize and
              (config.width > 0 and config.height > 0) and
              (config.width != platform_surface.width and config.height != platform_surface.height))
          {
            const resize_event = arena.create(platform.Event);
            resize_event.* = .{
              .timestamp_us = time.us(),
              .type = .surface_resize,
              .surface_handle = surface.*,
              .delta = .{ .x = f32_(config.width), .y = f32_(config.height) },
            };
            event_list.push(resize_event);
          }
        },
        .xdg_toplevel_close => {
          // TODO: Push close event to event queue
          const close_event = arena.create(platform.Event);
          close_event.* = .{
            .timestamp_us = time.us(),
            .type = .surface_close,
            .surface_handle = surface.*,
          };
          current_event = close_event;
        },
        .xdg_toplevel_configure_bounds => |xdg_toplevel_configure_bounds| {
          const config_bounds = xdg_toplevel_configure_bounds;
          _ = config_bounds;
          // config_bounds has: i32 width, height.
        },
        .xdg_toplevel_wm_capabilities => |xdg_toplevel_wm_capabilities| {
          const wm_capabilites = transmute(
            []const XdgToplevel.WmCapabilities,
            xdg_toplevel_wm_capabilities.capabilities,
          );
          _ = wm_capabilites;
          // array of Toplevel.Enum.WmCapabilities
          // { window_menu=1, maximize=2, fullscreen=3, minimize=4 }
        },
        .xdg_wm_base_ping => |ping| {
          conn.client_state.xdg_wm_base.pong(&conn_proxy, ping.serial);
        },
        .zwp_linux_dmabuf_feedback_v1_done => {
          log.info("dmabuf feedback done", .{});
        },
        .zwp_linux_dmabuf_feedback_v1_format_table => |format_table| {
          // conn.client_state.dmabuf_feedback.fmt_table = format_table;
          log.info(
            "dmabuf feedback format table received :: {{ fd={}, size={} }}",
            .{ format_table.fd, format_table.size },
          );
        },
        .zwp_linux_dmabuf_feedback_v1_main_device => {
          // conn.client_state.dmabuf_feedback.main_device = std.mem.bytesToValue(
            // linux.dev_t,
            // main_device.device
          // );
          // log.info(
            // "dmabuf feedback main device: 0x{x}",
            // .{ conn.client_state.dmabuf_feedback.main_device },
          // );
        },
        .zwp_linux_dmabuf_feedback_v1_tranche_done => {
          // conn.client_state.dmabuf_feedback.tranche_done = true;
          log.info("dmabuf feedback tranche done", .{});
        },
        .zwp_linux_dmabuf_feedback_v1_tranche_target_device => {
          // const tranche_target_device = std.mem.bytesToValue(linux.dev_t, tranche_target.device);
          // log.info(
            // "dmabuf feedback tranche target device: 0x{x}",
            // .{ tranche_target_device },
          // );
        },
        .zwp_linux_dmabuf_feedback_v1_tranche_formats => |tranche_formats| {
          log.info(
            "dmabuf feedback tranche formats :: [{}]u16",
            .{ tranche_formats.indices.len / 2 },
          );
        },
        .zwp_linux_dmabuf_feedback_v1_tranche_flags => |tranche_flags| {
          log.info("dmabuf feedback tranche flags :: {}", .{ tranche_flags.flags });
        },
        .zwp_linux_buffer_params_v1_created => |created| {
          log.debug("dma-buf creation returned ID :: {}", .{created.buffer});
        },
        .zwp_linux_buffer_params_v1_failed => {
          log.err("dma-buf creation failed!", .{});
        },
        else => |wl_event| {
          warn_unhandled_event(wl_event);
        },
      }
      if (current_event) |event| {
        event_list.push(event);
        current_event = null;
      }
    }

    return event_list;
  }

  /// Acquire a surface handle from host wayland compositor
  pub fn acquire_surface(
    noalias conn: *Connection,
    noalias arena: *Arena,
    noalias title: [:0]const u8,
    noalias class: [:0]const u8,
    width: i32,
    height: i32,
    flags: platform.Surface.Flags,
  ) Surface {
    const scratch = Thread.Context.get_scratch(1, .{arena}).?;
    defer scratch.end();

    var conn_proxy = conn.proxy();
    const wl_surface = conn.client_state.compositor.create_surface(
      &conn_proxy,
    );
    const xdg_surface = conn.client_state.xdg_wm_base.get_xdg_surface(
      &conn_proxy,
      wl_surface,
    );
    const xdg_toplevel = xdg_surface.get_toplevel(&conn_proxy);
    xdg_toplevel.set_title(&conn_proxy, title);
    xdg_toplevel.set_app_id(&conn_proxy, class);

    if (!flags.resize) {
      xdg_toplevel.set_min_size(&conn_proxy, width, height);
      xdg_toplevel.set_max_size(&conn_proxy, width, height);
    }
    const xdg_decoration =
      conn.client_state.xdg_decoration_manager.get_toplevel_decoration(
        &conn_proxy,
        xdg_toplevel,
      );

    wl_surface.commit(&conn_proxy);
    xdg_decoration.set_mode(&conn_proxy, .server_side);

    const feedback = conn.client_state.linux_dmabuf.get_surface_feedback(
      &conn_proxy,
      wl_surface,
    );
    defer feedback.destroy(&conn_proxy);
    const dmabuf_feedback = arena.create(ClientState.DmabufFeedback);
    conn.client_state.dmabuf_feedback = dmabuf_feedback;

    conn.flush() catch unreachable;

    conn.load_events();

    var ignore_tranche = false;
    var feedback_done = false;
    while (!feedback_done) {
      if (conn.get_event(scratch.arena)) |wl_event| switch (wl_event) {
        .wl_seat_capabilities => |wl_seat_capabilities| {
          const seat_capabilities = wl_seat_capabilities.capabilities;
          conn.client_state.seat_info.capabilities = seat_capabilities;
          // log.debug(
          //   "wl_seat_capabilities :: {{ keyboard: {}, pointer: {} }}",
          //   .{ seat_capabilities.keyboard, seat_capabilities.pointer },
          // );
          if (seat_capabilities.keyboard) {
            conn.client_state.keyboard =
              conn.client_state.seat.get_keyboard(&conn_proxy);
          }
          if (seat_capabilities.pointer) {
            conn.client_state.pointer =
              conn.client_state.seat.get_pointer(&conn_proxy);
            conn.client_state.relative_pointer =
              conn.client_state.relative_pointer_manager.get_relative_pointer(
                &conn_proxy,
                conn.client_state.pointer,
              );
          }
        },
        .wl_seat_name => |wl_seat_name| {
          const seat_name = wl_seat_name.name;
          @memcpy(
            conn.client_state.seat_info.name[0..seat_name.len],
            seat_name,
          );
          conn.client_state.seat_info.name[seat_name.len] = 0;
        },
        .zwp_linux_dmabuf_feedback_v1_done => {
          feedback_done = true;
        },
        .zwp_linux_dmabuf_feedback_v1_format_table => |format_table| {
          dmabuf_feedback.fmt_table = format_table;
        },
        .zwp_linux_dmabuf_feedback_v1_main_device => |main_device| {
          dmabuf_feedback.main_device = std.mem.bytesToValue(
            linux.dev_t,
            main_device.device
          );
        },
        .zwp_linux_dmabuf_feedback_v1_tranche_done => {
          ignore_tranche = false;
        },
        .zwp_linux_dmabuf_feedback_v1_tranche_target_device => |target| {
          const tranche_target_device = std.mem.bytesToValue(
            linux.dev_t,
            target.device,
          );
          if (tranche_target_device != dmabuf_feedback.main_device)
            ignore_tranche = true;
        },
        .zwp_linux_dmabuf_feedback_v1_tranche_formats => |tranche_formats| {
          if (!ignore_tranche) {
            const index_count = tranche_formats.indices.len / 2;
            dmabuf_feedback.tranche_formats = arena.push(u16, index_count);
            @memcpy(
              transmute([]u8, dmabuf_feedback.tranche_formats),
              tranche_formats.indices,
            );
          }
        },

        else => {},
      } else conn.load_events();
    }

    return .{
      .connection = conn,
      .wl_surface = wl_surface,
      .xdg_surface = xdg_surface,
      .xdg_toplevel = xdg_toplevel,
      .xdg_decoration = xdg_decoration,
      .is_ready = false,
    };
  }

  pub fn lock_pointer(
    noalias conn: *Connection,
    surface: Surface,
    region: ?math.Vec4i32,
  ) void {
    var conn_proxy = conn.proxy();

    if (region != null) {
      log.warn("Region-locking pointer not implemented", .{});
    }
    conn.client_state.locked_pointer =
      conn.client_state.pointer_constraints.lock_pointer(
        &conn_proxy,
        surface.wl_surface,
        conn.client_state.pointer,
        .fromInt(0),
        .persistent,
      );
  }

  pub fn unlock_pointer(
    conn: *Connection,
  ) void {
    var conn_proxy = conn.proxy();

    conn.client_state.locked_pointer.?.destroy(&conn_proxy);
    conn.client_state.locked_pointer = null;
  }

  pub fn select_vk_physical_device(
    conn: *Connection,
    vki: vk.InstanceProxy,
    required_extensions: []const [*:0]const u8,
  ) vk.PhysicalDevice {
    const VkPhysicalDeviceCandidate = struct {
      pdev: vk.PhysicalDevice,
      props: vk.PhysicalDeviceProperties,
      score: u32,
    };
    var candidate: VkPhysicalDeviceCandidate = .{
      .pdev = .null_handle,
      .props = undefined,
      .score = 0,
    };

    var pdev_count: u32 = 0;
    _ = vki.enumeratePhysicalDevices(
      &pdev_count,
      null,
    ) catch |err| {
      log.err(
        "Failed to enumerate vk physical devices! :: {s}",
        .{ @errorName(err) },
      );
    };

    var scratch = Thread.Context.get_scratch(0, .{}).?;
    defer scratch.end();

    var pdev_options = scratch.arena.push(vk.PhysicalDevice, pdev_count);

    _ = vki.enumeratePhysicalDevices(
      &pdev_count,
      pdev_options.ptr,
    ) catch |err| {
      log.err(
        "Failed to enumerate vk physical devices! :: {s}",
        .{ @errorName(err) },
      );
    };

    const main_device: linux.dev_t =
    if (conn.client_state.dmabuf_feedback) |feedback|
      feedback.main_device
    else .fromInt(0);

    for (pdev_options) |pdev| {
      var drm: vk.PhysicalDeviceDrmPropertiesEXT = .{
        .has_primary = .false,
        .has_render = .false,
        .primary_major = 0,
        .primary_minor = 0,
        .render_major = 0,
        .render_minor = 0,
      };

      var props13: vk.PhysicalDeviceVulkan13Properties = undefined;
      props13.s_type = .physical_device_vulkan_1_3_properties;
      props13.p_next = &drm;

      var props2: vk.PhysicalDeviceProperties2 = .{
        .p_next = &props13,
        .properties = undefined,
      };

      _ = vki.getPhysicalDeviceProperties2(pdev, &props2);
      var score: u32 = 0;

      const props = props2.properties;
      if (props.device_type == .discrete_gpu)
        score += 1000;

      score += props.limits.max_image_dimension_2d;

      var ext_prop_count: u32 = 0;
      _ = vki.enumerateDeviceExtensionProperties(
        pdev,
        null,
        &ext_prop_count,
        null,
      ) catch |err| {
        log.err(
          "Failed to enumerate vk physical device extension props :: {s}",
          .{ @errorName(err) },
        );
        break;
      };

      const ext_props = scratch.arena.push(vk.ExtensionProperties, ext_prop_count);

      _ = vki.enumerateDeviceExtensionProperties(
        pdev,
        null,
        &ext_prop_count,
        ext_props.ptr,
      ) catch |err| {
        log.err(
          "Failed to enumerate vk physical device extension props :: {s}",
          .{ @errorName(err) },
        );
        break;
      };
      const supports_desired_extensions = ext_support: {
        for (required_extensions) |ext| {
          const found_ext = found: {
            for (ext_props) |ext_prop| {
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

      if (supports_desired_extensions and score > candidate.score) {
        if (drm.has_primary == .true) {
          if (drm.primary_major == main_device.major() and
              drm.primary_minor == main_device.minor())
          {
            candidate = .{
              .pdev = pdev,
              .props = props2.properties,
              .score = score,
            };
          }
        }

        if (drm.has_render == .true) {
          if (drm.render_major == main_device.major() and
              drm.render_minor == main_device.minor())
          {
            candidate = .{
              .pdev = pdev,
              .props = props2.properties,
              .score = score,
            };
          }
        }
      }
    }

    return candidate.pdev;
  }

  //---------------------------------------------------------------------------

  pub fn select_drm_modifier_for_format(
    conn: *Connection,
    format: Drm.Format,
  ) Drm.Modifier {
    const desired_fmt = format;

    const feedback = conn.client_state.dmabuf_feedback orelse return .invalid;
    const format_table = feedback.fmt_table;
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
      const fmt = cast(
        Drm.Format,
        std.mem.bytesToValue(u32, entry[0..4]),
      );
      const mod = cast(
        Drm.Modifier,
        std.mem.bytesToValue(u64, entry[8..]),
      );
      if (fmt == desired_fmt) {
        if (mod != .invalid and mod != .linear) {
          return mod;
        }
      }
    }
    return .invalid;
  }

  fn warn_unhandled_event(event: anytype) void {
    _ = event;
    // log.warn("Unhandled {s} event", .{@tagName(event)});
  }

  pub fn load_events(conn: *Connection) void {
    //-------------------------------------------------------------------------
    // Prepare IOV Buffer(s) For Read
    //-------------------------------------------------------------------------

    var iov: [2]linux.iovec = undefined;
    const iov_len = conn.in.prep_iovecs_in(&iov);

    //-------------------------------------------------------------------------

    //-------------------------------------------------------------------------
    // Read Into Buffer(s)
    //-------------------------------------------------------------------------

    var cmsg_buf: [cmsg_buf_len] u8 align(@alignOf(linux.cmsghdr)) = @splat(0);
    var msg: linux.msghdr = .{
      .name = null,
      .namelen = 0,
      .iov = &iov,
      .iovlen = iov_len,
      .control = &cmsg_buf,
      .controllen = cmsg_buf.len,
      .flags = 0,
    };

    var rc: usize = linux.recvmsg(
      conn.fd,
      &msg,
      linux.MSG.DONTWAIT,
    );

    while (linux.errno(rc) == .INTR) {
      rc = linux.recvmsg(
        conn.fd,
        &msg,
        linux.MSG.DONTWAIT,
      );
    }

    const err = linux.errno(rc);
    const bytes_read = if (transmute(isize, rc) < 0)
      switch (err) {
        .SUCCESS => return,
        .AGAIN => return,
        .INVAL => { log.err("EINVAL on socket read!", .{}); return; },
        .PIPE, .CONNRESET => @panic("Socket connection lost!"),
        else => |e| {log.err("socket read failed with err :: {s}", .{@tagName(e)}); @panic("unknown err"); },
      }
    else
      u32_(rc);

    defer conn.in.write +%= bytes_read;

    //-------------------------------------------------------------------------

    //-------------------------------------------------------------------------
    // Parse Control Messages
    //-------------------------------------------------------------------------

    var cmsg_iter = linux.cmsghdr.iter(cmsg_buf[0..msg.controllen]);
    while (cmsg_iter.next()) |cmsg_header| {
      if (cmsg_header.level == linux.SOL.SOCKET and cmsg_header.type == linux.SCM_RIGHTS) {
        const fd = cmsg_header.data(c_int).*;
        conn.fd_in.putBytes(std.mem.asBytes(&fd));
      }
    }

    //-------------------------------------------------------------------------
  }

  pub fn peek_event(noalias conn: *Connection, noalias arena: *Arena) ?Event {
    var conn_proxy = conn.proxy();

    const event = if (!conn.in.empty()) wayland_event: {
      const size = conn.in.size();

      // not enough data for header
      if (size < @sizeOf(WireEventHeader))
        break :wayland_event null;

      //-----------------------------------------------------------------------
      // Parse Event Header
      //-----------------------------------------------------------------------

      var header: WireEventHeader = .{
        .id = 0,
        .op = 0,
        .len = 0,
      };
      const header_read_idx = conn.in.mask(conn.in.read);
      conn.in.getNBytesFrom(header_read_idx,8,std.mem.asBytes(&header));

      //-----------------------------------------------------------------------

      //-----------------------------------------------------------------------
      // Parse Event Body
      //-----------------------------------------------------------------------

      // not enough data for whole event
      if (size < header.len)
        break :wayland_event null;

      // bump read idx to event data begin
      conn.in.read +%= u32_(@sizeOf(WireEventHeader));

      const data_len = header.len - @sizeOf(WireEventHeader);
      const data_read_idx = conn.in.mask(conn.in.read);

      defer conn.in.read -%= u32_(@sizeOf(WireEventHeader));

      const scratch = Thread.Context.get_scratch(1, .{arena}).?;

      const scratch_arena = scratch.arena;
      defer scratch.end();

      const data_bytes = scratch_arena.push(u8, data_len);
      conn.in.getNBytesFrom(data_read_idx, data_len, data_bytes);

      const relevant_object = conn.client_state.object_pool.get(header.id);
      const wayland_event = relevant_object.message_decode(
        &conn_proxy,
        header.op,
        data_bytes,
      );
      if (wayland_event == .wl_callback_done)
        log.debug(
          "received response on callback object of id: {}",
          .{transmute(*const u32, relevant_object).*},
        );

      break :wayland_event wayland_event;
    } else null;

    return event;
  }

  pub fn get_event(noalias conn: *Connection, noalias arena: *Arena) ?Event {
    const event = conn.peek_event(arena) orelse return null;
    conn.consume_event();
    return event;
  }

  pub fn consume_event(conn: *Connection) void {
    var header: WireEventHeader = .{
       .id = 0,
       .op = 0,
       .len = 0,
     };
     const header_read_idx = conn.in.mask(conn.in.read);
     conn.in.getNBytesFrom(header_read_idx,8,std.mem.asBytes(&header));
     conn.in.read +%= header.len;
  }

  pub fn flush(conn: *Connection) !void {
    // const out_read_start = conn.out.read;

    //-------------------------------------------------------------------------
    // Prepare outgoing iovecs
    //-------------------------------------------------------------------------

    var iov: [2]linux.iovec = undefined;
    const iov_len = if (conn.out.read != conn.out.write)
      conn.out.prep_iovecs_out(&iov) else 0;

    const bytes_to_write = conn.out.write - conn.out.read;
    defer conn.out.read +%= bytes_to_write;

    //-------------------------------------------------------------------------

    //-------------------------------------------------------------------------
    // Prepare outgoing control messages
    //-------------------------------------------------------------------------

    var cmsg: [cmsg_buf_len]u8 = undefined;
    var cmsg_len: usize = 0;

    const c_int_size = @sizeOf(c_int);
    const fd_cmsg_t = linux.cmsg(c_int);
    const ctrlmsg_size = @sizeOf(fd_cmsg_t);

    while (!conn.fd_out.empty()) {
      const fd_out_read = conn.fd_out.mask(conn.fd_out.read);
      var fd_out: c_int = -1;
      conn.fd_out.getNBytesFrom(fd_out_read,4,std.mem.asBytes(&fd_out));

      const control_msg: fd_cmsg_t = .init(
        posix.SOL.SOCKET,
        linux.SCM_RIGHTS,
        fd_out,
      );

      @memcpy(
        cmsg[cmsg_len..][0..ctrlmsg_size],
        std.mem.asBytes(&control_msg),
      );

      conn.fd_out.read +%= u32_(c_int_size);
      cmsg_len += ctrlmsg_size;
    }

    //-------------------------------------------------------------------------

    //-------------------------------------------------------------------------
    // Construct and send message
    //-------------------------------------------------------------------------

    const msg: linux.msghdr_const = .{
      .name = null,
      .namelen = 0,
      .iov = @ptrCast(&iov),
      .iovlen = iov_len,
      .control = &cmsg,
      .controllen = cmsg_len,
      .flags = 0,
    };

    var written: usize = 0;
    var rc = transmute(usize, @as(isize, -1));
    var errno: linux.E = .AGAIN;
    read: while (transmute(isize, rc) < 0 and (errno == .AGAIN or errno == .INTR)) {
      const val = linux.sendmsg(
        conn.fd,
        &msg,
        0,
      );

      rc = val;

      if (rc < 0) {
        errno = linux.errno(rc);
        if (errno == .INTR) written += cast(usize, -rc);
        continue :read;
      }
    }


    if (rc < 0) {
      log.err(
        "Failed to write to socket! :: {s}",
        .{ @tagName(linux.errno(u32_(-rc))) },
      );
    }

    written += cast(usize, rc);

    base.DebugAssert(
      written == bytes_to_write,
      "bytes_written should match bytes_to_write!",
    );

    //-------------------------------------------------------------------------
  }

  pub fn should_flush(conn: *const Connection) void {
    return @atomicLoad(u32, &conn.want_flush, .monotonic) == 1;
  }

  pub fn signal_flush_wanted(conn: *Connection) void {
    // wait until any previous flush is complete
    while (@atomicLoad(u32, &conn.want_flush, .monotonic) != 0) {
      Thread.yield();
    }

    @atomicStore(u32, &conn.want_flush, 1, .release);
  }

  pub fn signal_flush_complete(conn: *Connection) void {
    base.DebugAssert(
      @atomicLoad(u32, &conn.want_flush, .monotonic) != 1,
      "Connection `want_flush` flag already reset",
    );

    @atomicStore(u32, &conn.want_flush, 0, .release);
  }

  pub fn proxy(conn: *Connection) Proxy {
    return .{
      .ctx = conn,
      .vtable = .{
        .message_decode = msg_decode,
        .message_encode = msg_encode,
        .get_id = next_id,
        .put_object = obj_push,
        .destroy_object = obj_destroy,
      },
    };
  }

  fn msg_decode(noalias ctx: *anyopaque, args_out: []MessageArg, noalias data: []const u8) void {
    const connection = transmute(*Connection, ctx);
    var offset: u32 = 0;

    for (args_out) |*arg| {
      switch (arg.*) {
        .fd => |*arg_fd| {
          arg_fd.* = connection.next_fd();
        },
        .uint, .object, .new_id => |*uint_arg| {
          uint_arg.* = std.mem.bytesToValue(u32, data[offset..][0..4]);
          offset += 4;
        },
        .int => |*int_arg| {
          int_arg.* = std.mem.bytesToValue(i32, data[offset..][0..4]);
          offset += 4;
        },
        .@"enum" => |*enum_arg| {
          const int_ptr = transmute(*u32, enum_arg);
          int_ptr.* = std.mem.bytesToValue(u32, data[offset..][0..4]);
          offset += 4;
        },
        .fixed => |*fixed_arg| {
          const int_val = std.mem.bytesToValue(i32, data[offset..][0..4]);
          offset += 4;
          fixed_arg.* = f32_(int_val) / 256;
        },
        .string => |*string_arg| {
          const str_len = std.mem.bytesToValue(u32, data[offset..][0..4]);
          offset += 4;
          string_arg.* = @ptrCast(data[offset..][0..(str_len - 1):0]);

          const rounded_len = math.div_roundup(str_len, 4);
          offset += rounded_len;
        },
        .array => |*array_arg| {
          const arr_len = std.mem.bytesToValue(u32, data[offset..][0..4]);
          offset += 4;
          const rounded_len = math.div_roundup(arr_len, 4);
          array_arg.* = data[offset..][0..arr_len];
          offset += rounded_len;
        },
      }
    }
  }

  fn msg_encode(noalias ctx: *anyopaque, id: u32, op: u16, noalias args: []const ?MessageArg) void {
    const connection = transmute(*Connection, ctx);

    var msg_len: u16 = @sizeOf(WireEventHeader);
    for (args) |arg_opt| {
      if (arg_opt) |arg| switch (arg) {
        .int, .uint, .fixed, .object, .new_id, .@"enum" => msg_len += @sizeOf(u32),
        .string => |string_arg| msg_len += msg_str_len(string_arg),
        .array => |array_arg| msg_len += msg_arr_len(array_arg),
        .fd => {},
      } else {
        msg_len += @sizeOf(u32);
      }
    }
    if (!connection.out.empty() and connection.out.size() < msg_len) {
      connection.flush() catch |err| {
        log.err("Connection flush failed due to err :: {s}", .{@errorName(err)});
      };
    }

    const header: WireEventHeader = .{
      .id = id,
      .op = op,
      .len = msg_len,
    };
    connection.out.putBytes(std.mem.asBytes(&header));

    for (args) |arg_opt| {
      if (arg_opt) |arg| arg: switch (arg) {
        .uint, .new_id, .object => |uint_arg| {
          connection.out.putBytes(std.mem.asBytes(&uint_arg));
        },
        .int => |int_arg| {
          continue :arg .{ .uint = transmute(u32, int_arg) };
        },
        .@"enum" => |*enum_arg| {
          const u32_val = transmute(*const u32, enum_arg);
          continue :arg .{ .uint = u32_val.* };
        },
        .fixed => |float_arg| {
          const val = transmute(i32, float_arg * 256);
          continue :arg .{ .uint = transmute(u32, val) };
        },
        .string => |string_arg| {
          continue :arg .{ .array = string_arg[0 .. string_arg.len + 1] };
        },
        .array => |array_arg| {
          const padding_bytes: [4]u8 = @splat(0);

          const write_len = u32_(msg_arr_len(array_arg));
          const len = u32_(array_arg.len);
          const padding_bytes_needed = (write_len - @sizeOf(u32)) - len;

          connection.out.putBytes(std.mem.asBytes(&len));
          connection.out.putBytes(array_arg);
          connection.out.putBytes(padding_bytes[0..padding_bytes_needed]);
        },
        .fd => |fd_arg| {
          connection.fd_out.putBytes(std.mem.asBytes(&fd_arg));
        },
      } else {
        const null_value: u32 = 0;
        connection.out.putBytes(std.mem.asBytes(&null_value));
      }
    }
  }

  fn next_id(noalias ctx: *anyopaque) u32 {
    const conn = transmute(*Connection, ctx);
    const idx = conn.client_state.object_pool.next_object_id();
    return idx;
  }

  fn next_fd(conn: *Connection) i32 {
    var fd: i32 = -1;
    const read = conn.fd_in.mask(conn.fd_in.read);
    @memcpy(
      std.mem.asBytes(&fd),
      conn.fd_in.buf[read..][0..@sizeOf(i32)],
    );
    conn.fd_in.read +%= @sizeOf(i32);

    return fd;
  }

  fn obj_destroy(noalias ctx: *anyopaque, object_id: u32) void {
    const conn = transmute(*Connection, ctx);
    conn.client_state.object_pool.release_object(object_id);
  }

  fn obj_push(noalias ctx: *anyopaque, object: Object) void {
    const conn = transmute(*Connection, ctx);
    conn.client_state.object_pool.push_object(object);
  }

  inline fn msg_str_len(str: [:0]const u8) u16 {
    return msg_arr_len(str[0 .. str.len + 1]);
  }

  inline fn msg_arr_len(arr: []const u8) u16 {
    return u16_(math.div_roundup(@sizeOf(u32) + arr.len, @sizeOf(u32)));
  }

  const cmsg_buf_len = 32 * linux.cmsghdr.msg_len(@sizeOf(c_int));
  const ring_buffers_mmap_size: usize = (2 * default_ring_buffer_size +
                                         2 * default_fd_ring_buffer_size);
  const ring_buffer_size: usize = default_ring_buffer_size;
  const fd_ring_buffer_size: usize = default_fd_ring_buffer_size;
  const default_ring_buffer_size = 4096;
  const default_fd_ring_buffer_size = 2048;
};

pub const Surface = struct {
  connection: *Connection,
  wl_surface: WaylandSurface,
  xdg_surface: XdgSurface,
  xdg_toplevel: XdgToplevel,
  xdg_decoration: XdgDecoration,
  is_ready: bool,

  //---------------------------------------------------------------------------
  // Platform::Surface API
  //---------------------------------------------------------------------------
  pub fn attach_image(
    surface: *const Surface,
    noalias image: *const platform.Image,
  ) void {
    var proxy = surface.connection.proxy();

    surface.wl_surface.attach(&proxy, image.platform_specific.wl_buffer, 0, 0);
    surface.wl_surface.damage_buffer(&proxy, 0, 0, i32_(image.width), i32_(image.height));
    surface.wl_surface.commit(&proxy);
  }

  pub fn ready(surface: *const Surface) bool {
    return surface.is_ready;
  }

  pub fn prepare_image(
    noalias surface: *const Surface,
    noalias image: *platform.Image,
  ) void {
    var proxy = surface.connection.proxy();
    const params = surface.connection.client_state.linux_dmabuf.create_params(
      &proxy,
    );

    const fd = image.platform_specific.fd;
    const drm_modifier = image.platform_specific.drm_modifier;

    defer {
      params.destroy(&proxy);
      surface.connection.flush() catch unreachable;
      _ = linux.close(fd);
    }

    params.add(
      &proxy,
      fd,
      0,
      image.offset,
      image.stride,
      drm_modifier.hi(),
      drm_modifier.lo(),
    );

    const wl_buffer = params.create_immed(
      &proxy,
      i32_(image.width),
      i32_(image.height),
      u32_(image.format.toDrm()),
      .{},
    );

    image.platform_specific.wl_buffer = wl_buffer;
  }

  pub fn release_image(
    surface: *const Surface,
    image: *const platform.Image,
  ) void {
    var proxy = surface.connection.proxy();
    const wl_buffer = image.platform_specific.wl_buffer;
    wl_buffer.destroy(&proxy);
  }

  //---------------------------------------------------------------------------

  pub fn attach_wl_buffer(
    surface: *Surface,
    buffer: WaylandBuffer,
    width: i32,
    height: i32,
  ) void {
    var proxy = surface.connection.proxy();
    surface.wl_surface.attach(
      &proxy,
      .{
        .buffer = buffer,
        .x = 0,
        .y = 0,
      },
    );

    surface.wl_surface.damage(
      &proxy,
      .{
        .x = 0,
        .y = 0,
        .width = width,
        .height = height,
      },
    );

    surface.wl_surface.commit(&proxy);
  }

  pub const nil: Surface = .{
    .wl_surface = 0,
    .toplevel = .fromInt(0),
  };
};

pub const SwapchainBuffer = WaylandBuffer;

pub const Swapchain = struct {
  connection: *Connection,

  pub fn alloc(
    connection: *Connection,
    vk_ctx: *VkContext,
    width: u32,
    height: u32,
    format: gfx.Format,
    buffers: []platform.SwapchainBuffer,
  ) !Swapchain {
    try alloc_buffers(
      connection,
      vk_ctx,
      width,
      height,
      format,
      buffers,
    );
    return .{
      .connection = connection,
    };
  }

  pub fn alloc_buffers(
    connection: *Connection,
    vk_ctx: *VkContext,
    width: u32,
    height: u32,
    format: gfx.Format,
    buffers: []platform.SwapchainBuffer,
  ) !void {
    var proxy = connection.proxy();
    const linux_dmabuf = connection.client_state.linux_dmabuf;

    const vk_format = format.toVk();
    const drm_format = format.toDrm();
    const drm_modifier =
      connection.select_drm_modifier_for_format(drm_format);

    const fmt_list_info: vk.ImageFormatListCreateInfo = .{
      .view_format_count = 1,
      .p_view_formats = &.{ vk_format },
    };
    const ext_mem_info: vk.ExternalMemoryImageCreateInfo = .{
      .p_next = &fmt_list_info,
      .handle_types = .{ .dma_buf_bit_ext = true },
    };
    const drm_fmt_mod_info: vk.ImageDrmFormatModifierListCreateInfoEXT = .{
      .p_next = &ext_mem_info,
      .drm_format_modifier_count = 1,
      .p_drm_format_modifiers = &.{ u64_(drm_modifier) },
    };

    for (buffers) |*buffer| {
      // Alloc vkImage With Export Info
      const buffer_image_p_next = &drm_fmt_mod_info;
      const buffer_image = try vk_ctx.alloc_image(
        width,
        height,
        vk_format,
        .{ .transfer_dst_bit = true },
        .drm_format_modifier_ext,
        buffer_image_p_next,
        .{ .dma_buf_bit_ext = true },
      );

      // Get Necessary Image Data For Export
      const layout = vk_ctx.device_proxy.getImageSubresourceLayout(
        buffer_image.image,
        &.{
          .aspect_mask = .{ .memory_plane_0_bit_ext = true },
          .mip_level = 0,
          .array_layer = 0,
        },
      );
      const image_export_fd = try vk_ctx.device_proxy.getMemoryFdKHR(
        &.{
          .memory = buffer_image.memory,
          .handle_type = .{ .dma_buf_bit_ext = true },
        },
      );
      var modifier_properties: vk.ImageDrmFormatModifierPropertiesEXT = .{
        .drm_format_modifier = u64_(drm_modifier),
      };
      try vk_ctx.device_proxy.getImageDrmFormatModifierPropertiesEXT(
        buffer_image.image,
        &modifier_properties,
      );

      const image_drm_format_modifier: Drm.Modifier = cast(
        Drm.Modifier,
        modifier_properties.drm_format_modifier,
      );

      // Export Image As wl_buffer
      const dmabuf_create_params = linux_dmabuf.create_params(&proxy);
      // These can probably all be run after the loop, will see later.
      defer {
        dmabuf_create_params.destroy(&proxy);
        connection.flush() catch unreachable;
        _ = linux.close(image_export_fd);
      }

      dmabuf_create_params.add(
        &proxy,
        image_export_fd,
        0,
        u32_(layout.offset),
        u32_(layout.row_pitch),
        image_drm_format_modifier.hi(),
        image_drm_format_modifier.lo(),
      );

      const image_wl_buffer = dmabuf_create_params.create_immed(
        &proxy,
        i32_(width),
        i32_(height),
        u32_(drm_format),
        .{},
      );

      buffer.* = .{
        .handle = image_wl_buffer,
        .image = buffer_image,
      };
    }
  }

  pub fn destroy_buffers(
    sc: *Swapchain,
    vk_ctx: *VkContext,
    buffers: []platform.SwapchainBuffer,
  ) void {
    var proxy = sc.connection.proxy();
    for (buffers) |buffer| {
      buffer.handle.destroy(&proxy);
      vk_ctx.destroy_image(buffer.image);
    }
  }

  pub fn recreate(
    sc: *Swapchain,
    vk_ctx: *VkContext,
    width: u32,
    height: u32,
    format: gfx.Format,
    buffers: []platform.SwapchainBuffer,
  ) !void {
    sc.destroy_buffers(vk_ctx, buffers);

    try alloc_buffers(
      sc.connection,
      vk_ctx,
      width,
      height,
      format,
      buffers,
    );
  }

  pub fn present(
    noalias sc: *const Swapchain,
    noalias surface: *const Surface,
    noalias buffer: *const platform.SwapchainBuffer,
  ) void {
    var proxy = sc.connection.proxy();
    const wl_surface = surface.wl_surface;
    const wl_buffer = buffer.handle;

    // TODO:
    // - Add something in here for presentation timing
    // - Add something in here for viewport management -- maybe

    // Attach Buffer -> Surface
    wl_surface.attach(&proxy, wl_buffer, 0, 0);
    wl_surface.damage_buffer(
      &proxy,
      0,
      0,
      i32_(buffer.image.width),
      i32_(buffer.image.height),
    );
    wl_surface.commit(&proxy);
  }
};

pub const ClientState = struct {
  // Base Wayland Connection
  display: Display,
  registry: Registry,

  // Globals
  seat: Seat,
  compositor: Compositor,
  xdg_wm_base: XdgWmBase,
  linux_dmabuf: LinuxDmabuf,
  xdg_decoration_manager: XdgDecorationManager,
  pointer_constraints: PointerConstraints,
  relative_pointer_manager: RelativePointerManager,

  // Wayland Objects
  object_pool: ObjectPool,

  // Runtime Input Information
  keyboard: Keyboard,
  pointer: Pointer,
  locked_pointer: ?LockedPointer = null,
  relative_pointer: RelativePointer,
  keymap: []const u8 = &.{},
  xkb_ctx: *Xkb.Context = undefined,
  xkb_state: *Xkb.State = undefined,

  // Runtime Compositor Information
  seat_info: SeatInfo = .{},
  dmabuf_feedback: ?*DmabufFeedback = null,

  const SeatInfo = struct {
    name: [512]u8 = undefined,
    capabilities: Seat.Capability = .{},
  };

  const DmabufFeedback = struct {
    fmt_table: LinuxDmabufFeedback.format_table,
    main_device: linux.dev_t,
    tranche_target_device: linux.dev_t,
    tranche_formats: []u16,
    tranche_flags: LinuxDmabufFeedback.TrancheFlags,

    pub const nil: DmabufFeedback = .{
      .fmt_table = .{
        .fd = -1,
        .size = 0,
      },
      .main_device = .fromInt(0),
      .tranche_target_device = .fromInt(0),
      .tranche_formats = .{},
      .tranche_flags = .{},
    };
  };
};

pub const ObjectPool = struct {
  objects: []Object,
  free_idx_list: FreeIdxList,

  fn id_to_idx(id: u32) u32 {
    return id-1;
  }
  pub fn next_object_id(op: *ObjectPool) u32 {
    return op.free_idx_list.pull();
  }

  pub fn push_object(op: *ObjectPool, object: Object) void {
    const idx = transmute(*const u32, &object);

    op.objects[ id_to_idx(idx.*) ] = object;
  }

  pub fn release_object(op: *ObjectPool, object_id: u32) void {
    op.objects[ id_to_idx(object_id) ] = undefined;
    op.free_idx_list.push(object_id);
  }

  pub fn get(op: *ObjectPool, object_id: u32) *Object {
    return &op.objects[id_to_idx(object_id)];
  }
};

const FreeIdxList = struct {
  indices: []u32,
  index_available: u32,

  pub fn init_backing(buf: []u32) FreeIdxList {
    for (buf, 0..) |*index, i| {
      index.* = u32_(buf.len - i);
    }

    return .{
      .indices = buf,
      .index_available = u32_(buf.len),
    };
  }

  pub fn pull(fil: *FreeIdxList) u32 {
    fil.index_available -= 1;
    return fil.indices[fil.index_available];
  }

  pub fn push(fil: *FreeIdxList, index: u32) void {
    base.DebugAssert(
      fil.index_available < fil.indices.len,
      "Index Queue Already Full",
    );

    fil.indices[fil.index_available] = index;
    fil.index_available += 1;
  }
};

const ShmPool = struct {
  proxy: Proxy,
  wl_shm_pool: WaylandShmPool,
  buffer: []u32,
  fd: c_int,

  pub fn create(
    conn: *Connection,
    width: i32,
    height:i32,
  ) ShmPool {
    const shm = conn.client_state.wl_shm;

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

  pub fn create_buffer(
    pool: *ShmPool,
    width: i32,
    height: i32,
    format: Shm.Format,
  ) WaylandBuffer {
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

fn open_shmfile(arena: *Arena) c_int {
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
    transmute([*:0]const u8, name),
    .{
      .ACCMODE = .RDWR,
      .CREAT = true,
      .EXCL = true,
      .CLOEXEC = true,
    },
    0o600,
  );

  _ = linux.unlink(transmute([*:0]const u8, name));
  return base.i32_(transmute(isize, fd));
}

const WireEventHeader = packed struct (u64) {
  id: u32,
  op: u16,
  len: u16,
};

// Object Aliases
pub const WaylandBuffer = wl_protocols.wl_buffer;
pub const WaylandSurface = wl_protocols.wl_surface;
pub const XdgSurface = wl_protocols.xdg_surface;
pub const XdgToplevel = wl_protocols.xdg_toplevel;
pub const WaylandShmPool = wl_protocols.wl_shm_pool;
pub const LinuxDmabufFeedback = wl_protocols.zwp_linux_dmabuf_feedback_v1;

pub const Display = wl_protocols.wl_display;
pub const Pointer = wl_protocols.wl_pointer;
pub const Keyboard = wl_protocols.wl_keyboard;
pub const Registry = wl_protocols.wl_registry;
pub const XdgDecoration = wl_protocols.zxdg_toplevel_decoration_v1;
pub const RelativePointer = wl_protocols.zwp_relative_pointer_v1;
pub const ConfinedPointer = wl_protocols.zwp_confined_pointer_v1;
pub const LockedPointer = wl_protocols.zwp_locked_pointer_v1;

// Registry Global Aliases
pub const Shm = wl_protocols.wl_shm;
pub const Seat = wl_protocols.wl_seat;
pub const XdgWmBase = wl_protocols.xdg_wm_base;
pub const Compositor = wl_protocols.wl_compositor;
pub const LinuxDmabuf = wl_protocols.zwp_linux_dmabuf_v1;
pub const XdgDecorationManager = wl_protocols.zxdg_decoration_manager_v1;
pub const PointerConstraints = wl_protocols.zwp_pointer_constraints_v1;
pub const RelativePointerManager = wl_protocols.zwp_relative_pointer_manager_v1;


// Wayland Base Type Aliases
pub const Proxy = wl_protocols.Proxy;
pub const Object = wl_protocols.Object;
pub const Event = wl_protocols.Event;
pub const MessageArg = wl_protocols.MessageArg;

pub const Xkb = struct {
  var handle: std.DynLib = undefined;

  var context_new_fn: ContextNewPfn = undefined;
  var keymap_new_from_buffer_fn: KeymapNewFromBufferPfn = undefined;
  var state_new_fn: StateNewPfn = undefined;
  var get_keymap_fn: GetKeymapPfn = undefined;
  var get_one_sym_fn: GetOneSymPfn = undefined;

  const ContextNewPfn = *fn (u32) callconv (.c) ?*anyopaque;
  const KeymapNewFromBufferPfn = *fn (
    *anyopaque,
    [*]const u8,
    usize,
    KeymapCompileFormat,
    KeymapCompileFlags,
  ) callconv(.c) ?*anyopaque;
  const StateNewPfn = *fn (*anyopaque) callconv(.c) ?*anyopaque;
  const GetKeymapPfn = *fn (?*anyopaque) callconv(.c) ?*anyopaque;
  const GetOneSymPfn = *fn (*anyopaque, u32) callconv(.c) u32;

  pub fn load_lib(env: os.Environ) !void {
    handle = try os.lib(env, "libxkbcommon.so.0");

    context_new_fn = handle.lookup(
      ContextNewPfn,
      "xkb_context_new",
    ).?;
    keymap_new_from_buffer_fn = handle.lookup(
      KeymapNewFromBufferPfn,
      "xkb_keymap_new_from_buffer"
    ).?;
    state_new_fn = handle.lookup(
      StateNewPfn,
      "xkb_state_new",
    ).?;
    get_keymap_fn = handle.lookup(
      GetKeymapPfn,
      "xkb_state_get_keymap"
    ).?;
    get_one_sym_fn = handle.lookup(
      GetOneSymPfn,
      "xkb_state_key_get_one_sym",
    ).?;
  }

  pub fn ctx_new(flags: ContextFlags) *Context {
    return transmute(*Context, context_new_fn(u32_(flags)).?);
  }

  pub fn keymap_from_buffer(
    ctx: *Context,
    str: [*]const u8,
    len: usize,
    fmt: KeymapCompileFormat,
    flags: KeymapCompileFlags,
  ) ?*Keymap {
    const xkb_keymap = keymap_new_from_buffer_fn(ctx, str, len, fmt, flags)
      orelse return null;
    return transmute(
      *Keymap,
      xkb_keymap,
    );
  }

  pub fn state_new(xkb_keymap: *Keymap) *State {
    return transmute(*State, state_new_fn(xkb_keymap).?);
  }

  pub fn keymap(state: *State) *Keymap {
    return transmute(*Keymap, get_keymap_fn(state));
  }

  pub fn keysym(state: *State, keycode: Keycode) KeySym {
    return .fromInt(get_one_sym_fn(state, keycode.toInt()));
  }

  pub const KeySym = enum (u32) {
    NoSymbol = 0x000000,
    VoidSymbol = 0xffffff,
    BackSpace = 0xff08,
    Tab = 0xff09,
    Linefeed = 0xff0a,
    Clear = 0xff0b,
    Return = 0xff0d,
    Pause = 0xff13,
    Scroll_Lock = 0xff14,
    Sys_Req = 0xff15,
    Escape = 0xff1b,
    Delete = 0xffff,
    Multi_key = 0xff20,
    Codeinput = 0xff37,
    // SingleCandidate = 0xff3c,
    // MultipleCandidate = 0xff3d,
    // PreviousCandidate = 0xff3e,
    // Kanji = 0xff21,
    // Muhenkan = 0xff22,
    // Henkan = 0xff23,
    // Romaji = 0xff24,
    // Hiragana = 0xff25,
    // Katakana = 0xff26,
    // Hiragana_Katakana = 0xff27,
    // Zenkaku = 0xff28,
    // Hankaku = 0xff29,
    // Zenkaku_Hankaku = 0xff2a,
    // Touroku = 0xff2b,
    // Massyo = 0xff2c,
    // Kana_Lock = 0xff2d,
    // Kana_Shift = 0xff2e,
    // Eisu_Shift = 0xff2f,
    // Eisu_toggle = 0xff30,
    // Kanji_Bangou = 0xff37,
    // Zen_Koho = 0xff3d,
    // Mae_Koho = 0xff3e,
    Home = 0xff50,
    Left = 0xff51,
    Up = 0xff52,
    Right = 0xff53,
    Down = 0xff54,
    // Prior = 0xff55,
    Page_Up = 0xff55,
    // Next = 0xff56,
    Page_Down = 0xff56,
    End = 0xff57,
    Begin = 0xff58,
    Select = 0xff60,
    Print = 0xff61,
    Execute = 0xff62,
    Insert = 0xff63,
    Undo = 0xff65,
    Redo = 0xff66,
    Menu = 0xff67,
    Find = 0xff68,
    Cancel = 0xff69,
    Help = 0xff6a,
    Break = 0xff6b,
    Mode_switch = 0xff7e,
    // script_switch = 0xff7e,
    Num_Lock = 0xff7f,
    KP_Space = 0xff80,
    KP_Tab = 0xff89,
    KP_Enter = 0xff8d,
    KP_F1 = 0xff91,
    KP_F2 = 0xff92,
    KP_F3 = 0xff93,
    KP_F4 = 0xff94,
    KP_Home = 0xff95,
    KP_Left = 0xff96,
    KP_Up = 0xff97,
    KP_Right = 0xff98,
    KP_Down = 0xff99,
    // KP_Prior = 0xff9a,
    KP_Page_Up = 0xff9a,
    // KP_Next = 0xff9b,
    KP_Page_Down = 0xff9b,
    KP_End = 0xff9c,
    KP_Begin = 0xff9d,
    KP_Insert = 0xff9e,
    KP_Delete = 0xff9f,
    KP_Equal = 0xffbd,
    KP_Multiply = 0xffaa,
    KP_Add = 0xffab,
    KP_Separator = 0xffac,
    KP_Subtract = 0xffad,
    KP_Decimal = 0xffae,
    KP_Divide = 0xffaf,
    KP_0 = 0xffb0,
    KP_1 = 0xffb1,
    KP_2 = 0xffb2,
    KP_3 = 0xffb3,
    KP_4 = 0xffb4,
    KP_5 = 0xffb5,
    KP_6 = 0xffb6,
    KP_7 = 0xffb7,
    KP_8 = 0xffb8,
    KP_9 = 0xffb9,
    F1 = 0xffbe,
    F2 = 0xffbf,
    F3 = 0xffc0,
    F4 = 0xffc1,
    F5 = 0xffc2,
    F6 = 0xffc3,
    F7 = 0xffc4,
    F8 = 0xffc5,
    F9 = 0xffc6,
    F10 = 0xffc7,
    F11 = 0xffc8,
    // L1 = 0xffc8,
    F12 = 0xffc9,
    // L2 = 0xffc9,
    F13 = 0xffca,
    // L3 = 0xffca,
    F14 = 0xffcb,
    // L4 = 0xffcb,
    F15 = 0xffcc,
    // L5 = 0xffcc,
    F16 = 0xffcd,
    // L6 = 0xffcd,
    F17 = 0xffce,
    // L7 = 0xffce,
    F18 = 0xffcf,
    // L8 = 0xffcf,
    F19 = 0xffd0,
    // L9 = 0xffd0,
    F20 = 0xffd1,
    // L10 = 0xffd1,
    F21 = 0xffd2,
    // R1 = 0xffd2,
    F22 = 0xffd3,
    // R2 = 0xffd3,
    F23 = 0xffd4,
    // R3 = 0xffd4,
    F24 = 0xffd5,
    // R4 = 0xffd5,
    F25 = 0xffd6,
    // R5 = 0xffd6,
    F26 = 0xffd7,
    // R6 = 0xffd7,
    F27 = 0xffd8,
    // R7 = 0xffd8,
    F28 = 0xffd9,
    // R8 = 0xffd9,
    F29 = 0xffda,
    // R9 = 0xffda,
    F30 = 0xffdb,
    // R10 = 0xffdb,
    F31 = 0xffdc,
    // R11 = 0xffdc,
    F32 = 0xffdd,
    // R12 = 0xffdd,
    F33 = 0xffde,
    // R13 = 0xffde,
    F34 = 0xffdf,
    // R14 = 0xffdf,
    F35 = 0xffe0,
    // R15 = 0xffe0,
    Shift_L = 0xffe1,
    Shift_R = 0xffe2,
    Control_L = 0xffe3,
    Control_R = 0xffe4,
    Caps_Lock = 0xffe5,
    Shift_Lock = 0xffe6,
    Meta_L = 0xffe7,
    Meta_R = 0xffe8,
    Alt_L = 0xffe9,
    Alt_R = 0xffea,
    Super_L = 0xffeb,
    Super_R = 0xffec,
    Hyper_L = 0xffed,
    Hyper_R = 0xffee,
    // ISO_Lock = 0xfe01,
    // ISO_Level2_Latch = 0xfe02,
    // ISO_Level3_Shift = 0xfe03,
    // ISO_Level3_Latch = 0xfe04,
    // ISO_Level3_Lock = 0xfe05,
    // ISO_Level5_Shift = 0xfe11,
    // ISO_Level5_Latch = 0xfe12,
    // ISO_Level5_Lock = 0xfe13,
    // ISO_Group_Shift = 0xff7e,
    // ISO_Group_Latch = 0xfe06,
    // ISO_Group_Lock = 0xfe07,
    // ISO_Next_Group = 0xfe08,
    // ISO_Next_Group_Lock = 0xfe09,
    // ISO_Prev_Group = 0xfe0a,
    // ISO_Prev_Group_Lock = 0xfe0b,
    // ISO_First_Group = 0xfe0c,
    // ISO_First_Group_Lock = 0xfe0d,
    // ISO_Last_Group = 0xfe0e,
    // ISO_Last_Group_Lock = 0xfe0f,
    // ISO_Left_Tab = 0xfe20,
    // ISO_Move_Line_Up = 0xfe21,
    // ISO_Move_Line_Down = 0xfe22,
    // ISO_Partial_Line_Up = 0xfe23,
    // ISO_Partial_Line_Down = 0xfe24,
    // ISO_Partial_Space_Left = 0xfe25,
    // ISO_Partial_Space_Right = 0xfe26,
    // ISO_Set_Margin_Left = 0xfe27,
    // ISO_Set_Margin_Right = 0xfe28,
    // ISO_Release_Margin_Left = 0xfe29,
    // ISO_Release_Margin_Right = 0xfe2a,
    // ISO_Release_Both_Margins = 0xfe2b,
    // ISO_Fast_Cursor_Left = 0xfe2c,
    // ISO_Fast_Cursor_Right = 0xfe2d,
    // ISO_Fast_Cursor_Up = 0xfe2e,
    // ISO_Fast_Cursor_Down = 0xfe2f,
    // ISO_Continuous_Underline = 0xfe30,
    // ISO_Discontinuous_Underline = 0xfe31,
    // ISO_Emphasize = 0xfe32,
    // ISO_Center_Object = 0xfe33,
    // ISO_Enter = 0xfe34,
    dead_grave = 0xfe50,
    dead_acute = 0xfe51,
    dead_circumflex = 0xfe52,
    dead_tilde = 0xfe53,
    // dead_perispomeni = 0xfe53,
    dead_macron = 0xfe54,
    dead_breve = 0xfe55,
    dead_abovedot = 0xfe56,
    dead_diaeresis = 0xfe57,
    dead_abovering = 0xfe58,
    dead_doubleacute = 0xfe59,
    dead_caron = 0xfe5a,
    dead_cedilla = 0xfe5b,
    dead_ogonek = 0xfe5c,
    dead_iota = 0xfe5d,
    dead_voiced_sound = 0xfe5e,
    dead_semivoiced_sound = 0xfe5f,
    dead_belowdot = 0xfe60,
    dead_hook = 0xfe61,
    dead_horn = 0xfe62,
    dead_stroke = 0xfe63,
    dead_abovecomma = 0xfe64,
    // dead_psili = 0xfe64,
    dead_abovereversedcomma = 0xfe65,
    // dead_dasia = 0xfe65,
    dead_doublegrave = 0xfe66,
    dead_belowring = 0xfe67,
    dead_belowmacron = 0xfe68,
    dead_belowcircumflex = 0xfe69,
    dead_belowtilde = 0xfe6a,
    dead_belowbreve = 0xfe6b,
    dead_belowdiaeresis = 0xfe6c,
    dead_invertedbreve = 0xfe6d,
    dead_belowcomma = 0xfe6e,
    dead_currency = 0xfe6f,
    dead_lowline = 0xfe90,
    dead_aboveverticalline = 0xfe91,
    dead_belowverticalline = 0xfe92,
    dead_longsolidusoverlay = 0xfe93,
    dead_a = 0xfe80,
    dead_A = 0xfe81,
    dead_e = 0xfe82,
    dead_E = 0xfe83,
    dead_i = 0xfe84,
    dead_I = 0xfe85,
    dead_o = 0xfe86,
    dead_O = 0xfe87,
    dead_u = 0xfe88,
    dead_U = 0xfe89,
    // dead_small_schwa = 0xfe8a,
    dead_schwa = 0xfe8a,
    // dead_capital_schwa = 0xfe8b,
    dead_SCHWA = 0xfe8b,
    dead_greek = 0xfe8c,
    dead_hamza = 0xfe8d,
    // First_Virtual_Screen = 0xfed0,
    // Prev_Virtual_Screen = 0xfed1,
    // Next_Virtual_Screen = 0xfed2,
    // Last_Virtual_Screen = 0xfed4,
    // Terminate_Server = 0xfed5,
    // AccessX_Enable = 0xfe70,
    // AccessX_Feedback_Enable = 0xfe71,
    // RepeatKeys_Enable = 0xfe72,
    // SlowKeys_Enable = 0xfe73,
    // BounceKeys_Enable = 0xfe74,
    // StickyKeys_Enable = 0xfe75,
    // MouseKeys_Enable = 0xfe76,
    // MouseKeys_Accel_Enable = 0xfe77,
    // Overlay1_Enable = 0xfe78,
    // Overlay2_Enable = 0xfe79,
    // AudibleBell_Enable = 0xfe7a,
    // Pointer_Left = 0xfee0,
    // Pointer_Right = 0xfee1,
    // Pointer_Up = 0xfee2,
    // Pointer_Down = 0xfee3,
    // Pointer_UpLeft = 0xfee4,
    // Pointer_UpRight = 0xfee5,
    // Pointer_DownLeft = 0xfee6,
    // Pointer_DownRight = 0xfee7,
    // Pointer_Button_Dflt = 0xfee8,
    // Pointer_Button1 = 0xfee9,
    // Pointer_Button2 = 0xfeea,
    // Pointer_Button3 = 0xfeeb,
    // Pointer_Button4 = 0xfeec,
    // Pointer_Button5 = 0xfeed,
    // Pointer_DblClick_Dflt = 0xfeee,
    // Pointer_DblClick1 = 0xfeef,
    // Pointer_DblClick2 = 0xfef0,
    // Pointer_DblClick3 = 0xfef1,
    // Pointer_DblClick4 = 0xfef2,
    // Pointer_DblClick5 = 0xfef3,
    // Pointer_Drag_Dflt = 0xfef4,
    // Pointer_Drag1 = 0xfef5,
    // Pointer_Drag2 = 0xfef6,
    // Pointer_Drag3 = 0xfef7,
    // Pointer_Drag4 = 0xfef8,
    // Pointer_Drag5 = 0xfefd,
    // Pointer_EnableKeys = 0xfef9,
    // Pointer_Accelerate = 0xfefa,
    // Pointer_DfltBtnNext = 0xfefb,
    // Pointer_DfltBtnPrev = 0xfefc,
    // ch = 0xfea0,
    // Ch = 0xfea1,
    // CH = 0xfea2,
    // c_h = 0xfea3,
    // C_h = 0xfea4,
    // C_H = 0xfea5,
    // @"3270_Duplicate" = 0xfd01,
    // @"3270_FieldMark" = 0xfd02,
    // @"3270_Right2" = 0xfd03,
    // @"3270_Left2" = 0xfd04,
    // @"3270_BackTab" = 0xfd05,
    // @"3270_EraseEOF" = 0xfd06,
    // @"3270_EraseInput" = 0xfd07,
    // @"3270_Reset" = 0xfd08,
    // @"3270_Quit" = 0xfd09,
    // @"3270_PA1" = 0xfd0a,
    // @"3270_PA2" = 0xfd0b,
    // @"3270_PA3" = 0xfd0c,
    // @"3270_Test" = 0xfd0d,
    // @"3270_Attn" = 0xfd0e,
    // @"3270_CursorBlink" = 0xfd0f,
    // @"3270_AltCursor" = 0xfd10,
    // @"3270_KeyClick" = 0xfd11,
    // @"3270_Jump" = 0xfd12,
    // @"3270_Ident" = 0xfd13,
    // @"3270_Rule" = 0xfd14,
    // @"3270_Copy" = 0xfd15,
    // @"3270_Play" = 0xfd16,
    // @"3270_Setup" = 0xfd17,
    // @"3270_Record" = 0xfd18,
    // @"3270_ChangeScreen" = 0xfd19,
    // @"3270_DeleteWord" = 0xfd1a,
    // @"3270_ExSelect" = 0xfd1b,
    // @"3270_CursorSelect" = 0xfd1c,
    // @"3270_PrintScreen" = 0xfd1d,
    // @"3270_Enter" = 0xfd1e,
    space = 0x0020,
    exclam = 0x0021,
    quotedbl = 0x0022,
    numbersign = 0x0023,
    dollar = 0x0024,
    percent = 0x0025,
    ampersand = 0x0026,
    apostrophe = 0x0027,
    // quoteright = 0x0027,
    parenleft = 0x0028,
    parenright = 0x0029,
    asterisk = 0x002a,
    plus = 0x002b,
    comma = 0x002c,
    minus = 0x002d,
    period = 0x002e,
    slash = 0x002f,
    @"0" = 0x0030,
    @"1" = 0x0031,
    @"2" = 0x0032,
    @"3" = 0x0033,
    @"4" = 0x0034,
    @"5" = 0x0035,
    @"6" = 0x0036,
    @"7" = 0x0037,
    @"8" = 0x0038,
    @"9" = 0x0039,
    colon = 0x003a,
    semicolon = 0x003b,
    less = 0x003c,
    equal = 0x003d,
    greater = 0x003e,
    question = 0x003f,
    at = 0x0040,
    A = 0x0041,
    B = 0x0042,
    C = 0x0043,
    D = 0x0044,
    E = 0x0045,
    F = 0x0046,
    G = 0x0047,
    H = 0x0048,
    I = 0x0049,
    J = 0x004a,
    K = 0x004b,
    L = 0x004c,
    M = 0x004d,
    N = 0x004e,
    O = 0x004f,
    P = 0x0050,
    Q = 0x0051,
    R = 0x0052,
    S = 0x0053,
    T = 0x0054,
    U = 0x0055,
    V = 0x0056,
    W = 0x0057,
    X = 0x0058,
    Y = 0x0059,
    Z = 0x005a,
    bracketleft = 0x005b,
    backslash = 0x005c,
    bracketright = 0x005d,
    asciicircum = 0x005e,
    underscore = 0x005f,
    grave = 0x0060,
    // quoteleft = 0x0060,
    a = 0x0061,
    b = 0x0062,
    c = 0x0063,
    d = 0x0064,
    e = 0x0065,
    f = 0x0066,
    g = 0x0067,
    h = 0x0068,
    i = 0x0069,
    j = 0x006a,
    k = 0x006b,
    l = 0x006c,
    m = 0x006d,
    n = 0x006e,
    o = 0x006f,
    p = 0x0070,
    q = 0x0071,
    r = 0x0072,
    s = 0x0073,
    t = 0x0074,
    u = 0x0075,
    v = 0x0076,
    w = 0x0077,
    x = 0x0078,
    y = 0x0079,
    z = 0x007a,
    braceleft = 0x007b,
    bar = 0x007c,
    braceright = 0x007d,
    asciitilde = 0x007e,
    nobreakspace = 0x00a0,
    exclamdown = 0x00a1,
    cent = 0x00a2,
    sterling = 0x00a3,
    currency = 0x00a4,
    yen = 0x00a5,
    brokenbar = 0x00a6,
    section = 0x00a7,
    diaeresis = 0x00a8,
    copyright = 0x00a9,
    ordfeminine = 0x00aa,
    guillemotleft = 0x00ab,
    // guillemetleft = 0x00ab,
    notsign = 0x00ac,
    hyphen = 0x00ad,
    registered = 0x00ae,
    macron = 0x00af,
    degree = 0x00b0,
    plusminus = 0x00b1,
    // twosuperior = 0x00b2,
    // threesuperior = 0x00b3,
    // acute = 0x00b4,
    // mu = 0x00b5,
    // paragraph = 0x00b6,
    // periodcentered = 0x00b7,
    // cedilla = 0x00b8,
    // onesuperior = 0x00b9,
    // masculine = 0x00ba,
    // ordmasculine = 0x00ba,
    // guillemotright = 0x00bb,
    // guillemetright = 0x00bb,
    // onequarter = 0x00bc,
    // onehalf = 0x00bd,
    // threequarters = 0x00be,
    // questiondown = 0x00bf,
    // Agrave = 0x00c0,
    // Aacute = 0x00c1,
    // Acircumflex = 0x00c2,
    // Atilde = 0x00c3,
    // Adiaeresis = 0x00c4,
    // Aring = 0x00c5,
    // AE = 0x00c6,
    // Ccedilla = 0x00c7,
    // Egrave = 0x00c8,
    // Eacute = 0x00c9,
    // Ecircumflex = 0x00ca,
    // Ediaeresis = 0x00cb,
    // Igrave = 0x00cc,
    // Iacute = 0x00cd,
    // Icircumflex = 0x00ce,
    // Idiaeresis = 0x00cf,
    // ETH = 0x00d0,
    // Eth = 0x00d0,
    // Ntilde = 0x00d1,
    // Ograve = 0x00d2,
    // Oacute = 0x00d3,
    // Ocircumflex = 0x00d4,
    // Otilde = 0x00d5,
    // Odiaeresis = 0x00d6,
    // multiply = 0x00d7,
    // Oslash = 0x00d8,
    // Ooblique = 0x00d8,
    // Ugrave = 0x00d9,
    // Uacute = 0x00da,
    // Ucircumflex = 0x00db,
    // Udiaeresis = 0x00dc,
    // Yacute = 0x00dd,
    // THORN = 0x00de,
    // Thorn = 0x00de,
    // ssharp = 0x00df,
    // agrave = 0x00e0,
    // aacute = 0x00e1,
    // acircumflex = 0x00e2,
    // atilde = 0x00e3,
    // adiaeresis = 0x00e4,
    // aring = 0x00e5,
    // ae = 0x00e6,
    // ccedilla = 0x00e7,
    // egrave = 0x00e8,
    // eacute = 0x00e9,
    // ecircumflex = 0x00ea,
    // ediaeresis = 0x00eb,
    // igrave = 0x00ec,
    // iacute = 0x00ed,
    // icircumflex = 0x00ee,
    // idiaeresis = 0x00ef,
    // eth = 0x00f0,
    // ntilde = 0x00f1,
    // ograve = 0x00f2,
    // oacute = 0x00f3,
    // ocircumflex = 0x00f4,
    // otilde = 0x00f5,
    // odiaeresis = 0x00f6,
    // division = 0x00f7,
    // oslash = 0x00f8,
    // ooblique = 0x00f8,
    // ugrave = 0x00f9,
    // uacute = 0x00fa,
    // ucircumflex = 0x00fb,
    // udiaeresis = 0x00fc,
    // yacute = 0x00fd,
    // thorn = 0x00fe,
    // ydiaeresis = 0x00ff,
    // Aogonek = 0x01a1,
    // breve = 0x01a2,
    // Lstroke = 0x01a3,
    // Lcaron = 0x01a5,
    // Sacute = 0x01a6,
    // Scaron = 0x01a9,
    // Scedilla = 0x01aa,
    // Tcaron = 0x01ab,
    // Zacute = 0x01ac,
    // Zcaron = 0x01ae,
    // Zabovedot = 0x01af,
    // aogonek = 0x01b1,
    // ogonek = 0x01b2,
    // lstroke = 0x01b3,
    // lcaron = 0x01b5,
    // sacute = 0x01b6,
    // caron = 0x01b7,
    // scaron = 0x01b9,
    // scedilla = 0x01ba,
    // tcaron = 0x01bb,
    // zacute = 0x01bc,
    // doubleacute = 0x01bd,
    // zcaron = 0x01be,
    // zabovedot = 0x01bf,
    // Racute = 0x01c0,
    // Abreve = 0x01c3,
    // Lacute = 0x01c5,
    // Cacute = 0x01c6,
    // Ccaron = 0x01c8,
    // Eogonek = 0x01ca,
    // Ecaron = 0x01cc,
    // Dcaron = 0x01cf,
    // Dstroke = 0x01d0,
    // Nacute = 0x01d1,
    // Ncaron = 0x01d2,
    // Odoubleacute = 0x01d5,
    // Rcaron = 0x01d8,
    // Uring = 0x01d9,
    // Udoubleacute = 0x01db,
    // Tcedilla = 0x01de,
    // racute = 0x01e0,
    // abreve = 0x01e3,
    // lacute = 0x01e5,
    // cacute = 0x01e6,
    // ccaron = 0x01e8,
    // eogonek = 0x01ea,
    // ecaron = 0x01ec,
    // dcaron = 0x01ef,
    // dstroke = 0x01f0,
    // nacute = 0x01f1,
    // ncaron = 0x01f2,
    // odoubleacute = 0x01f5,
    // rcaron = 0x01f8,
    // uring = 0x01f9,
    // udoubleacute = 0x01fb,
    // tcedilla = 0x01fe,
    // abovedot = 0x01ff,
    // Hstroke = 0x02a1,
    // Hcircumflex = 0x02a6,
    // Iabovedot = 0x02a9,
    // Gbreve = 0x02ab,
    // Jcircumflex = 0x02ac,
    // hstroke = 0x02b1,
    // hcircumflex = 0x02b6,
    // idotless = 0x02b9,
    // gbreve = 0x02bb,
    // jcircumflex = 0x02bc,
    // Cabovedot = 0x02c5,
    // Ccircumflex = 0x02c6,
    // Gabovedot = 0x02d5,
    // Gcircumflex = 0x02d8,
    // Ubreve = 0x02dd,
    // Scircumflex = 0x02de,
    // cabovedot = 0x02e5,
    // ccircumflex = 0x02e6,
    // gabovedot = 0x02f5,
    // gcircumflex = 0x02f8,
    // ubreve = 0x02fd,
    // scircumflex = 0x02fe,
    // kra = 0x03a2,
    // kappa = 0x03a2,
    // Rcedilla = 0x03a3,
    // Itilde = 0x03a5,
    // Lcedilla = 0x03a6,
    // Emacron = 0x03aa,
    // Gcedilla = 0x03ab,
    // Tslash = 0x03ac,
    // rcedilla = 0x03b3,
    // itilde = 0x03b5,
    // lcedilla = 0x03b6,
    // emacron = 0x03ba,
    // gcedilla = 0x03bb,
    // tslash = 0x03bc,
    // ENG = 0x03bd,
    // eng = 0x03bf,
    // Amacron = 0x03c0,
    // Iogonek = 0x03c7,
    // Eabovedot = 0x03cc,
    // Imacron = 0x03cf,
    // Ncedilla = 0x03d1,
    // Omacron = 0x03d2,
    // Kcedilla = 0x03d3,
    // Uogonek = 0x03d9,
    // Utilde = 0x03dd,
    // Umacron = 0x03de,
    // amacron = 0x03e0,
    // iogonek = 0x03e7,
    // eabovedot = 0x03ec,
    // imacron = 0x03ef,
    // ncedilla = 0x03f1,
    // omacron = 0x03f2,
    // kcedilla = 0x03f3,
    // uogonek = 0x03f9,
    // utilde = 0x03fd,
    // umacron = 0x03fe,
    // Wcircumflex = 0x1000174,
    // wcircumflex = 0x1000175,
    // Ycircumflex = 0x1000176,
    // ycircumflex = 0x1000177,
    // Babovedot = 0x1001e02,
    // babovedot = 0x1001e03,
    // Dabovedot = 0x1001e0a,
    // dabovedot = 0x1001e0b,
    // Fabovedot = 0x1001e1e,
    // fabovedot = 0x1001e1f,
    // Mabovedot = 0x1001e40,
    // mabovedot = 0x1001e41,
    // Pabovedot = 0x1001e56,
    // pabovedot = 0x1001e57,
    // Sabovedot = 0x1001e60,
    // sabovedot = 0x1001e61,
    // Tabovedot = 0x1001e6a,
    // tabovedot = 0x1001e6b,
    // Wgrave = 0x1001e80,
    // wgrave = 0x1001e81,
    // Wacute = 0x1001e82,
    // wacute = 0x1001e83,
    // Wdiaeresis = 0x1001e84,
    // wdiaeresis = 0x1001e85,
    // Ygrave = 0x1001ef2,
    // ygrave = 0x1001ef3,
    // OE = 0x13bc,
    // oe = 0x13bd,
    // Ydiaeresis = 0x13be,
    // overline = 0x047e,
    // kana_fullstop = 0x04a1,
    // kana_openingbracket = 0x04a2,
    // kana_closingbracket = 0x04a3,
    // kana_comma = 0x04a4,
    // kana_conjunctive = 0x04a5,
    // kana_middledot = 0x04a5,
    // kana_WO = 0x04a6,
    // kana_a = 0x04a7,
    // kana_i = 0x04a8,
    // kana_u = 0x04a9,
    // kana_e = 0x04aa,
    // kana_o = 0x04ab,
    // kana_ya = 0x04ac,
    // kana_yu = 0x04ad,
    // kana_yo = 0x04ae,
    // kana_tsu = 0x04af,
    // kana_tu = 0x04af,
    // prolongedsound = 0x04b0,
    // kana_A = 0x04b1,
    // kana_I = 0x04b2,
    // kana_U = 0x04b3,
    // kana_E = 0x04b4,
    // kana_O = 0x04b5,
    // kana_KA = 0x04b6,
    // kana_KI = 0x04b7,
    // kana_KU = 0x04b8,
    // kana_KE = 0x04b9,
    // kana_KO = 0x04ba,
    // kana_SA = 0x04bb,
    // kana_SHI = 0x04bc,
    // kana_SU = 0x04bd,
    // kana_SE = 0x04be,
    // kana_SO = 0x04bf,
    // kana_TA = 0x04c0,
    // kana_CHI = 0x04c1,
    // kana_TI = 0x04c1,
    // kana_TSU = 0x04c2,
    // kana_TU = 0x04c2,
    // kana_TE = 0x04c3,
    // kana_TO = 0x04c4,
    // kana_NA = 0x04c5,
    // kana_NI = 0x04c6,
    // kana_NU = 0x04c7,
    // kana_NE = 0x04c8,
    // kana_NO = 0x04c9,
    // kana_HA = 0x04ca,
    // kana_HI = 0x04cb,
    // kana_FU = 0x04cc,
    // kana_HU = 0x04cc,
    // kana_HE = 0x04cd,
    // kana_HO = 0x04ce,
    // kana_MA = 0x04cf,
    // kana_MI = 0x04d0,
    // kana_MU = 0x04d1,
    // kana_ME = 0x04d2,
    // kana_MO = 0x04d3,
    // kana_YA = 0x04d4,
    // kana_YU = 0x04d5,
    // kana_YO = 0x04d6,
    // kana_RA = 0x04d7,
    // kana_RI = 0x04d8,
    // kana_RU = 0x04d9,
    // kana_RE = 0x04da,
    // kana_RO = 0x04db,
    // kana_WA = 0x04dc,
    // kana_N = 0x04dd,
    // voicedsound = 0x04de,
    // semivoicedsound = 0x04df,
    // kana_switch = 0xff7e,
    // Farsi_0 = 0x10006f0,
    // Farsi_1 = 0x10006f1,
    // Farsi_2 = 0x10006f2,
    // Farsi_3 = 0x10006f3,
    // Farsi_4 = 0x10006f4,
    // Farsi_5 = 0x10006f5,
    // Farsi_6 = 0x10006f6,
    // Farsi_7 = 0x10006f7,
    // Farsi_8 = 0x10006f8,
    // Farsi_9 = 0x10006f9,
    // Arabic_percent = 0x100066a,
    // Arabic_superscript_alef = 0x1000670,
    // Arabic_tteh = 0x1000679,
    // Arabic_peh = 0x100067e,
    // Arabic_tcheh = 0x1000686,
    // Arabic_ddal = 0x1000688,
    // Arabic_rreh = 0x1000691,
    // Arabic_comma = 0x05ac,
    // Arabic_fullstop = 0x10006d4,
    // Arabic_0 = 0x1000660,
    // Arabic_1 = 0x1000661,
    // Arabic_2 = 0x1000662,
    // Arabic_3 = 0x1000663,
    // Arabic_4 = 0x1000664,
    // Arabic_5 = 0x1000665,
    // Arabic_6 = 0x1000666,
    // Arabic_7 = 0x1000667,
    // Arabic_8 = 0x1000668,
    // Arabic_9 = 0x1000669,
    // Arabic_semicolon = 0x05bb,
    // Arabic_question_mark = 0x05bf,
    // Arabic_hamza = 0x05c1,
    // Arabic_maddaonalef = 0x05c2,
    // Arabic_hamzaonalef = 0x05c3,
    // Arabic_hamzaonwaw = 0x05c4,
    // Arabic_hamzaunderalef = 0x05c5,
    // Arabic_hamzaonyeh = 0x05c6,
    // Arabic_alef = 0x05c7,
    // Arabic_beh = 0x05c8,
    // Arabic_tehmarbuta = 0x05c9,
    // Arabic_teh = 0x05ca,
    // Arabic_theh = 0x05cb,
    // Arabic_jeem = 0x05cc,
    // Arabic_hah = 0x05cd,
    // Arabic_khah = 0x05ce,
    // Arabic_dal = 0x05cf,
    // Arabic_thal = 0x05d0,
    // Arabic_ra = 0x05d1,
    // Arabic_zain = 0x05d2,
    // Arabic_seen = 0x05d3,
    // Arabic_sheen = 0x05d4,
    // Arabic_sad = 0x05d5,
    // Arabic_dad = 0x05d6,
    // Arabic_tah = 0x05d7,
    // Arabic_zah = 0x05d8,
    // Arabic_ain = 0x05d9,
    // Arabic_ghain = 0x05da,
    // Arabic_tatweel = 0x05e0,
    // Arabic_feh = 0x05e1,
    // Arabic_qaf = 0x05e2,
    // Arabic_kaf = 0x05e3,
    // Arabic_lam = 0x05e4,
    // Arabic_meem = 0x05e5,
    // Arabic_noon = 0x05e6,
    // Arabic_ha = 0x05e7,
    // Arabic_heh = 0x05e7,
    // Arabic_waw = 0x05e8,
    // Arabic_alefmaksura = 0x05e9,
    // Arabic_yeh = 0x05ea,
    // Arabic_fathatan = 0x05eb,
    // Arabic_dammatan = 0x05ec,
    // Arabic_kasratan = 0x05ed,
    // Arabic_fatha = 0x05ee,
    // Arabic_damma = 0x05ef,
    // Arabic_kasra = 0x05f0,
    // Arabic_shadda = 0x05f1,
    // Arabic_sukun = 0x05f2,
    // Arabic_madda_above = 0x1000653,
    // Arabic_hamza_above = 0x1000654,
    // Arabic_hamza_below = 0x1000655,
    // Arabic_jeh = 0x1000698,
    // Arabic_veh = 0x10006a4,
    // Arabic_keheh = 0x10006a9,
    // Arabic_gaf = 0x10006af,
    // Arabic_noon_ghunna = 0x10006ba,
    // Arabic_heh_doachashmee = 0x10006be,
    // Farsi_yeh = 0x10006cc,
    // Arabic_farsi_yeh = 0x10006cc,
    // Arabic_yeh_baree = 0x10006d2,
    // Arabic_heh_goal = 0x10006c1,
    // Arabic_switch = 0xff7e,
    // Cyrillic_GHE_bar = 0x1000492,
    // Cyrillic_ghe_bar = 0x1000493,
    // Cyrillic_ZHE_descender = 0x1000496,
    // Cyrillic_zhe_descender = 0x1000497,
    // Cyrillic_KA_descender = 0x100049a,
    // Cyrillic_ka_descender = 0x100049b,
    // Cyrillic_KA_vertstroke = 0x100049c,
    // Cyrillic_ka_vertstroke = 0x100049d,
    // Cyrillic_EN_descender = 0x10004a2,
    // Cyrillic_en_descender = 0x10004a3,
    // Cyrillic_U_straight = 0x10004ae,
    // Cyrillic_u_straight = 0x10004af,
    // Cyrillic_U_straight_bar = 0x10004b0,
    // Cyrillic_u_straight_bar = 0x10004b1,
    // Cyrillic_HA_descender = 0x10004b2,
    // Cyrillic_ha_descender = 0x10004b3,
    // Cyrillic_CHE_descender = 0x10004b6,
    // Cyrillic_che_descender = 0x10004b7,
    // Cyrillic_CHE_vertstroke = 0x10004b8,
    // Cyrillic_che_vertstroke = 0x10004b9,
    // Cyrillic_SHHA = 0x10004ba,
    // Cyrillic_shha = 0x10004bb,
    // Cyrillic_SCHWA = 0x10004d8,
    // Cyrillic_schwa = 0x10004d9,
    // Cyrillic_I_macron = 0x10004e2,
    // Cyrillic_i_macron = 0x10004e3,
    // Cyrillic_O_bar = 0x10004e8,
    // Cyrillic_o_bar = 0x10004e9,
    // Cyrillic_U_macron = 0x10004ee,
    // Cyrillic_u_macron = 0x10004ef,
    // Serbian_dje = 0x06a1,
    // Macedonia_gje = 0x06a2,
    // Cyrillic_io = 0x06a3,
    // Ukrainian_ie = 0x06a4,
    // Ukranian_je = 0x06a4,
    // Macedonia_dse = 0x06a5,
    // Ukrainian_i = 0x06a6,
    // Ukranian_i = 0x06a6,
    // Ukrainian_yi = 0x06a7,
    // Ukranian_yi = 0x06a7,
    // Cyrillic_je = 0x06a8,
    // Serbian_je = 0x06a8,
    // Cyrillic_lje = 0x06a9,
    // Serbian_lje = 0x06a9,
    // Cyrillic_nje = 0x06aa,
    // Serbian_nje = 0x06aa,
    // Serbian_tshe = 0x06ab,
    // Macedonia_kje = 0x06ac,
    // Ukrainian_ghe_with_upturn = 0x06ad,
    // Byelorussian_shortu = 0x06ae,
    // Cyrillic_dzhe = 0x06af,
    // Serbian_dze = 0x06af,
    // numerosign = 0x06b0,
    // Serbian_DJE = 0x06b1,
    // Macedonia_GJE = 0x06b2,
    // Cyrillic_IO = 0x06b3,
    // Ukrainian_IE = 0x06b4,
    // Ukranian_JE = 0x06b4,
    // Macedonia_DSE = 0x06b5,
    // Ukrainian_I = 0x06b6,
    // Ukranian_I = 0x06b6,
    // Ukrainian_YI = 0x06b7,
    // Ukranian_YI = 0x06b7,
    // Cyrillic_JE = 0x06b8,
    // Serbian_JE = 0x06b8,
    // Cyrillic_LJE = 0x06b9,
    // Serbian_LJE = 0x06b9,
    // Cyrillic_NJE = 0x06ba,
    // Serbian_NJE = 0x06ba,
    // Serbian_TSHE = 0x06bb,
    // Macedonia_KJE = 0x06bc,
    // Ukrainian_GHE_WITH_UPTURN = 0x06bd,
    // Byelorussian_SHORTU = 0x06be,
    // Cyrillic_DZHE = 0x06bf,
    // Serbian_DZE = 0x06bf,
    // Cyrillic_yu = 0x06c0,
    // Cyrillic_a = 0x06c1,
    // Cyrillic_be = 0x06c2,
    // Cyrillic_tse = 0x06c3,
    // Cyrillic_de = 0x06c4,
    // Cyrillic_ie = 0x06c5,
    // Cyrillic_ef = 0x06c6,
    // Cyrillic_ghe = 0x06c7,
    // Cyrillic_ha = 0x06c8,
    // Cyrillic_i = 0x06c9,
    // Cyrillic_shorti = 0x06ca,
    // Cyrillic_ka = 0x06cb,
    // Cyrillic_el = 0x06cc,
    // Cyrillic_em = 0x06cd,
    // Cyrillic_en = 0x06ce,
    // Cyrillic_o = 0x06cf,
    // Cyrillic_pe = 0x06d0,
    // Cyrillic_ya = 0x06d1,
    // Cyrillic_er = 0x06d2,
    // Cyrillic_es = 0x06d3,
    // Cyrillic_te = 0x06d4,
    // Cyrillic_u = 0x06d5,
    // Cyrillic_zhe = 0x06d6,
    // Cyrillic_ve = 0x06d7,
    // Cyrillic_softsign = 0x06d8,
    // Cyrillic_yeru = 0x06d9,
    // Cyrillic_ze = 0x06da,
    // Cyrillic_sha = 0x06db,
    // Cyrillic_e = 0x06dc,
    // Cyrillic_shcha = 0x06dd,
    // Cyrillic_che = 0x06de,
    // Cyrillic_hardsign = 0x06df,
    // Cyrillic_YU = 0x06e0,
    // Cyrillic_A = 0x06e1,
    // Cyrillic_BE = 0x06e2,
    // Cyrillic_TSE = 0x06e3,
    // Cyrillic_DE = 0x06e4,
    // Cyrillic_IE = 0x06e5,
    // Cyrillic_EF = 0x06e6,
    // Cyrillic_GHE = 0x06e7,
    // Cyrillic_HA = 0x06e8,
    // Cyrillic_I = 0x06e9,
    // Cyrillic_SHORTI = 0x06ea,
    // Cyrillic_KA = 0x06eb,
    // Cyrillic_EL = 0x06ec,
    // Cyrillic_EM = 0x06ed,
    // Cyrillic_EN = 0x06ee,
    // Cyrillic_O = 0x06ef,
    // Cyrillic_PE = 0x06f0,
    // Cyrillic_YA = 0x06f1,
    // Cyrillic_ER = 0x06f2,
    // Cyrillic_ES = 0x06f3,
    // Cyrillic_TE = 0x06f4,
    // Cyrillic_U = 0x06f5,
    // Cyrillic_ZHE = 0x06f6,
    // Cyrillic_VE = 0x06f7,
    // Cyrillic_SOFTSIGN = 0x06f8,
    // Cyrillic_YERU = 0x06f9,
    // Cyrillic_ZE = 0x06fa,
    // Cyrillic_SHA = 0x06fb,
    // Cyrillic_E = 0x06fc,
    // Cyrillic_SHCHA = 0x06fd,
    // Cyrillic_CHE = 0x06fe,
    // Cyrillic_HARDSIGN = 0x06ff,
    // Greek_ALPHAaccent = 0x07a1,
    // Greek_EPSILONaccent = 0x07a2,
    // Greek_ETAaccent = 0x07a3,
    // Greek_IOTAaccent = 0x07a4,
    // Greek_IOTAdieresis = 0x07a5,
    // Greek_IOTAdiaeresis = 0x07a5,
    // Greek_OMICRONaccent = 0x07a7,
    // Greek_UPSILONaccent = 0x07a8,
    // Greek_UPSILONdieresis = 0x07a9,
    // Greek_OMEGAaccent = 0x07ab,
    // Greek_accentdieresis = 0x07ae,
    // Greek_horizbar = 0x07af,
    // Greek_alphaaccent = 0x07b1,
    // Greek_epsilonaccent = 0x07b2,
    // Greek_etaaccent = 0x07b3,
    // Greek_iotaaccent = 0x07b4,
    // Greek_iotadieresis = 0x07b5,
    // Greek_iotaaccentdieresis = 0x07b6,
    // Greek_omicronaccent = 0x07b7,
    // Greek_upsilonaccent = 0x07b8,
    // Greek_upsilondieresis = 0x07b9,
    // Greek_upsilonaccentdieresis = 0x07ba,
    // Greek_omegaaccent = 0x07bb,
    // Greek_ALPHA = 0x07c1,
    // Greek_BETA = 0x07c2,
    // Greek_GAMMA = 0x07c3,
    // Greek_DELTA = 0x07c4,
    // Greek_EPSILON = 0x07c5,
    // Greek_ZETA = 0x07c6,
    // Greek_ETA = 0x07c7,
    // Greek_THETA = 0x07c8,
    // Greek_IOTA = 0x07c9,
    // Greek_KAPPA = 0x07ca,
    // Greek_LAMDA = 0x07cb,
    // Greek_LAMBDA = 0x07cb,
    // Greek_MU = 0x07cc,
    // Greek_NU = 0x07cd,
    // Greek_XI = 0x07ce,
    // Greek_OMICRON = 0x07cf,
    // Greek_PI = 0x07d0,
    // Greek_RHO = 0x07d1,
    // Greek_SIGMA = 0x07d2,
    // Greek_TAU = 0x07d4,
    // Greek_UPSILON = 0x07d5,
    // Greek_PHI = 0x07d6,
    // Greek_CHI = 0x07d7,
    // Greek_PSI = 0x07d8,
    // Greek_OMEGA = 0x07d9,
    // Greek_alpha = 0x07e1,
    // Greek_beta = 0x07e2,
    // Greek_gamma = 0x07e3,
    // Greek_delta = 0x07e4,
    // Greek_epsilon = 0x07e5,
    // Greek_zeta = 0x07e6,
    // Greek_eta = 0x07e7,
    // Greek_theta = 0x07e8,
    // Greek_iota = 0x07e9,
    // Greek_kappa = 0x07ea,
    // Greek_lamda = 0x07eb,
    // Greek_lambda = 0x07eb,
    // Greek_mu = 0x07ec,
    // Greek_nu = 0x07ed,
    // Greek_xi = 0x07ee,
    // Greek_omicron = 0x07ef,
    // Greek_pi = 0x07f0,
    // Greek_rho = 0x07f1,
    // Greek_sigma = 0x07f2,
    // Greek_finalsmallsigma = 0x07f3,
    // Greek_tau = 0x07f4,
    // Greek_upsilon = 0x07f5,
    // Greek_phi = 0x07f6,
    // Greek_chi = 0x07f7,
    // Greek_psi = 0x07f8,
    // Greek_omega = 0x07f9,
    // Greek_switch = 0xff7e,
    // leftradical = 0x08a1,
    // topleftradical = 0x08a2,
    // horizconnector = 0x08a3,
    // topintegral = 0x08a4,
    // botintegral = 0x08a5,
    // vertconnector = 0x08a6,
    // topleftsqbracket = 0x08a7,
    // botleftsqbracket = 0x08a8,
    // toprightsqbracket = 0x08a9,
    // botrightsqbracket = 0x08aa,
    // topleftparens = 0x08ab,
    // botleftparens = 0x08ac,
    // toprightparens = 0x08ad,
    // botrightparens = 0x08ae,
    // leftmiddlecurlybrace = 0x08af,
    // rightmiddlecurlybrace = 0x08b0,
    // topleftsummation = 0x08b1,
    // botleftsummation = 0x08b2,
    // topvertsummationconnector = 0x08b3,
    // botvertsummationconnector = 0x08b4,
    // toprightsummation = 0x08b5,
    // botrightsummation = 0x08b6,
    // rightmiddlesummation = 0x08b7,
    // lessthanequal = 0x08bc,
    // notequal = 0x08bd,
    // greaterthanequal = 0x08be,
    // integral = 0x08bf,
    // therefore = 0x08c0,
    // variation = 0x08c1,
    // infinity = 0x08c2,
    // nabla = 0x08c5,
    // approximate = 0x08c8,
    // similarequal = 0x08c9,
    // ifonlyif = 0x08cd,
    // implies = 0x08ce,
    // identical = 0x08cf,
    // radical = 0x08d6,
    // includedin = 0x08da,
    // includes = 0x08db,
    // intersection = 0x08dc,
    // @"union" = 0x08dd,
    // logicaland = 0x08de,
    // logicalor = 0x08df,
    // partialderivative = 0x08ef,
    // function = 0x08f6,
    // leftarrow = 0x08fb,
    // uparrow = 0x08fc,
    // rightarrow = 0x08fd,
    // downarrow = 0x08fe,
    // blank = 0x09df,
    // soliddiamond = 0x09e0,
    // checkerboard = 0x09e1,
    // ht = 0x09e2,
    // ff = 0x09e3,
    // cr = 0x09e4,
    // lf = 0x09e5,
    // nl = 0x09e8,
    // vt = 0x09e9,
    // lowrightcorner = 0x09ea,
    // uprightcorner = 0x09eb,
    // upleftcorner = 0x09ec,
    // lowleftcorner = 0x09ed,
    // crossinglines = 0x09ee,
    // horizlinescan1 = 0x09ef,
    // horizlinescan3 = 0x09f0,
    // horizlinescan5 = 0x09f1,
    // horizlinescan7 = 0x09f2,
    // horizlinescan9 = 0x09f3,
    // leftt = 0x09f4,
    // rightt = 0x09f5,
    // bott = 0x09f6,
    // topt = 0x09f7,
    // vertbar = 0x09f8,
    // emspace = 0x0aa1,
    // enspace = 0x0aa2,
    // em3space = 0x0aa3,
    // em4space = 0x0aa4,
    // digitspace = 0x0aa5,
    // punctspace = 0x0aa6,
    // thinspace = 0x0aa7,
    // hairspace = 0x0aa8,
    // emdash = 0x0aa9,
    // endash = 0x0aaa,
    // signifblank = 0x0aac,
    // ellipsis = 0x0aae,
    // doubbaselinedot = 0x0aaf,
    // onethird = 0x0ab0,
    // twothirds = 0x0ab1,
    // onefifth = 0x0ab2,
    // twofifths = 0x0ab3,
    // threefifths = 0x0ab4,
    // fourfifths = 0x0ab5,
    // onesixth = 0x0ab6,
    // fivesixths = 0x0ab7,
    // careof = 0x0ab8,
    // figdash = 0x0abb,
    // leftanglebracket = 0x0abc,
    // decimalpoint = 0x0abd,
    // rightanglebracket = 0x0abe,
    // marker = 0x0abf,
    // oneeighth = 0x0ac3,
    // threeeighths = 0x0ac4,
    // fiveeighths = 0x0ac5,
    // seveneighths = 0x0ac6,
    // trademark = 0x0ac9,
    // signaturemark = 0x0aca,
    // trademarkincircle = 0x0acb,
    // leftopentriangle = 0x0acc,
    // rightopentriangle = 0x0acd,
    // emopencircle = 0x0ace,
    // emopenrectangle = 0x0acf,
    // leftsinglequotemark = 0x0ad0,
    // rightsinglequotemark = 0x0ad1,
    // leftdoublequotemark = 0x0ad2,
    // rightdoublequotemark = 0x0ad3,
    // prescription = 0x0ad4,
    // permille = 0x0ad5,
    // minutes = 0x0ad6,
    // seconds = 0x0ad7,
    // latincross = 0x0ad9,
    // hexagram = 0x0ada,
    // filledrectbullet = 0x0adb,
    // filledlefttribullet = 0x0adc,
    // filledrighttribullet = 0x0add,
    // emfilledcircle = 0x0ade,
    // emfilledrect = 0x0adf,
    // enopencircbullet = 0x0ae0,
    // enopensquarebullet = 0x0ae1,
    // openrectbullet = 0x0ae2,
    // opentribulletup = 0x0ae3,
    // opentribulletdown = 0x0ae4,
    // openstar = 0x0ae5,
    // enfilledcircbullet = 0x0ae6,
    // enfilledsqbullet = 0x0ae7,
    // filledtribulletup = 0x0ae8,
    // filledtribulletdown = 0x0ae9,
    // leftpointer = 0x0aea,
    // rightpointer = 0x0aeb,
    // club = 0x0aec,
    // diamond = 0x0aed,
    // heart = 0x0aee,
    // maltesecross = 0x0af0,
    // dagger = 0x0af1,
    // doubledagger = 0x0af2,
    // checkmark = 0x0af3,
    // ballotcross = 0x0af4,
    // musicalsharp = 0x0af5,
    // musicalflat = 0x0af6,
    // malesymbol = 0x0af7,
    // femalesymbol = 0x0af8,
    // telephone = 0x0af9,
    // telephonerecorder = 0x0afa,
    // phonographcopyright = 0x0afb,
    // caret = 0x0afc,
    // singlelowquotemark = 0x0afd,
    // doublelowquotemark = 0x0afe,
    // cursor = 0x0aff,
    // leftcaret = 0x0ba3,
    // rightcaret = 0x0ba6,
    // downcaret = 0x0ba8,
    // upcaret = 0x0ba9,
    // overbar = 0x0bc0,
    // downtack = 0x0bc2,
    // upshoe = 0x0bc3,
    // downstile = 0x0bc4,
    // underbar = 0x0bc6,
    // jot = 0x0bca,
    // quad = 0x0bcc,
    // uptack = 0x0bce,
    // circle = 0x0bcf,
    // upstile = 0x0bd3,
    // downshoe = 0x0bd6,
    // rightshoe = 0x0bd8,
    // leftshoe = 0x0bda,
    // lefttack = 0x0bdc,
    // righttack = 0x0bfc,
    // hebrew_doublelowline = 0x0cdf,
    // hebrew_aleph = 0x0ce0,
    // hebrew_bet = 0x0ce1,
    // hebrew_beth = 0x0ce1,
    // hebrew_gimel = 0x0ce2,
    // hebrew_gimmel = 0x0ce2,
    // hebrew_dalet = 0x0ce3,
    // hebrew_daleth = 0x0ce3,
    // hebrew_he = 0x0ce4,
    // hebrew_waw = 0x0ce5,
    // hebrew_zain = 0x0ce6,
    // hebrew_zayin = 0x0ce6,
    // hebrew_chet = 0x0ce7,
    // hebrew_het = 0x0ce7,
    // hebrew_tet = 0x0ce8,
    // hebrew_teth = 0x0ce8,
    // hebrew_yod = 0x0ce9,
    // hebrew_finalkaph = 0x0cea,
    // hebrew_kaph = 0x0ceb,
    // hebrew_lamed = 0x0cec,
    // hebrew_finalmem = 0x0ced,
    // hebrew_mem = 0x0cee,
    // hebrew_finalnun = 0x0cef,
    // hebrew_nun = 0x0cf0,
    // hebrew_samech = 0x0cf1,
    // hebrew_samekh = 0x0cf1,
    // hebrew_ayin = 0x0cf2,
    // hebrew_finalpe = 0x0cf3,
    // hebrew_pe = 0x0cf4,
    // hebrew_finalzade = 0x0cf5,
    // hebrew_finalzadi = 0x0cf5,
    // hebrew_zade = 0x0cf6,
    // hebrew_zadi = 0x0cf6,
    // hebrew_qoph = 0x0cf7,
    // hebrew_kuf = 0x0cf7,
    // hebrew_resh = 0x0cf8,
    // hebrew_shin = 0x0cf9,
    // hebrew_taw = 0x0cfa,
    // hebrew_taf = 0x0cfa,
    // Hebrew_switch = 0xff7e,
    // Thai_kokai = 0x0da1,
    // Thai_khokhai = 0x0da2,
    // Thai_khokhuat = 0x0da3,
    // Thai_khokhwai = 0x0da4,
    // Thai_khokhon = 0x0da5,
    // Thai_khorakhang = 0x0da6,
    // Thai_ngongu = 0x0da7,
    // Thai_chochan = 0x0da8,
    // Thai_choching = 0x0da9,
    // Thai_chochang = 0x0daa,
    // Thai_soso = 0x0dab,
    // Thai_chochoe = 0x0dac,
    // Thai_yoying = 0x0dad,
    // Thai_dochada = 0x0dae,
    // Thai_topatak = 0x0daf,
    // Thai_thothan = 0x0db0,
    // Thai_thonangmontho = 0x0db1,
    // Thai_thophuthao = 0x0db2,
    // Thai_nonen = 0x0db3,
    // Thai_dodek = 0x0db4,
    // Thai_totao = 0x0db5,
    // Thai_thothung = 0x0db6,
    // Thai_thothahan = 0x0db7,
    // Thai_thothong = 0x0db8,
    // Thai_nonu = 0x0db9,
    // Thai_bobaimai = 0x0dba,
    // Thai_popla = 0x0dbb,
    // Thai_phophung = 0x0dbc,
    // Thai_fofa = 0x0dbd,
    // Thai_phophan = 0x0dbe,
    // Thai_fofan = 0x0dbf,
    // Thai_phosamphao = 0x0dc0,
    // Thai_moma = 0x0dc1,
    // Thai_yoyak = 0x0dc2,
    // Thai_rorua = 0x0dc3,
    // Thai_ru = 0x0dc4,
    // Thai_loling = 0x0dc5,
    // Thai_lu = 0x0dc6,
    // Thai_wowaen = 0x0dc7,
    // Thai_sosala = 0x0dc8,
    // Thai_sorusi = 0x0dc9,
    // Thai_sosua = 0x0dca,
    // Thai_hohip = 0x0dcb,
    // Thai_lochula = 0x0dcc,
    // Thai_oang = 0x0dcd,
    // Thai_honokhuk = 0x0dce,
    // Thai_paiyannoi = 0x0dcf,
    // Thai_saraa = 0x0dd0,
    // Thai_maihanakat = 0x0dd1,
    // Thai_saraaa = 0x0dd2,
    // Thai_saraam = 0x0dd3,
    // Thai_sarai = 0x0dd4,
    // Thai_saraii = 0x0dd5,
    // Thai_saraue = 0x0dd6,
    // Thai_sarauee = 0x0dd7,
    // Thai_sarau = 0x0dd8,
    // Thai_sarauu = 0x0dd9,
    // Thai_phinthu = 0x0dda,
    // Thai_maihanakat_maitho = 0x0dde,
    // Thai_baht = 0x0ddf,
    // Thai_sarae = 0x0de0,
    // Thai_saraae = 0x0de1,
    // Thai_sarao = 0x0de2,
    // Thai_saraaimaimuan = 0x0de3,
    // Thai_saraaimaimalai = 0x0de4,
    // Thai_lakkhangyao = 0x0de5,
    // Thai_maiyamok = 0x0de6,
    // Thai_maitaikhu = 0x0de7,
    // Thai_maiek = 0x0de8,
    // Thai_maitho = 0x0de9,
    // Thai_maitri = 0x0dea,
    // Thai_maichattawa = 0x0deb,
    // Thai_thanthakhat = 0x0dec,
    // Thai_nikhahit = 0x0ded,
    // Thai_leksun = 0x0df0,
    // Thai_leknung = 0x0df1,
    // Thai_leksong = 0x0df2,
    // Thai_leksam = 0x0df3,
    // Thai_leksi = 0x0df4,
    // Thai_lekha = 0x0df5,
    // Thai_lekhok = 0x0df6,
    // Thai_lekchet = 0x0df7,
    // Thai_lekpaet = 0x0df8,
    // Thai_lekkao = 0x0df9,
    // Hangul = 0xff31,
    // Hangul_Start = 0xff32,
    // Hangul_End = 0xff33,
    // Hangul_Hanja = 0xff34,
    // Hangul_Jamo = 0xff35,
    // Hangul_Romaja = 0xff36,
    // Hangul_Codeinput = 0xff37,
    // Hangul_Jeonja = 0xff38,
    // Hangul_Banja = 0xff39,
    // Hangul_PreHanja = 0xff3a,
    // Hangul_PostHanja = 0xff3b,
    // Hangul_SingleCandidate = 0xff3c,
    // Hangul_MultipleCandidate = 0xff3d,
    // Hangul_PreviousCandidate = 0xff3e,
    // Hangul_Special = 0xff3f,
    // Hangul_switch = 0xff7e,
    // Hangul_Kiyeog = 0x0ea1,
    // Hangul_SsangKiyeog = 0x0ea2,
    // Hangul_KiyeogSios = 0x0ea3,
    // Hangul_Nieun = 0x0ea4,
    // Hangul_NieunJieuj = 0x0ea5,
    // Hangul_NieunHieuh = 0x0ea6,
    // Hangul_Dikeud = 0x0ea7,
    // Hangul_SsangDikeud = 0x0ea8,
    // Hangul_Rieul = 0x0ea9,
    // Hangul_RieulKiyeog = 0x0eaa,
    // Hangul_RieulMieum = 0x0eab,
    // Hangul_RieulPieub = 0x0eac,
    // Hangul_RieulSios = 0x0ead,
    // Hangul_RieulTieut = 0x0eae,
    // Hangul_RieulPhieuf = 0x0eaf,
    // Hangul_RieulHieuh = 0x0eb0,
    // Hangul_Mieum = 0x0eb1,
    // Hangul_Pieub = 0x0eb2,
    // Hangul_SsangPieub = 0x0eb3,
    // Hangul_PieubSios = 0x0eb4,
    // Hangul_Sios = 0x0eb5,
    // Hangul_SsangSios = 0x0eb6,
    // Hangul_Ieung = 0x0eb7,
    // Hangul_Jieuj = 0x0eb8,
    // Hangul_SsangJieuj = 0x0eb9,
    // Hangul_Cieuc = 0x0eba,
    // Hangul_Khieuq = 0x0ebb,
    // Hangul_Tieut = 0x0ebc,
    // Hangul_Phieuf = 0x0ebd,
    // Hangul_Hieuh = 0x0ebe,
    // Hangul_A = 0x0ebf,
    // Hangul_AE = 0x0ec0,
    // Hangul_YA = 0x0ec1,
    // Hangul_YAE = 0x0ec2,
    // Hangul_EO = 0x0ec3,
    // Hangul_E = 0x0ec4,
    // Hangul_YEO = 0x0ec5,
    // Hangul_YE = 0x0ec6,
    // Hangul_O = 0x0ec7,
    // Hangul_WA = 0x0ec8,
    // Hangul_WAE = 0x0ec9,
    // Hangul_OE = 0x0eca,
    // Hangul_YO = 0x0ecb,
    // Hangul_U = 0x0ecc,
    // Hangul_WEO = 0x0ecd,
    // Hangul_WE = 0x0ece,
    // Hangul_WI = 0x0ecf,
    // Hangul_YU = 0x0ed0,
    // Hangul_EU = 0x0ed1,
    // Hangul_YI = 0x0ed2,
    // Hangul_I = 0x0ed3,
    // Hangul_J_Kiyeog = 0x0ed4,
    // Hangul_J_SsangKiyeog = 0x0ed5,
    // Hangul_J_KiyeogSios = 0x0ed6,
    // Hangul_J_Nieun = 0x0ed7,
    // Hangul_J_NieunJieuj = 0x0ed8,
    // Hangul_J_NieunHieuh = 0x0ed9,
    // Hangul_J_Dikeud = 0x0eda,
    // Hangul_J_Rieul = 0x0edb,
    // Hangul_J_RieulKiyeog = 0x0edc,
    // Hangul_J_RieulMieum = 0x0edd,
    // Hangul_J_RieulPieub = 0x0ede,
    // Hangul_J_RieulSios = 0x0edf,
    // Hangul_J_RieulTieut = 0x0ee0,
    // Hangul_J_RieulPhieuf = 0x0ee1,
    // Hangul_J_RieulHieuh = 0x0ee2,
    // Hangul_J_Mieum = 0x0ee3,
    // Hangul_J_Pieub = 0x0ee4,
    // Hangul_J_PieubSios = 0x0ee5,
    // Hangul_J_Sios = 0x0ee6,
    // Hangul_J_SsangSios = 0x0ee7,
    // Hangul_J_Ieung = 0x0ee8,
    // Hangul_J_Jieuj = 0x0ee9,
    // Hangul_J_Cieuc = 0x0eea,
    // Hangul_J_Khieuq = 0x0eeb,
    // Hangul_J_Tieut = 0x0eec,
    // Hangul_J_Phieuf = 0x0eed,
    // Hangul_J_Hieuh = 0x0eee,
    // Hangul_RieulYeorinHieuh = 0x0eef,
    // Hangul_SunkyeongeumMieum = 0x0ef0,
    // Hangul_SunkyeongeumPieub = 0x0ef1,
    // Hangul_PanSios = 0x0ef2,
    // Hangul_KkogjiDalrinIeung = 0x0ef3,
    // Hangul_SunkyeongeumPhieuf = 0x0ef4,
    // Hangul_YeorinHieuh = 0x0ef5,
    // Hangul_AraeA = 0x0ef6,
    // Hangul_AraeAE = 0x0ef7,
    // Hangul_J_PanSios = 0x0ef8,
    // Hangul_J_KkogjiDalrinIeung = 0x0ef9,
    // Hangul_J_YeorinHieuh = 0x0efa,
    // Korean_Won = 0x0eff,
    // Armenian_ligature_ew = 0x1000587,
    // Armenian_full_stop = 0x1000589,
    // Armenian_verjaket = 0x1000589,
    // Armenian_separation_mark = 0x100055d,
    // Armenian_but = 0x100055d,
    // Armenian_hyphen = 0x100058a,
    // Armenian_yentamna = 0x100058a,
    // Armenian_exclam = 0x100055c,
    // Armenian_amanak = 0x100055c,
    // Armenian_accent = 0x100055b,
    // Armenian_shesht = 0x100055b,
    // Armenian_question = 0x100055e,
    // Armenian_paruyk = 0x100055e,
    // Armenian_AYB = 0x1000531,
    // Armenian_ayb = 0x1000561,
    // Armenian_BEN = 0x1000532,
    // Armenian_ben = 0x1000562,
    // Armenian_GIM = 0x1000533,
    // Armenian_gim = 0x1000563,
    // Armenian_DA = 0x1000534,
    // Armenian_da = 0x1000564,
    // Armenian_YECH = 0x1000535,
    // Armenian_yech = 0x1000565,
    // Armenian_ZA = 0x1000536,
    // Armenian_za = 0x1000566,
    // Armenian_E = 0x1000537,
    // Armenian_e = 0x1000567,
    // Armenian_AT = 0x1000538,
    // Armenian_at = 0x1000568,
    // Armenian_TO = 0x1000539,
    // Armenian_to = 0x1000569,
    // Armenian_ZHE = 0x100053a,
    // Armenian_zhe = 0x100056a,
    // Armenian_INI = 0x100053b,
    // Armenian_ini = 0x100056b,
    // Armenian_LYUN = 0x100053c,
    // Armenian_lyun = 0x100056c,
    // Armenian_KHE = 0x100053d,
    // Armenian_khe = 0x100056d,
    // Armenian_TSA = 0x100053e,
    // Armenian_tsa = 0x100056e,
    // Armenian_KEN = 0x100053f,
    // Armenian_ken = 0x100056f,
    // Armenian_HO = 0x1000540,
    // Armenian_ho = 0x1000570,
    // Armenian_DZA = 0x1000541,
    // Armenian_dza = 0x1000571,
    // Armenian_GHAT = 0x1000542,
    // Armenian_ghat = 0x1000572,
    // Armenian_TCHE = 0x1000543,
    // Armenian_tche = 0x1000573,
    // Armenian_MEN = 0x1000544,
    // Armenian_men = 0x1000574,
    // Armenian_HI = 0x1000545,
    // Armenian_hi = 0x1000575,
    // Armenian_NU = 0x1000546,
    // Armenian_nu = 0x1000576,
    // Armenian_SHA = 0x1000547,
    // Armenian_sha = 0x1000577,
    // Armenian_VO = 0x1000548,
    // Armenian_vo = 0x1000578,
    // Armenian_CHA = 0x1000549,
    // Armenian_cha = 0x1000579,
    // Armenian_PE = 0x100054a,
    // Armenian_pe = 0x100057a,
    // Armenian_JE = 0x100054b,
    // Armenian_je = 0x100057b,
    // Armenian_RA = 0x100054c,
    // Armenian_ra = 0x100057c,
    // Armenian_SE = 0x100054d,
    // Armenian_se = 0x100057d,
    // Armenian_VEV = 0x100054e,
    // Armenian_vev = 0x100057e,
    // Armenian_TYUN = 0x100054f,
    // Armenian_tyun = 0x100057f,
    // Armenian_RE = 0x1000550,
    // Armenian_re = 0x1000580,
    // Armenian_TSO = 0x1000551,
    // Armenian_tso = 0x1000581,
    // Armenian_VYUN = 0x1000552,
    // Armenian_vyun = 0x1000582,
    // Armenian_PYUR = 0x1000553,
    // Armenian_pyur = 0x1000583,
    // Armenian_KE = 0x1000554,
    // Armenian_ke = 0x1000584,
    // Armenian_O = 0x1000555,
    // Armenian_o = 0x1000585,
    // Armenian_FE = 0x1000556,
    // Armenian_fe = 0x1000586,
    // Armenian_apostrophe = 0x100055a,
    // Georgian_an = 0x10010d0,
    // Georgian_ban = 0x10010d1,
    // Georgian_gan = 0x10010d2,
    // Georgian_don = 0x10010d3,
    // Georgian_en = 0x10010d4,
    // Georgian_vin = 0x10010d5,
    // Georgian_zen = 0x10010d6,
    // Georgian_tan = 0x10010d7,
    // Georgian_in = 0x10010d8,
    // Georgian_kan = 0x10010d9,
    // Georgian_las = 0x10010da,
    // Georgian_man = 0x10010db,
    // Georgian_nar = 0x10010dc,
    // Georgian_on = 0x10010dd,
    // Georgian_par = 0x10010de,
    // Georgian_zhar = 0x10010df,
    // Georgian_rae = 0x10010e0,
    // Georgian_san = 0x10010e1,
    // Georgian_tar = 0x10010e2,
    // Georgian_un = 0x10010e3,
    // Georgian_phar = 0x10010e4,
    // Georgian_khar = 0x10010e5,
    // Georgian_ghan = 0x10010e6,
    // Georgian_qar = 0x10010e7,
    // Georgian_shin = 0x10010e8,
    // Georgian_chin = 0x10010e9,
    // Georgian_can = 0x10010ea,
    // Georgian_jil = 0x10010eb,
    // Georgian_cil = 0x10010ec,
    // Georgian_char = 0x10010ed,
    // Georgian_xan = 0x10010ee,
    // Georgian_jhan = 0x10010ef,
    // Georgian_hae = 0x10010f0,
    // Georgian_he = 0x10010f1,
    // Georgian_hie = 0x10010f2,
    // Georgian_we = 0x10010f3,
    // Georgian_har = 0x10010f4,
    // Georgian_hoe = 0x10010f5,
    // Georgian_fi = 0x10010f6,
    // Xabovedot = 0x1001e8a,
    // Ibreve = 0x100012c,
    // Zstroke = 0x10001b5,
    // Gcaron = 0x10001e6,
    // Ocaron = 0x10001d1,
    // Obarred = 0x100019f,
    // xabovedot = 0x1001e8b,
    // ibreve = 0x100012d,
    // zstroke = 0x10001b6,
    // gcaron = 0x10001e7,
    // ocaron = 0x10001d2,
    // obarred = 0x1000275,
    // SCHWA = 0x100018f,
    // schwa = 0x1000259,
    // EZH = 0x10001b7,
    // ezh = 0x1000292,
    // Lbelowdot = 0x1001e36,
    // lbelowdot = 0x1001e37,
    // Abelowdot = 0x1001ea0,
    // abelowdot = 0x1001ea1,
    // Ahook = 0x1001ea2,
    // ahook = 0x1001ea3,
    // Acircumflexacute = 0x1001ea4,
    // acircumflexacute = 0x1001ea5,
    // Acircumflexgrave = 0x1001ea6,
    // acircumflexgrave = 0x1001ea7,
    // Acircumflexhook = 0x1001ea8,
    // acircumflexhook = 0x1001ea9,
    // Acircumflextilde = 0x1001eaa,
    // acircumflextilde = 0x1001eab,
    // Acircumflexbelowdot = 0x1001eac,
    // acircumflexbelowdot = 0x1001ead,
    // Abreveacute = 0x1001eae,
    // abreveacute = 0x1001eaf,
    // Abrevegrave = 0x1001eb0,
    // abrevegrave = 0x1001eb1,
    // Abrevehook = 0x1001eb2,
    // abrevehook = 0x1001eb3,
    // Abrevetilde = 0x1001eb4,
    // abrevetilde = 0x1001eb5,
    // Abrevebelowdot = 0x1001eb6,
    // abrevebelowdot = 0x1001eb7,
    // Ebelowdot = 0x1001eb8,
    // ebelowdot = 0x1001eb9,
    // Ehook = 0x1001eba,
    // ehook = 0x1001ebb,
    // Etilde = 0x1001ebc,
    // etilde = 0x1001ebd,
    // Ecircumflexacute = 0x1001ebe,
    // ecircumflexacute = 0x1001ebf,
    // Ecircumflexgrave = 0x1001ec0,
    // ecircumflexgrave = 0x1001ec1,
    // Ecircumflexhook = 0x1001ec2,
    // ecircumflexhook = 0x1001ec3,
    // Ecircumflextilde = 0x1001ec4,
    // ecircumflextilde = 0x1001ec5,
    // Ecircumflexbelowdot = 0x1001ec6,
    // ecircumflexbelowdot = 0x1001ec7,
    // Ihook = 0x1001ec8,
    // ihook = 0x1001ec9,
    // Ibelowdot = 0x1001eca,
    // ibelowdot = 0x1001ecb,
    // Obelowdot = 0x1001ecc,
    // obelowdot = 0x1001ecd,
    // Ohook = 0x1001ece,
    // ohook = 0x1001ecf,
    // Ocircumflexacute = 0x1001ed0,
    // ocircumflexacute = 0x1001ed1,
    // Ocircumflexgrave = 0x1001ed2,
    // ocircumflexgrave = 0x1001ed3,
    // Ocircumflexhook = 0x1001ed4,
    // ocircumflexhook = 0x1001ed5,
    // Ocircumflextilde = 0x1001ed6,
    // ocircumflextilde = 0x1001ed7,
    // Ocircumflexbelowdot = 0x1001ed8,
    // ocircumflexbelowdot = 0x1001ed9,
    // Ohornacute = 0x1001eda,
    // ohornacute = 0x1001edb,
    // Ohorngrave = 0x1001edc,
    // ohorngrave = 0x1001edd,
    // Ohornhook = 0x1001ede,
    // ohornhook = 0x1001edf,
    // Ohorntilde = 0x1001ee0,
    // ohorntilde = 0x1001ee1,
    // Ohornbelowdot = 0x1001ee2,
    // ohornbelowdot = 0x1001ee3,
    // Ubelowdot = 0x1001ee4,
    // ubelowdot = 0x1001ee5,
    // Uhook = 0x1001ee6,
    // uhook = 0x1001ee7,
    // Uhornacute = 0x1001ee8,
    // uhornacute = 0x1001ee9,
    // Uhorngrave = 0x1001eea,
    // uhorngrave = 0x1001eeb,
    // Uhornhook = 0x1001eec,
    // uhornhook = 0x1001eed,
    // Uhorntilde = 0x1001eee,
    // uhorntilde = 0x1001eef,
    // Uhornbelowdot = 0x1001ef0,
    // uhornbelowdot = 0x1001ef1,
    // Ybelowdot = 0x1001ef4,
    // ybelowdot = 0x1001ef5,
    // Yhook = 0x1001ef6,
    // yhook = 0x1001ef7,
    // Ytilde = 0x1001ef8,
    // ytilde = 0x1001ef9,
    // Ohorn = 0x10001a0,
    // ohorn = 0x10001a1,
    // Uhorn = 0x10001af,
    // uhorn = 0x10001b0,
    // combining_tilde = 0x1000303,
    // combining_grave = 0x1000300,
    // combining_acute = 0x1000301,
    // combining_hook = 0x1000309,
    // combining_belowdot = 0x1000323,
    // EcuSign = 0x10020a0,
    // ColonSign = 0x10020a1,
    // CruzeiroSign = 0x10020a2,
    // FFrancSign = 0x10020a3,
    // LiraSign = 0x10020a4,
    // MillSign = 0x10020a5,
    // NairaSign = 0x10020a6,
    // PesetaSign = 0x10020a7,
    // RupeeSign = 0x10020a8,
    // WonSign = 0x10020a9,
    // NewSheqelSign = 0x10020aa,
    // DongSign = 0x10020ab,
    // EuroSign = 0x20ac,
    // zerosuperior = 0x1002070,
    // foursuperior = 0x1002074,
    // fivesuperior = 0x1002075,
    // sixsuperior = 0x1002076,
    // sevensuperior = 0x1002077,
    // eightsuperior = 0x1002078,
    // ninesuperior = 0x1002079,
    // zerosubscript = 0x1002080,
    // onesubscript = 0x1002081,
    // twosubscript = 0x1002082,
    // threesubscript = 0x1002083,
    // foursubscript = 0x1002084,
    // fivesubscript = 0x1002085,
    // sixsubscript = 0x1002086,
    // sevensubscript = 0x1002087,
    // eightsubscript = 0x1002088,
    // ninesubscript = 0x1002089,
    // partdifferential = 0x1002202,
    // emptyset = 0x1002205,
    // elementof = 0x1002208,
    // notelementof = 0x1002209,
    // containsas = 0x100220b,
    // squareroot = 0x100221a,
    // cuberoot = 0x100221b,
    // fourthroot = 0x100221c,
    // dintegral = 0x100222c,
    // tintegral = 0x100222d,
    // because = 0x1002235,
    // approxeq = 0x1002248,
    // notapproxeq = 0x1002247,
    // notidentical = 0x1002262,
    // stricteq = 0x1002263,
    // braille_dot_1 = 0xfff1,
    // braille_dot_2 = 0xfff2,
    // braille_dot_3 = 0xfff3,
    // braille_dot_4 = 0xfff4,
    // braille_dot_5 = 0xfff5,
    // braille_dot_6 = 0xfff6,
    // braille_dot_7 = 0xfff7,
    // braille_dot_8 = 0xfff8,
    // braille_dot_9 = 0xfff9,
    // braille_dot_10 = 0xfffa,
    // braille_blank = 0x1002800,
    // braille_dots_1 = 0x1002801,
    // braille_dots_2 = 0x1002802,
    // braille_dots_12 = 0x1002803,
    // braille_dots_3 = 0x1002804,
    // braille_dots_13 = 0x1002805,
    // braille_dots_23 = 0x1002806,
    // braille_dots_123 = 0x1002807,
    // braille_dots_4 = 0x1002808,
    // braille_dots_14 = 0x1002809,
    // braille_dots_24 = 0x100280a,
    // braille_dots_124 = 0x100280b,
    // braille_dots_34 = 0x100280c,
    // braille_dots_134 = 0x100280d,
    // braille_dots_234 = 0x100280e,
    // braille_dots_1234 = 0x100280f,
    // braille_dots_5 = 0x1002810,
    // braille_dots_15 = 0x1002811,
    // braille_dots_25 = 0x1002812,
    // braille_dots_125 = 0x1002813,
    // braille_dots_35 = 0x1002814,
    // braille_dots_135 = 0x1002815,
    // braille_dots_235 = 0x1002816,
    // braille_dots_1235 = 0x1002817,
    // braille_dots_45 = 0x1002818,
    // braille_dots_145 = 0x1002819,
    // braille_dots_245 = 0x100281a,
    // braille_dots_1245 = 0x100281b,
    // braille_dots_345 = 0x100281c,
    // braille_dots_1345 = 0x100281d,
    // braille_dots_2345 = 0x100281e,
    // braille_dots_12345 = 0x100281f,
    // braille_dots_6 = 0x1002820,
    // braille_dots_16 = 0x1002821,
    // braille_dots_26 = 0x1002822,
    // braille_dots_126 = 0x1002823,
    // braille_dots_36 = 0x1002824,
    // braille_dots_136 = 0x1002825,
    // braille_dots_236 = 0x1002826,
    // braille_dots_1236 = 0x1002827,
    // braille_dots_46 = 0x1002828,
    // braille_dots_146 = 0x1002829,
    // braille_dots_246 = 0x100282a,
    // braille_dots_1246 = 0x100282b,
    // braille_dots_346 = 0x100282c,
    // braille_dots_1346 = 0x100282d,
    // braille_dots_2346 = 0x100282e,
    // braille_dots_12346 = 0x100282f,
    // braille_dots_56 = 0x1002830,
    // braille_dots_156 = 0x1002831,
    // braille_dots_256 = 0x1002832,
    // braille_dots_1256 = 0x1002833,
    // braille_dots_356 = 0x1002834,
    // braille_dots_1356 = 0x1002835,
    // braille_dots_2356 = 0x1002836,
    // braille_dots_12356 = 0x1002837,
    // braille_dots_456 = 0x1002838,
    // braille_dots_1456 = 0x1002839,
    // braille_dots_2456 = 0x100283a,
    // braille_dots_12456 = 0x100283b,
    // braille_dots_3456 = 0x100283c,
    // braille_dots_13456 = 0x100283d,
    // braille_dots_23456 = 0x100283e,
    // braille_dots_123456 = 0x100283f,
    // braille_dots_7 = 0x1002840,
    // braille_dots_17 = 0x1002841,
    // braille_dots_27 = 0x1002842,
    // braille_dots_127 = 0x1002843,
    // braille_dots_37 = 0x1002844,
    // braille_dots_137 = 0x1002845,
    // braille_dots_237 = 0x1002846,
    // braille_dots_1237 = 0x1002847,
    // braille_dots_47 = 0x1002848,
    // braille_dots_147 = 0x1002849,
    // braille_dots_247 = 0x100284a,
    // braille_dots_1247 = 0x100284b,
    // braille_dots_347 = 0x100284c,
    // braille_dots_1347 = 0x100284d,
    // braille_dots_2347 = 0x100284e,
    // braille_dots_12347 = 0x100284f,
    // braille_dots_57 = 0x1002850,
    // braille_dots_157 = 0x1002851,
    // braille_dots_257 = 0x1002852,
    // braille_dots_1257 = 0x1002853,
    // braille_dots_357 = 0x1002854,
    // braille_dots_1357 = 0x1002855,
    // braille_dots_2357 = 0x1002856,
    // braille_dots_12357 = 0x1002857,
    // braille_dots_457 = 0x1002858,
    // braille_dots_1457 = 0x1002859,
    // braille_dots_2457 = 0x100285a,
    // braille_dots_12457 = 0x100285b,
    // braille_dots_3457 = 0x100285c,
    // braille_dots_13457 = 0x100285d,
    // braille_dots_23457 = 0x100285e,
    // braille_dots_123457 = 0x100285f,
    // braille_dots_67 = 0x1002860,
    // braille_dots_167 = 0x1002861,
    // braille_dots_267 = 0x1002862,
    // braille_dots_1267 = 0x1002863,
    // braille_dots_367 = 0x1002864,
    // braille_dots_1367 = 0x1002865,
    // braille_dots_2367 = 0x1002866,
    // braille_dots_12367 = 0x1002867,
    // braille_dots_467 = 0x1002868,
    // braille_dots_1467 = 0x1002869,
    // braille_dots_2467 = 0x100286a,
    // braille_dots_12467 = 0x100286b,
    // braille_dots_3467 = 0x100286c,
    // braille_dots_13467 = 0x100286d,
    // braille_dots_23467 = 0x100286e,
    // braille_dots_123467 = 0x100286f,
    // braille_dots_567 = 0x1002870,
    // braille_dots_1567 = 0x1002871,
    // braille_dots_2567 = 0x1002872,
    // braille_dots_12567 = 0x1002873,
    // braille_dots_3567 = 0x1002874,
    // braille_dots_13567 = 0x1002875,
    // braille_dots_23567 = 0x1002876,
    // braille_dots_123567 = 0x1002877,
    // braille_dots_4567 = 0x1002878,
    // braille_dots_14567 = 0x1002879,
    // braille_dots_24567 = 0x100287a,
    // braille_dots_124567 = 0x100287b,
    // braille_dots_34567 = 0x100287c,
    // braille_dots_134567 = 0x100287d,
    // braille_dots_234567 = 0x100287e,
    // braille_dots_1234567 = 0x100287f,
    // braille_dots_8 = 0x1002880,
    // braille_dots_18 = 0x1002881,
    // braille_dots_28 = 0x1002882,
    // braille_dots_128 = 0x1002883,
    // braille_dots_38 = 0x1002884,
    // braille_dots_138 = 0x1002885,
    // braille_dots_238 = 0x1002886,
    // braille_dots_1238 = 0x1002887,
    // braille_dots_48 = 0x1002888,
    // braille_dots_148 = 0x1002889,
    // braille_dots_248 = 0x100288a,
    // braille_dots_1248 = 0x100288b,
    // braille_dots_348 = 0x100288c,
    // braille_dots_1348 = 0x100288d,
    // braille_dots_2348 = 0x100288e,
    // braille_dots_12348 = 0x100288f,
    // braille_dots_58 = 0x1002890,
    // braille_dots_158 = 0x1002891,
    // braille_dots_258 = 0x1002892,
    // braille_dots_1258 = 0x1002893,
    // braille_dots_358 = 0x1002894,
    // braille_dots_1358 = 0x1002895,
    // braille_dots_2358 = 0x1002896,
    // braille_dots_12358 = 0x1002897,
    // braille_dots_458 = 0x1002898,
    // braille_dots_1458 = 0x1002899,
    // braille_dots_2458 = 0x100289a,
    // braille_dots_12458 = 0x100289b,
    // braille_dots_3458 = 0x100289c,
    // braille_dots_13458 = 0x100289d,
    // braille_dots_23458 = 0x100289e,
    // braille_dots_123458 = 0x100289f,
    // braille_dots_68 = 0x10028a0,
    // braille_dots_168 = 0x10028a1,
    // braille_dots_268 = 0x10028a2,
    // braille_dots_1268 = 0x10028a3,
    // braille_dots_368 = 0x10028a4,
    // braille_dots_1368 = 0x10028a5,
    // braille_dots_2368 = 0x10028a6,
    // braille_dots_12368 = 0x10028a7,
    // braille_dots_468 = 0x10028a8,
    // braille_dots_1468 = 0x10028a9,
    // braille_dots_2468 = 0x10028aa,
    // braille_dots_12468 = 0x10028ab,
    // braille_dots_3468 = 0x10028ac,
    // braille_dots_13468 = 0x10028ad,
    // braille_dots_23468 = 0x10028ae,
    // braille_dots_123468 = 0x10028af,
    // braille_dots_568 = 0x10028b0,
    // braille_dots_1568 = 0x10028b1,
    // braille_dots_2568 = 0x10028b2,
    // braille_dots_12568 = 0x10028b3,
    // braille_dots_3568 = 0x10028b4,
    // braille_dots_13568 = 0x10028b5,
    // braille_dots_23568 = 0x10028b6,
    // braille_dots_123568 = 0x10028b7,
    // braille_dots_4568 = 0x10028b8,
    // braille_dots_14568 = 0x10028b9,
    // braille_dots_24568 = 0x10028ba,
    // braille_dots_124568 = 0x10028bb,
    // braille_dots_34568 = 0x10028bc,
    // braille_dots_134568 = 0x10028bd,
    // braille_dots_234568 = 0x10028be,
    // braille_dots_1234568 = 0x10028bf,
    // braille_dots_78 = 0x10028c0,
    // braille_dots_178 = 0x10028c1,
    // braille_dots_278 = 0x10028c2,
    // braille_dots_1278 = 0x10028c3,
    // braille_dots_378 = 0x10028c4,
    // braille_dots_1378 = 0x10028c5,
    // braille_dots_2378 = 0x10028c6,
    // braille_dots_12378 = 0x10028c7,
    // braille_dots_478 = 0x10028c8,
    // braille_dots_1478 = 0x10028c9,
    // braille_dots_2478 = 0x10028ca,
    // braille_dots_12478 = 0x10028cb,
    // braille_dots_3478 = 0x10028cc,
    // braille_dots_13478 = 0x10028cd,
    // braille_dots_23478 = 0x10028ce,
    // braille_dots_123478 = 0x10028cf,
    // braille_dots_578 = 0x10028d0,
    // braille_dots_1578 = 0x10028d1,
    // braille_dots_2578 = 0x10028d2,
    // braille_dots_12578 = 0x10028d3,
    // braille_dots_3578 = 0x10028d4,
    // braille_dots_13578 = 0x10028d5,
    // braille_dots_23578 = 0x10028d6,
    // braille_dots_123578 = 0x10028d7,
    // braille_dots_4578 = 0x10028d8,
    // braille_dots_14578 = 0x10028d9,
    // braille_dots_24578 = 0x10028da,
    // braille_dots_124578 = 0x10028db,
    // braille_dots_34578 = 0x10028dc,
    // braille_dots_134578 = 0x10028dd,
    // braille_dots_234578 = 0x10028de,
    // braille_dots_1234578 = 0x10028df,
    // braille_dots_678 = 0x10028e0,
    // braille_dots_1678 = 0x10028e1,
    // braille_dots_2678 = 0x10028e2,
    // braille_dots_12678 = 0x10028e3,
    // braille_dots_3678 = 0x10028e4,
    // braille_dots_13678 = 0x10028e5,
    // braille_dots_23678 = 0x10028e6,
    // braille_dots_123678 = 0x10028e7,
    // braille_dots_4678 = 0x10028e8,
    // braille_dots_14678 = 0x10028e9,
    // braille_dots_24678 = 0x10028ea,
    // braille_dots_124678 = 0x10028eb,
    // braille_dots_34678 = 0x10028ec,
    // braille_dots_134678 = 0x10028ed,
    // braille_dots_234678 = 0x10028ee,
    // braille_dots_1234678 = 0x10028ef,
    // braille_dots_5678 = 0x10028f0,
    // braille_dots_15678 = 0x10028f1,
    // braille_dots_25678 = 0x10028f2,
    // braille_dots_125678 = 0x10028f3,
    // braille_dots_35678 = 0x10028f4,
    // braille_dots_135678 = 0x10028f5,
    // braille_dots_235678 = 0x10028f6,
    // braille_dots_1235678 = 0x10028f7,
    // braille_dots_45678 = 0x10028f8,
    // braille_dots_145678 = 0x10028f9,
    // braille_dots_245678 = 0x10028fa,
    // braille_dots_1245678 = 0x10028fb,
    // braille_dots_345678 = 0x10028fc,
    // braille_dots_1345678 = 0x10028fd,
    // braille_dots_2345678 = 0x10028fe,
    // braille_dots_12345678 = 0x10028ff,
    // Sinh_ng = 0x1000d82,
    // Sinh_h2 = 0x1000d83,
    // Sinh_a = 0x1000d85,
    // Sinh_aa = 0x1000d86,
    // Sinh_ae = 0x1000d87,
    // Sinh_aee = 0x1000d88,
    // Sinh_i = 0x1000d89,
    // Sinh_ii = 0x1000d8a,
    // Sinh_u = 0x1000d8b,
    // Sinh_uu = 0x1000d8c,
    // Sinh_ri = 0x1000d8d,
    // Sinh_rii = 0x1000d8e,
    // Sinh_lu = 0x1000d8f,
    // Sinh_luu = 0x1000d90,
    // Sinh_e = 0x1000d91,
    // Sinh_ee = 0x1000d92,
    // Sinh_ai = 0x1000d93,
    // Sinh_o = 0x1000d94,
    // Sinh_oo = 0x1000d95,
    // Sinh_au = 0x1000d96,
    // Sinh_ka = 0x1000d9a,
    // Sinh_kha = 0x1000d9b,
    // Sinh_ga = 0x1000d9c,
    // Sinh_gha = 0x1000d9d,
    // Sinh_ng2 = 0x1000d9e,
    // Sinh_nga = 0x1000d9f,
    // Sinh_ca = 0x1000da0,
    // Sinh_cha = 0x1000da1,
    // Sinh_ja = 0x1000da2,
    // Sinh_jha = 0x1000da3,
    // Sinh_nya = 0x1000da4,
    // Sinh_jnya = 0x1000da5,
    // Sinh_nja = 0x1000da6,
    // Sinh_tta = 0x1000da7,
    // Sinh_ttha = 0x1000da8,
    // Sinh_dda = 0x1000da9,
    // Sinh_ddha = 0x1000daa,
    // Sinh_nna = 0x1000dab,
    // Sinh_ndda = 0x1000dac,
    // Sinh_tha = 0x1000dad,
    // Sinh_thha = 0x1000dae,
    // Sinh_dha = 0x1000daf,
    // Sinh_dhha = 0x1000db0,
    // Sinh_na = 0x1000db1,
    // Sinh_ndha = 0x1000db3,
    // Sinh_pa = 0x1000db4,
    // Sinh_pha = 0x1000db5,
    // Sinh_ba = 0x1000db6,
    // Sinh_bha = 0x1000db7,
    // Sinh_ma = 0x1000db8,
    // Sinh_mba = 0x1000db9,
    // Sinh_ya = 0x1000dba,
    // Sinh_ra = 0x1000dbb,
    // Sinh_la = 0x1000dbd,
    // Sinh_va = 0x1000dc0,
    // Sinh_sha = 0x1000dc1,
    // Sinh_ssha = 0x1000dc2,
    // Sinh_sa = 0x1000dc3,
    // Sinh_ha = 0x1000dc4,
    // Sinh_lla = 0x1000dc5,
    // Sinh_fa = 0x1000dc6,
    // Sinh_al = 0x1000dca,
    // Sinh_aa2 = 0x1000dcf,
    // Sinh_ae2 = 0x1000dd0,
    // Sinh_aee2 = 0x1000dd1,
    // Sinh_i2 = 0x1000dd2,
    // Sinh_ii2 = 0x1000dd3,
    // Sinh_u2 = 0x1000dd4,
    // Sinh_uu2 = 0x1000dd6,
    // Sinh_ru2 = 0x1000dd8,
    // Sinh_e2 = 0x1000dd9,
    // Sinh_ee2 = 0x1000dda,
    // Sinh_ai2 = 0x1000ddb,
    // Sinh_o2 = 0x1000ddc,
    // Sinh_oo2 = 0x1000ddd,
    // Sinh_au2 = 0x1000dde,
    // Sinh_lu2 = 0x1000ddf,
    // Sinh_ruu2 = 0x1000df2,
    // Sinh_luu2 = 0x1000df3,
    // Sinh_kunddaliya = 0x1000df4,
    // XF86ModeLock = 0x1008ff01,
    // XF86MonBrightnessUp = 0x1008ff02,
    // XF86MonBrightnessDown = 0x1008ff03,
    // XF86KbdLightOnOff = 0x1008ff04,
    // XF86KbdBrightnessUp = 0x1008ff05,
    // XF86KbdBrightnessDown = 0x1008ff06,
    // XF86MonBrightnessCycle = 0x1008ff07,
    // XF86Standby = 0x1008ff10,
    // XF86AudioLowerVolume = 0x1008ff11,
    // XF86AudioMute = 0x1008ff12,
    // XF86AudioRaiseVolume = 0x1008ff13,
    // XF86AudioPlay = 0x1008ff14,
    // XF86AudioStop = 0x1008ff15,
    // XF86AudioPrev = 0x1008ff16,
    // XF86AudioNext = 0x1008ff17,
    // XF86HomePage = 0x1008ff18,
    // XF86Mail = 0x1008ff19,
    // XF86Start = 0x1008ff1a,
    // XF86Search = 0x1008ff1b,
    // XF86AudioRecord = 0x1008ff1c,
    // XF86Calculator = 0x1008ff1d,
    // XF86Memo = 0x1008ff1e,
    // XF86ToDoList = 0x1008ff1f,
    // XF86Calendar = 0x1008ff20,
    // XF86PowerDown = 0x1008ff21,
    // XF86ContrastAdjust = 0x1008ff22,
    // XF86RockerUp = 0x1008ff23,
    // XF86RockerDown = 0x1008ff24,
    // XF86RockerEnter = 0x1008ff25,
    // XF86Back = 0x1008ff26,
    // XF86Forward = 0x1008ff27,
    // XF86Stop = 0x1008ff28,
    // XF86Refresh = 0x1008ff29,
    // XF86PowerOff = 0x1008ff2a,
    // XF86WakeUp = 0x1008ff2b,
    // XF86Eject = 0x1008ff2c,
    // XF86ScreenSaver = 0x1008ff2d,
    // XF86WWW = 0x1008ff2e,
    // XF86Sleep = 0x1008ff2f,
    // XF86Favorites = 0x1008ff30,
    // XF86AudioPause = 0x1008ff31,
    // XF86AudioMedia = 0x1008ff32,
    // XF86MyComputer = 0x1008ff33,
    // XF86VendorHome = 0x1008ff34,
    // XF86LightBulb = 0x1008ff35,
    // XF86Shop = 0x1008ff36,
    // XF86History = 0x1008ff37,
    // XF86OpenURL = 0x1008ff38,
    // XF86AddFavorite = 0x1008ff39,
    // XF86HotLinks = 0x1008ff3a,
    // XF86BrightnessAdjust = 0x1008ff3b,
    // XF86Finance = 0x1008ff3c,
    // XF86Community = 0x1008ff3d,
    // XF86AudioRewind = 0x1008ff3e,
    // XF86BackForward = 0x1008ff3f,
    // XF86Launch0 = 0x1008ff40,
    // XF86Launch1 = 0x1008ff41,
    // XF86Launch2 = 0x1008ff42,
    // XF86Launch3 = 0x1008ff43,
    // XF86Launch4 = 0x1008ff44,
    // XF86Launch5 = 0x1008ff45,
    // XF86Launch6 = 0x1008ff46,
    // XF86Launch7 = 0x1008ff47,
    // XF86Launch8 = 0x1008ff48,
    // XF86Launch9 = 0x1008ff49,
    // XF86LaunchA = 0x1008ff4a,
    // XF86LaunchB = 0x1008ff4b,
    // XF86LaunchC = 0x1008ff4c,
    // XF86LaunchD = 0x1008ff4d,
    // XF86LaunchE = 0x1008ff4e,
    // XF86LaunchF = 0x1008ff4f,
    // XF86ApplicationLeft = 0x1008ff50,
    // XF86ApplicationRight = 0x1008ff51,
    // XF86Book = 0x1008ff52,
    // XF86CD = 0x1008ff53,
    // XF86MediaSelectCD = 0x1008ff53,
    // XF86Calculater = 0x1008ff54,
    // XF86Clear = 0x1008ff55,
    // XF86Close = 0x1008ff56,
    // XF86Copy = 0x1008ff57,
    // XF86Cut = 0x1008ff58,
    // XF86Display = 0x1008ff59,
    // XF86DOS = 0x1008ff5a,
    // XF86Documents = 0x1008ff5b,
    // XF86Excel = 0x1008ff5c,
    // XF86Explorer = 0x1008ff5d,
    // XF86Game = 0x1008ff5e,
    // XF86Go = 0x1008ff5f,
    // XF86iTouch = 0x1008ff60,
    // XF86LogOff = 0x1008ff61,
    // XF86Market = 0x1008ff62,
    // XF86Meeting = 0x1008ff63,
    // XF86MenuKB = 0x1008ff65,
    // XF86MenuPB = 0x1008ff66,
    // XF86MySites = 0x1008ff67,
    // XF86New = 0x1008ff68,
    // XF86News = 0x1008ff69,
    // XF86OfficeHome = 0x1008ff6a,
    // XF86Open = 0x1008ff6b,
    // XF86Option = 0x1008ff6c,
    // XF86Paste = 0x1008ff6d,
    // XF86Phone = 0x1008ff6e,
    // XF86Q = 0x1008ff70,
    // XF86Reply = 0x1008ff72,
    // XF86Reload = 0x1008ff73,
    // XF86RotateWindows = 0x1008ff74,
    // XF86RotationPB = 0x1008ff75,
    // XF86RotationKB = 0x1008ff76,
    // XF86Save = 0x1008ff77,
    // XF86ScrollUp = 0x1008ff78,
    // XF86ScrollDown = 0x1008ff79,
    // XF86ScrollClick = 0x1008ff7a,
    // XF86Send = 0x1008ff7b,
    // XF86Spell = 0x1008ff7c,
    // XF86SplitScreen = 0x1008ff7d,
    // XF86Support = 0x1008ff7e,
    // XF86TaskPane = 0x1008ff7f,
    // XF86Terminal = 0x1008ff80,
    // XF86Tools = 0x1008ff81,
    // XF86Travel = 0x1008ff82,
    // XF86UserPB = 0x1008ff84,
    // XF86User1KB = 0x1008ff85,
    // XF86User2KB = 0x1008ff86,
    // XF86Video = 0x1008ff87,
    // XF86WheelButton = 0x1008ff88,
    // XF86Word = 0x1008ff89,
    // XF86Xfer = 0x1008ff8a,
    // XF86ZoomIn = 0x1008ff8b,
    // XF86ZoomOut = 0x1008ff8c,
    // XF86Away = 0x1008ff8d,
    // XF86Messenger = 0x1008ff8e,
    // XF86WebCam = 0x1008ff8f,
    // XF86MailForward = 0x1008ff90,
    // XF86Pictures = 0x1008ff91,
    // XF86Music = 0x1008ff92,
    // XF86Battery = 0x1008ff93,
    // XF86Bluetooth = 0x1008ff94,
    // XF86WLAN = 0x1008ff95,
    // XF86UWB = 0x1008ff96,
    // XF86AudioForward = 0x1008ff97,
    // XF86AudioRepeat = 0x1008ff98,
    // XF86AudioRandomPlay = 0x1008ff99,
    // XF86Subtitle = 0x1008ff9a,
    // XF86AudioCycleTrack = 0x1008ff9b,
    // XF86CycleAngle = 0x1008ff9c,
    // XF86FrameBack = 0x1008ff9d,
    // XF86FrameForward = 0x1008ff9e,
    // XF86Time = 0x1008ff9f,
    // XF86Select = 0x1008ffa0,
    // XF86View = 0x1008ffa1,
    // XF86TopMenu = 0x1008ffa2,
    // XF86Red = 0x1008ffa3,
    // XF86Green = 0x1008ffa4,
    // XF86Yellow = 0x1008ffa5,
    // XF86Blue = 0x1008ffa6,
    // XF86Suspend = 0x1008ffa7,
    // XF86Hibernate = 0x1008ffa8,
    // XF86TouchpadToggle = 0x1008ffa9,
    // XF86TouchpadOn = 0x1008ffb0,
    // XF86TouchpadOff = 0x1008ffb1,
    // XF86AudioMicMute = 0x1008ffb2,
    // XF86Keyboard = 0x1008ffb3,
    // XF86WWAN = 0x1008ffb4,
    // XF86RFKill = 0x1008ffb5,
    // XF86AudioPreset = 0x1008ffb6,
    // XF86RotationLockToggle = 0x1008ffb7,
    // XF86FullScreen = 0x1008ffb8,
    // XF86Switch_VT_1 = 0x1008fe01,
    // XF86Switch_VT_2 = 0x1008fe02,
    // XF86Switch_VT_3 = 0x1008fe03,
    // XF86Switch_VT_4 = 0x1008fe04,
    // XF86Switch_VT_5 = 0x1008fe05,
    // XF86Switch_VT_6 = 0x1008fe06,
    // XF86Switch_VT_7 = 0x1008fe07,
    // XF86Switch_VT_8 = 0x1008fe08,
    // XF86Switch_VT_9 = 0x1008fe09,
    // XF86Switch_VT_10 = 0x1008fe0a,
    // XF86Switch_VT_11 = 0x1008fe0b,
    // XF86Switch_VT_12 = 0x1008fe0c,
    // XF86Ungrab = 0x1008fe20,
    // XF86ClearGrab = 0x1008fe21,
    // XF86Next_VMode = 0x1008fe22,
    // XF86Prev_VMode = 0x1008fe23,
    // XF86LogWindowTree = 0x1008fe24,
    // XF86LogGrabInfo = 0x1008fe25,
    // XF86MediaPlayPause = 0x100810a4,
    // XF86Exit = 0x100810ae,
    // XF86AudioBassBoost = 0x100810d1,
    // XF86Sport = 0x100810dc,
    // XF86BrightnessAuto = 0x100810f4,
    // XF86MonBrightnessAuto = 0x100810f4,
    // XF86DisplayOff = 0x100810f5,
    // XF86OK = 0x10081160,
    // XF86GoTo = 0x10081162,
    // XF86Info = 0x10081166,
    // XF86VendorLogo = 0x10081168,
    // XF86MediaSelectProgramGuide = 0x1008116a,
    // XF86MediaSelectHome = 0x1008116e,
    // XF86MediaLanguageMenu = 0x10081170,
    // XF86MediaTitleMenu = 0x10081171,
    // XF86AudioChannelMode = 0x10081175,
    // XF86AspectRatio = 0x10081177,
    // XF86MediaSelectPC = 0x10081178,
    // XF86MediaSelectTV = 0x10081179,
    // XF86MediaSelectCable = 0x1008117a,
    // XF86MediaSelectVCR = 0x1008117b,
    // XF86MediaSelectVCRPlus = 0x1008117c,
    // XF86MediaSelectSatellite = 0x1008117d,
    // XF86MediaSelectTape = 0x10081180,
    // XF86MediaSelectRadio = 0x10081181,
    // XF86MediaSelectTuner = 0x10081182,
    // XF86MediaPlayer = 0x10081183,
    // XF86MediaSelectTeletext = 0x10081184,
    // XF86DVD = 0x10081185,
    // XF86MediaSelectDVD = 0x10081185,
    // XF86MediaSelectAuxiliary = 0x10081186,
    // XF86Audio = 0x10081188,
    // XF86ChannelUp = 0x10081192,
    // XF86ChannelDown = 0x10081193,
    // XF86MediaPlaySlow = 0x10081199,
    // XF86Break = 0x1008119b,
    // XF86NumberEntryMode = 0x1008119d,
    // XF86VideoPhone = 0x100811a0,
    // XF86ZoomReset = 0x100811a4,
    // XF86Editor = 0x100811a6,
    // XF86GraphicsEditor = 0x100811a8,
    // XF86Presentation = 0x100811a9,
    // XF86Database = 0x100811aa,
    // XF86Voicemail = 0x100811ac,
    // XF86Addressbook = 0x100811ad,
    // XF86DisplayToggle = 0x100811af,
    // XF86SpellCheck = 0x100811b0,
    // XF86ContextMenu = 0x100811b6,
    // XF86MediaRepeat = 0x100811b7,
    // XF8610ChannelsUp = 0x100811b8,
    // XF8610ChannelsDown = 0x100811b9,
    // XF86Images = 0x100811ba,
    // XF86NotificationCenter = 0x100811bc,
    // XF86PickupPhone = 0x100811bd,
    // XF86HangupPhone = 0x100811be,
    // XF86LinkPhone = 0x100811bf,
    // XF86Fn = 0x100811d0,
    // XF86Fn_Esc = 0x100811d1,
    // XF86Fn_F1 = 0x100811d2,
    // XF86Fn_F2 = 0x100811d3,
    // XF86Fn_F3 = 0x100811d4,
    // XF86Fn_F4 = 0x100811d5,
    // XF86Fn_F5 = 0x100811d6,
    // XF86Fn_F6 = 0x100811d7,
    // XF86Fn_F7 = 0x100811d8,
    // XF86Fn_F8 = 0x100811d9,
    // XF86Fn_F9 = 0x100811da,
    // XF86Fn_F10 = 0x100811db,
    // XF86Fn_F11 = 0x100811dc,
    // XF86Fn_F12 = 0x100811dd,
    // XF86Fn_1 = 0x100811de,
    // XF86Fn_2 = 0x100811df,
    // XF86Fn_D = 0x100811e0,
    // XF86Fn_E = 0x100811e1,
    // XF86Fn_F = 0x100811e2,
    // XF86Fn_S = 0x100811e3,
    // XF86Fn_B = 0x100811e4,
    // XF86FnRightShift = 0x100811e5,
    // XF86Numeric0 = 0x10081200,
    // XF86Numeric1 = 0x10081201,
    // XF86Numeric2 = 0x10081202,
    // XF86Numeric3 = 0x10081203,
    // XF86Numeric4 = 0x10081204,
    // XF86Numeric5 = 0x10081205,
    // XF86Numeric6 = 0x10081206,
    // XF86Numeric7 = 0x10081207,
    // XF86Numeric8 = 0x10081208,
    // XF86Numeric9 = 0x10081209,
    // XF86NumericStar = 0x1008120a,
    // XF86NumericPound = 0x1008120b,
    // XF86NumericA = 0x1008120c,
    // XF86NumericB = 0x1008120d,
    // XF86NumericC = 0x1008120e,
    // XF86NumericD = 0x1008120f,
    // XF86CameraFocus = 0x10081210,
    // XF86WPSButton = 0x10081211,
    // XF86CameraZoomIn = 0x10081215,
    // XF86CameraZoomOut = 0x10081216,
    // XF86CameraUp = 0x10081217,
    // XF86CameraDown = 0x10081218,
    // XF86CameraLeft = 0x10081219,
    // XF86CameraRight = 0x1008121a,
    // XF86AttendantOn = 0x1008121b,
    // XF86AttendantOff = 0x1008121c,
    // XF86AttendantToggle = 0x1008121d,
    // XF86LightsToggle = 0x1008121e,
    // XF86ALSToggle = 0x10081230,
    // XF86RefreshRateToggle = 0x10081232,
    // XF86Buttonconfig = 0x10081240,
    // XF86Taskmanager = 0x10081241,
    // XF86Journal = 0x10081242,
    // XF86ControlPanel = 0x10081243,
    // XF86AppSelect = 0x10081244,
    // XF86Screensaver = 0x10081245,
    // XF86VoiceCommand = 0x10081246,
    // XF86Assistant = 0x10081247,
    // XF86EmojiPicker = 0x10081249,
    // XF86Dictate = 0x1008124a,
    // XF86CameraAccessEnable = 0x1008124b,
    // XF86CameraAccessDisable = 0x1008124c,
    // XF86CameraAccessToggle = 0x1008124d,
    // XF86Accessibility = 0x1008124e,
    // XF86DoNotDisturb = 0x1008124f,
    // XF86BrightnessMin = 0x10081250,
    // XF86BrightnessMax = 0x10081251,
    // XF86ElectronicPrivacyScreenOn = 0x10081252,
    // XF86ElectronicPrivacyScreenOff = 0x10081253,
    // XF86KbdInputAssistPrev = 0x10081260,
    // XF86KbdInputAssistNext = 0x10081261,
    // XF86KbdInputAssistPrevgroup = 0x10081262,
    // XF86KbdInputAssistNextgroup = 0x10081263,
    // XF86KbdInputAssistAccept = 0x10081264,
    // XF86KbdInputAssistCancel = 0x10081265,
    // XF86RightUp = 0x10081266,
    // XF86RightDown = 0x10081267,
    // XF86LeftUp = 0x10081268,
    // XF86LeftDown = 0x10081269,
    // XF86RootMenu = 0x1008126a,
    // XF86MediaTopMenu = 0x1008126b,
    // XF86Numeric11 = 0x1008126c,
    // XF86Numeric12 = 0x1008126d,
    // XF86AudioDesc = 0x1008126e,
    // XF863DMode = 0x1008126f,
    // XF86NextFavorite = 0x10081270,
    // XF86StopRecord = 0x10081271,
    // XF86PauseRecord = 0x10081272,
    // XF86VOD = 0x10081273,
    // XF86Unmute = 0x10081274,
    // XF86FastReverse = 0x10081275,
    // XF86SlowReverse = 0x10081276,
    // XF86Data = 0x10081277,
    // XF86OnScreenKeyboard = 0x10081278,
    // XF86PrivacyScreenToggle = 0x10081279,
    // XF86SelectiveScreenshot = 0x1008127a,
    // XF86NextElement = 0x1008127b,
    // XF86PreviousElement = 0x1008127c,
    // XF86AutopilotEngageToggle = 0x1008127d,
    // XF86MarkWaypoint = 0x1008127e,
    // XF86Sos = 0x1008127f,
    // XF86NavChart = 0x10081280,
    // XF86FishingChart = 0x10081281,
    // XF86SingleRangeRadar = 0x10081282,
    // XF86DualRangeRadar = 0x10081283,
    // XF86RadarOverlay = 0x10081284,
    // XF86TraditionalSonar = 0x10081285,
    // XF86ClearvuSonar = 0x10081286,
    // XF86SidevuSonar = 0x10081287,
    // XF86NavInfo = 0x10081288,
    // XF86Macro1 = 0x10081290,
    // XF86Macro2 = 0x10081291,
    // XF86Macro3 = 0x10081292,
    // XF86Macro4 = 0x10081293,
    // XF86Macro5 = 0x10081294,
    // XF86Macro6 = 0x10081295,
    // XF86Macro7 = 0x10081296,
    // XF86Macro8 = 0x10081297,
    // XF86Macro9 = 0x10081298,
    // XF86Macro10 = 0x10081299,
    // XF86Macro11 = 0x1008129a,
    // XF86Macro12 = 0x1008129b,
    // XF86Macro13 = 0x1008129c,
    // XF86Macro14 = 0x1008129d,
    // XF86Macro15 = 0x1008129e,
    // XF86Macro16 = 0x1008129f,
    // XF86Macro17 = 0x100812a0,
    // XF86Macro18 = 0x100812a1,
    // XF86Macro19 = 0x100812a2,
    // XF86Macro20 = 0x100812a3,
    // XF86Macro21 = 0x100812a4,
    // XF86Macro22 = 0x100812a5,
    // XF86Macro23 = 0x100812a6,
    // XF86Macro24 = 0x100812a7,
    // XF86Macro25 = 0x100812a8,
    // XF86Macro26 = 0x100812a9,
    // XF86Macro27 = 0x100812aa,
    // XF86Macro28 = 0x100812ab,
    // XF86Macro29 = 0x100812ac,
    // XF86Macro30 = 0x100812ad,
    // XF86MacroRecordStart = 0x100812b0,
    // XF86MacroRecordStop = 0x100812b1,
    // XF86MacroPresetCycle = 0x100812b2,
    // XF86MacroPreset1 = 0x100812b3,
    // XF86MacroPreset2 = 0x100812b4,
    // XF86MacroPreset3 = 0x100812b5,
    // XF86KbdLcdMenu1 = 0x100812b8,
    // XF86KbdLcdMenu2 = 0x100812b9,
    // XF86KbdLcdMenu3 = 0x100812ba,
    // XF86KbdLcdMenu4 = 0x100812bb,
    // XF86KbdLcdMenu5 = 0x100812bc,
    // XF86PerformanceMode = 0x100812bd,
    // SunFA_Grave = 0x1005ff00,
    // SunFA_Circum = 0x1005ff01,
    // SunFA_Tilde = 0x1005ff02,
    // SunFA_Acute = 0x1005ff03,
    // SunFA_Diaeresis = 0x1005ff04,
    // SunFA_Cedilla = 0x1005ff05,
    // SunF36 = 0x1005ff10,
    // SunF37 = 0x1005ff11,
    // SunSys_Req = 0x1005ff60,
    // SunPrint_Screen = 0x0000ff61,
    // SunCompose = 0x0000ff20,
    // SunAltGraph = 0x0000ff7e,
    // SunPageUp = 0x0000ff55,
    // SunPageDown = 0x0000ff56,
    // SunUndo = 0x0000ff65,
    // SunAgain = 0x0000ff66,
    // SunFind = 0x0000ff68,
    // SunStop = 0x0000ff69,
    // SunProps = 0x1005ff70,
    // SunFront = 0x1005ff71,
    // SunCopy = 0x1005ff72,
    // SunOpen = 0x1005ff73,
    // SunPaste = 0x1005ff74,
    // SunCut = 0x1005ff75,
    // SunPowerSwitch = 0x1005ff76,
    // SunAudioLowerVolume = 0x1005ff77,
    // SunAudioMute = 0x1005ff78,
    // SunAudioRaiseVolume = 0x1005ff79,
    // SunVideoDegauss = 0x1005ff7a,
    // SunVideoLowerBrightness = 0x1005ff7b,
    // SunVideoRaiseBrightness = 0x1005ff7c,
    // SunPowerSwitchShift = 0x1005ff7d,
    // Dring_accent = 0x1000feb0,
    // Dcircumflex_accent = 0x1000fe5e,
    // Dcedilla_accent = 0x1000fe2c,
    // Dacute_accent = 0x1000fe27,
    // Dgrave_accent = 0x1000fe60,
    // Dtilde = 0x1000fe7e,
    // Ddiaeresis = 0x1000fe22,
    // DRemove = 0x1000ff00,
    // hpClearLine = 0x1000ff6f,
    // hpInsertLine = 0x1000ff70,
    // hpDeleteLine = 0x1000ff71,
    // hpInsertChar = 0x1000ff72,
    // hpDeleteChar = 0x1000ff73,
    // hpBackTab = 0x1000ff74,
    // hpKP_BackTab = 0x1000ff75,
    // hpModelock1 = 0x1000ff48,
    // hpModelock2 = 0x1000ff49,
    // hpReset = 0x1000ff6c,
    // hpSystem = 0x1000ff6d,
    // hpUser = 0x1000ff6e,
    // hpmute_acute = 0x100000a8,
    // hpmute_grave = 0x100000a9,
    // hpmute_asciicircum = 0x100000aa,
    // hpmute_diaeresis = 0x100000ab,
    // hpmute_asciitilde = 0x100000ac,
    // hplira = 0x100000af,
    // hpguilder = 0x100000be,
    // hpYdiaeresis = 0x100000ee,
    // hpIO = 0x100000ee,
    // hplongminus = 0x100000f6,
    // hpblock = 0x100000fc,
    // osfCopy = 0x1004ff02,
    // osfCut = 0x1004ff03,
    // osfPaste = 0x1004ff04,
    // osfBackTab = 0x1004ff07,
    // osfBackSpace = 0x1004ff08,
    // osfClear = 0x1004ff0b,
    // osfEscape = 0x1004ff1b,
    // osfAddMode = 0x1004ff31,
    // osfPrimaryPaste = 0x1004ff32,
    // osfQuickPaste = 0x1004ff33,
    // osfPageLeft = 0x1004ff40,
    // osfPageUp = 0x1004ff41,
    // osfPageDown = 0x1004ff42,
    // osfPageRight = 0x1004ff43,
    // osfActivate = 0x1004ff44,
    // osfMenuBar = 0x1004ff45,
    // osfLeft = 0x1004ff51,
    // osfUp = 0x1004ff52,
    // osfRight = 0x1004ff53,
    // osfDown = 0x1004ff54,
    // osfEndLine = 0x1004ff57,
    // osfBeginLine = 0x1004ff58,
    // osfEndData = 0x1004ff59,
    // osfBeginData = 0x1004ff5a,
    // osfPrevMenu = 0x1004ff5b,
    // osfNextMenu = 0x1004ff5c,
    // osfPrevField = 0x1004ff5d,
    // osfNextField = 0x1004ff5e,
    // osfSelect = 0x1004ff60,
    // osfInsert = 0x1004ff63,
    // osfUndo = 0x1004ff65,
    // osfMenu = 0x1004ff67,
    // osfCancel = 0x1004ff69,
    // osfHelp = 0x1004ff6a,
    // osfSelectAll = 0x1004ff71,
    // osfDeselectAll = 0x1004ff72,
    // osfReselect = 0x1004ff73,
    // osfExtend = 0x1004ff74,
    // osfRestore = 0x1004ff78,
    // osfDelete = 0x1004ffff,
    // Reset = 0x1000ff6c,
    // System = 0x1000ff6d,
    // User = 0x1000ff6e,
    // ClearLine = 0x1000ff6f,
    // InsertLine = 0x1000ff70,
    // DeleteLine = 0x1000ff71,
    // InsertChar = 0x1000ff72,
    // DeleteChar = 0x1000ff73,
    // BackTab = 0x1000ff74,
    // KP_BackTab = 0x1000ff75,
    // Ext16bit_L = 0x1000ff76,
    // Ext16bit_R = 0x1000ff77,
    // mute_acute = 0x100000a8,
    // mute_grave = 0x100000a9,
    // mute_asciicircum = 0x100000aa,
    // mute_diaeresis = 0x100000ab,
    // mute_asciitilde = 0x100000ac,
    // lira = 0x100000af,
    // guilder = 0x100000be,
    // IO = 0x100000ee,
    // longminus = 0x100000f6,
    // block = 0x100000fc,
    _,

    pub const Henkan_Mode: KeySym = @enumFromInt(0xff23);
    pub fn toInt(kc: KeySym) u32 {
      return @intFromEnum(kc);
    }
    pub fn fromInt(n: u32) KeySym {
      return @enumFromInt(n);
    }
  };

  pub const Keycode = enum(u32) {
    _,

    pub fn toInt(kc: Keycode) u32 {
      return @intFromEnum(kc);
    }
    pub fn fromInt(n: u32) Keycode {
      return @enumFromInt(n);
    }
  };

  pub const KeymapCompileFormat = enum(c_int) {
    text_v1 = 1,
    text_v2 = 2,
  };

  pub const LogLevel = enum (u32) {
    critical = 10,
    @"error" = 20,
    warning = 30,
    info = 40,
    debug = 50,
  };

  pub const ContextFlags = packed struct(u32) {
    no_default_includes: bool = false,
    no_environment_names: bool = false,
    no_secure_getenv: bool = false,
    __reserved_bits: u29 = 0,
  };

  pub const KeymapCompileFlags = enum(c_int) {
    none = 0,
  };

  pub const KeysymFlags = packed struct (u32) {
    case_insensitive: bool = false,
    __reserved_bits: u31 = 0,
  };

  pub const Context = opaque {};
  pub const State = opaque {};
  pub const Keymap = opaque {};
};

const wl_protocols = @import("wayland-protocols");
const log = std.log.scoped(.wayland);


const Arena = base.Arena;
const Thread = base.Thread;
const RingBuffer = base.RingBuffer;

const VkContext = platform.VkContext;
const Drm = gfx.Drm;

const gfx = platform.gfx;

const platform = @import("platform.zig");

const u16_ = base.u16_;
const u32_ = base.u32_;
const i32_ = base.i32_;
const u64_ = base.u64_;
const f32_ = base.f32_;

const cast = base.casts.cast;
const transmute = base.casts.transmute;

const time = base.time;
const math = base.math;

const linux = os.linux;
const posix = os.posix;

const os = @import("os");
const base = @import("base");

const vk = @import("vulkan");
const std = @import("std");
