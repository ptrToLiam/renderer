pub const Connection = struct {
  pub fn open(env: os.Environ) Connection {
    _ = env;
    return .{};
  }

  pub fn close(conn: *Connection) void {
    _ = conn;
  }
};

const os = @import("os");
