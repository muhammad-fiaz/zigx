const std = @import("std");
const Allocator = std.mem.Allocator;
const config = @import("config.zig");
const utils = @import("utils.zig");
const zstd = @import("zstd");

pub const CompressionError = error{
    CompressionFailed,
    DecompressionFailed,
    InvalidData,
    OutOfMemory,
    UnexpectedEndOfStream,
    InvalidMagic,
    UnsupportedVersion,
    ChecksumMismatch,
    ContentSizeUnknown,
    FileTooLarge,
};

/// Compression Format Version 1 - ZXCM with Zstandard
/// Header: MAGIC(4) + VERSION(1) + FLAGS(1) + ORIG_SIZE(8) + CHECKSUM(4) = 18 bytes
/// This version uses Zstandard (zstd) compression with:
/// - Extremely fast decompression
/// - Excellent compression ratios (better than gzip/deflate)
/// - Support for compression levels 1-22
/// - Built-in frame format with content size
const MAGIC: [4]u8 = .{ 'Z', 'X', 'C', 'M' };
/// Compression algorithm version
pub const VERSION: u8 = 1;
const HEADER_SIZE: usize = 18;

// Flags
const FLAG_NONE: u8 = 0x00;
const FLAG_ZSTD: u8 = 0x01;
const FLAG_CHECKSUM: u8 = 0x04;

// Zstd content size constants (from zstd manual)
const ZSTD_CONTENTSIZE_UNKNOWN: u64 = std.math.maxInt(u64);
const ZSTD_CONTENTSIZE_ERROR: u64 = std.math.maxInt(u64) - 1;

pub const CompressionStats = struct {
    original_size: u64,
    compressed_size: u64,
    level: config.CompressionLevel,
    literals: u64 = 0,
    matches: u64 = 0,
    rle_runs: u64 = 0,

    pub fn ratio(self: CompressionStats) f64 {
        if (self.original_size == 0) return 1.0;
        return @as(f64, @floatFromInt(self.compressed_size)) / @as(f64, @floatFromInt(self.original_size));
    }

    pub fn savedPercent(self: CompressionStats) f64 {
        return (1.0 - self.ratio()) * 100.0;
    }
};

/// Compress data using the default or specified compression level
pub fn compress(data: []const u8, allocator: Allocator, level: ?config.CompressionLevel) CompressionError![]u8 {
    const comp_level = level orelse config.global.compression.level;
    return compressAdvanced(data, allocator, comp_level);
}

/// Compress data with advanced options using Zstandard compression
pub fn compressAdvanced(data: []const u8, allocator: Allocator, level: config.CompressionLevel) CompressionError![]u8 {
    // Handle store mode (no compression)
    if (level == .none) {
        return compressStore(data, allocator);
    }

    // Calculate maximum compressed size
    const max_compressed_size = zstd.c.ZSTD_compressBound(data.len);
    if (max_compressed_size == 0) {
        return CompressionError.CompressionFailed;
    }

    // Allocate output buffer: header + compressed data
    const total_size = HEADER_SIZE + max_compressed_size;
    const output = allocator.alloc(u8, total_size) catch {
        return CompressionError.OutOfMemory;
    };
    errdefer allocator.free(output);

    // Write header
    @memcpy(output[0..4], &MAGIC);
    output[4] = VERSION;
    output[5] = FLAG_ZSTD | FLAG_CHECKSUM;

    // Write original size (8 bytes, little-endian)
    std.mem.writeInt(u64, output[6..14], data.len, .little);

    // Write CRC32 checksum of original data
    const checksum = utils.crc32(data);
    std.mem.writeInt(u32, output[14..18], checksum, .little);

    // Compress using zstd
    const zstd_level = level.toZstdLevel();
    const compressed_size = zstd.c.ZSTD_compress(
        output[HEADER_SIZE..].ptr,
        max_compressed_size,
        data.ptr,
        data.len,
        zstd_level,
    );

    // Check for compression errors
    if (zstd.c.ZSTD_isError(compressed_size) != 0) {
        allocator.free(output);
        return CompressionError.CompressionFailed;
    }

    // Resize to actual size
    const final_size = HEADER_SIZE + compressed_size;
    if (allocator.resize(output, final_size)) {
        return output[0..final_size];
    } else {
        // Resize failed, copy to new buffer
        const result = allocator.alloc(u8, final_size) catch {
            allocator.free(output);
            return CompressionError.OutOfMemory;
        };
        @memcpy(result, output[0..final_size]);
        allocator.free(output);
        return result;
    }
}

