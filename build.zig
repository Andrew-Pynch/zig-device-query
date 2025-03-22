const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the module
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Create the static library
    const lib = b.addStaticLibrary(.{
        .name = "zig_device_query",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add X11 dependency for Linux
    if (target.result.os.tag == .linux) {
        // Add system lib dependency
        lib.linkSystemLibrary("X11");
    } else if (target.result.os.tag == .windows) {
        // Add Windows-specific libraries if needed
        lib.linkSystemLibrary("user32");
    } else if (target.result.os.tag == .macos) {
        // Add macOS-specific libraries if needed
    }

    b.installArtifact(lib);

    // Create the example executable
    const exe = b.addExecutable(.{
        .name = "device_query_example",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add the library module to the executable
    exe.root_module.addImport("zig_device_query_lib", lib_mod);

    // Add X11 dependency for Linux
    if (target.result.os.tag == .linux) {
        // Add system lib dependency
        exe.linkSystemLibrary("X11");
    } else if (target.result.os.tag == .windows) {
        // Add Windows-specific libraries if needed
        exe.linkSystemLibrary("user32");
    } else if (target.result.os.tag == .macos) {
        // Add macOS-specific libraries if needed
    }

    b.installArtifact(exe);

    // Create a run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the example");
    run_step.dependOn(&run_cmd.step);

    // Add unit tests
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add X11 dependency for Linux tests
    if (target.result.os.tag == .linux) {
        lib_unit_tests.linkSystemLibrary("X11");
    } else if (target.result.os.tag == .windows) {
        lib_unit_tests.linkSystemLibrary("user32");
    } else if (target.result.os.tag == .macos) {
        // Add macOS-specific libraries if needed
    }

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}