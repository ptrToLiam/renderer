pub fn main(init: std.process.Init.Minimal) void {
    base.entry.primary(VkApp.app, .{init.environ});
}

pub var start_time: u64 = undefined;
const Thread = base.Thread;

const app = @import("app.zig");
const VkApp = @import("vk-app.zig");

const base = @import("base");
const std = @import("std");
