const std = @import("std");
const zigx = @import("zigx");
const builtin = @import("builtin");

const CompressionLevel = zigx.CompressionLevel;

/// Benchmark results structure with all dynamic data
const BenchmarkResult = struct {
    name: []const u8,
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

/// Run compression benchmark with accurate timing
fn runCompressionBenchmark(
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
        const result = try zigx.compression.compressAdvanced(data, allocator, level);
        defer allocator.free(result);
        const decompressed = try zigx.compression.decompress(result, allocator);
        defer allocator.free(decompressed);
    }

    // Benchmark iterations
    for (0..ITERATIONS) |_| {
        var timer = try std.time.Timer.start();

        const result = try zigx.compression.compressAdvanced(data, allocator, level);
        defer allocator.free(result);

        total_compress_time += timer.read();
        compressed_size = result.len;

        // Benchmark decompression
        timer.reset();
        const decompressed = try zigx.compression.decompress(result, allocator);
        defer allocator.free(decompressed);

        total_decompress_time += timer.read();
    }

    const avg_compress_time = total_compress_time / ITERATIONS;
    const avg_decompress_time = total_decompress_time / ITERATIONS;

    const original_size_f: f64 = @floatFromInt(data.len);
    const compressed_size_f: f64 = @floatFromInt(compressed_size);

    // Calculate metrics
    const compression_ratio = if (compressed_size > 0) (1.0 - compressed_size_f / original_size_f) * 100.0 else 0.0;
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

/// Print results to console
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
        std.debug.print("{s:<35} {s:>12} {s:>12} {s:>10} {s:>12} {s:>12} {s:>15}\n", .{
            "Benchmark",
            "Original",
            "Compressed",
            "Ratio",
            "Comp MB/s",
            "Decomp MB/s",
            "Notes",
        });
        std.debug.print("-" ** 120, .{});
        std.debug.print("\n", .{});

        for (results) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                std.debug.print("{s:<35} {d:>12} {d:>12} {d:>9.1}% {d:>12.1} {d:>12.1} {s:>15}\n", .{
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

    var best_ratio: f64 = -1000;
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
        \\- **Compression Algorithm:** LZ77+RLE v{d}
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

    // Dynamic algorithm description
    _ = try file.write("## Compression Algorithm\n\n");
    _ = try file.write("ZIGX uses a hybrid compression approach:\n\n");

    const algo_info = std.fmt.bufPrint(&buf,
        \\- **Window Size:** 64 KB (LZ77 sliding window)
        \\- **Hash Chain:** 32 KB (match finding acceleration)
        \\- **Minimum Match:** 3 bytes
        \\- **Maximum Match:** 258 bytes
        \\- **Checksum:** SHA-256 for integrity verification
        \\- **Header Size:** {d} bytes
        \\
        \\
    , .{zigx.HEADER_SIZE}) catch "";
    _ = try file.write(algo_info);

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

        _ = try file.write("| Benchmark | Original | Compressed | Ratio | Comp Speed | Decomp Speed | Notes |\n");
        _ = try file.write("|:----------|----------:|-----------:|------:|-----------:|-------------:|:------|\n");

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

    // Dynamic performance summary
    _ = try file.write("\n## Performance Summary\n\n");

    var summary_buf: [1024]u8 = undefined;
    const summary = std.fmt.bufPrint(&summary_buf,
        \\| Metric | Value | Best Performer |
        \\|:-------|------:|:---------------|
        \\| Average Compression Ratio | {d:.1}% | {s} ({d:.1}%) |
        \\| Average Compression Speed | {d:.1} MB/s | {s} ({d:.1} MB/s) |
        \\| Average Decompression Speed | {d:.1} MB/s | {s} ({d:.1} MB/s) |
        \\| Total Data Processed | {d} bytes | - |
        \\| Total Compressed Size | {d} bytes | - |
        \\
        \\
    , .{
        stats.avg_ratio,
        stats.best_ratio_name,
        stats.best_ratio,
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

    // Dynamic format comparison based on measured results
    _ = try file.write("\n## Format Comparison (Measured vs Industry Standards)\n\n");
    _ = try file.write("Based on the benchmark results, here's how ZIGX compares:\n\n");
    _ = try file.write("| Format | ZIGX Measured | Industry Typical | Speed Class | Dependencies |\n");
    _ = try file.write("|:-------|-------------:|:-----------------|:------------|:-------------|\n");

    // Calculate ZIGX measured values dynamically
    var zigx_text_ratio: f64 = 0;
    var text_count: usize = 0;

    for (results) |r| {
        if (std.mem.indexOf(u8, r.name, "Text") != null or
            std.mem.indexOf(u8, r.name, "text") != null or
            std.mem.indexOf(u8, r.name, "BEST") != null or
            std.mem.indexOf(u8, r.name, "DEFAULT") != null)
        {
            zigx_text_ratio += r.compression_ratio;
            text_count += 1;
        }
    }
    if (text_count > 0) {
        zigx_text_ratio /= @floatFromInt(text_count);
    }

    // Dynamic comparison table row for ZIGX
    var comp_buf: [256]u8 = undefined;
    const zigx_row = std.fmt.bufPrint(&comp_buf, "| **ZIGX (.zigx)** | {d:.1}% | {d:.0}-{d:.0}% | {d:.0} MB/s | None (Pure Zig) |\n", .{
        stats.avg_ratio,
        @max(0, stats.avg_ratio - 10),
        stats.best_ratio,
        stats.avg_compress_speed,
    }) catch "";
    _ = try file.write(zigx_row);

    // Reference formats
    _ = try file.write("| ZIP (.zip) | - | 60-70% | Medium | zlib |\n");
    _ = try file.write("| GZIP (.tar.gz) | - | 60-70% | Medium | zlib |\n");
    _ = try file.write("| 7-Zip (.7z) | - | 70-80% | Slow | lzma |\n");
    _ = try file.write("| LZ4 (.lz4) | - | 50-60% | Very Fast | lz4 |\n");
    _ = try file.write("| Zstd (.zst) | - | 65-75% | Fast | zstd |\n\n");

    // Dynamic key advantages based on measured performance
    _ = try file.write("## Key Advantages of ZIGX\n\n");

    const advantages = std.fmt.bufPrint(&summary_buf,
        \\Based on the measured benchmark results:
        \\
        \\1. **Zero Dependencies** - Pure Zig implementation, no external libraries
        \\2. **Cross-Platform** - Tested on {s}/{s}, supports all Zig platforms
        \\3. **Fast Decompression** - {d:.1} MB/s average decompression speed
        \\4. **Competitive Ratio** - {d:.1}% average, up to {d:.1}% on optimal data
        \\5. **Security** - SHA-256 checksums for payload verification
        \\6. **Compact Format** - Only {d} bytes header overhead
        \\7. **Versioned** - Format v0x{X:0>4} for compatibility
        \\
        \\
    , .{
        @tagName(builtin.os.tag),
        @tagName(builtin.cpu.arch),
        stats.avg_decompress_speed,
        stats.avg_ratio,
        stats.best_ratio,
        zigx.HEADER_SIZE,
        zigx.FORMAT_VERSION,
    }) catch "";
    _ = try file.write(advantages);

    // Dynamic conclusion
    _ = try file.write("## Conclusion\n\n");

    const conclusion = std.fmt.bufPrint(&summary_buf,
        \\ZIGX achieved **{d:.1}%** average compression ratio with **{d:.1} MB/s** compression
        \\and **{d:.1} MB/s** decompression speeds on {s} {s}.
        \\
        \\Best compression: **{d:.1}%** on "{s}"
        \\Fastest compression: **{d:.1} MB/s** on "{s}"
        \\Fastest decompression: **{d:.1} MB/s** on "{s}"
        \\
        \\The pure Zig implementation ensures portability across all platforms without external dependencies.
        \\
        \\
    , .{
        stats.avg_ratio,
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

    var results: std.ArrayList(BenchmarkResult) = .{};
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

    // Category: ZIGX Compression Levels
    std.debug.print("Running compression level benchmarks...\n", .{});

    try results.append(allocator, try runCompressionBenchmark(
        allocator,
        text_data_medium,
        .best,
        "ZIGX BEST (64KB text)",
        "Max compression",
        "ZIGX Compression Levels",
    ));

    try results.append(allocator, try runCompressionBenchmark(
        allocator,
        text_data_medium,
        .default,
        "ZIGX DEFAULT (64KB text)",
        "Balanced",
        "ZIGX Compression Levels",
    ));

    try results.append(allocator, try runCompressionBenchmark(
        allocator,
        text_data_medium,
        .fast,
        "ZIGX FAST (64KB text)",
        "Speed priority",
        "ZIGX Compression Levels",
    ));

    try results.append(allocator, try runCompressionBenchmark(
        allocator,
        text_data_medium,
        .none,
        "ZIGX STORE (64KB text)",
        "No compression",
        "ZIGX Compression Levels",
    ));

    // Category: File Type Performance
    std.debug.print("Running file type benchmarks...\n", .{});

    try results.append(allocator, try runCompressionBenchmark(
        allocator,
        text_data_medium,
        .default,
        "Text data (64KB)",
        "Source code",
        "File Type Performance",
    ));

    try results.append(allocator, try runCompressionBenchmark(
        allocator,
        binary_data,
        .default,
        "Binary data (64KB)",
        "Executables",
        "File Type Performance",
    ));

    try results.append(allocator, try runCompressionBenchmark(
        allocator,
        repetitive_data,
        .default,
        "Repetitive data (64KB)",
        "Log files",
        "File Type Performance",
    ));

    try results.append(allocator, try runCompressionBenchmark(
        allocator,
        random_data,
        .default,
        "Random data (64KB)",
        "Encrypted",
        "File Type Performance",
    ));

    try results.append(allocator, try runCompressionBenchmark(
        allocator,
        mixed_data,
        .default,
        "Mixed data (64KB)",
        "Archives",
        "File Type Performance",
    ));

    // Category: Scalability Test
    std.debug.print("Running scalability benchmarks...\n", .{});

    try results.append(allocator, try runCompressionBenchmark(
        allocator,
        text_data_small,
        .default,
        "Small file (1KB)",
        "Config files",
        "Scalability Test",
    ));

    try results.append(allocator, try runCompressionBenchmark(
        allocator,
        text_data_medium,
        .default,
        "Medium file (64KB)",
        "Source files",
        "Scalability Test",
    ));

    try results.append(allocator, try runCompressionBenchmark(
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

    try results.append(allocator, try runCompressionBenchmark(
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
    std.debug.print("=" ** 60, .{});
    std.debug.print("\n", .{});
    std.debug.print("[OK] Benchmarks completed successfully!\n", .{});
    std.debug.print("     Average ratio: {d:.1}%\n", .{stats.avg_ratio});
    std.debug.print("     Best ratio: {d:.1}% ({s})\n", .{ stats.best_ratio, stats.best_ratio_name });
    std.debug.print("     Avg compress speed: {d:.1} MB/s\n", .{stats.avg_compress_speed});
    std.debug.print("     Avg decompress speed: {d:.1} MB/s\n", .{stats.avg_decompress_speed});
    std.debug.print("     Results written to: benchmark-results.md\n", .{});
    std.debug.print("=" ** 60, .{});
    std.debug.print("\n\n", .{});
}
