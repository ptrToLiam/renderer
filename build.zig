const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const codegen_debug = b.option(
        bool,
        "codegen-debug",
        "run wayland protocol codegen with debug logs",
    ) orelse false;

    const codegen_output_dir = b.option(
        []const u8,
        "codegen-dir",
        "output path for generated code",
    ) orelse "src/generated";

    const codegen_output_name = b.option(
        []const u8,
        "codegen-name",
        "output name for generated code",
    ) orelse "wayland_protocols.zig";

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
    ) orelse false;

    const wayland_protocols = &.{
        b.pathFromRoot("protocols/wayland/wayland.xml"),
        b.pathFromRoot("protocols/wayland/xdg-shell.xml"),
        b.pathFromRoot("protocols/wayland/xdg-decoration-unstable-v1.xml"),
        b.pathFromRoot("protocols/wayland/linux-dmabuf-v1.xml"),
    };

    const os_mod = b.addModule("wayland", .{
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

    const vulkan_mod = b.addModule("vulkan", .{
        .root_source_file = b.path("src/generated/vulkan.zig"),
        .target = target,
    });

    const gfx_mod = b.addModule("wayland", .{
        .root_source_file = b.path("src/gfx.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "base", .module = base_mod },
            .{ .name = "vulkan", .module = vulkan_mod },
        },
    });

    const wayland_mod = b.addModule("wayland", .{
        .root_source_file = b.path("src/wayland.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "base", .module = base_mod },
            .{ .name = "os", .module = os_mod },
            .{ .name = "gfx", .module = gfx_mod },
        },
    });

    // const codegen_output_path = b.pathJoin(&.{ codegen_output_dir, codegen_output_name });

    const codegen_exe = b.addExecutable(.{
        .name = "codegen",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/codegen.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "base", .module = base_mod },
            },
        }),
    });
    b.installArtifact(codegen_exe);

    const exe = b.addExecutable(.{
        .name = "renderer",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc =  link_libc,
            .imports = &.{
                .{ .name = "base", .module = base_mod },
                .{ .name = "os", .module = os_mod },
                .{ .name = "gfx", .module = gfx_mod },
                .{ .name = "wayland", .module = wayland_mod },
            },
        }),
        .use_llvm = use_llvm,
        .use_lld = use_lld,
    });
    b.installArtifact(exe);

    const codegen_step = b.step("codegen", "Run codegen");
    const codegen_cmd = b.addRunArtifact(codegen_exe);
    codegen_step.dependOn(&codegen_cmd.step);
    codegen_cmd.addArgs(&.{
        "--prefix",
        b.pathFromRoot(codegen_output_dir),
        "--name",
        codegen_output_name,
    });
    codegen_cmd.addArgs(wayland_protocols);
    if (codegen_debug) codegen_cmd.addArg("--debug");

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
