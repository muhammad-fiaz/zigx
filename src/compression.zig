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
    DictionaryError,
    WindowSizeExceeded,
    StreamingError,
};

/// Dictionary for improved compression of similar data
pub const Dictionary = struct {
    data: []const u8,
    id: u32,
    allocator: ?Allocator,
    owned: bool,

    /// Create a dictionary from training data
    pub fn train(samples: []const []const u8, dict_size: usize, allocator: Allocator) !Dictionary {
        if (samples.len == 0) return error.InvalidData;

        // Calculate total size and create sample sizes array
        var total_size: usize = 0;
        for (samples) |sample| total_size += sample.len;

        const combined = try allocator.alloc(u8, total_size);
        defer allocator.free(combined);

        const sizes = try allocator.alloc(usize, samples.len);
        defer allocator.free(sizes);

        var offset: usize = 0;
        for (samples, 0..) |sample, i| {
            @memcpy(combined[offset..][0..sample.len], sample);
            sizes[i] = sample.len;
            offset += sample.len;
        }

        const dict_buf = try allocator.alloc(u8, dict_size);
        errdefer allocator.free(dict_buf);

        const actual_size = zstd.c.ZDICT_trainFromBuffer(
            dict_buf.ptr,
            dict_size,
            combined.ptr,
            sizes.ptr,
            @intCast(samples.len),
        );

        if (zstd.c.ZSTD_isError(actual_size) != 0) {
            allocator.free(dict_buf);
            return CompressionError.DictionaryError;
        }

        // Calculate dictionary ID from content
        const id = utils.crc32(dict_buf[0..actual_size]);

        return Dictionary{
            .data = dict_buf[0..actual_size],
            .id = id,
            .allocator = allocator,
            .owned = true,
        };
    }

    /// Create a dictionary from pre-built data
    pub fn fromData(data: []const u8, allocator: ?Allocator) Dictionary {
        return .{
            .data = data,
            .id = utils.crc32(data),
            .allocator = allocator,
            .owned = false,
        };
    }

    pub fn deinit(self: *Dictionary) void {
        if (self.owned) {
            if (self.allocator) |alloc| {
                alloc.free(self.data);
            }
        }
    }
};

/// Advanced compression options
pub const AdvancedOptions = struct {
    /// Compression level
    level: config.CompressionLevel = .default,
    /// Dictionary for improved compression
    dictionary: ?*const Dictionary = null,
    /// Enable long-distance matching (better for large files)
    long_distance_matching: bool = false,
    /// Window log (higher = more memory, better compression for large files)
    window_log: ?u5 = null,
    /// Enable content checksum in zstd frame
    content_checksum: bool = true,
    /// Enable multi-threaded compression (0 = auto, 1 = single-threaded)
    threads: u8 = 0,
    /// Target size hint (0 = no limit)
    target_size: usize = 0,
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
const FLAG_DICTIONARY: u8 = 0x08;
const FLAG_LONG_DISTANCE: u8 = 0x10;

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
    dictionary_used: bool = false,
    content_type: ContentType = .unknown,

    pub fn ratio(self: CompressionStats) f64 {
        if (self.original_size == 0) return 1.0;
        return @as(f64, @floatFromInt(self.compressed_size)) / @as(f64, @floatFromInt(self.original_size));
    }

    pub fn savedPercent(self: CompressionStats) f64 {
        return (1.0 - self.ratio()) * 100.0;
    }

    pub fn format(self: CompressionStats) CompressionStatsFormatted {
        return .{
            .ratio = self.ratio(),
            .saved_percent = self.savedPercent(),
            .original = utils.formatSize(self.original_size),
            .compressed = utils.formatSize(self.compressed_size),
        };
    }
};

/// Formatted compression stats for display
pub const CompressionStatsFormatted = struct {
    ratio: f64,
    saved_percent: f64,
    original: utils.SizeUnit,
    compressed: utils.SizeUnit,
};

