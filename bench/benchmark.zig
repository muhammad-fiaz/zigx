const std = @import("std");
const zigx = @import("zigx");
const builtin = @import("builtin");

const CompressionLevel = zigx.CompressionLevel;

/// Benchmark results structure for ZIGX archive format
const BenchmarkResult = struct {
    name: []const u8,
    format: []const u8,
    original_size: u64,
    archive_size: u64,
    compression_ratio: f64,
    bundle_time_ns: u64,
    unbundle_time_ns: u64,
    bundle_speed_mbs: f64,
    unbundle_speed_mbs: f64,
    notes: []const u8,
    category: []const u8,
    file_count: usize,

    const categories = [_][]const u8{
        "ZIGX Compression Levels",
        "File Type Performance",
        "Scalability Test",
    };
};

/// Test data sizes
const SMALL_SIZE: usize = 1024; // 1 KB
const MEDIUM_SIZE: usize = 64 * 1024; // 64 KB
const LARGE_SIZE: usize = 1024 * 1024; // 1 MB
const XLARGE_SIZE: usize = 4 * 1024 * 1024; // 4 MB

/// Number of iterations for accurate timing
const ITERATIONS: u32 = 5;

/// Benchmark temp directory
const BENCH_DIR = "bench_temp";
const BENCH_OUTPUT = "bench_temp/test.zigx";
const BENCH_EXTRACT = "bench_temp/extracted";

/// Generate test data of specified type
fn generateTestData(allocator: std.mem.Allocator, size: usize, data_type: enum { text, binary, mixed, repetitive, random }) ![]u8 {
    const data = try allocator.alloc(u8, size);

    switch (data_type) {
        .text => {
            // Simulate text file (high compressibility)
            const text_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 \n\t.,;:!?(){}[]=-+*/<>\"'";
            var rng = std.Random.DefaultPrng.init(12345);
            for (data) |*byte| {
                byte.* = text_chars[rng.random().uintLessThan(usize, text_chars.len)];
            }
        },
        .binary => {
            // Simulate binary file (medium compressibility)
            var rng = std.Random.DefaultPrng.init(54321);
            for (data) |*byte| {
                byte.* = rng.random().int(u8);
            }
        },
        .mixed => {
            // Mixed content (header + data patterns)
            var rng = std.Random.DefaultPrng.init(11111);
            for (data, 0..) |*byte, i| {
                if (i % 4 == 0) {
                    byte.* = @truncate(i);
                } else {
                    byte.* = rng.random().int(u8);
                }
            }
        },
        .repetitive => {
            // Highly repetitive (excellent compressibility - similar to log files)
            const pattern = "2024-01-13 12:00:00 INFO  Application started successfully\n";
            for (data, 0..) |*byte, i| {
                byte.* = pattern[i % pattern.len];
            }
        },
        .random => {
            // Truly random (poor compressibility - worst case)
            var rng = std.Random.DefaultPrng.init(@truncate(@as(u128, @bitCast(std.time.nanoTimestamp()))));
            for (data) |*byte| {
                byte.* = rng.random().int(u8);
            }
        },
    }

    return data;
}

/// Setup benchmark directory and write test file
fn setupBenchmarkFile(allocator: std.mem.Allocator, data: []const u8, filename: []const u8) !void {
    // Create benchmark directory
    std.fs.cwd().makePath(BENCH_DIR) catch {};
    std.fs.cwd().makePath(BENCH_EXTRACT) catch {};

    // Write test data to file
    const file_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ BENCH_DIR, filename });
    defer allocator.free(file_path);

    const file = try std.fs.cwd().createFile(file_path, .{});
    defer file.close();
    try file.writeAll(data);
}

/// Clean up benchmark files
fn cleanupBenchmark() void {
    // Remove extracted directory
    std.fs.cwd().deleteTree(BENCH_EXTRACT) catch {};
    // Recreate for next iteration
    std.fs.cwd().makePath(BENCH_EXTRACT) catch {};
}

