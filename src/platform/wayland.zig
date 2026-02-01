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

  pub fn open(arena: *Arena, env: os.Environ) Connection {
    //-------------------------------------------------------------------------
    // Allocate & Initialize Ring Buffers
    //-------------------------------------------------------------------------

    // 4 * 2048 = 2 pages of 4KB Virtual Memory
    var ring_buffers: [4]RingBuffer = undefined;
    const ring_buffer_bytes = os.mem_reserve(4 * ring_buffer_size);

    if (!os.mem_commit(ring_buffer_bytes))
      @panic("Failed to map pages for ring buffers!");

    inline for (0..4) |i| {
      const backing_bytes_rng_start = (i * ring_buffer_size);
      const backing_bytes =
        ring_buffer_bytes[backing_bytes_rng_start..][0..ring_buffer_size];

      ring_buffers[i] = .init_backing(backing_bytes);
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

    const socket_fd = base.i32_(linux.socket(
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

    posix.connect(
      socket_fd,
      @ptrCast(&socket_addr),
      @intCast(@sizeOf(@TypeOf(socket_addr))),
    ) catch {
      @panic("Failed to connect to wayland socket :: ");
    };

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
      .in = ring_buffers[0],
      .out = ring_buffers[1],
      .fd_in = ring_buffers[2],
      .fd_out = ring_buffers[3],

      // Wayland State Management
      .client_state = client_state,
    };
    var conn_proxy = connection.proxy();

    client_state.display = .fromInt(client_state.object_pool.next_object_id());
    client_state.object_pool.push_object(client_state.display.object());
    client_state.registry = client_state.display.get_registry(&conn_proxy) catch {
      @panic("Call to get_registry failed!");
    };

    // TODO:
    // - Implement Wayland RingBuffer flush
    // - Bind Globals
    connection.flush() catch @panic("failed to write to wayland socket");

    const GlobalsBound = packed struct (u8) {
      wl_seat: bool = false,
      wl_compositor: bool = false,
      xdg_wm_base: bool = false,
      linux_dmabuf: bool = false,
      __reserved_bits: u4 = 0,

      pub fn match(a: @This(), b: @This()) bool {
        return @as(u8, @bitCast(a)) == @as(u8, @bitCast(b));
      }

      pub const all_bound: @This() = .{
        .wl_seat = true,
        .wl_compositor = true,
        .xdg_wm_base = true,
        .linux_dmabuf = true,
      };
    };

    var globals_bound: GlobalsBound = .{};
    // Loop until all desired globals are bound OR no more globals are available
    while (globals_bound.match(.all_bound)) {
      const event = connection.peek_event(scratch_arena) orelse { connection.load_events(); log.info("gotta load anew", .{}); continue; };
      switch (event) {
        .wl_registry => |registry_event| switch (registry_event) {
          .global => |registry_global| {
            if (std.mem.eql(u8, Seat.InterfaceName, registry_global.interface)) {
              connection.client_state.seat = connection.client_state.registry.bind(
                &conn_proxy,
                Seat,
                .{ .name = registry_global.name, .interface_version = registry_global.version }
              ) catch unreachable;
              globals_bound.wl_seat = true;
            } else if (std.mem.eql(u8, Compositor.InterfaceName, registry_global.interface)) {
              connection.client_state.compositor = connection.client_state.registry.bind(
                &conn_proxy,
                Compositor,
                .{ .name = registry_global.name, .interface_version = registry_global.version }
              ) catch unreachable;
              globals_bound.wl_compositor = true;
            } else if (std.mem.eql(u8, XdgWmBase.InterfaceName, registry_global.interface)) {
              connection.client_state.xdg_wm_base = connection.client_state.registry.bind(
                &conn_proxy,
                XdgWmBase,
                .{ .name = registry_global.name, .interface_version = registry_global.version }
              ) catch unreachable;
              globals_bound.xdg_wm_base = true;
            } else if (std.mem.eql(u8, LinuxDmabuf.InterfaceName, registry_global.interface)) {
              connection.client_state.linux_dmabuf = connection.client_state.registry.bind(
                &conn_proxy,
                LinuxDmabuf,
                .{ .name = registry_global.name, .interface_version = registry_global.version }
              ) catch unreachable;
              globals_bound.linux_dmabuf = true;
            }
            // log.info(
            //   "registry_global :: {{ .name={}, .interface={s}, .version={} }}",
            //   .{ registry_global.name, registry_global.interface, registry_global.version },
            // );
            // conn.consume_event()
          },
          .global_remove => |registry_global_remove| {
            _ = registry_global_remove;
          },
        },
        .wl_display => |display_event| switch (display_event) {
          .@"error" => |display_error| {
            log.err(
              "display error :: {{ obj_id={}, code={}, message=\"{s}\" }}",
              .{ display_error.object_id, display_error.code, display_error.message },
            );
          },
          .delete_id => |delete_id| {
            log.debug("display requested delete_id :: {{ id={} }} ", .{delete_id.id});
          },
        },
        else => { break; },
      }
    }
    // log.info("succesfully bound desired globals!", .{});

    //-------------------------------------------------------------------------

    return connection;
  }

  pub fn close(conn: *Connection) void {
    //-------------------------------------------------------------------------
    //  Retrieve & Free Ring Buffer Backing Pages
    //-------------------------------------------------------------------------

    const ring_buffer_bytes_len = 4 * ring_buffer_size;
    const ring_buffer_bytes: []align(os.page_size_min) u8 =
      @alignCast(@ptrCast(conn.in.buf.ptr[0..ring_buffer_bytes_len]));

    os.mem_release(ring_buffer_bytes);
    posix.close(conn.fd);

    //-------------------------------------------------------------------------
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

    var cmsg_buf: [cmsg_buf_len]u8 = undefined;
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
    const bytes_read = if (@as(isize, @bitCast(rc)) < 0)
      switch (err) {
        .SUCCESS => return,
        .AGAIN => return,
        .INVAL => { log.err("EINVAL on socket read!", .{}); return; },
        .PIPE, .CONNRESET => @panic("Socket connection lost!"),
        else => |e| {log.err("socket read failed with err :: {s}", .{@tagName(e)}); @panic("unknown err"); },
      }
    else
      base.u32_(rc);

    // log.debug("read {} bytes from socket!", .{ bytes_read });
    defer conn.in.write +%= bytes_read;

    //-------------------------------------------------------------------------

    //-------------------------------------------------------------------------
    // Parse Control Messages
    //-------------------------------------------------------------------------

    var cmsg_iter = linux.cmsghdr.iter(cmsg_buf[0..msg.controllen]);
    while (cmsg_iter.next()) |cmsg_header| {
      if (cmsg_header.type == linux.SOL.SOCKET and cmsg_header.level == linux.SCM_RIGHTS) {
        conn.fd_in.put(std.mem.asBytes(cmsg_header.data(i32)));
      }
    }

    //-------------------------------------------------------------------------
  }

  pub fn peek_event(conn: *Connection, arena: *Arena) ?wl_protocols.Event {
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
      conn.in.read +%= base.u32_(@sizeOf(WireEventHeader));

      const data_len = header.len - @sizeOf(WireEventHeader);
      const data_read_idx = conn.in.mask(conn.in.read);
      const data_contiguous_bytes = conn.in.buf[data_read_idx..];

      defer conn.in.read +%= base.u32_(data_len);

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

      const wayland_event = conn.client_state.object_pool
        .get(header.id)
        .parse_msg(
          &conn_proxy,
          header.op,
          data_bytes,
        ) catch unreachable;

      break :wayland_event wayland_event;
    } else null;

    return event;
  }

  pub fn get_events(conn: *Connection, arena: *Arena) platform.EventList {
    var conn_proxy = conn.proxy();
    var event_list: platform.EventList = .empty;
    conn.load_events();

    while (conn.peek_event(arena)) |wayland_event| {
      _ = &conn_proxy;
      _ = wayland_event;
      _ = &event_list;
    }
    return event_list;
  }

  pub fn acquire_surface(
    conn: *Connection,
    arena: *Arena,
    title: [:0]const u8,
    class: [:0]const u8,
    width: i32,
    height: i32,
  ) platform.Surface {
    _ = arena;

    var conn_proxy = conn.proxy();
    const wl_surface = conn.client_state.compositor.create_surface(
      &conn_proxy,
    ) catch unreachable;
    const xdg_surface = conn.client_state.xdg_wm_base.get_xdg_surface(
      &conn_proxy,
      .{ .surface = wl_surface },
    ) catch unreachable;
    const xdg_toplevel = xdg_surface.get_toplevel(&conn_proxy) catch unreachable;

    xdg_toplevel.set_title(&conn_proxy, .{ .title = title }) catch unreachable;
    xdg_toplevel.set_app_id(&conn_proxy, .{ .app_id = class }) catch unreachable;

    wl_surface.commit(&conn_proxy) catch unreachable;

    conn.flush() catch unreachable;
    return .{
      .handle = .{
        .wl_surface = wl_surface,
        .xdg_surface = xdg_surface,
        .xdg_toplevel = xdg_toplevel,
      },
      .dimensions = .{
        .x = width,
        .y = height,
      },
    };
  }

  pub fn flush(conn: *Connection) wl_protocols.WriteError!void {
    const out_read = conn.out.mask(conn.out.read);
    const out_write = conn.out.mask(conn.out.write);

    //-------------------------------------------------------------------------
    // Prepare outgoing iovecs
    //-------------------------------------------------------------------------

    var iov: [2]linux.iovec = undefined;
    var iov_len: usize = 1;

    if (out_read < out_write) {
      const iov_buf = conn.out.buf[out_read..out_write];
      iov[0].base = iov_buf.ptr;
      iov[0].len = iov_buf.len;
      conn.out.read +%= base.u32_(iov_buf.len);
    } else if (out_read == 0) {
      const iov_buf = conn.out.buf[out_read..];
      iov[0].base = iov_buf.ptr;
      iov[0].len = iov_buf.len;
      conn.out.read +%= base.u32_(iov_buf.len);
    } else {
      const iov_buf_0 = conn.out.buf[out_read..];
      iov[0].base = iov_buf_0.ptr;
      iov[0].len = iov_buf_0.len;

      const iov_buf_1 = conn.out.buf[0..out_write];
      iov[1].base = iov_buf_1.ptr;
      iov[1].len = iov_buf_1.len;
      iov_len = 2;

      conn.out.read +%= base.u32_(iov_buf_0.len + iov_buf_1.len);
    }

    //-------------------------------------------------------------------------

    //-------------------------------------------------------------------------
    // Prepare outgoing control messages
    //-------------------------------------------------------------------------

    var cmsg: [cmsg_buf_len]u8 = undefined;
    var cmsg_len: usize = 0;

    while (!conn.fd_out.empty()) {
      const fd_out_read = conn.fd_out.mask(conn.fd_out.read);
      const contiguous_bytes = conn.fd_out.buf[fd_out_read..];

      var control_msg: linux.cmsg(i32) = .init(
        posix.SOL.SOCKET,
        linux.SCM_RIGHTS,
        -1,
      );
      var control_msg_data_bytes = std.mem.asBytes(&control_msg.data);
      if (contiguous_bytes.len < @sizeOf(i32)) {
        @branchHint(.cold);
        const remainder = @sizeOf(i32) - contiguous_bytes.len;
        @memcpy(
          control_msg_data_bytes[0..contiguous_bytes.len],
          contiguous_bytes[0..],
        );
        @memcpy(
          control_msg_data_bytes[contiguous_bytes.len..],
          conn.fd_out.buf[0..remainder],
        );
      } else {
        @memcpy(
          control_msg_data_bytes[cmsg_len..][0..@sizeOf(i32)],
          contiguous_bytes[fd_out_read..][0..@sizeOf(i32)],
        );
      }

      @memcpy(
        cmsg[cmsg_len..][0..@sizeOf(@TypeOf(control_msg))],
        std.mem.asBytes(&control_msg),
      );

      conn.fd_out.read +%= base.u32_(@sizeOf(i32));
      cmsg_len += @sizeOf(@TypeOf(control_msg));
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

      _ = linux.sendmsg(
      conn.fd,
      &msg,
      0,
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
        .msg_parse_fn = msg_parse,
        .msg_write_fn = msg_write,
        .next_id_fn = next_id,
        .obj_push_fn = obj_push,
        .obj_destroy_fn = obj_destroy,
      },
    };
  }

  fn msg_parse(noalias ctx: *anyopaque, args_out: []MessageArg, data: []const u8) !void {
    const connection: *Connection = @ptrCast(@alignCast(ctx));
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
          const int_ptr: *u32 = @ptrCast(enum_arg);
          int_ptr.* = std.mem.bytesToValue(u32, data[offset..][0..4]);
          offset += 4;
        },
        .fixed => |*fixed_arg| {
          const int_val = std.mem.bytesToValue(i32, data[offset..][0..4]);
          offset += 4;
          fixed_arg.* = @as(f32, @floatFromInt(int_val)) / 256;
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

  fn msg_write(noalias ctx: *anyopaque, id: u32, op: u16, noalias args: []const ?MessageArg) wl_protocols.WriteError!void {
    const connection: *Connection = @ptrCast(@alignCast(ctx));
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
      log.debug("out.size < msg_len, flushing", .{});
      connection.flush() catch |err| {
        log.err("Connection flush failed due to err :: {s}", .{@errorName(err)});
        return wl_protocols.WriteError.WriteFailed;
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
          continue :arg .{ .uint = @bitCast(int_arg) };
        },
        .@"enum" => |*enum_arg| {
          const u32_val: *const u32 = @ptrCast(enum_arg);
          continue :arg .{ .uint = u32_val.* };
        },
        .fixed => |float_arg| {
          const val: i32 = @intFromFloat(float_arg * 256);
          continue :arg .{ .uint = @bitCast(val) };
        },
        .string => |string_arg| {
          continue :arg .{ .array = string_arg[0 .. string_arg.len + 1] };
        },
        .array => |array_arg| {
          const padding_bytes: [4]u8 = @splat(0);

          const write_len: u32 = @intCast(msg_arr_len(array_arg));
          const len: u32 = @intCast(array_arg.len);
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
    const conn: *Connection = @alignCast(@ptrCast(ctx));
    const idx = conn.client_state.object_pool.next_object_id();
    return idx;
  }

  fn next_fd(conn: *Connection) i32 {
    // TODO
    var fd: i32 = -1;
    _ = &fd;
    const read = conn.fd_in.mask(conn.fd_in.read);
    _ = read;

    return fd;
  }

  fn obj_destroy(noalias ctx: *anyopaque, object_id: u32) void {
    const conn: *Connection = @alignCast(@ptrCast(ctx));
    conn.client_state.object_pool.release_object(object_id);
  }

  fn obj_push(noalias ctx: *anyopaque, object: Object) void {
    const conn: *Connection = @alignCast(@ptrCast(ctx));
    conn.client_state.object_pool.push_object(object);
  }

  inline fn msg_str_len(str: [:0]const u8) u16 {
    return msg_arr_len(str[0 .. str.len + 1]);
  }

  inline fn msg_arr_len(arr: []const u8) u16 {
    return @intCast(math.div_roundup(@sizeOf(u32) + arr.len, @sizeOf(u32)));
  }

  const cmsg_buf_len = 32 * linux.cmsghdr.msg_len(@sizeOf(i32));
  const ring_buffer_size: usize = default_ring_buffer_size;
  const default_ring_buffer_size = 2048;
};

pub const Surface = struct {
  wl_surface: Wayland.Surface,
  xdg_surface: XdgShell.Surface,
  xdg_toplevel: XdgShell.Toplevel,

  pub const nil: Surface = .{
    .wl_surface = 0,
    .toplevel = .fromInt(0),
  };
};

pub const ClientState = struct {
  // Base Wayland Connection Management
  display: Display,
  registry: Registry,

  // Globals
  seat: Seat,
  compositor: Compositor,
  xdg_wm_base: XdgWmBase,
  linux_dmabuf: LinuxDmabuf,

  // Objects
  object_pool: ObjectPool,
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
    const idx: *const u32 = @alignCast(@ptrCast(object.ptr));

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
      index.* = base.u32_(buf.len - i);
    }

    return .{
      .indices = buf,
      .index_available = base.u32_(buf.len),
    };
  }

  pub fn peek(fil: *FreeIdxList) u32 {
    return fil.indices[fil.index_available-1];
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

const WireEventHeader = packed struct {
  id: u32,
  op: u16,
  len: u16,
};

pub const Seat = Wayland.Seat;
pub const Display = Wayland.Display;
pub const Registry = Wayland.Registry;
pub const Compositor = Wayland.Compositor;

pub const XdgWmBase = XdgShell.WmBase;

pub const LinuxDmabuf = LinuxDmabufV1.LinuxDmabufV1;

const log = std.log.scoped(.wayland);
const Arena = base.Arena;
const Thread = base.Thread;
const RingBuffer = base.RingBuffer;

const linux = os.linux;
const posix = os.posix;

const Wayland = wl_protocols.Wayland;
const XdgShell = wl_protocols.XdgShell;
const LinuxDmabufV1 = wl_protocols.LinuxDmabufV1;
const XdgDecoration = wl_protocols.XdgDecorationUnstableV1;

const Proxy = wl_protocols.Proxy;
const Object = wl_protocols.Object;
const MessageArg = wl_protocols.MessageArg;

const wl_protocols = @import("wayland_protocols.zig");
const platform = @import("platform.zig");

const math = base.math;

const os = @import("os");
const base = @import("base");

const std = @import("std");