/// Content type hint for adaptive compression
pub const ContentType = enum(u8) {
    unknown = 0,
    text = 1,
    binary = 2,
    source_code = 3,
    json = 4,
    xml = 5,
    image = 6,
    audio = 7,
    video = 8,
    archive = 9,
    executable = 10,
    config = 11,

    /// Detect content type from data
    pub fn detect(data: []const u8) ContentType {
        if (data.len == 0) return .unknown;

        // Check magic bytes for common formats
        if (data.len >= 4) {
            // PNG
            if (data[0] == 0x89 and data[1] == 'P' and data[2] == 'N' and data[3] == 'G') return .image;
            // JPEG
            if (data[0] == 0xFF and data[1] == 0xD8) return .image;
            // GIF
            if (std.mem.startsWith(u8, data, "GIF8")) return .image;
            // ZIP/JAR
            if (data[0] == 'P' and data[1] == 'K') return .archive;
            // GZIP
            if (data[0] == 0x1F and data[1] == 0x8B) return .archive;
            // ELF
            if (data[0] == 0x7F and std.mem.startsWith(u8, data[1..], "ELF")) return .executable;
            // PE (Windows exe)
            if (data[0] == 'M' and data[1] == 'Z') return .executable;
        }

        // Check for JSON
        const trimmed = std.mem.trim(u8, data[0..@min(data.len, 256)], " \t\n\r");
        if (trimmed.len > 0 and (trimmed[0] == '{' or trimmed[0] == '[')) return .json;

        // Check for XML
        if (std.mem.startsWith(u8, trimmed, "<?xml") or std.mem.startsWith(u8, trimmed, "<")) return .xml;

        // Analyze byte distribution for text vs binary
        var printable: usize = 0;
        var null_count: usize = 0;
        const sample_size = @min(data.len, 4096);

        if (sample_size == 0) return .unknown;

        for (data[0..sample_size]) |byte| {
            if (byte == 0) null_count += 1;
            if (byte >= 32 and byte < 127 or byte == '\n' or byte == '\r' or byte == '\t') {
                printable += 1;
            }
        }

        // Binary if has null bytes
        if (null_count > sample_size / 100) return .binary;

        // Text if mostly printable (use division to avoid overflow)
        if (printable * 100 / sample_size > 90) {
            // Check for source code patterns
            if (std.mem.indexOf(u8, data[0..sample_size], "const ") != null or
                std.mem.indexOf(u8, data[0..sample_size], "fn ") != null or
                std.mem.indexOf(u8, data[0..sample_size], "pub ") != null or
                std.mem.indexOf(u8, data[0..sample_size], "import ") != null or
                std.mem.indexOf(u8, data[0..sample_size], "function ") != null or
                std.mem.indexOf(u8, data[0..sample_size], "class ") != null or
                std.mem.indexOf(u8, data[0..sample_size], "#include") != null)
            {
                return .source_code;
            }
            return .text;
        }

        return .binary;
    }

    /// Get recommended compression level for content type
    pub fn recommendedLevel(self: ContentType) config.CompressionLevel {
        return switch (self) {
            .text, .source_code, .json, .xml, .config => .best,
            .image, .audio, .video, .archive => .fast, // Already compressed
            .binary, .executable => .default,
            .unknown => .default,
        };
    }
};

/// Compress data using the default or specified compression level
pub fn compress(data: []const u8, allocator: Allocator, level: ?config.CompressionLevel) CompressionError![]u8 {
    const comp_level = level orelse config.global.compression.level;
    return compressAdvanced(data, allocator, comp_level);
}

/// Compress with content-aware adaptive level selection
pub fn compressAdaptive(data: []const u8, allocator: Allocator) CompressionError![]u8 {
    const content_type = ContentType.detect(data);
    const level = content_type.recommendedLevel();
    return compressAdvanced(data, allocator, level);
}

