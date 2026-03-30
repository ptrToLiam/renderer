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

/// Dynamically load libraries if they can be located on the system.
/// If user is on NixOS with nix-ld configured, we can check NIX_LD_LIBRARY_PATH
/// to try to locate the library, otherwise NotFound does truly mean NOT FOUND.
pub fn lib(env: Environ, path: []const u8) DynLib.Error!DynLib {
  const libhandle = DynLib.open(path) catch |err| lib: {
    if (err == DynLib.Error.FileNotFound)
      if (env.getPosix("NIX_LD_LIBRARY_PATH")) |ldpath| {
        var pathbuf: [512]u8 = undefined;
        const pathlen = ldpath.len + 1 + path.len;
        if (pathlen > pathbuf.len) return err;
        @memcpy(pathbuf[0..ldpath.len],ldpath);
        pathbuf[ldpath.len] = '/';
        @memcpy(pathbuf[ldpath.len+1..][0..path.len], path);
        pathbuf[pathlen] = 0;
        break :lib try DynLib.open(pathbuf[0..pathlen]);
      };
    return err;
  };
  return libhandle;
}

pub fn UnsupportedPlatformError() void {
  @compileError("Unsupported Platform :: " ++ @tagName(Target.tag));
}

pub const page_size_min = std.heap.page_size_min;
pub const page_size_max = std.heap.page_size_max;
pub const posix = std.posix;

const DynLib = std.DynLib;

pub const Environ = std.process.Environ;
pub const Target = builtin.target.os;

// File Imports
pub const linux = @import("linux.zig");
pub const windows = @import("windows.zig");

// 3rd-Party Modules
const std = @import("std");
const builtin = @import("builtin");
