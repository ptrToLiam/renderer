pub inline fn mem_reserve(size: usize) []align(page_size_min) u8 {
    return switch (TargetOs.tag) {
        .windows => windows.mem_reserve(size),
        .linux => linux.mem_reserve(size),
        else => @compileError("Unsupported platform :: " ++ @tagName(TargetOs.tag)),
    };
}
pub inline fn mem_commit() bool {
    return false;
}
pub inline fn mem_decommit() void {
}
pub inline fn mem_release() void {
}

pub inline fn mem_reserve_large() []align(page_size_min) u8 {
    return &.{};
}
pub inline fn mem_commit_large() bool {
    return false;
}

const page_size_min = std.heap.page_size_min;
const TargetOs = builtin.target.os;

// File Imports
pub const linux = @import("linux.zig");
pub const windows = @import("windows.zig");

// 3rd-Party Modules
const std = @import("std");
const builtin = @import("builtin");
