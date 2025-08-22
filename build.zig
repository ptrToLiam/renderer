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

    const math_mod = b.addModule("math", .{
        .root_source_file = b.path("src/math.zig"),
        .target = target,
    });

    const wayland_protocols = &.{
        b.pathFromRoot("protocols/wayland/wayland.xml"),
        b.pathFromRoot("protocols/wayland/xdg-shell.xml"),
        b.pathFromRoot("protocols/wayland/xdg-decoration-unstable-v1.xml"),
        b.pathFromRoot("protocols/wayland/linux-dmabuf-v1.xml"),
    };

    const arena_mod = b.addModule("arena", .{
        .root_source_file = b.path("src/Arena.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "math", .module = math_mod },
        },
    });

    const vulkan_mod = b.addModule("vulkan", .{
        .root_source_file = b.path("src/generated/vulkan.zig"),
        .target = target,
    });

    const codegen_output_path = b.pathJoin(&.{ codegen_output_dir, codegen_output_name });
    const wayland_mod = b.addModule("wayland", .{
        .root_source_file = b.path(codegen_output_path),
        .target = target,
    });

    const codegen_exe = b.addExecutable(.{
        .name = "codegen",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/codegen.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "arena", .module = arena_mod },
                .{ .name = "math", .module = math_mod },
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
            .imports = &.{
                .{ .name = "arena", .module = arena_mod },
                .{ .name = "math", .module = math_mod },
                .{ .name = "vulkan", .module = vulkan_mod },
                .{ .name = "wayland", .module = wayland_mod },
            },
        }),
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