/// Store data without compression (for incompressible data)
fn compressStore(data: []const u8, allocator: Allocator) CompressionError![]u8 {
    const output = allocator.alloc(u8, HEADER_SIZE + data.len) catch {
        return CompressionError.OutOfMemory;
    };
    errdefer allocator.free(output);

    // Write header
    @memcpy(output[0..4], &MAGIC);
    output[4] = VERSION;
    output[5] = FLAG_NONE | FLAG_CHECKSUM; // No compression flag

    // Write original size
    std.mem.writeInt(u64, output[6..14], data.len, .little);

    // Write checksum
    const checksum = utils.crc32(data);
    std.mem.writeInt(u32, output[14..18], checksum, .little);

    // Copy data as-is
    @memcpy(output[HEADER_SIZE..], data);

    return output;
}

/// Decompress data compressed with compress() or compressAdvanced()
pub fn decompress(data: []const u8, allocator: Allocator) CompressionError![]u8 {
    // Validate minimum size
    if (data.len < HEADER_SIZE) {
        return CompressionError.InvalidData;
    }

    // Validate magic
    if (!std.mem.eql(u8, data[0..4], &MAGIC)) {
        return CompressionError.InvalidMagic;
    }

    // Check version
    const version = data[4];
    if (version > VERSION) {
        return CompressionError.UnsupportedVersion;
    }

    const flags = data[5];
    const original_size = std.mem.readInt(u64, data[6..14], .little);
    const stored_checksum = std.mem.readInt(u32, data[14..18], .little);

    // Validate original size for 32-bit systems
    const output_size: usize = std.math.cast(usize, original_size) orelse {
        return CompressionError.FileTooLarge;
    };

    // Allocate output buffer
    const output = allocator.alloc(u8, output_size) catch {
        return CompressionError.OutOfMemory;
    };
    errdefer allocator.free(output);

    const compressed_data = data[HEADER_SIZE..];

    // Check if data was stored without compression
    if (flags & FLAG_ZSTD == 0) {
        // Store mode - just copy
        if (compressed_data.len != output_size) {
            allocator.free(output);
            return CompressionError.InvalidData;
        }
        @memcpy(output, compressed_data);
    } else {
        // Decompress using zstd
        const decompressed_size = zstd.c.ZSTD_decompress(
            output.ptr,
            output_size,
            compressed_data.ptr,
            compressed_data.len,
        );

        // Check for decompression errors
        if (zstd.c.ZSTD_isError(decompressed_size) != 0) {
            allocator.free(output);
            return CompressionError.DecompressionFailed;
        }

        // Validate decompressed size matches expected
        if (decompressed_size != output_size) {
            allocator.free(output);
            return CompressionError.InvalidData;
        }
    }

    // Verify checksum if present
    if (flags & FLAG_CHECKSUM != 0) {
        const actual_checksum = utils.crc32(output);
        if (actual_checksum != stored_checksum) {
            allocator.free(output);
            return CompressionError.ChecksumMismatch;
        }
    }

    return output;
}

