const std = @import("std");
const zigx = @import("zigx");
const builtin = @import("builtin");

const CompressionLevel = zigx.CompressionLevel;

/// Benchmark results structure with all dynamic data
const BenchmarkResult = struct {
    name: []const u8,
    format: []const u8,
    original_size: u64,
    compressed_size: u64,
    compression_ratio: f64,
    compression_time_ns: u64,
    decompression_time_ns: u64,
    compression_speed_mbs: f64,
    decompression_speed_mbs: f64,
    notes: []const u8,
    category: []const u8,

    const categories = [_][]const u8{
        "All Compression Levels (zstd 0-22)",
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

/// Run ZIGX compression benchmark with accurate timing
fn runZigxBenchmark(
    allocator: std.mem.Allocator,
    data: []const u8,
    level: CompressionLevel,
    name: []const u8,
    notes: []const u8,
    category: []const u8,
) !BenchmarkResult {
    var total_compress_time: u64 = 0;
    var total_decompress_time: u64 = 0;
    var compressed_size: u64 = 0;

    // Warmup run (not timed)
    {
        const warmup = try zigx.compression.compress(data, allocator, level);
        defer allocator.free(warmup);
    }

    // Benchmark iterations
    for (0..ITERATIONS) |_| {
        var timer = try std.time.Timer.start();
        const compressed = try zigx.compression.compress(data, allocator, level);
        total_compress_time += timer.read();
        compressed_size = compressed.len;

        timer.reset();
        const decompressed = try zigx.compression.decompress(compressed, allocator);
        total_decompress_time += timer.read();

        allocator.free(compressed);
        allocator.free(decompressed);
    }

    const avg_compress_time = total_compress_time / ITERATIONS;
    const avg_decompress_time = total_decompress_time / ITERATIONS;

    const original_size_f: f64 = @floatFromInt(data.len);
    const compressed_size_f: f64 = @floatFromInt(compressed_size);

    // Calculate metrics - saved % is (1 - compressed/original) * 100 (higher = better compression)
    const compression_ratio = if (original_size_f > 0) (1.0 - compressed_size_f / original_size_f) * 100.0 else 0.0;
    const compress_speed = if (avg_compress_time > 0)
        original_size_f / (@as(f64, @floatFromInt(avg_compress_time)) / 1_000_000_000.0) / (1024.0 * 1024.0)
    else
        0.0;
    const decompress_speed = if (avg_decompress_time > 0)
        original_size_f / (@as(f64, @floatFromInt(avg_decompress_time)) / 1_000_000_000.0) / (1024.0 * 1024.0)
    else
        0.0;

    return BenchmarkResult{
        .name = name,
        .format = "ZIGX (.zigx)",
        .original_size = data.len,
        .compressed_size = compressed_size,
        .compression_ratio = compression_ratio,
        .compression_time_ns = avg_compress_time,
        .decompression_time_ns = avg_decompress_time,
        .compression_speed_mbs = compress_speed,
        .decompression_speed_mbs = decompress_speed,
        .notes = notes,
        .category = category,
    };
}

/// Print results to console with proper table formatting
fn printResults(results: []const BenchmarkResult) void {
    std.debug.print("\n", .{});
    std.debug.print("=" ** 120, .{});
    std.debug.print("\n", .{});
    std.debug.print("                                    ZIGX COMPRESSION BENCHMARK RESULTS\n", .{});
    std.debug.print("=" ** 120, .{});
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
        std.debug.print("-" ** 120, .{});
        std.debug.print("\n", .{});

        // Header row - clear column names
        std.debug.print("{s:<28} {s:>10} {s:>10} {s:>12} {s:>10} {s:>10} {s:<18}\n", .{
            "Benchmark",
            "Original",
            "Output",
            "Compressed%",
            "Comp MB/s",
            "Decomp MB/s",
            "Notes",
        });
        // Sub-header showing direction (lower/higher = better)
        std.debug.print("{s:<28} {s:>10} {s:>10} {s:>12} {s:>10} {s:>10} {s:<18}\n", .{
            "",
            "(bytes)",
            "(lower)",
            "(higher)",
            "(higher)",
            "(higher)",
            "",
        });
        std.debug.print("-" ** 120, .{});
        std.debug.print("\n", .{});

        for (results) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                std.debug.print("{s:<28} {d:>10} {d:>10} {d:>11.1}% {d:>10.1} {d:>10.1}   {s:<18}\n", .{
                    r.name,
                    r.original_size,
                    r.compressed_size,
                    r.compression_ratio,
                    r.compression_speed_mbs,
                    r.decompression_speed_mbs,
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
    avg_compress_speed: f64,
    avg_decompress_speed: f64,
    best_ratio: f64,
    best_ratio_name: []const u8,
    best_compress_speed: f64,
    best_compress_name: []const u8,
    best_decompress_speed: f64,
    best_decompress_name: []const u8,
    total_original: u64,
    total_compressed: u64,
} {
    var total_ratio: f64 = 0;
    var total_compress: f64 = 0;
    var total_decompress: f64 = 0;
    var count: usize = 0;
    var total_original: u64 = 0;
    var total_compressed: u64 = 0;

    var best_ratio: f64 = -1000; // Start low since higher saved % = better
    var best_ratio_name: []const u8 = "";
    var best_compress_speed: f64 = 0;
    var best_compress_name: []const u8 = "";
    var best_decompress_speed: f64 = 0;
    var best_decompress_name: []const u8 = "";

    for (results) |r| {
        total_ratio += r.compression_ratio;
        total_compress += r.compression_speed_mbs;
        total_decompress += r.decompression_speed_mbs;
        total_original += r.original_size;
        total_compressed += r.compressed_size;
        count += 1;

        // Higher saved % = better compression, so find maximum
        if (r.compression_ratio > best_ratio) {
            best_ratio = r.compression_ratio;
            best_ratio_name = r.name;
        }
        if (r.compression_speed_mbs > best_compress_speed) {
            best_compress_speed = r.compression_speed_mbs;
            best_compress_name = r.name;
        }
        if (r.decompression_speed_mbs > best_decompress_speed) {
            best_decompress_speed = r.decompression_speed_mbs;
            best_decompress_name = r.name;
        }
    }

    const n: f64 = @floatFromInt(count);
    return .{
        .avg_ratio = if (count > 0) total_ratio / n else 0,
        .avg_compress_speed = if (count > 0) total_compress / n else 0,
        .avg_decompress_speed = if (count > 0) total_decompress / n else 0,
        .best_ratio = best_ratio,
        .best_ratio_name = best_ratio_name,
        .best_compress_speed = best_compress_speed,
        .best_compress_name = best_compress_name,
        .best_decompress_speed = best_decompress_speed,
        .best_decompress_name = best_decompress_name,
        .total_original = total_original,
        .total_compressed = total_compressed,
    };
}

/// Write fully dynamic Markdown report
fn writeMarkdownReport(results: []const BenchmarkResult, allocator: std.mem.Allocator) !void {
    const file = std.fs.cwd().createFile("benchmark-results.md", .{}) catch {
        std.debug.print("Warning: Could not create benchmark-results.md\n", .{});
        return;
    };
    defer file.close();

    const stats = calculateStats(results);

    // Header with dynamic environment info
    _ = try file.write("# ZIGX Compression Benchmark Results\n\n");
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
        \\- **Compression Algorithm:** Zstandard (zstd) v{d}
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
        zigx.compression.VERSION,
    }) catch "";
    _ = try file.write(env_info);

    // Algorithm description
    _ = try file.write("## Algorithm\n\n");
    _ = try file.write("| Format | Algorithm | Implementation | Dependencies |\n");
    _ = try file.write("|:-------|:----------|:---------------|:-------------|\n");
    _ = try file.write("| **ZIGX (.zigx)** | Zstandard (zstd) | zstd.zig (C bindings) | zstd C library |\n\n");

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

        _ = try file.write("| Benchmark | Original | Output | Compressed % | Comp Speed | Decomp Speed | Notes |\n");
        _ = try file.write("|:----------|----------:|-------:|-------------:|-----------:|-------------:|:------|\n");
        _ = try file.write("| | *(bytes)* | *(lower=better)* | *(higher=better)* | *(higher=better)* | *(higher=better)* | |\n");

        for (results) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                var line_buf: [512]u8 = undefined;
                const line = std.fmt.bufPrint(&line_buf, "| {s} | {d} B | {d} B | {d:.1}% | {d:.1} MB/s | {d:.1} MB/s | {s} |\n", .{
                    r.name,
                    r.original_size,
                    r.compressed_size,
                    r.compression_ratio,
                    r.compression_speed_mbs,
                    r.decompression_speed_mbs,
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
        \\| Best Compressed % | {d:.1}% | {s} |
        \\| Average Compressed % | {d:.1}% | - |
        \\| Average Compression Speed | {d:.1} MB/s | {s} ({d:.1} MB/s) |
        \\| Average Decompression Speed | {d:.1} MB/s | {s} ({d:.1} MB/s) |
        \\| Total Data Processed | {d} bytes | - |
        \\| Total Output Size | {d} bytes | - |
        \\
        \\
    , .{
        stats.best_ratio,
        stats.best_ratio_name,
        stats.avg_ratio,
        stats.avg_compress_speed,
        stats.best_compress_name,
        stats.best_compress_speed,
        stats.avg_decompress_speed,
        stats.best_decompress_name,
        stats.best_decompress_speed,
        stats.total_original,
        stats.total_compressed,
    }) catch "";
    _ = try file.write(summary);

    // Key features
    _ = try file.write("\n## Key Features of ZIGX\n\n");

    const features = std.fmt.bufPrint(&summary_buf,
        \\1. **Zstandard Compression** - Industry-leading zstd algorithm via Zig bindings
        \\2. **Excellent on Repetitive Data** - {d:.1}% compressed on log files (best case)
        \\3. **Fast Compression** - {d:.1} MB/s average compression speed
        \\4. **Fast Decompression** - {d:.1} MB/s average decompression speed
        \\5. **Cross-Platform** - Tested on {s}/{s}, supports all Zig platforms
        \\6. **Security** - SHA-256 checksums for payload verification
        \\7. **Compact Format** - Only {d} bytes header overhead
        \\8. **Versioned** - Format v0x{X:0>4} for compatibility
        \\
        \\
    , .{
        stats.best_ratio,
        stats.avg_compress_speed,
        stats.avg_decompress_speed,
        @tagName(builtin.os.tag),
        @tagName(builtin.cpu.arch),
        zigx.HEADER_SIZE,
        zigx.FORMAT_VERSION,
    }) catch "";
    _ = try file.write(features);

    // Conclusion
    _ = try file.write("## Conclusion\n\n");

    const conclusion = std.fmt.bufPrint(&summary_buf,
        \\ZIGX achieved **{d:.1}%** best compression with **{d:.1} MB/s** average compression
        \\and **{d:.1} MB/s** average decompression speeds on {s} {s}.
        \\
        \\- **Best compression:** {d:.1}% compressed on "{s}"
        \\- **Fastest compression:** {d:.1} MB/s on "{s}"
        \\- **Fastest decompression:** {d:.1} MB/s on "{s}"
        \\
        \\ZIGX uses Zstandard (zstd) compression via Zig bindings, providing excellent compression
        \\especially on repetitive data (log files, configs) with fast compression speeds.
        \\
        \\
    , .{
        stats.best_ratio,
        stats.avg_compress_speed,
        stats.avg_decompress_speed,
        @tagName(builtin.os.tag),
        @tagName(builtin.cpu.arch),
        stats.best_ratio,
        stats.best_ratio_name,
        stats.best_compress_speed,
        stats.best_compress_name,
        stats.best_decompress_speed,
        stats.best_decompress_name,
    }) catch "";
    _ = try file.write(conclusion);

    _ = try file.write("---\n");
    _ = try file.write("*Generated dynamically by ZIGX Benchmark Suite*\n");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var results: std.ArrayListUnmanaged(BenchmarkResult) = .empty;
    defer results.deinit(allocator);

    std.debug.print("ZIGX Compression Benchmark\n", .{});
    std.debug.print("==========================\n", .{});
    std.debug.print("Version: {s} | Format: 0x{X:0>4} | Algorithm: v{d}\n\n", .{
        zigx.VERSION,
        zigx.FORMAT_VERSION,
        zigx.COMPRESSION_VERSION,
    });

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
    // Category: All Compression Levels (zstd 0-22)
    // ========================================
    std.debug.print("Running compression level benchmarks (all zstd levels 0-22)...\n", .{});

    // Level 0 - No compression (store)
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .none,
        "ZIGX Level 0 (64KB text)",
        "zstd 0 (store)",
        "All Compression Levels (zstd 0-22)",
    ));

    // Level 1 - Fast
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .fast,
        "ZIGX Level 1 (64KB text)",
        "zstd 1 (fast)",
        "All Compression Levels (zstd 0-22)",
    ));

    // Level 2
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .level_2,
        "ZIGX Level 2 (64KB text)",
        "zstd 2",
        "All Compression Levels (zstd 0-22)",
    ));

    // Level 3 - Default
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .default,
        "ZIGX Level 3 (64KB text)",
        "zstd 3 (default)",
        "All Compression Levels (zstd 0-22)",
    ));

    // Level 4
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .level_4,
        "ZIGX Level 4 (64KB text)",
        "zstd 4",
        "All Compression Levels (zstd 0-22)",
    ));

    // Level 5
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .level_5,
        "ZIGX Level 5 (64KB text)",
        "zstd 5",
        "All Compression Levels (zstd 0-22)",
    ));

    // Level 6
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .level_6,
        "ZIGX Level 6 (64KB text)",
        "zstd 6",
        "All Compression Levels (zstd 0-22)",
    ));

    // Level 7
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .level_7,
        "ZIGX Level 7 (64KB text)",
        "zstd 7",
        "All Compression Levels (zstd 0-22)",
    ));

    // Level 8
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .level_8,
        "ZIGX Level 8 (64KB text)",
        "zstd 8",
        "All Compression Levels (zstd 0-22)",
    ));

    // Level 9
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .level_9,
        "ZIGX Level 9 (64KB text)",
        "zstd 9",
        "All Compression Levels (zstd 0-22)",
    ));

    // Level 10
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .level_10,
        "ZIGX Level 10 (64KB text)",
        "zstd 10",
        "All Compression Levels (zstd 0-22)",
    ));

    // Level 11
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .level_11,
        "ZIGX Level 11 (64KB text)",
        "zstd 11",
        "All Compression Levels (zstd 0-22)",
    ));

    // Level 12
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .level_12,
        "ZIGX Level 12 (64KB text)",
        "zstd 12",
        "All Compression Levels (zstd 0-22)",
    ));

    // Level 13
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .level_13,
        "ZIGX Level 13 (64KB text)",
        "zstd 13",
        "All Compression Levels (zstd 0-22)",
    ));

    // Level 14
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .level_14,
        "ZIGX Level 14 (64KB text)",
        "zstd 14",
        "All Compression Levels (zstd 0-22)",
    ));

    // Level 15
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .level_15,
        "ZIGX Level 15 (64KB text)",
        "zstd 15",
        "All Compression Levels (zstd 0-22)",
    ));

    // Level 16
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .level_16,
        "ZIGX Level 16 (64KB text)",
        "zstd 16",
        "All Compression Levels (zstd 0-22)",
    ));

    // Level 17
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .level_17,
        "ZIGX Level 17 (64KB text)",
        "zstd 17",
        "All Compression Levels (zstd 0-22)",
    ));

    // Level 18
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .level_18,
        "ZIGX Level 18 (64KB text)",
        "zstd 18",
        "All Compression Levels (zstd 0-22)",
    ));

    // Level 19 - Best
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .best,
        "ZIGX Level 19 (64KB text)",
        "zstd 19 (best)",
        "All Compression Levels (zstd 0-22)",
    ));

    // Level 20
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .level_20,
        "ZIGX Level 20 (64KB text)",
        "zstd 20",
        "All Compression Levels (zstd 0-22)",
    ));

    // Level 21
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .level_21,
        "ZIGX Level 21 (64KB text)",
        "zstd 21",
        "All Compression Levels (zstd 0-22)",
    ));

    // Level 22 - Maximum
    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .level_22,
        "ZIGX Level 22 (64KB text)",
        "zstd 22 (max)",
        "All Compression Levels (zstd 0-22)",
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
    ));

    try results.append(allocator, try runZigxBenchmark(
        allocator,
        binary_data,
        .default,
        "Binary data (64KB)",
        "Executables",
        "File Type Performance",
    ));

    try results.append(allocator, try runZigxBenchmark(
        allocator,
        repetitive_data,
        .default,
        "Repetitive data (64KB)",
        "Log files",
        "File Type Performance",
    ));

    try results.append(allocator, try runZigxBenchmark(
        allocator,
        random_data,
        .default,
        "Random data (64KB)",
        "Encrypted",
        "File Type Performance",
    ));

    try results.append(allocator, try runZigxBenchmark(
        allocator,
        mixed_data,
        .default,
        "Mixed data (64KB)",
        "Archives",
        "File Type Performance",
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
    ));

    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_medium,
        .default,
        "Medium file (64KB)",
        "Source files",
        "Scalability Test",
    ));

    try results.append(allocator, try runZigxBenchmark(
        allocator,
        text_data_large,
        .default,
        "Large file (1MB)",
        "Large source",
        "Scalability Test",
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
    ));

    // Print results to console
    printResults(results.items);

    // Write dynamic Markdown report
    std.debug.print("Writing benchmark-results.md...\n", .{});
    try writeMarkdownReport(results.items, allocator);

    // Final summary with dynamic stats
    const stats = calculateStats(results.items);
    std.debug.print("\n", .{});
    std.debug.print("=" ** 80, .{});
    std.debug.print("\n", .{});
    std.debug.print("[OK] Benchmarks completed successfully!\n", .{});
    std.debug.print("     ZIGX Average Compressed: {d:.1}% (higher = better)\n", .{stats.avg_ratio});
    std.debug.print("     ZIGX Best Compressed: {d:.1}% ({s})\n", .{ stats.best_ratio, stats.best_ratio_name });
    std.debug.print("     ZIGX Avg Compress Speed: {d:.1} MB/s (higher = faster)\n", .{stats.avg_compress_speed});
    std.debug.print("     ZIGX Avg Decompress Speed: {d:.1} MB/s (higher = faster)\n", .{stats.avg_decompress_speed});
    std.debug.print("     Results written to: benchmark-results.md\n", .{});
    std.debug.print("=" ** 80, .{});
    std.debug.print("\n\n", .{});
}
