pub const Connection = struct {
  pub fn open(arena: *Arena, env: os.Environ) Connection {
    _ = arena;
    _ = env;
    
    return .{};
  }

  pub fn close(conn: *Connection) void {
    _ = conn;
  }
};

const Arena = base.Arena;

const os = @import("os");
const base = @import("base");