/// Streaming compressor for incremental compression
pub const StreamingCompressor = struct {
    buffer: std.ArrayList(u8),
    level: config.CompressionLevel,
    allocator: Allocator,

    pub fn init(allocator: Allocator, level: config.CompressionLevel) StreamingCompressor {
        return .{
            .buffer = .empty,
            .level = level,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *StreamingCompressor) void {
        self.buffer.deinit(self.allocator);
    }

    pub fn write(self: *StreamingCompressor, data: []const u8) CompressionError!void {
        self.buffer.appendSlice(self.allocator, data) catch return CompressionError.OutOfMemory;
    }

    pub fn finish(self: *StreamingCompressor) CompressionError![]u8 {
        return compressAdvanced(self.buffer.items, self.allocator, self.level);
    }
};

/// Streaming decompressor for incremental decompression
pub const StreamingDecompressor = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) StreamingDecompressor {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *StreamingDecompressor) void {
        _ = self;
    }

    pub fn decompress_data(self: *StreamingDecompressor, data: []const u8) CompressionError![]u8 {
        return decompress(data, self.allocator);
    }
};

/// Get compression statistics
pub fn getStats(original: []const u8, compressed: []const u8, level: config.CompressionLevel) CompressionStats {
    return .{
        .original_size = original.len,
        .compressed_size = compressed.len,
        .level = level,
    };
}

/// Calculate maximum possible compressed size
pub fn maxCompressedSize(size: usize) usize {
    return HEADER_SIZE + zstd.c.ZSTD_compressBound(size);
}

/// Estimate compression ratio based on data entropy
pub fn estimateRatio(data: []const u8) f32 {
    if (data.len == 0) return 1.0;

    // Count unique bytes as a simple entropy estimate
    var seen: [256]bool = .{false} ** 256;
    var unique: usize = 0;
    for (data) |byte| {
        if (!seen[byte]) {
            seen[byte] = true;
            unique += 1;
        }
    }

    // Higher unique count = higher entropy = worse compression
    const entropy_ratio = @as(f32, @floatFromInt(unique)) / 256.0;
    return 0.1 + entropy_ratio * 0.9; // Range: 0.1 to 1.0
}

// ============================================================================
// Tests
// ============================================================================

test "empty" {
    const allocator = std.testing.allocator;
    const compressed = try compress(&.{}, allocator, null);
    defer allocator.free(compressed);
    const decompressed = try decompress(compressed, allocator);
    defer allocator.free(decompressed);
    try std.testing.expectEqual(@as(usize, 0), decompressed.len);
}

test "roundtrip" {
    const allocator = std.testing.allocator;
    const data = "Hello, Zstandard compression!";
    const compressed = try compress(data, allocator, null);
    defer allocator.free(compressed);
    const decompressed = try decompress(compressed, allocator);
    defer allocator.free(decompressed);
    try std.testing.expectEqualStrings(data, decompressed);
}

test "roundtrip_store" {
    const allocator = std.testing.allocator;
    const data = "Store mode test - no compression";
    const compressed = try compressAdvanced(data, allocator, .none);
    defer allocator.free(compressed);
    const decompressed = try decompress(compressed, allocator);
    defer allocator.free(decompressed);
    try std.testing.expectEqualStrings(data, decompressed);
}

test "roundtrip_best" {
    const allocator = std.testing.allocator;
    const data = "Best compression level test with some repetitive content: " ++
        "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" ++
        "The quick brown fox jumps over the lazy dog. " ** 10;
    const compressed = try compressAdvanced(data, allocator, .best);
    defer allocator.free(compressed);
    const decompressed = try decompress(compressed, allocator);
    defer allocator.free(decompressed);
    try std.testing.expectEqualStrings(data, decompressed);
}

test "repetitive" {
    const allocator = std.testing.allocator;
    // Create highly repetitive data - zstd excels at this
    const data = "ABCD" ** 10000; // 40KB of repetitive data
    const compressed = try compress(data, allocator, .best);
    defer allocator.free(compressed);

    // Zstd should compress this extremely well
    try std.testing.expect(compressed.len < data.len / 10); // At least 90% compression

    const decompressed = try decompress(compressed, allocator);
    defer allocator.free(decompressed);
    try std.testing.expectEqualStrings(data, decompressed);
}

