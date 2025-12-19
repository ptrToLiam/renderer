pub const WindowHandle = struct {
  conn: *Connection,
  proxy: *Protocols.Proxy,

  // globals
  display: Protocols.Wayland.Display,
  registry: Protocols.Wayland.Registry,
  seat: Protocols.Wayland.Seat,
  shm: Protocols.Wayland.Shm,
  wm_base: Protocols.XdgShell.WmBase,

  // objects
  wl_surface: Protocols.Wayland.Surface,
  xdg_surface: Protocols.XdgShell.Surface,
  xdg_toplevel: Protocols.XdgShell.Toplevel,

  // TODO: Make window handle come later?
  // -- maybe make 
  pub fn create(
    arena: *Arena,
    params: struct {
      title: [:0]const u8,
      class: [:0]const u8,
      width: i32,
      height: i32,
    },
  ) !*WindowHandle {
    const handle = arena.create(WindowHandle);
    var conn  = arena.create(Connection);
    conn.* = try .open(arena);
    const proxy = arena.create(Protocols.Proxy);
    proxy.* = conn.proxy();

    log.debug("connection handle :: {d}", .{conn.handle});
    log.debug("wl_display  :: id :: {d}", .{conn.display.toInt()});

    const wl_registry = try conn.display.get_registry(proxy);
    log.debug("wl_registry :: id :: {d}", .{wl_registry.toInt()});
    try conn.flush();

    // Bind interfaces
    // TODO: Re-think bind stage?
    // - possibly just async window handle return?
    // - return window handle that *should* be valid at first use?
    // - quietly handle binding in regular event handling?
    const wl_seat, const wl_compositor, const xdg_wm_base, const wl_shm = bind: {
      var read_success = false;
      while (!read_success) load_loop: {
        conn.load_events() catch |err| {
          switch (err) {
            error.NoData => {
              std.Thread.sleep(std.time.ns_per_us);
              break :load_loop;
            },
            error.SocketReadFailed => {
              std.Thread.sleep(std.time.ns_per_us);
              break :load_loop;
            },
            else => return err,
            }
        };
        read_success = true;
      }

      var seat: Protocols.Wayland.Seat = undefined;
      var compositor: Protocols.Wayland.Compositor = undefined;
      var wm_base: Protocols.XdgShell.WmBase = undefined;
      var shm: Protocols.Wayland.Shm = undefined;
      while (conn.event()) |event| {
        switch (event) {
          .wl_registry => |registry| switch (registry) {
            .global => |global| {
              if (std.mem.eql(u8, @TypeOf(seat).InterfaceName, global.interface)) {
                log.debug("Binding interface :: {s}", .{global.interface});
                seat = try wl_registry.bind(proxy, @TypeOf(seat), .{
                  .name = global.name,
                  .interface_version = global.version,
                });
                log.debug("Bound {s} with :: {{ .name={d}, .id={d}, .version={d} }}", .{
                  global.interface,
                  global.name,
                  seat.toInt(),
                  global.version,
                });
              } else if (std.mem.eql(u8, @TypeOf(compositor).InterfaceName, global.interface)) {
                log.debug("Binding interface :: {s}", .{global.interface});
                compositor = try wl_registry.bind(proxy, @TypeOf(compositor), .{
                  .name = global.name,
                  .interface_version = global.version,
                });
                log.debug("Bound {s} with :: {{ .name={d}, .id={d}, .version={d} }}", .{
                  global.interface,
                  global.name,
                  compositor.toInt(),
                  global.version,
                });
              } else if (std.mem.eql(u8, @TypeOf(wm_base).InterfaceName, global.interface)) {
                log.debug("Binding interface :: {s}", .{global.interface});
                wm_base = try wl_registry.bind(proxy, @TypeOf(wm_base), .{
                  .name = global.name,
                  .interface_version = global.version,
                });
                log.debug("Bound {s} with :: {{ .name={d}, .id={d}, .version={d} }}", .{
                  global.interface,
                  global.name,
                  wm_base.toInt(),
                  global.version,
                });
              } else if (std.mem.eql(u8, @TypeOf(shm).InterfaceName, global.interface)) {
                log.debug("Binding interface :: {s}", .{global.interface});
                shm = try wl_registry.bind(proxy, @TypeOf(shm), .{
                  .name = global.name,
                  .interface_version = global.version,
                });
                log.debug("Bound {s} with :: {{ .name={d}, .id={d}, .version={d} }}", .{
                  global.interface,
                  global.name,
                  shm.toInt(),
                  global.version,
                });
              }
            },
            .global_remove => |remove| {
              log.debug("Received Unexpected global_remove during bind phase :: {any}", .{remove});
            },
          },
          else => {
            log.warn("Unexpected event during bind phase :: {any}", .{event});
          },
        }
      }
      try conn.flush();

      break :bind .{ seat, compositor, wm_base, shm };
    };

    const wl_surface = try wl_compositor.create_surface(proxy);

    const xdg_surface = try xdg_wm_base.get_xdg_surface(proxy, .{ .surface = wl_surface });
    const xdg_toplevel = try xdg_surface.get_toplevel(proxy);

    try xdg_toplevel.set_title(proxy, .{ .title = params.title });
    try xdg_toplevel.set_app_id(proxy, .{ .app_id = params.class });

    try wl_surface.commit(proxy);
    try conn.flush();
    handle.* = .{
      .conn = conn,
      .proxy = proxy,

      // globals
      .display = conn.display,
      .registry = wl_registry,
      .seat = wl_seat,
      .shm = wl_shm,
      .wm_base = xdg_wm_base,

      // objects
      .wl_surface = wl_surface,
      .xdg_surface = xdg_surface,
      .xdg_toplevel = xdg_toplevel,
    };

    return handle;
  }

  pub fn destroy(window: *WindowHandle) void {
    defer window.conn.close();
  }
};