/// Compress with full advanced options
pub fn compressWithOptions(data: []const u8, allocator: Allocator, options: AdvancedOptions) CompressionError![]u8 {
    if (options.level == .none) {
        return compressStore(data, allocator);
    }

    const max_compressed_size = zstd.c.ZSTD_compressBound(data.len);
    if (max_compressed_size == 0) {
        return CompressionError.CompressionFailed;
    }

    const total_size = HEADER_SIZE + max_compressed_size;
    const output = allocator.alloc(u8, total_size) catch {
        return CompressionError.OutOfMemory;
    };
    errdefer allocator.free(output);

    // Write header
    @memcpy(output[0..4], &MAGIC);
    output[4] = VERSION;

    var flags: u8 = FLAG_ZSTD;
    if (options.content_checksum) flags |= FLAG_CHECKSUM;
    if (options.dictionary != null) flags |= FLAG_DICTIONARY;
    output[5] = flags;

    std.mem.writeInt(u64, output[6..14], data.len, .little);
    const checksum = utils.crc32(data);
    std.mem.writeInt(u32, output[14..18], checksum, .little);

    // Create compression context for advanced options
    const cctx = zstd.c.ZSTD_createCCtx();
    if (cctx == null) return CompressionError.OutOfMemory;
    defer _ = zstd.c.ZSTD_freeCCtx(cctx);

    // Set compression parameters
    _ = zstd.c.ZSTD_CCtx_setParameter(cctx, zstd.c.ZSTD_c_compressionLevel, options.level.toZstdLevel());

    if (options.long_distance_matching) {
        _ = zstd.c.ZSTD_CCtx_setParameter(cctx, zstd.c.ZSTD_c_enableLongDistanceMatching, 1);
    }

    if (options.window_log) |wlog| {
        _ = zstd.c.ZSTD_CCtx_setParameter(cctx, zstd.c.ZSTD_c_windowLog, @intCast(wlog));
    }

    if (options.content_checksum) {
        _ = zstd.c.ZSTD_CCtx_setParameter(cctx, zstd.c.ZSTD_c_checksumFlag, 1);
    }

    // Load dictionary if provided
    if (options.dictionary) |dict| {
        const dict_result = zstd.c.ZSTD_CCtx_loadDictionary(cctx, dict.data.ptr, dict.data.len);
        if (zstd.c.ZSTD_isError(dict_result) != 0) {
            allocator.free(output);
            return CompressionError.DictionaryError;
        }
    }

    // Compress
    const compressed_size = zstd.c.ZSTD_compress2(
        cctx,
        output[HEADER_SIZE..].ptr,
        max_compressed_size,
        data.ptr,
        data.len,
    );

    if (zstd.c.ZSTD_isError(compressed_size) != 0) {
        allocator.free(output);
        return CompressionError.CompressionFailed;
    }

    const final_size = HEADER_SIZE + compressed_size;
    if (allocator.resize(output, final_size)) {
        return output[0..final_size];
    } else {
        const result = allocator.alloc(u8, final_size) catch {
            allocator.free(output);
            return CompressionError.OutOfMemory;
        };
        @memcpy(result, output[0..final_size]);
        allocator.free(output);
        return result;
    }
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
    total_input: u64 = 0,
    options: AdvancedOptions = .{},

    pub fn init(allocator: Allocator, level: config.CompressionLevel) StreamingCompressor {
        return .{
            .buffer = .empty,
            .level = level,
            .allocator = allocator,
            .options = .{ .level = level },
        };
    }

    pub fn initWithOptions(allocator: Allocator, options: AdvancedOptions) StreamingCompressor {
        return .{
            .buffer = .empty,
            .level = options.level,
            .allocator = allocator,
            .options = options,
        };
    }

    pub fn deinit(self: *StreamingCompressor) void {
        self.buffer.deinit(self.allocator);
    }

    pub fn write(self: *StreamingCompressor, data: []const u8) CompressionError!void {
        self.buffer.appendSlice(self.allocator, data) catch return CompressionError.OutOfMemory;
        self.total_input += data.len;
    }

    pub fn finish(self: *StreamingCompressor) CompressionError![]u8 {
        return compressWithOptions(self.buffer.items, self.allocator, self.options);
    }

    pub fn reset(self: *StreamingCompressor) void {
        self.buffer.clearRetainingCapacity();
        self.total_input = 0;
    }

    pub fn getTotalInput(self: *const StreamingCompressor) u64 {
        return self.total_input;
    }
};