/// Run ZIGX archive benchmark using bundle() and unbundle()
fn runZigxBenchmark(
    allocator: std.mem.Allocator,
    data: []const u8,
    level: CompressionLevel,
    name: []const u8,
    notes: []const u8,
    category: []const u8,
    filename: []const u8,
) !BenchmarkResult {
    var total_bundle_time: u64 = 0;
    var total_unbundle_time: u64 = 0;
    var archive_size: u64 = 0;
    var file_count: usize = 0;

    // Setup test file
    try setupBenchmarkFile(allocator, data, filename);
    const test_file_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ BENCH_DIR, filename });
    defer allocator.free(test_file_path);

    // Warmup run (not timed)
    {
        var result = zigx.bundle(.{
            .allocator = allocator,
            .include = &.{test_file_path},
            .output_path = BENCH_OUTPUT,
            .level = level,
        }) catch |err| {
            std.debug.print("Warmup bundle error: {}\n", .{err});
            return err;
        };
        result.deinit();

        zigx.unbundle(.{
            .archive_path = BENCH_OUTPUT,
            .output_dir = BENCH_EXTRACT,
            .allocator = allocator,
            .overwrite = true,
        }) catch |err| {
            std.debug.print("Warmup unbundle error: {}\n", .{err});
            return err;
        };
        cleanupBenchmark();
    }

    // Benchmark iterations
    for (0..ITERATIONS) |_| {
        // Time bundle operation
        var timer = try std.time.Timer.start();
        var result = try zigx.bundle(.{
            .allocator = allocator,
            .include = &.{test_file_path},
            .output_path = BENCH_OUTPUT,
            .level = level,
        });
        total_bundle_time += timer.read();
        archive_size = result.archive_size;
        file_count = result.file_count;
        result.deinit();

        // Time unbundle operation
        timer.reset();
        try zigx.unbundle(.{
            .archive_path = BENCH_OUTPUT,
            .output_dir = BENCH_EXTRACT,
            .allocator = allocator,
            .overwrite = true,
        });
        total_unbundle_time += timer.read();

        cleanupBenchmark();
    }

    const avg_bundle_time = total_bundle_time / ITERATIONS;
    const avg_unbundle_time = total_unbundle_time / ITERATIONS;

    const original_size_f: f64 = @floatFromInt(data.len);
    const archive_size_f: f64 = @floatFromInt(archive_size);

    // Calculate metrics - saved % is (1 - archive/original) * 100 (higher = better compression)
    const compression_ratio = if (original_size_f > 0) (1.0 - archive_size_f / original_size_f) * 100.0 else 0.0;
    const bundle_speed = if (avg_bundle_time > 0)
        original_size_f / (@as(f64, @floatFromInt(avg_bundle_time)) / 1_000_000_000.0) / (1024.0 * 1024.0)
    else
        0.0;
    const unbundle_speed = if (avg_unbundle_time > 0)
        original_size_f / (@as(f64, @floatFromInt(avg_unbundle_time)) / 1_000_000_000.0) / (1024.0 * 1024.0)
    else
        0.0;

    return BenchmarkResult{
        .name = name,
        .format = "ZIGX (.zigx)",
        .original_size = data.len,
        .archive_size = archive_size,
        .compression_ratio = compression_ratio,
        .bundle_time_ns = avg_bundle_time,
        .unbundle_time_ns = avg_unbundle_time,
        .bundle_speed_mbs = bundle_speed,
        .unbundle_speed_mbs = unbundle_speed,
        .notes = notes,
        .category = category,
        .file_count = file_count,
    };
}

/// Print results to console with proper table formatting
fn printResults(results: []const BenchmarkResult) void {
    std.debug.print("\n", .{});
    std.debug.print("=" ** 130, .{});
    std.debug.print("\n", .{});
    std.debug.print("                                    ZIGX ARCHIVE FORMAT BENCHMARK RESULTS\n", .{});
    std.debug.print("=" ** 130, .{});
    std.debug.print("\n\n", .{});

    for (BenchmarkResult.categories) |cat| {
        var has_category = false;
        for (results) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                has_category = true;
                break;
            }
        }
        if (!has_category) continue;

        std.debug.print("[{s}]\n", .{cat});
        std.debug.print("-" ** 130, .{});
        std.debug.print("\n", .{});

        // Header row - clear column names
        std.debug.print("{s:<30} {s:>10} {s:>12} {s:>12} {s:>12} {s:>12} {s:<20}\n", .{
            "Benchmark",
            "Original",
            "Archive",
            "Saved %",
            "Bundle MB/s",
            "Unbundle MB/s",
            "Notes",
        });
        // Sub-header showing direction (lower/higher = better)
        std.debug.print("{s:<30} {s:>10} {s:>12} {s:>12} {s:>12} {s:>12} {s:<20}\n", .{
            "",
            "(bytes)",
            "(lower=better)",
            "(higher=better)",
            "(higher=better)",
            "(higher=better)",
            "",
        });
        std.debug.print("-" ** 130, .{});
        std.debug.print("\n", .{});

        for (results) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                std.debug.print("{s:<30} {d:>10} {d:>12} {d:>11.1}% {d:>12.1} {d:>12.1}   {s:<20}\n", .{
                    r.name,
                    r.original_size,
                    r.archive_size,
                    r.compression_ratio,
                    r.bundle_speed_mbs,
                    r.unbundle_speed_mbs,
                    r.notes,
                });
            }
        }
        std.debug.print("\n", .{});
    }
}