test "code" {
    const allocator = std.testing.allocator;
    const data =
        \\const std = @import("std");
        \\
        \\pub fn main() !void {
        \\    const allocator = std.heap.page_allocator;
        \\    var list = std.ArrayList(u8).init(allocator);
        \\    defer list.deinit();
        \\    try list.append(42);
        \\    std.debug.print("Hello, World!\n", .{});
        \\}
    ;
    const compressed = try compress(data, allocator, .default);
    defer allocator.free(compressed);
    const decompressed = try decompress(compressed, allocator);
    defer allocator.free(decompressed);
    try std.testing.expectEqualStrings(data, decompressed);
}

test "binary" {
    const allocator = std.testing.allocator;
    var data: [1024]u8 = undefined;
    for (&data, 0..) |*byte, i| byte.* = @truncate(i *% 137 +% 42);
    const compressed = try compress(&data, allocator, null);
    defer allocator.free(compressed);
    const decompressed = try decompress(compressed, allocator);
    defer allocator.free(decompressed);
    try std.testing.expectEqualSlices(u8, &data, decompressed);
}

test "streaming" {
    const allocator = std.testing.allocator;
    var compressor = StreamingCompressor.init(allocator, .default);
    defer compressor.deinit();
    try compressor.write("Hello, ");
    try compressor.write("streaming ");
    try compressor.write("world!");
    const compressed = try compressor.finish();
    defer allocator.free(compressed);
    const decompressed = try decompress(compressed, allocator);
    defer allocator.free(decompressed);
    try std.testing.expectEqualStrings("Hello, streaming world!", decompressed);
}

test "checksum" {
    const allocator = std.testing.allocator;
    const compressed = try compress("test data", allocator, null);
    defer allocator.free(compressed);
    try std.testing.expect(compressed[5] & FLAG_CHECKSUM != 0);
}

test "stats" {
    const allocator = std.testing.allocator;
    const data = "Test data for stats" ** 100;
    const compressed = try compress(data, allocator, .default);
    defer allocator.free(compressed);
    const stats = getStats(data, compressed, .default);
    try std.testing.expect(stats.ratio() < 1.0);
    try std.testing.expect(stats.savedPercent() > 0);
}

test "best_better_than_fast" {
    const allocator = std.testing.allocator;
    const data = "The quick brown fox jumps over the lazy dog. " ** 100;

    const fast = try compressAdvanced(data, allocator, .fast);
    defer allocator.free(fast);

    const best = try compressAdvanced(data, allocator, .best);
    defer allocator.free(best);

    // Best should produce smaller or equal output (usually smaller)
    try std.testing.expect(best.len <= fast.len);

    // Both should decompress correctly
    const d1 = try decompress(fast, allocator);
    defer allocator.free(d1);
    const d2 = try decompress(best, allocator);
    defer allocator.free(d2);
    try std.testing.expectEqualStrings(data, d1);
    try std.testing.expectEqualStrings(data, d2);
}

test "large_data" {
    const allocator = std.testing.allocator;
    // Create 1MB of test data
    const data = try allocator.alloc(u8, 1024 * 1024);
    defer allocator.free(data);

    // Fill with semi-random but compressible pattern
    for (data, 0..) |*byte, i| {
        byte.* = @truncate((i % 256) ^ (i / 256));
    }

    const compressed = try compress(data, allocator, .default);
    defer allocator.free(compressed);

    const decompressed = try decompress(compressed, allocator);
    defer allocator.free(decompressed);

    try std.testing.expectEqualSlices(u8, data, decompressed);
}

test "all_levels" {
    const allocator = std.testing.allocator;
    const data = "Test all compression levels work correctly " ** 50;

    const levels = [_]config.CompressionLevel{
        .none,
        .fast,
        .level_4,
        .level_5,
        .level_6,
        .default,
        .level_7,
        .level_8,
        .level_9,
        .best,
    };

    for (levels) |level| {
        const compressed = try compressAdvanced(data, allocator, level);
        defer allocator.free(compressed);

        const decompressed = try decompress(compressed, allocator);
        defer allocator.free(decompressed);

        try std.testing.expectEqualStrings(data, decompressed);
    }
}