pub const WireEventHeader = packed struct(u64) {
  id: u32,
  op: u16,
  len: u16,
};

pub const Connection = struct {
  handle: posix.fd_t = 0,
  addr: posix.sockaddr.un = .{ .path = @splat(0) },
  display: Protocols.Wayland.Display = .fromInt(0),
  ev_queue_in: EventQueue = .{},
  fd_queue_in: FdQueue = .{},
  idx_free_queue: IndexFreeQueue = .{},
  cur_idx: u32 = 2,
  objects: []Protocols.Object,
  
  buf_in: ShiftBuffer,
  buf_fd_in: ShiftBuffer,
  
  out_buf: [2048]u8 = @splat(0),
  out_buf_idx: usize = 0,
  fd_out_buf: [256]u8 = @splat(0),
  fd_out_buf_idx: usize = 0,

  pub fn open(arena: *Arena) !Connection {
    const temp = Thread.Context.get_scratch(1, .{arena}).?;
    defer temp.end();
    const xdg_runtime_dir = posix.getenv("XDG_RUNTIME_DIR").?;
    const wayland_display = posix.getenv("WAYLAND_DISPLAY").?;

    const sock_path = try std.mem.join(temp.arena.allocator(), "/", &[_][]const u8{ xdg_runtime_dir, wayland_display });

    const opt_non_block = 0;
    const sockfd = try posix.socket(
      posix.AF.UNIX,
      posix.SOCK.STREAM | posix.SOCK.CLOEXEC | opt_non_block,
      0,
    );

    var addr: posix.sockaddr.un = addr: {
      var sock_addr: posix.sockaddr.un = .{
        .family = posix.AF.UNIX,
        .path = undefined,
      };

      if (sock_path.len + 1 > sock_addr.path.len) return error.SocketPathTooLong;

      @memset(&sock_addr.path, 0);
      @memcpy(sock_addr.path[0..sock_path.len], sock_path);
      break :addr sock_addr;
    };

    posix.connect(
      sockfd,
      @ptrCast(&addr),
      @as(posix.socklen_t, @intCast(@sizeOf(posix.sockaddr.un))),
    ) catch |err| {
      log.err("Failed to connect to Wayland Socket with err :: {s}", .{@errorName(err)});
      return err;
    };
    const display: Protocols.Wayland.Display = .fromInt(1);

    const objects = arena.push(Protocols.Object, 256);
    objects[display.toInt()] = display.object();
    
    const shift_in_backing_buf = arena.push(u8, 2048);
    const shift_fd_in_backing_buf = arena.push(u8, 2048);

    return .{
      .handle = sockfd,
      .addr = addr,
      .display = .fromInt(1),
      .objects = objects,
      .buf_in = .{ .buf = shift_in_backing_buf },
      .buf_fd_in = .{ .buf = shift_fd_in_backing_buf },
    };
  }

  pub fn close(conn: *Connection) void {
    posix.close(conn.handle);
  }

  pub fn proxy(conn: *Connection) Proxy {
    return .{
      .ctx = @ptrCast(conn),
      .vtable = .{
          .msg_parse_fn = msg_parse,
          .msg_write_fn = msg_write,
          .next_id_fn = next_id,
          .obj_push_fn = push_object,
          .obj_destroy_fn = destroy_object,
      },
    };
  }

  pub fn peek_event(conn: *Connection) ?Event {
    return conn.ev_queue_in.peek();
  }
  pub fn pop_event(conn: *Connection) void {
    return conn.ev_queue_in.pop();
  }
  pub fn event(conn: *Connection) ?Event {
    return conn.ev_queue_in.next();
  }

  pub fn flush(connection: *Connection) !void {
    if (connection.out_buf_idx > 0) {
      defer {
        @memset(connection.out_buf[0..], 0);
        connection.out_buf_idx = 0;
        @memset(connection.fd_out_buf[0..], 0);
        connection.fd_out_buf_idx = 0;
      }
      
      const iov = [_]posix.iovec_const{
        .{
            .base = connection.out_buf[0..].ptr,
            .len = connection.out_buf_idx,
        },
      };

      const msg: posix.msghdr_const = .{
        .name = null,
        .namelen = 0,
        .iov = &iov,
        .iovlen = iov.len,
        .control = @ptrCast(connection.fd_out_buf[0..].ptr),
        .controllen = connection.fd_out_buf_idx,
        .flags = 0,
      };

      _ = try posix.sendmsg(connection.handle, &msg, 0);
    }
  }

  // TODO: rewrite to actually use indices and shift back data from partial reads
  pub fn load_events(conn: *Connection) !void {
    conn.buf_in.shift_back();
    conn.buf_fd_in.shift_back();

    const write_in_buf = conn.buf_in.buf[conn.buf_in.write..];
    const write_in_fd_buf = conn.buf_fd_in.buf[conn.buf_fd_in.write..];
    
    var iov = [_]posix.iovec{
      .{
        .base = write_in_buf.ptr,
        .len = write_in_buf.len,
      },
    };

    var message: posix.msghdr = .{
      .name = null,
      .namelen = 0,
      .iov = &iov,
      .iovlen = @intCast(iov.len),
      .control = write_in_fd_buf.ptr,
      .controllen = write_in_fd_buf.len,
      .flags = 0,
    };

    const rc = linux.recvmsg(
      conn.handle,
      &message,
      linux.MSG.DONTWAIT,
    );
    
    if (rc > iov[0].len) {
      const err = posix.errno(rc);
      switch (err) {
        .AGAIN => {
          return error.NoData;
        },
        else => {
          return error.SocketReadFailed;
        },
      }
    } else if (rc == 0) {
      log.warn("rc==0!", .{});
      return error.SocketClosed;
    }

    const bytes_read: u32 = @intCast(rc);
    // Control messages
    {
      var cmsg_iter = linux.cmsghdr.iter(
        write_in_fd_buf[conn.buf_fd_in.read..][0..message.controllen],
      );

      while (cmsg_iter.next()) |cmsg_header| {
        if (cmsg_header.type == posix.SOL.SOCKET and
          cmsg_header.level == linux.SCM_RIGHTS)
        {
          conn.fd_queue_in.push(cmsg_header.data(posix.fd_t).*);
        }
      }
    }
    log.debug("load_events :: bytes_read={d}", .{bytes_read});

    // Standard wire events
    {
      conn.buf_in.write += bytes_read;
      while (conn.buf_in.read < conn.buf_in.write) {
        const space_available = conn.buf_in.write - conn.buf_in.read;
        if (space_available < @sizeOf(WireEventHeader)) {
          log.debug(
            "Not enough space for header (have {d} bytes, need {d} @ read_idx={d})",
            .{ space_available, @sizeOf(WireEventHeader), conn.buf_in.read }
          );
          break;
        }

        const header: WireEventHeader = std.mem.bytesToValue(
          WireEventHeader,
          conn.buf_in.buf[conn.buf_in.read..][0..@sizeOf(WireEventHeader)]
        );

        if (header.len > space_available) {
          log.debug("Not enough space for data", .{});
          log.debug("Header :: {{ .id={d}, .op={d}, .len={d} }}", .{
            header.id,
            header.op,
            header.len,
          });
          break;
        } else {       
          defer conn.buf_in.read += header.len;   
          log.debug("Header :: {{ .id={d}, .op={d}, .len={d} }}", .{
            header.id,
            header.op,
            header.len,
          });

          const parsed_event = try conn.objects[header.id].parse_msg(
            &conn.proxy(),
            header.op,
            conn.buf_in.buf[conn.buf_in.read..][@sizeOf(WireEventHeader)..header.len],
          );
          conn.ev_queue_in.push(parsed_event);
        }
      }
    }
  }

  fn next_id(noalias ctx: *anyopaque) u32 {
    const connection: *Connection = @ptrCast(@alignCast(ctx));
    const id =  if (connection.idx_free_queue.next()) |free_idx|
      free_idx
    else idx: {
      defer connection.cur_idx += 1;
      break :idx connection.cur_idx;
    };

    return id;
  }

  fn push_object(noalias ctx: *anyopaque, object: Protocols.Object) void {
    const connection: *Connection = @ptrCast(@alignCast(ctx));
    const idx = @as(*const u32, @ptrCast(@alignCast(object.ptr))).*;
    connection.objects[idx] = object;
  }

  fn destroy_object(noalias ctx: *anyopaque, id: u32) void {
    const connection: *Connection = @ptrCast(@alignCast(ctx));
    connection.idx_free_queue.push(id);
    connection.objects[id] = undefined;
  }

  fn msg_parse(noalias ctx: *anyopaque, args_out: []MessageArg, data: []const u8) !void {
    const connection: *Connection = @ptrCast(@alignCast(ctx));
    var offset: u32 = 0;

    for (args_out) |*arg| {
      switch (arg.*) {
        .fd => |*arg_fd| {
          arg_fd.* = connection.fd_queue_in.next().?;
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
          const rounded_len = round_up(str_len, 4);
          
          string_arg.* = @ptrCast(data[offset..][0..(str_len - 1):0]);
          defer offset += rounded_len;
        },
        .array => |*array_arg| {
          const arr_len = std.mem.bytesToValue(u32, data[offset..][0..4]);
          offset += 4;
          const rounded_len = round_up(arr_len, 4);
          array_arg.* = data[offset..][0..arr_len];
          offset += rounded_len;
        },
      }
    }
  }

  fn msg_write(noalias ctx: *anyopaque, id: u32, op: u16, noalias args: []const ?MessageArg) Protocols.WriteError!void {
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

    if (connection.out_buf[connection.out_buf_idx..].len < msg_len) {
      connection.flush() catch |err| {
        log.err("Connection flush failed due to err :: {s}", .{@errorName(err)});
        return Protocols.WriteError.WriteFailed;
      };
    }

    const header: WireEventHeader = .{
      .id = id,
      .op = op,
      .len = msg_len,
    };

    @memcpy(connection.out_buf[connection.out_buf_idx..][0..@sizeOf(WireEventHeader)], std.mem.asBytes(&header));
    connection.out_buf_idx += @sizeOf(WireEventHeader);
    for (args) |arg_opt| {
      if (arg_opt) |arg| arg: switch (arg) {
        .uint, .new_id, .object => |uint_arg| {
          defer connection.out_buf_idx += @sizeOf(u32);
          @memcpy(connection.out_buf[connection.out_buf_idx..][0..@sizeOf(u32)], std.mem.asBytes(&uint_arg));
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
          const write_len: u32 = @intCast(msg_arr_len(array_arg));
          const len: u32 = @intCast(array_arg.len);
          defer connection.out_buf_idx += write_len;

          @memcpy(connection.out_buf[connection.out_buf_idx..][0..@sizeOf(u32)], std.mem.asBytes(&len));
          @memcpy(connection.out_buf[connection.out_buf_idx + @sizeOf(u32) ..][0..len], array_arg);
          const padding_byte_count = (write_len - @sizeOf(u32)) - len;

          if (padding_byte_count > 0) {
            @memset(connection.out_buf[connection.out_buf_idx + @sizeOf(u32) + len ..][0..padding_byte_count], 0);
          }
        },
        .fd => |fd_arg| {
          const fd_cmsg: linux.cmsg(posix.fd_t) = .init(
            posix.SOL.SOCKET,
            linux.SCM_RIGHTS,
            fd_arg,
          );
          @memcpy(connection.fd_out_buf[connection.fd_out_buf_idx..][0..@sizeOf(@TypeOf(fd_cmsg))], std.mem.asBytes(&fd_cmsg));
          connection.fd_out_buf_idx += @sizeOf(@TypeOf(fd_cmsg));
        },
      } else {
        defer connection.out_buf_idx += @sizeOf(u32);
        @memset(connection.out_buf[connection.out_buf_idx..][0..@sizeOf(u32)], 0);
      }
    }
  }

  inline fn msg_str_len(str: [:0]const u8) u16 {
    return msg_arr_len(str[0 .. str.len + 1]);
  }

  inline fn msg_arr_len(arr: []const u8) u16 {
    return @intCast(round_up(@sizeOf(u32) + arr.len, @sizeOf(u32)));
  }

  inline fn round_up(val: anytype, mul: @TypeOf(val)) @TypeOf(val) {
    if (val == 0)
      return 0
    else
      return if (val % mul == 0)
        val
      else
        val + (mul - (val % mul));
  }

  const EventQueue = struct {
    buf: [Size]Event = undefined,
    read: u32 = 0,
    write: u32 = 0,

    pub fn push(noalias queue: *EventQueue, ev: Event) void {
      const write_idx = queue.write % queue.buf.len;
      queue.buf[write_idx] = ev;
      queue.write += 1;
    }

    pub fn pop(noalias queue: *EventQueue) void {
      queue.read += 1;
    }

    pub fn peek(noalias queue: *EventQueue) ?Event {
      if (queue.read != queue.write) {
        const read_idx = queue.read % queue.buf.len;
        return queue.buf[read_idx];
      } else {
        return null;
      }
    }

    pub fn next(noalias queue: *EventQueue) ?Event {
      if (queue.read != queue.write) {
        defer queue.read += 1;

        const read_idx = queue.read % queue.buf.len;
        return queue.buf[read_idx];
      } else {
        return null;
      }
    }

    pub const Size = 64;
  };

  const FdQueue = struct {
    buf: [Size]posix.fd_t = @splat(0),
    read: u32 = 0,
    write: u32 = 0,

    pub fn push(noalias queue: *FdQueue, fd: posix.fd_t) void {
      const write_idx = queue.write % queue.buf.len;
      queue.buf[write_idx] = fd;
      queue.write += 1;
    }

    pub fn next(noalias queue: *FdQueue) ?posix.fd_t {
      if (queue.read != queue.write) {
        defer queue.read += 1;

        const read_idx = queue.read % queue.buf.len;
        return queue.buf[read_idx];
      } else {
        return null;
      }
    }

    pub const Size = 64;
  };

  const IndexFreeQueue = struct {
    buf: [QueueSize]u32 = [_]u32{0} ** QueueSize,
    first: usize = 0,
    last: usize = 0,

    const QueueSize = 32;

    pub fn push(q: *IndexFreeQueue, idx: u32) void {
      q.buf[(q.last % QueueSize)] = idx;
      q.last += 1;
    }
    pub fn next(q: *IndexFreeQueue) ?u32 {
      const res = blk: {
        if ((q.first == q.last) or
            (q.buf[(q.first % QueueSize)] == 0))
        {
          break :blk null;
        } else {
          defer q.first += 1;
          defer q.buf[(q.first % QueueSize)] = 0;
          break :blk q.buf[(q.first % QueueSize)];
        }
      };
      return res;
    }
  };

  const MessageArg = Protocols.MessageArg;
  const Proxy = Protocols.Proxy;

};

