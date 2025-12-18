pub fn main() !void {
    Thread.ctx_init();
    Thread.set_name("LmRenderer");

    try app.main_entry();

    defer Thread.ctx_release();
}

const Thread = base.Thread;

const app = @import("app.zig");

const base = @import("base");
