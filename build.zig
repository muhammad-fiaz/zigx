const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Resolve zstd dependency for standard builds
    const zstd_dep = b.dependency("zstd", .{
        .target = target,
        .optimize = optimize,
    });
    const zstd_mod = zstd_dep.module("zstd");

    // Resolve zstd dependency for ReleaseFast builds (benchmark)
    const zstd_dep_fast = b.dependency("zstd", .{
        .target = target,
        .optimize = .ReleaseFast,
    });
    const zstd_mod_fast = zstd_dep_fast.module("zstd");

    // Core library module
    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/zigx.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_mod.addImport("zstd", zstd_mod);

    // ReleaseFast library module for benchmarks
    const lib_mod_fast = b.createModule(.{
        .root_source_file = b.path("src/zigx.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    lib_mod_fast.addImport("zstd", zstd_mod_fast);

    // Export as dependency module
    const exported_mod = b.addModule("zigx", .{
        .root_source_file = b.path("src/zigx.zig"),
    });
    exported_mod.addImport("zstd", zstd_mod);

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
    const docs_mod = b.createModule(.{
        .root_source_file = b.path("src/zigx.zig"),
        .target = target,
        .optimize = optimize,
    });
    docs_mod.addImport("zstd", zstd_mod);

    const lib_docs = b.addObject(.{
        .name = "zigx_docs",
        .root_module = docs_mod,
    });

    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib_docs.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Generate API documentation");
    docs_step.dependOn(&install_docs.step);

    // Benchmark executable - uses ReleaseFast lib module
    const bench_mod = b.createModule(.{
        .root_source_file = b.path("bench/benchmark.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    bench_mod.addImport("zigx", lib_mod_fast);

    const bench_exe = b.addExecutable(.{
        .name = "benchmark",
        .root_module = bench_mod,
    });

    const run_bench = b.addRunArtifact(bench_exe);
    run_bench.setCwd(b.path("."));
    const bench_step = b.step("bench", "Run compression benchmarks");
    bench_step.dependOn(&run_bench.step);

    b.installArtifact(bench_exe);
}