/// Streaming decompressor for incremental decompression
pub const StreamingDecompressor = struct {
    allocator: Allocator,
    total_output: u64 = 0,

    pub fn init(allocator: Allocator) StreamingDecompressor {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *StreamingDecompressor) void {
        _ = self;
    }

    pub fn decompress_data(self: *StreamingDecompressor, data: []const u8) CompressionError![]u8 {
        const result = try decompress(data, self.allocator);
        self.total_output += result.len;
        return result;
    }

    pub fn getTotalOutput(self: *const StreamingDecompressor) u64 {
        return self.total_output;
    }
};

/// Get compression statistics
pub fn getStats(original: []const u8, compressed: []const u8, level: config.CompressionLevel) CompressionStats {
    return .{
        .original_size = original.len,
        .compressed_size = compressed.len,
        .level = level,
        .content_type = ContentType.detect(original),
    };
}

/// Get detailed compression statistics with content analysis
pub fn getDetailedStats(original: []const u8, compressed: []const u8, level: config.CompressionLevel) CompressionStats {
    var stats = getStats(original, compressed, level);

    // Analyze compression patterns
    if (original.len > 0) {
        var i: usize = 0;
        while (i < original.len) {
            const byte = original[i];
            // Count RLE-like runs
            var run_len: usize = 1;
            while (i + run_len < original.len and original[i + run_len] == byte) {
                run_len += 1;
            }
            if (run_len >= 4) {
                stats.rle_runs += 1;
            }
            i += run_len;
        }
    }

    return stats;
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
    var byte_freq: [256]u32 = .{0} ** 256;

    for (data) |byte| {
        byte_freq[byte] += 1;
        if (!seen[byte]) {
            seen[byte] = true;
            unique += 1;
        }
    }

    // Calculate Shannon entropy
    var entropy: f32 = 0.0;
    const n: f32 = @floatFromInt(data.len);
    for (byte_freq) |freq| {
        if (freq > 0) {
            const p: f32 = @as(f32, @floatFromInt(freq)) / n;
            entropy -= p * @log2(p);
        }
    }

    // Normalize entropy (max is 8 for 256 symbols)
    const normalized_entropy = entropy / 8.0;

    // Higher entropy = worse compression
    return 0.1 + normalized_entropy * 0.9; // Range: 0.1 to 1.0
}

/// Analyze data compressibility
pub const CompressibilityAnalysis = struct {
    estimated_ratio: f32,
    content_type: ContentType,
    recommended_level: config.CompressionLevel,
    is_already_compressed: bool,
    has_repetitive_patterns: bool,

    pub fn format(self: CompressibilityAnalysis) []const u8 {
        if (self.is_already_compressed) return "Already compressed - use store mode";
        if (self.has_repetitive_patterns) return "Highly compressible - use best level";
        if (self.estimated_ratio < 0.3) return "Very compressible";
        if (self.estimated_ratio < 0.6) return "Moderately compressible";
        if (self.estimated_ratio < 0.8) return "Slightly compressible";
        return "Low compressibility";
    }
};

/// Analyze data for compressibility
pub fn analyzeCompressibility(data: []const u8) CompressibilityAnalysis {
    const content_type = ContentType.detect(data);
    const estimated_ratio = estimateRatio(data);

    // Check for repetitive patterns
    var has_repetitive: bool = false;
    if (data.len >= 64) {
        var i: usize = 0;
        var long_runs: usize = 0;
        while (i < data.len) {
            var run_len: usize = 1;
            while (i + run_len < data.len and data[i + run_len] == data[i]) {
                run_len += 1;
            }
            if (run_len >= 8) long_runs += 1;
            i += run_len;
        }
        has_repetitive = long_runs > data.len / 256;
    }

    const is_compressed = switch (content_type) {
        .archive, .image, .audio, .video => true,
        else => false,
    };

    return .{
        .estimated_ratio = estimated_ratio,
        .content_type = content_type,
        .recommended_level = if (is_compressed) .none else content_type.recommendedLevel(),
        .is_already_compressed = is_compressed,
        .has_repetitive_patterns = has_repetitive,
    };
}

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
