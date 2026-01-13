const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Core library module
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/zigx.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Export as dependency module
    _ = b.addModule("zigx", .{
        .root_source_file = b.path("src/zigx.zig"),
    });

    // Unit tests
    const lib_unit_tests = b.addTest(.{ .root_module = lib_mod });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Main example with all commands (bundle, debundle, info, list, compare)
    const example_mod = b.createModule(.{
        .root_source_file = b.path("examples/self_bundle.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_mod.addImport("zigx", lib_mod);

    const example = b.addExecutable(.{
        .name = "zigx",
        .root_module = example_mod,
    });

    // Default run (comparison demo)
    const run_example = b.addRunArtifact(example);
    run_example.setCwd(b.path("."));
    if (b.args) |args| {
        run_example.addArgs(args);
    }
    const example_step = b.step("run-example", "Run zigx example (default: compare compression levels)");
    example_step.dependOn(&run_example.step);

    // Bundle command shortcut
    const run_bundle = b.addRunArtifact(example);
    run_bundle.setCwd(b.path("."));
    run_bundle.addArg("bundle");
    if (b.args) |args| {
        run_bundle.addArgs(args);
    }
    const bundle_step = b.step("bundle", "Create a .zigx archive of this project");
    bundle_step.dependOn(&run_bundle.step);

    // Debundle command shortcut
    const run_debundle = b.addRunArtifact(example);
    run_debundle.setCwd(b.path("."));
    run_debundle.addArg("debundle");
    if (b.args) |args| {
        run_debundle.addArgs(args);
    }
    const debundle_step = b.step("debundle", "Extract a .zigx archive");
    debundle_step.dependOn(&run_debundle.step);

    // Info command shortcut
    const run_info = b.addRunArtifact(example);
    run_info.setCwd(b.path("."));
    run_info.addArg("info");
    if (b.args) |args| {
        run_info.addArgs(args);
    }
    const info_step = b.step("info", "Show .zigx archive information");
    info_step.dependOn(&run_info.step);

    // List command shortcut
    const run_list = b.addRunArtifact(example);
    run_list.setCwd(b.path("."));
    run_list.addArg("list");
    if (b.args) |args| {
        run_list.addArgs(args);
    }
    const list_step = b.step("list", "List files in .zigx archive");
    list_step.dependOn(&run_list.step);

    // Install executable
    b.installArtifact(example);

    // API documentation
    const lib_docs = b.addObject(.{
        .name = "zigx_docs",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zigx.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib_docs.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Generate API documentation");
    docs_step.dependOn(&install_docs.step);
}
