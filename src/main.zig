pub fn main(init: std.process.Init.Minimal) void {
    base.entry.primary(App.app, .{init.environ});
}

const App = @import("app.zig");

const base = @import("base");
const std = @import("std");
