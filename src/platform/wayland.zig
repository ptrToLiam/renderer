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
    client_state.registry = client_state.display.get_registry(&conn_proxy) catch {
      @panic("Call to get_registry failed!");
    };

    // TODO:
    // - Implement Wayland RingBuffer I/O
    // - Bind Globals

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

  pub fn flush(conn: *const Connection) wl_protocols.WriteError!void {
    _ = conn;
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

  pub fn next_fd(conn: *Connection) i32 {
    // TODO
    _ = conn;
    return -1;
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
          const rounded_len = math.div_roundup(str_len, 4);

          string_arg.* = @ptrCast(data[offset..][0..(str_len - 1):0]);
          defer offset += rounded_len;
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

    if (connection.out.size() < msg_len) {
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
    _ = header;

    // @memcpy(connection.out_buf[connection.out_buf_idx..][0..@sizeOf(WireEventHeader)], std.mem.asBytes(&header));
    // connection.out_buf_idx += @sizeOf(WireEventHeader);
    for (args) |arg_opt| {
      if (arg_opt) |arg| arg: switch (arg) {
        .uint, .new_id, .object => |uint_arg| {
          _ = uint_arg;
          // defer connection.out_buf_idx += @sizeOf(u32);
          // @memcpy(connection.out_buf[connection.out_buf_idx..][0..@sizeOf(u32)], std.mem.asBytes(&uint_arg));
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
          _ = array_arg;
          // const write_len: u32 = @intCast(msg_arr_len(array_arg));
          // const len: u32 = @intCast(array_arg.len);
          // defer connection.out_buf_idx += write_len;

          // @memcpy(connection.out_buf[connection.out_buf_idx..][0..@sizeOf(u32)], std.mem.asBytes(&len));
          // @memcpy(connection.out_buf[connection.out_buf_idx + @sizeOf(u32) ..][0..len], array_arg);
          // const padding_byte_count = (write_len - @sizeOf(u32)) - len;

          // if (padding_byte_count > 0) {
          //   @memset(connection.out_buf[connection.out_buf_idx + @sizeOf(u32) + len ..][0..padding_byte_count], 0);
          // }
        },
        .fd => |fd_arg| {
          const fd_cmsg: linux.cmsg(posix.fd_t) = .init(
            posix.SOL.SOCKET,
            linux.SCM_RIGHTS,
            fd_arg,
          );
          _ = fd_cmsg;
          // @memcpy(connection.fd_out_buf[connection.fd_out_buf_idx..][0..@sizeOf(@TypeOf(fd_cmsg))], std.mem.asBytes(&fd_cmsg));
        //   connection.fd_out_buf_idx += @sizeOf(@TypeOf(fd_cmsg));
        },
      } else {
        // defer connection.out_buf_idx += @sizeOf(u32);
        // @memset(connection.out_buf[connection.out_buf_idx..][0..@sizeOf(u32)], 0);
      }
    }
  }

  fn next_id(noalias ctx: *anyopaque) u32 {
    const conn: *Connection = @alignCast(@ptrCast(ctx));
    const idx = conn.client_state.object_pool.next_object_id();
    return idx;
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

  const ring_buffer_size: usize = default_ring_buffer_size;
  const default_ring_buffer_size = 2048;
};

pub const ClientState = struct {
  // Base Wayland Connection Management
  display: Display,
  registry: Registry,

  // Globals
  seat: Seat,
  compositor: Compositor,
  xdg_wm_base: XdgWmBase,
  linux_dma_buf: LinuxDmabuf,

  // Objects
  object_pool: ObjectPool,
};

pub const ObjectPool = struct {
  objects: []Object,
  free_idx_list: FreeIdxList,

  pub fn next_object_id(op: *ObjectPool) u32 {
    return op.free_idx_list.pull() + 1;
  }

  pub fn push_object(op: *ObjectPool, object: Object) void {
    const idx: *const u32 = @alignCast(@ptrCast(object.ptr));
    op.objects[ idx.* - 1 ] = object;
  }

  pub fn release_object(op: *ObjectPool, object_id: u32) void {
    op.objects[ object_id - 1 ] = undefined;
    op.free_idx_list.push(object_id - 1);
  }
};

const FreeIdxList = struct {
  indices: []u32,
  index_available: u32,

  pub fn init_backing(buf: []u32) FreeIdxList {
    for (buf, 0..) |*index, i| {
      index.* = base.u32_(buf.len - i - 1);
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

const log = std.log.scoped(.wayland);
const Arena = base.Arena;
const Thread = base.Thread;
const RingBuffer = base.RingBuffer;

const linux = os.linux;
const posix = os.posix;

const Wayland = wl_protocols.Wayland;
const XdgShell = wl_protocols.XdgShell;
const LinuxDmabuf = wl_protocols.LinuxDmabufV1;
const XdgDecoration = wl_protocols.XdgDecorationUnstableV1;

const Proxy = wl_protocols.Proxy;
const Object = wl_protocols.Object;
const MessageArg = wl_protocols.MessageArg;

const wl_protocols = @import("wayland_protocols.zig");

const math = base.math;

const os = @import("os");
const base = @import("base");

const std = @import("std");