/// Calculate aggregate statistics from results
fn calculateStats(results: []const BenchmarkResult) struct {
    avg_ratio: f64,
    avg_bundle_speed: f64,
    avg_unbundle_speed: f64,
    best_ratio: f64,
    best_ratio_name: []const u8,
    best_bundle_speed: f64,
    best_bundle_name: []const u8,
    best_unbundle_speed: f64,
    best_unbundle_name: []const u8,
    total_original: u64,
    total_archive: u64,
} {
    var total_ratio: f64 = 0;
    var total_bundle: f64 = 0;
    var total_unbundle: f64 = 0;
    var count: usize = 0;
    var total_original: u64 = 0;
    var total_archive: u64 = 0;

    var best_ratio: f64 = -1000; // Start low since higher saved % = better
    var best_ratio_name: []const u8 = "";
    var best_bundle_speed: f64 = 0;
    var best_bundle_name: []const u8 = "";
    var best_unbundle_speed: f64 = 0;
    var best_unbundle_name: []const u8 = "";

    for (results) |r| {
        total_ratio += r.compression_ratio;
        total_bundle += r.bundle_speed_mbs;
        total_unbundle += r.unbundle_speed_mbs;
        total_original += r.original_size;
        total_archive += r.archive_size;
        count += 1;

        // Higher saved % = better compression, so find maximum
        if (r.compression_ratio > best_ratio) {
            best_ratio = r.compression_ratio;
            best_ratio_name = r.name;
        }
        if (r.bundle_speed_mbs > best_bundle_speed) {
            best_bundle_speed = r.bundle_speed_mbs;
            best_bundle_name = r.name;
        }
        if (r.unbundle_speed_mbs > best_unbundle_speed) {
            best_unbundle_speed = r.unbundle_speed_mbs;
            best_unbundle_name = r.name;
        }
    }

    const n: f64 = @floatFromInt(count);
    return .{
        .avg_ratio = if (count > 0) total_ratio / n else 0,
        .avg_bundle_speed = if (count > 0) total_bundle / n else 0,
        .avg_unbundle_speed = if (count > 0) total_unbundle / n else 0,
        .best_ratio = best_ratio,
        .best_ratio_name = best_ratio_name,
        .best_bundle_speed = best_bundle_speed,
        .best_bundle_name = best_bundle_name,
        .best_unbundle_speed = best_unbundle_speed,
        .best_unbundle_name = best_unbundle_name,
        .total_original = total_original,
        .total_archive = total_archive,
    };
}