pub const ShmImageQueue = struct {
  conn: *Connection,
  fd: posix.fd_t,
  width: i32,
  height: i32,
  images: [3]gfx.Image,
  active: [3]bool,
  buffers: [3]Protocols.Wayland.Buffer,
  present_idx: ?u32 = null,
  shm_pool: Protocols.Wayland.ShmPool,
  write: usize,
  size: usize,

  pub fn create(conn: *Connection, shm: Protocols.Wayland.Shm, width: i32, height: i32) !ShmImageQueue {
    log.debug("Creating Swapchain with dims :: {{ .width={d}, .height={d} }}", .{
      width, height,
    });
    const tmp = scratch_begin(0, .{}).?;
    defer tmp.end();
    var proxy = conn.proxy();

    const shm_fd = try alloc_shm_file(tmp.arena);
    const img_stride = width * 4;
    const img_size: usize = @intCast(height * img_stride);
    const size: usize = @intCast(img_size * 3);

    try posix.ftruncate(shm_fd, size);
    const buffer = try std.posix.mmap(
      null,
      size,
      posix.PROT.READ | posix.PROT.WRITE,
      .{ .TYPE = .SHARED },
      shm_fd,
      0,
    );

    const imgs: [3]gfx.Image = blk: {
      const img_1 = buffer[0..img_size];
      const img_2 = buffer[img_size..][0..img_size];
      const img_3 = buffer[img_size * 2 ..][0..img_size];

      break :blk .{
        @ptrCast(@alignCast(img_1)),
        @ptrCast(@alignCast(img_2)),
        @ptrCast(@alignCast(img_3)),
      };
    };

    const shm_pool = try shm.create_pool(&proxy, .{
      .fd = shm_fd,
      .size = @intCast(size),
    });

    const buffers: [3]Protocols.Wayland.Buffer = .{
      try shm_pool.create_buffer(&proxy, .{
        .width = width,
        .height = height,
        .format = .argb8888,
        .offset = 0,
        .stride = img_stride,
      }),
      try shm_pool.create_buffer(&proxy, .{
        .width = width,
        .height = height,
        .format = .argb8888,
        .offset = @intCast(img_size),
        .stride = img_stride,
      }),
      try shm_pool.create_buffer(&proxy, .{
        .width = width,
        .height = height,
        .format = .argb8888,
        .offset = @intCast(img_size * 2),
        .stride = img_stride,
      }),
    };

    return .{
      .conn = conn,
      .fd = shm_fd,
      .images = imgs,
      .width = width,
      .height = height,
      .shm_pool = shm_pool,
      .buffers = buffers,
      .active = @splat(false),
      .write = 0,
      .size = size,
    };
  }

  pub fn resize(queue: *ShmImageQueue, width: i32, height: i32) !void {
    var proxy = queue.conn.proxy();

    const img_width = @max(100, width);
    const img_height = @max(100, height);
    const img_stride = img_width * 4;
    const img_size: usize = @intCast(img_height * img_stride);
    const new_size: usize = @intCast(img_size * 3);

    const buffer = buffer: {
      const ptr: [*]u8 = @ptrFromInt(@intFromPtr(queue.images[0].ptr));
      const buf: []align(4096)u8 = @alignCast(ptr[0..queue.size]);

      if (new_size > queue.size) {
        defer queue.size = new_size;
        std.posix.munmap(buf);

        try posix.ftruncate(queue.fd, new_size);

        try queue.shm_pool.resize(&proxy, .{ .size = @intCast(new_size) });
        const buffer = try std.posix.mmap(
          null,
          new_size,
          posix.PROT.READ | posix.PROT.WRITE,
          .{ .TYPE = .SHARED },
            queue.fd,
          0,
        );

        break :buffer buffer;
      } else
        break :buffer buf;
    };

    queue.images = blk: {
      const img_1 = buffer[0..img_size];
      const img_2 = buffer[img_size..][0..img_size];
      const img_3 = buffer[img_size * 2 ..][0..img_size];

      break :blk .{
        @ptrCast(@alignCast(img_1)),
        @ptrCast(@alignCast(img_2)),
        @ptrCast(@alignCast(img_3)),
      };
    };

    for (queue.buffers) |wl_buffer| {
      try wl_buffer.destroy(&proxy);
    }


    queue.buffers = .{
      try queue.shm_pool.create_buffer(&proxy, .{
        .width = img_width,
        .height = img_height,
        .format = .argb8888,
        .offset = 0,
        .stride = img_stride,
      }),
      try queue.shm_pool.create_buffer(&proxy, .{
        .width = img_width,
        .height = img_height,
        .format = .argb8888,
        .offset = @intCast(img_size),
        .stride = img_stride,
      }),
      try queue.shm_pool.create_buffer(&proxy, .{
        .width = img_width,
        .height = img_height,
        .format = .argb8888,
        .offset = @intCast(img_size * 2),
        .stride = img_stride,
      }),
    };
    queue.width = img_width; queue.height = img_height;
  }

  pub fn destroy(queue: *ShmImageQueue) !void {
    var proxy = queue.conn.proxy();

    for (queue.buffers) |wl_buffer| {
      try wl_buffer.destroy(&proxy);
    }

    const ptr: [*]align(4096) u8 = @ptrCast(@alignCast(queue.images[0].ptr));
    const mem = ptr[0 .. (queue.images[0].len * 3) * @sizeOf(gfx.Pixel)];
    defer posix.close(queue.fd);

    defer queue.shm_pool.destroy(&proxy) catch unreachable;
    defer posix.munmap(mem);
  }

  pub fn next_img(queue: *ShmImageQueue) ?gfx.Image {
    if (!queue.active[queue.write % 3]) {
      defer queue.write += 1;
      return queue.images[queue.write % 3];
    } else return null;
  }

  inline fn alloc_shm_file(arena: *Arena) !posix.fd_t {
    const timestamp = std.time.nanoTimestamp();
    const name_template = "/var/tmp/Lm_Renderer-XXXXXX";
    var name = try arena.allocator().dupeZ(u8, name_template);
    for (name[(name.len - 6)..]) |*byte| {
      byte.* = @intCast((
        'A' + (timestamp & 15) + ((timestamp & 16) * 2)
      ));
    }

    log.debug("attempting to open shm file with name '{s}'", .{
      name,
    });

    const fd = posix.open(
      name,
      .{
        .ACCMODE = .RDWR,
        .CREAT = true,
        .EXCL = true,
        .CLOEXEC = true,
      },
      0o600,
    ) catch |err| {
      log.err("shm file open failed :: {s}", .{@errorName(err)});
      return err;
    };

    log.debug("Opened shm file :: {{ .name={s}, .fd={d} }}", .{
      name,
      fd,
    });
    posix.unlink(name) catch unreachable;
    return fd;
  }
};

