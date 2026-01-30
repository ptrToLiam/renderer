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

  pub fn open(env: os.Environ) Connection {
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

    return .{
      .fd = socket_fd,

      .in = ring_buffers[0],
      .out = ring_buffers[1],
      .fd_in = ring_buffers[2],
      .fd_out = ring_buffers[3],
    };
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

  const ring_buffer_size: usize = default_ring_buffer_size;
  const default_ring_buffer_size = 2048;
};

const WlConnectionProxy = struct {
  conn: *Connection,

  registry: []Object,
};

const Arena = base.Arena;
const Thread = base.Thread;
const RingBuffer = base.RingBuffer;

const linux = os.linux;
const posix = os.posix;

const Proxy = wl_protocols.Proxy;
const Object = wl_protocols.Object;
const MessageArg = wl_protocols.MessageArg;

const wl_protocols = @import("wayland_protocols.zig");

const os = @import("os");
const base = @import("base");