/// Write fully dynamic Markdown report
fn writeMarkdownReport(results: []const BenchmarkResult, allocator: std.mem.Allocator) !void {
    const file = std.fs.cwd().createFile("docs/benchmark-results.md", .{}) catch {
        std.debug.print("Warning: Could not create docs/benchmark-results.md\n", .{});
        return;
    };
    defer file.close();

    const stats = calculateStats(results);

    // Header with dynamic environment info
    _ = try file.write("# ZIGX Archive Format Benchmark Results\n\n");
    _ = try file.write("## Environment\n\n");

    var buf: [512]u8 = undefined;
    const env_info = std.fmt.bufPrint(&buf,
        \\- **Platform:** {s}
        \\- **Architecture:** {s}
        \\- **Pointer Size:** {d}-bit
        \\- **Endianness:** {s}
        \\- **Benchmark Iterations:** {d}
        \\- **ZIGX Version:** {s}
        \\- **Format Version:** 0x{X:0>4}
        \\- **Compression Version:** v{d}
        \\
        \\
    , .{
        @tagName(builtin.os.tag),
        @tagName(builtin.cpu.arch),
        @sizeOf(usize) * 8,
        @tagName(builtin.cpu.arch.endian()),
        ITERATIONS,
        zigx.VERSION,
        zigx.FORMAT_VERSION,
        zigx.COMPRESSION_VERSION,
    }) catch "";
    _ = try file.write(env_info);

    // What's being tested
    _ = try file.write("## What's Being Tested\n\n");
    _ = try file.write("This benchmark tests the **full ZIGX archive format**, including:\n\n");
    _ = try file.write("- `zigx.bundle()` - Create `.zigx` archives with header, metadata, checksums, and compressed payload\n");
    _ = try file.write("- `zigx.unbundle()` - Extract `.zigx` archives with validation and file restoration\n\n");
    _ = try file.write("The times include all ZIGX overhead: header generation, SHA-256 checksums, metadata handling, file I/O, and Zstandard compression.\n\n");

    // Format description
    _ = try file.write("## ZIGX Archive Format\n\n");
    _ = try file.write("| Component | Description |\n");
    _ = try file.write("|:----------|:------------|\n");
    _ = try file.write("| **Header** | 128-byte binary header with magic, version, flags, checksums |\n");
    _ = try file.write("| **Metadata** | Variable key-value pairs (author, version, etc.) |\n");
    _ = try file.write("| **Checksums** | SHA-256 hash for each file in archive |\n");
    _ = try file.write("| **Payload** | Zstandard compressed file data with CRC32 |\n\n");

    // Results by category (fully dynamic)
    for (BenchmarkResult.categories) |cat| {
        var has_category = false;
        for (results) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                has_category = true;
                break;
            }
        }
        if (!has_category) continue;

        const cat_header = try std.fmt.allocPrint(allocator, "\n## {s}\n\n", .{cat});
        defer allocator.free(cat_header);
        _ = try file.write(cat_header);

        _ = try file.write("| Benchmark | Original | Archive | Saved % | Bundle | Unbundle | Notes |\n");
        _ = try file.write("|:----------|----------:|-------:|--------:|-------:|---------:|:------|\n");
        _ = try file.write("| | *(bytes)* | *(lower=better)* | *(higher=better)* | *(MB/s)* | *(MB/s)* | |\n");

        for (results) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                var line_buf: [512]u8 = undefined;
                const line = std.fmt.bufPrint(&line_buf, "| {s} | {d} B | {d} B | {d:.1}% | {d:.1} | {d:.1} | {s} |\n", .{
                    r.name,
                    r.original_size,
                    r.archive_size,
                    r.compression_ratio,
                    r.bundle_speed_mbs,
                    r.unbundle_speed_mbs,
                    r.notes,
                }) catch continue;
                _ = try file.write(line);
            }
        }
    }

    // Performance summary
    _ = try file.write("\n## ZIGX Performance Summary\n\n");

    var summary_buf: [1024]u8 = undefined;
    const summary = std.fmt.bufPrint(&summary_buf,
        \\| Metric | Value | Best Performer |
        \\|:-------|------:|:---------------|
        \\| Best Space Saved | {d:.1}% | {s} |
        \\| Average Space Saved | {d:.1}% | - |
        \\| Average Bundle Speed | {d:.1} MB/s | {s} ({d:.1} MB/s) |
        \\| Average Unbundle Speed | {d:.1} MB/s | {s} ({d:.1} MB/s) |
        \\| Total Data Processed | {d} bytes | - |
        \\| Total Archive Size | {d} bytes | - |
        \\
        \\
    , .{
        stats.best_ratio,
        stats.best_ratio_name,
        stats.avg_ratio,
        stats.avg_bundle_speed,
        stats.best_bundle_name,
        stats.best_bundle_speed,
        stats.avg_unbundle_speed,
        stats.best_unbundle_name,
        stats.best_unbundle_speed,
        stats.total_original,
        stats.total_archive,
    }) catch "";
    _ = try file.write(summary);

    // Key features
    _ = try file.write("\n## Key Features of ZIGX Archive Format\n\n");

    const features = std.fmt.bufPrint(&summary_buf,
        \\1. **Full Archive Format** - Complete `.zigx` files with headers, metadata, and validation
        \\2. **Excellent on Repetitive Data** - {d:.1}% space saved on log files (best case)
        \\3. **Fast Bundling** - {d:.1} MB/s average archive creation speed
        \\4. **Fast Unbundling** - {d:.1} MB/s average extraction speed
        \\5. **Cross-Platform** - Tested on {s}/{s}, supports all Zig platforms
        \\6. **Security** - SHA-256 checksums for file and payload verification
        \\7. **Compact Header** - Only {d} bytes header overhead
        \\8. **Versioned Format** - Format v0x{X:0>4} for forward compatibility
        \\
        \\
    , .{
        stats.best_ratio,
        stats.avg_bundle_speed,
        stats.avg_unbundle_speed,
        @tagName(builtin.os.tag),
        @tagName(builtin.cpu.arch),
        zigx.HEADER_SIZE,
        zigx.FORMAT_VERSION,
    }) catch "";
    _ = try file.write(features);

    // Conclusion
    _ = try file.write("## Conclusion\n\n");

    const conclusion = std.fmt.bufPrint(&summary_buf,
        \\ZIGX archive format achieved **{d:.1}%** best space savings with **{d:.1} MB/s** average bundling
        \\and **{d:.1} MB/s** average unbundling speeds on {s} {s}.
        \\
        \\- **Best compression:** {d:.1}% space saved on "{s}"
        \\- **Fastest bundling:** {d:.1} MB/s on "{s}"
        \\- **Fastest unbundling:** {d:.1} MB/s on "{s}"
        \\
        \\ZIGX provides a complete archive solution with excellent compression
        \\especially on repetitive data (log files, configs) while maintaining fast speeds.
        \\
        \\
    , .{
        stats.best_ratio,
        stats.avg_bundle_speed,
        stats.avg_unbundle_speed,
        @tagName(builtin.os.tag),
        @tagName(builtin.cpu.arch),
        stats.best_ratio,
        stats.best_ratio_name,
        stats.best_bundle_speed,
        stats.best_bundle_name,
        stats.best_unbundle_speed,
        stats.best_unbundle_name,
    }) catch "";
    _ = try file.write(conclusion);

    _ = try file.write("---\n");
    _ = try file.write("*Generated by ZIGX Benchmark Suite - Tests full archive format (bundle/unbundle)*\n");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var results: std.ArrayListUnmanaged(BenchmarkResult) = .empty;
    defer results.deinit(allocator);

    std.debug.print("ZIGX Archive Format Benchmark\n", .{});
    std.debug.print("==============================\n", .{});
    std.debug.print("Version: {s} | Format: 0x{X:0>4} | Compression: v{d}\n", .{
        zigx.VERSION,
        zigx.FORMAT_VERSION,
        zigx.COMPRESSION_VERSION,
    });
    std.debug.print("Testing: zigx.bundle() and zigx.unbundle() (full archive format)\n\n", .{});

    // Setup benchmark directory
    std.debug.print("Setting up benchmark environment...\n", .{});
    std.fs.cwd().makePath(BENCH_DIR) catch {};
    std.fs.cwd().makePath(BENCH_EXTRACT) catch {};

    // Generate test data
    std.debug.print("Generating test data...\n", .{});

    const text_data_small = try generateTestData(allocator, SMALL_SIZE, .text);
    defer allocator.free(text_data_small);

    const text_data_medium = try generateTestData(allocator, MEDIUM_SIZE, .text);
    defer allocator.free(text_data_medium);

    const text_data_large = try generateTestData(allocator, LARGE_SIZE, .text);
    defer allocator.free(text_data_large);

    const binary_data = try generateTestData(allocator, MEDIUM_SIZE, .binary);
    defer allocator.free(binary_data);

    const repetitive_data = try generateTestData(allocator, MEDIUM_SIZE, .repetitive);
    defer allocator.free(repetitive_data);

    const random_data = try generateTestData(allocator, MEDIUM_SIZE, .random);
    defer allocator.free(random_data);

    const mixed_data = try generateTestData(allocator, MEDIUM_SIZE, .mixed);
    defer allocator.free(mixed_data);

    // ========================================
    // Category: ZIGX Compression Levels
    // ========================================
    std.debug.print("Running ZIGX compression level benchmarks...\n", .{});

    // Level none - No compression (store)
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .none,
        "ZIGX .none (64KB text)",
        "Store mode",
        "ZIGX Compression Levels",
        "test_text.txt",
    ));

    // Level fast
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .fast,
        "ZIGX .fast (64KB text)",
        "Fast compression",
        "ZIGX Compression Levels",
        "test_text.txt",
    ));

    // Level default
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .default,
        "ZIGX .default (64KB text)",
        "Balanced",
        "ZIGX Compression Levels",
        "test_text.txt",
    ));

    // Level best
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .best,
        "ZIGX .best (64KB text)",
        "Best compression",
        "ZIGX Compression Levels",
        "test_text.txt",
    ));

    // ========================================
    // Category: File Type Performance
    // ========================================
    std.debug.print("Running file type benchmarks...\n", .{});

    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .default,
        "Text data (64KB)",
        "Source code",
        "File Type Performance",
        "test_text.txt",
    ));

    try results.append(allocator, try runZigxBenchmark(
        allocator,
        binary_data,
        .default,
        "Binary data (64KB)",
        "Executables",
        "File Type Performance",
        "test_binary.bin",
    ));

    try results.append(allocator, try runZigxBenchmark(
        allocator,
        repetitive_data,
        .default,
        "Repetitive data (64KB)",
        "Log files",
        "File Type Performance",
        "test_repetitive.log",
    ));

    try results.append(allocator, try runZigxBenchmark(
        allocator,
        random_data,
        .default,
        "Random data (64KB)",
        "Encrypted",
        "File Type Performance",
        "test_random.dat",
    ));

    try results.append(allocator, try runZigxBenchmark(
        allocator,
        mixed_data,
        .default,
        "Mixed data (64KB)",
        "Archives",
        "File Type Performance",
        "test_mixed.dat",
    ));

    // ========================================
    // Category: Scalability Test
    // ========================================
    std.debug.print("Running scalability benchmarks...\n", .{});

    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_small,
        .default,
        "Small file (1KB)",
        "Config files",
        "Scalability Test",
        "test_small.txt",
    ));

    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .default,
        "Medium file (64KB)",
        "Source files",
        "Scalability Test",
        "test_medium.txt",
    ));

    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_large,
        .default,
        "Large file (1MB)",
        "Large source",
        "Scalability Test",
        "test_large.txt",
    ));

    // Generate 4MB test data for XL test
    const xlarge_data = try generateTestData(allocator, XLARGE_SIZE, .text);
    defer allocator.free(xlarge_data);

    try results.append(allocator, try runZigxBenchmark(
        allocator,
        xlarge_data,
        .default,
        "XLarge file (4MB)",
        "Stress test",
        "Scalability Test",
        "test_xlarge.txt",
    ));

    // Print results to console
    printResults(results.items);

    // Write dynamic Markdown report
    std.debug.print("Writing benchmark-results.md...\n", .{});
    try writeMarkdownReport(results.items, allocator);

    // Cleanup benchmark directory
    std.debug.print("Cleaning up...\n", .{});
    std.fs.cwd().deleteTree(BENCH_DIR) catch {};

    // Final summary with dynamic stats
    const stats = calculateStats(results.items);
    std.debug.print("\n", .{});
    std.debug.print("=" ** 80, .{});
    std.debug.print("\n", .{});
    std.debug.print("[OK] ZIGX Archive Format Benchmarks completed successfully!\n", .{});
    std.debug.print("     Average Space Saved: {d:.1}% (higher = better)\n", .{stats.avg_ratio});
    std.debug.print("     Best Space Saved: {d:.1}% ({s})\n", .{ stats.best_ratio, stats.best_ratio_name });
    std.debug.print("     Avg Bundle Speed: {d:.1} MB/s (higher = faster)\n", .{stats.avg_bundle_speed});
    std.debug.print("     Avg Unbundle Speed: {d:.1} MB/s (higher = faster)\n", .{stats.avg_unbundle_speed});
    std.debug.print("     Results written to: docs/benchmark-results.md\n", .{});
    std.debug.print("=" ** 80, .{});
    std.debug.print("\n\n", .{});
}
