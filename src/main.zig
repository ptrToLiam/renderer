pub fn main() !void {
    Thread.ctx_init();
    Thread.set_name("LmAppMain");

    try VkApp.app();

    defer Thread.ctx_release();
}

const Thread = base.Thread;

const app = @import("app.zig");
const VkApp = @import("vk-app.zig");

const base = @import("base");