pub const Event = Protocols.Event;
const scratch_begin = Thread.Context.get_scratch;

const posix = std.posix;
// Begin Tests
test "Proxied Event Parse" {
  var conn: Connection = .{};

  const name: u32 = 3;
  const name_bytes = std.mem.asBytes(&name);
  const strlen: u32 = 8;
  const strlen_bytes = std.mem.asBytes(&strlen);
  const ver: u32 = 1;
  const ver_bytes = std.mem.asBytes(&ver);

  const wire_event = .{
    .header = .{
      .id = 2,
      .op = 0,
      .msg_len = 9,
    },
    .data = &.{
      name_bytes[0],   name_bytes[1],   name_bytes[2],   name_bytes[3],
      strlen_bytes[0], strlen_bytes[1], strlen_bytes[2], strlen_bytes[3],
      'w',             'l',             '_',             's',
      'e',             'a',             't',             '\x00',
      ver_bytes[0],    ver_bytes[1],    ver_bytes[2],    ver_bytes[3],
    },
  };

  const proxy = conn.proxy();
  const registry: Protocols.Wayland.Registry = .fromInt(2);
  const registry_object = registry.object();
  const event = try registry_object.parse_msg(
    &proxy,
    wire_event.header.op,
    wire_event.data,
  );
  switch (event) {
    .wl_registry => |registry_event| switch (registry_event) {
      .global => |global| {
        try testing.expectEqual(@as(u32, 3), global.name);
        try testing.expect(std.mem.eql(u8, global.interface, "wl_seat"));
        try testing.expectEqual(@as(u32, 1), global.version);
      },
      else => {},
    },
    else => {},
  }
}

const linux = os.linux;
const Arena = base.Arena;
const Thread = base.Thread;
const ShiftBuffer = base.ShiftBuffer;

const testing = std.testing;
const log = std.log.scoped(.WaylandConnection);

// File Imports
pub const Protocols = @import("generated/wayland_protocols.zig");
const gfx = @import("gfx.zig");

// Internal Module Imports
const os = @import("os");
const base = @import("base");

// 3rd-Party Module Imports
const std = @import("std");