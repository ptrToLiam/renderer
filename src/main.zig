pub fn main() !void {
    Thread.ctx_init();
    Thread.set_name("app_main_thread");

    try entry.app_main_entry();

    defer Thread.ctx_release();
}

const Thread = base.Thread;

const entry = @import("app_entry.zig");

const base = @import("base");
