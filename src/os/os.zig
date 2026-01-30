//------------------------------------------------------------------------------
//             Memory Management API Surface
//------------------------------------------------------------------------------
pub inline fn mem_reserve(size: usize) []align(page_size_min) u8 {
  return switch (Target.tag) {
    .windows => windows.mem_reserve(size),
    .linux => linux.mem_reserve(size),
    else => UnsupportedPlatformError(),
  };
}

pub inline fn mem_commit(bytes: []align(page_size_min) u8) bool {
  return switch (Target.tag) {
    .windows => windows.mem_commit(bytes),
    .linux => linux.mem_commit(bytes),
    else => UnsupportedPlatformError(),
  };
}

pub inline fn mem_decommit(bytes: []align(page_size_min) const u8) void {
  return switch (Target.tag) {
    .windows => windows.mem_decommit(bytes),
    .linux => linux.mem_decommit(bytes),
    else => UnsupportedPlatformError(),
  };
}

pub inline fn mem_release(bytes: []align(page_size_min) const u8) void {
  return switch (Target.tag) {
    .windows => windows.mem_release(bytes),
    .linux => linux.mem_release(bytes),
    else => UnsupportedPlatformError(),
  };
}

pub inline fn mem_reserve_large(size: usize) ?[]align(page_size_min) u8 {
  return switch (Target.tag) {
    .windows => windows.mem_reserve(size),
    .linux => linux.mem_reserve(size),
    else => UnsupportedPlatformError(),
  };
}

pub inline fn mem_commit_large(bytes: []align(page_size_min) u8) bool {
  return switch (Target.tag) {
    .windows => windows.mem_commit_large(bytes),
    .linux => linux.mem_commit_large(bytes),
    else => UnsupportedPlatformError(),
  };
}
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//             Sleep/Time API Surface
//------------------------------------------------------------------------------
pub inline fn sleep(ns: u64) void {
  return switch (Target.tag) {
    .linux => linux.sleep(ns),
    else => UnsupportedPlatformError(),
  };
}
//------------------------------------------------------------------------------

pub fn UnsupportedPlatformError() void {
  @compileError("Unsupported Platform :: " ++ @tagName(Target.tag));
}

pub const page_size_min = std.heap.page_size_min;
pub const page_size_max = std.heap.page_size_max;

pub const posix = std.posix;
pub const Environ = std.process.Environ;
pub const Target = builtin.target.os;

// File Imports
pub const linux = @import("linux.zig");
pub const windows = @import("windows.zig");

// 3rd-Party Modules
const std = @import("std");
const builtin = @import("builtin");
