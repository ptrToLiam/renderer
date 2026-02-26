const std = @import("std");

pub fn build(b: *std.Build) void {
  const target = b.standardTargetOptions(.{});
  const optimize = b.standardOptimizeOption(.{});

  const use_llvm = b.option(
    bool,
    "use-llvm",
    "use llvm backend",
  ) orelse false;
  const use_lld = b.option(
    bool,
    "use-lld",
    "use lld for linking",
  ) orelse use_llvm;

  const link_libc = b.option(
    bool,
    "link-libc",
    "link program against libc",
  ) orelse true; // true by default for vk

  const rpath_opt = b.option(
    []const u8,
    "rpath",
    "Add a custom rpath for loading dynamic libraries (i.e., libvulkan.so.1) on linux",
  );

  const vulkan = b.dependency("vulkan_zig", .{
    .registry = b.path("src/protocols/vulkan/vk.xml"),
  }).module("vulkan-zig");

  const wayland_protocol_specifications = [_]std.Build.LazyPath{
    b.path("src/protocols/wayland/wayland.xml"),
    b.path("src/protocols/wayland/xdg-shell.xml"),
    b.path("src/protocols/wayland/xdg-decoration-unstable-v1.xml"),
    b.path("src/protocols/wayland/linux-dmabuf-v1.xml"),
    b.path("src/protocols/wayland/presentation-time.xml"),
  };

  const wayland_protocols = b.dependency("wayland_protocol_codegen", .{
    .protocols = &wayland_protocol_specifications,
  }).module("wayland-protocols");

  const os_mod = b.addModule("os", .{
    .root_source_file = b.path("src/os/os.zig"),
    .target = target,
  });

  const base_mod = b.addModule("base", .{
    .root_source_file = b.path("src/base/base.zig"),
    .target = target,
    .imports = &.{
      .{ .name = "os", .module = os_mod },
    },
  });

  const platform_mod = b.addModule("platform", .{
    .root_source_file = b.path("src/platform/platform.zig"),
    .target = target,
    .imports = &.{
      .{ .name = "os", .module = os_mod },
      .{ .name = "base", .module = base_mod },
      .{ .name = "wayland-protocols", .module = wayland_protocols },
      .{ .name = "vulkan", .module = vulkan },
    },
  });

  // const gfx_mod = b.addModule("gfx", .{
  //   .root_source_file = b.path("src/gfx/gfx.zig"),
  //   .target = target,
  //   .imports = &.{
  //     .{ .name = "os", .module = os_mod },
  //     .{ .name = "base", .module = base_mod },
  //     .{ .name = "platform", .module = platform_mod },
  //     // .{ .name = "vulkan", .module = vulkan },
  //   },
  // });

  const root = b.createModule(.{
      .root_source_file = b.path("src/main.zig"),
      .target = target,
      .optimize = optimize,
      .link_libc =  link_libc,
      .imports = &.{
        .{ .name = "base", .module = base_mod },
        .{ .name = "os", .module = os_mod },
        .{ .name = "platform", .module = platform_mod },
        .{ .name = "vulkan", .module = vulkan },
      },
  });
  if (rpath_opt) |rpath| root.addRPathSpecial(rpath);

  const exe = b.addExecutable(.{
    .name = "project",
    .root_module = root,
    .use_llvm = use_llvm,
    .use_lld = use_lld,
  });
  b.installArtifact(exe);

  const run_step = b.step("run", "Run the app");
  const run_cmd = b.addRunArtifact(exe);
  run_step.dependOn(&run_cmd.step);
  run_cmd.step.dependOn(b.getInstallStep());

  if (b.args) |args| {
    run_cmd.addArgs(args);
  }

  const exe_tests = b.addTest(.{
    .root_module = exe.root_module,
  });

  const run_exe_tests = b.addRunArtifact(exe_tests);

  const test_step = b.step("test", "Run tests");
  test_step.dependOn(&run_exe_tests.step);
}
