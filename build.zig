const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // --- Dependencies ---
    const zstd_dep = b.dependency("zstd", .{
        .target = target,
        .optimize = optimize,
    });
    const zstd_mod = zstd_dep.module("zstd");
    const zstd_lib_artifact = zstd_dep.artifact("zstd");

    const zstd_dep_fast = b.dependency("zstd", .{
        .target = target,
        .optimize = .ReleaseFast,
    });
    const zstd_mod_fast = zstd_dep_fast.module("zstd");
    const zstd_lib_artifact_fast = zstd_dep_fast.artifact("zstd");

    // --- Modules ---

    // Standard module for normal use
    const zigx_mod = b.addModule("zigx", .{
        .root_source_file = b.path("src/zigx.zig"),
        .target = target,
        .optimize = optimize,
    });
    zigx_mod.addImport("zstd", zstd_mod);

    // Optimized module for high-performance benchmarks or users
    const zigx_mod_fast = b.addModule("zigx_fast", .{
        .root_source_file = b.path("src/zigx.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    zigx_mod_fast.addImport("zstd", zstd_mod_fast);

    // --- Artifacts ---

    // Static library for prebuilt releases (C interop or prebuilt binaries)
    const lib = b.addLibrary(.{
        .name = "zigx",
        .root_module = zigx_mod,
        .linkage = .static,
    });
    // Explicitly link the zstd artifact so it's associated with the library
    lib.linkLibrary(zstd_lib_artifact);
    b.installArtifact(lib);

    // Main CLI tool / Example
    const example_mod = b.createModule(.{
        .root_source_file = b.path("examples/self_bundle.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_mod.addImport("zigx", zigx_mod);

    const example_exe = b.addExecutable(.{
        .name = "zigx",
        .root_module = example_mod,
    });
    // Link binary against the library or module
    example_exe.linkLibrary(zstd_lib_artifact);

    // Install executable only if not freestanding
    if (target.result.os.tag != .freestanding) {
        b.installArtifact(example_exe);
    }

    // --- Run Steps ---

    // Default run (comparison demo)
    const run_example = b.addRunArtifact(example_exe);
    run_example.setCwd(b.path("."));
    if (b.args) |args| {
        run_example.addArgs(args);
    }
    const example_step = b.step("run-example", "Run zigx example (default: compare compression levels)");
    example_step.dependOn(&run_example.step);

    const commands = [_]struct { name: []const u8, arg: []const u8, desc: []const u8 }{
        .{ .name = "bundle", .arg = "bundle", .desc = "Create a .zigx archive" },
        .{ .name = "debundle", .arg = "debundle", .desc = "Extract a .zigx archive" },
        .{ .name = "info", .arg = "info", .desc = "Show .zigx archive information" },
        .{ .name = "list", .arg = "list", .desc = "List files in .zigx archive" },
    };

    for (commands) |cmd| {
        const run_cmd = b.addRunArtifact(example_exe);
        run_cmd.setCwd(b.path("."));
        run_cmd.addArg(cmd.arg);
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        const step = b.step(cmd.name, cmd.desc);
        step.dependOn(&run_cmd.step);
    }

    // --- Tests & Benchmarks ---

    const lib_unit_tests = b.addTest(.{
        .root_module = zigx_mod,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    const bench_mod = b.createModule(.{
        .root_source_file = b.path("bench/benchmark.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });
    bench_mod.addImport("zigx", zigx_mod_fast);

    const bench_exe = b.addExecutable(.{
        .name = "benchmark",
        .root_module = bench_mod,
    });
    bench_exe.linkLibrary(zstd_lib_artifact_fast);

    const run_bench = b.addRunArtifact(bench_exe);
    run_bench.setCwd(b.path("."));
    const bench_step = b.step("bench", "Run compression benchmarks");
    bench_step.dependOn(&run_bench.step);

    if (target.result.os.tag != .freestanding) {
        b.installArtifact(bench_exe);
    }

    // --- Documentation ---

    const lib_docs = b.addObject(.{
        .name = "zigx_docs",
        .root_module = zigx_mod,
    });

    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib_docs.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Generate API documentation");
    docs_step.dependOn(&install_docs.step);
}
