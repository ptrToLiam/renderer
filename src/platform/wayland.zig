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
      __reserved_bits: u3 = 0,

      pub fn match(a: @This(), b: @This()) bool {
        return transmute(u8, a) == transmute(u8, b);
      }

      pub const desired: @This() = .{
        .wl_seat = true,
        .wl_compositor = true,
        .xdg_wm_base = true,
        .linux_dmabuf = true,
        // .wl_shm = true,
      };
    };

    var globals_bound: GlobalsBound = .{};
    // Loop until all desired globals are bound OR no more globals are available
    while (true) {
      const event = connection.peek_event(scratch_arena) orelse { connection.load_events(); continue; };
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
          }
          // else if (std.mem.eql(u8, Shm.Name, registry_global.interface)) {
          //   connection.client_state.wl_shm = connection.client_state.registry.bind(
          //     &conn_proxy,
          //     registry_global.name,
          //     Shm,
          //     registry_global.version
          //   );
          //   globals_bound.wl_shm = true;
          // }
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

    if (globals_bound.match(.desired))
      log.info("succesfully bound desired globals!", .{})
    else
      log.info("failed to bind all desired globals!", .{});

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
          log.debug(
            "setting wl_seat_capabilities :: {{ pointer: {s}, touch: {s}, keyboard: {s} }}",
            .{
              if (seat_capabilities.pointer) "true" else "false",
              if (seat_capabilities.touch) "true" else "false",
              if (seat_capabilities.keyboard) "true" else "false",
            },
          );
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
        .wl_shm_format => |fmt_event| {
          _ = fmt_event;
        },
        .wl_buffer_release => {
          const swapchain_image_release_event = arena.create(platform.Event);
          swapchain_image_release_event.* = .{
            .timestamp_us = time.us(),
            .type = .buffer_release,
            .surface_handle = surface.*,
          };
          event_list.push(swapchain_image_release_event);
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
          event_list.push(close_event);
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

    wl_surface.commit(&conn_proxy);

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
        },
        .wl_seat_name => |wl_seat_name| {
          const seat_name = wl_seat_name.name;
          @memcpy(
            conn.client_state.seat_info.name[0..seat_name.len],
            seat_name,
          );
          conn.client_state.seat_info.name[seat_name.len] = 0;
        },
        // .zwp_linux_dmabuf_v1_format => |fmt| {
        //   log.debug("supported surface format :: 0x{x}", .{fmt.format});
        // },
        // .zwp_linux_dmabuf_v1_modifier => |mod| {
        //   log.debug("supported surface modifier :: {{ format = 0x{x}}}", .{mod.format});
        // },
        .zwp_linux_dmabuf_feedback_v1_done => {
          // log.info("dmabuf feedback done", .{});
          feedback_done = true;
        },
        .zwp_linux_dmabuf_feedback_v1_format_table => |format_table| {
          dmabuf_feedback.fmt_table = format_table;
          // log.info(
          //   "dmabuf feedback format table received :: {{ fd={}, size={} }}",
          //   .{ format_table.fd, format_table.size },
          // );
        },
        .zwp_linux_dmabuf_feedback_v1_main_device => |main_device| {
          dmabuf_feedback.main_device = std.mem.bytesToValue(
            linux.dev_t,
            main_device.device
          );
          // log.info(
          //   "dmabuf feedback main device: 0x{x}",
          //   .{ dmabuf_feedback.main_device.toInt() },
          // );
        },
        .zwp_linux_dmabuf_feedback_v1_tranche_done => {
          // log.info("dmabuf feedback tranche done", .{});
          ignore_tranche = false;
        },
        .zwp_linux_dmabuf_feedback_v1_tranche_target_device => |target| {
          const tranche_target_device = std.mem.bytesToValue(
            linux.dev_t,
            target.device,
          );
          if (tranche_target_device != dmabuf_feedback.main_device)
            ignore_tranche = true;
            // log.info(
            //   "dmabuf feedback tranche target device: 0x{x}",
            //   .{ tranche_target_device.toInt() },
            // );
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
        // .zwp_linux_dmabuf_feedback_v1_tranche_flags => |tranche_flags| {
        //   log.info("dmabuf feedback tranche flags :: {}", .{ tranche_flags.flags });
        // },
        else => {
          // log.debug(
          //   "SURFACE CREATION RECEIVED UNEXPECTED EVENT :: {}",
          //   .{ wl_event },
          // );
        },
      } else conn.load_events();
    }

    return .{
      .connection = conn,
      .wl_surface = wl_surface,
      .xdg_surface = xdg_surface,
      .xdg_toplevel = xdg_toplevel,
      .is_ready = false,
    };
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

    if (candidate.pdev != .null_handle)
      log.info("Selected GPU :: {s}", .{ candidate.props.device_name });

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
    const read = conn.in.mask(conn.in.read);
    const write = conn.in.mask(conn.in.write);

    //-------------------------------------------------------------------------
    // Prepare IOV Buffer(s) For Read
    //-------------------------------------------------------------------------

    var iov: [2]linux.iovec = undefined;
    var iov_len: usize = 1;
    if (write < read) {
      const iov_buf = conn.in.buf[write..read];
      iov[0].base = iov_buf.ptr;
      iov[0].len = iov_buf.len;
    } else if (write == 0) {
      const iov_buf = conn.in.buf[write..];
      iov[0].base = iov_buf.ptr;
      iov[0].len = iov_buf.len;
    } else {
      const iov_buf_0 = conn.in.buf[write..];
      iov[0].base = iov_buf_0.ptr;
      iov[0].len = iov_buf_0.len;
      const iov_buf_1 = conn.in.buf[0..read];
      iov[1].base = iov_buf_1.ptr;
      iov[1].len = iov_buf_1.len;
      iov_len = 2;
    }

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
        conn.fd_in.put(std.mem.asBytes(&fd));
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
      var header_bytes = std.mem.asBytes(&header);
      const header_read_idx = conn.in.mask(conn.in.read);
      const header_contiguous_bytes = conn.in.buf[header_read_idx..];

      // Current header bytes wrap around to start of buffer
      if (header_bytes.len > header_contiguous_bytes.len) {
        const remainder = header_bytes.len - header_contiguous_bytes.len;

        // copy contiguous bytes
        @memcpy(
          header_bytes[0..header_contiguous_bytes.len],
          header_contiguous_bytes,
        );

        // copy remaining bytes
        @memcpy(
          header_bytes[header_contiguous_bytes.len..],
          conn.in.buf[0..remainder],
        );
      } else {
        @memcpy(
          header_bytes,
          header_contiguous_bytes[0..header_bytes.len],
        );
      }

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
      const data_contiguous_bytes = conn.in.buf[data_read_idx..];

      defer conn.in.read -%= u32_(@sizeOf(WireEventHeader));

      const scratch = Thread.Context.get_scratch(1, .{arena}).?;

      const scratch_arena = scratch.arena;
      defer scratch.end();

      var data_bytes = scratch_arena.push(u8, data_len);

      // Current data bytes wrap around to start of buffer
      if (data_len > data_contiguous_bytes.len) {
        const remainder = data_len - data_contiguous_bytes.len;
        @memcpy(
          data_bytes[0..data_contiguous_bytes.len],
          data_contiguous_bytes,
        );
        @memcpy(
          data_bytes[data_contiguous_bytes.len..],
          conn.in.buf[0..remainder],
        );
      } else {
        @memcpy(
          data_bytes,
          data_contiguous_bytes[0..data_bytes.len]
        );
      }

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
     var header_bytes = std.mem.asBytes(&header);
     const header_read_idx = conn.in.mask(conn.in.read);
     const header_contiguous_bytes = conn.in.buf[header_read_idx..];

     // Current header bytes wrap around to start of buffer
     if (header_bytes.len > header_contiguous_bytes.len) {
       const remainder = header_bytes.len - header_contiguous_bytes.len;

       // copy contiguous bytes
       @memcpy(
         header_bytes[0..header_contiguous_bytes.len],
         header_contiguous_bytes,
       );

       // copy remaining bytes
       @memcpy(
         header_bytes[header_contiguous_bytes.len..],
         conn.in.buf[0..remainder],
       );
     } else {
       @memcpy(
         header_bytes,
         header_contiguous_bytes[0..header_bytes.len],
       );
     }
     conn.in.read +%= header.len;
  }

  pub fn flush(conn: *Connection) !void {
    const out_read_start = conn.out.read;
    const out_read = conn.out.mask(conn.out.read);
    const out_write = conn.out.mask(conn.out.write);

    //-------------------------------------------------------------------------
    // Prepare outgoing iovecs
    //-------------------------------------------------------------------------

    var iov: [2]linux.iovec = undefined;
    var iov_len: usize = 1;

    if (conn.out.read == conn.out.write) {
      iov_len = 0;
    } else if (out_read < out_write) {
      const iov_buf = conn.out.buf[out_read..out_write];
      iov[0].base = iov_buf.ptr;
      iov[0].len = iov_buf.len;
      conn.out.read +%= u32_(iov_buf.len);
    } else if (out_write == 0) {
      const iov_buf = conn.out.buf[out_read..];
      iov[0].base = iov_buf.ptr;
      iov[0].len = iov_buf.len;
      conn.out.read +%= u32_(iov_buf.len);
    } else {
      const iov_buf_0 = conn.out.buf[out_read..];
      iov[0].base = iov_buf_0.ptr;
      iov[0].len = iov_buf_0.len;

      const iov_buf_1 = conn.out.buf[0..out_write];
      iov[1].base = iov_buf_1.ptr;
      iov[1].len = iov_buf_1.len;
      iov_len = 2;

      conn.out.read +%= u32_(iov_buf_0.len + iov_buf_1.len);
    }

    const bytes_to_write = conn.out.read - out_read_start;

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
      const contiguous_bytes = conn.fd_out.buf[fd_out_read..];

      var fd_out: c_int = -1;
      var fd_out_bytes = std.mem.asBytes(&fd_out);

      @memcpy(
        fd_out_bytes[0..][0..c_int_size],
        contiguous_bytes[0..c_int_size],
      );

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
    var rc: isize = -1;
    var errno: linux.E = .AGAIN;
    read: while (rc < 0 and (errno == .AGAIN or errno == .INTR)) {
      const val = linux.sendmsg(
        conn.fd,
        &msg,
        0,
      );

      rc = transmute(isize, val);

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
    connection.out.put(std.mem.asBytes(&header));

    for (args) |arg_opt| {
      if (arg_opt) |arg| arg: switch (arg) {
        .uint, .new_id, .object => |uint_arg| {
          connection.out.put(std.mem.asBytes(&uint_arg));
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

          connection.out.put(std.mem.asBytes(&len));
          connection.out.put(array_arg);
          connection.out.put(padding_bytes[0..padding_bytes_needed]);
        },
        .fd => |fd_arg| {
          connection.fd_out.put(std.mem.asBytes(&fd_arg));
        },
      } else {
        const null_value: u32 = 0;
        connection.out.put(std.mem.asBytes(&null_value));
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
    // - Add something in here for viewport management

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
  // wl_shm: Shm,
  compositor: Compositor,
  xdg_wm_base: XdgWmBase,
  linux_dmabuf: LinuxDmabuf,

  // Wayland Objects
  object_pool: ObjectPool,

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

pub const WaylandBuffer = wl_protocols.wl_buffer;
pub const WaylandSurface = wl_protocols.wl_surface;
pub const XdgSurface = wl_protocols.xdg_surface;
pub const XdgToplevel = wl_protocols.xdg_toplevel;
pub const WaylandShmPool = wl_protocols.wl_shm_pool;

pub const Shm = wl_protocols.wl_shm;
pub const Seat = wl_protocols.wl_seat;
pub const Display = wl_protocols.wl_display;
pub const Registry = wl_protocols.wl_registry;
pub const Compositor = wl_protocols.wl_compositor;

pub const XdgWmBase = wl_protocols.xdg_wm_base;

pub const LinuxDmabuf = wl_protocols.zwp_linux_dmabuf_v1;
pub const LinuxDmabufFeedback = wl_protocols.zwp_linux_dmabuf_feedback_v1;

const Arena = base.Arena;
const Thread = base.Thread;
const RingBuffer = base.RingBuffer;

pub const Proxy = wl_protocols.Proxy;
pub const Object = wl_protocols.Object;
pub const Event = wl_protocols.Event;
pub const MessageArg = wl_protocols.MessageArg;

const log = std.log.scoped(.wayland);


const VkContext = platform.VkContext;
const Drm = gfx.Drm;

const gfx = platform.gfx;

const wl_protocols = @import("wayland-protocols");
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
