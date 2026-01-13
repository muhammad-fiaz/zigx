const std = @import("std");
const Allocator = std.mem.Allocator;
const config = @import("config.zig");
const utils = @import("utils.zig");

pub const CompressionError = error{
    CompressionFailed,
    DecompressionFailed,
    InvalidData,
    OutOfMemory,
    UnexpectedEndOfStream,
    InvalidMagic,
    UnsupportedVersion,
    ChecksumMismatch,
};

/// Compression Format Version 1 - ZXCM v1
/// Header: MAGIC(4) + VERSION(1) + FLAGS(1) + ORIG_SIZE(4) + CHECKSUM(4) = 14 bytes
/// This version uses LZ77 + RLE hybrid compression with:
/// - 64KB sliding window
/// - Hash chain for match finding
/// - Lazy matching for best compression
/// - CRC32 checksum for integrity
const MAGIC: [4]u8 = .{ 'Z', 'X', 'C', 'M' };
/// Compression algorithm version (from utils)
pub const VERSION: u8 = utils.COMPRESSION_VERSION;
const HEADER_SIZE: usize = 14;

// LZ77 parameters
const WINDOW_BITS: u5 = 16;
const WINDOW_SIZE: usize = 1 << WINDOW_BITS;
const WINDOW_MASK: usize = WINDOW_SIZE - 1;
const MIN_MATCH: usize = 3;
const MAX_MATCH: usize = 258;
const HASH_BITS: u5 = 15;
const HASH_SIZE: usize = 1 << HASH_BITS;

// Token encoding
const LITERAL_FLAG: u8 = 0x00;
const RLE_FLAG: u8 = 0x80;
const MATCH_FLAG: u8 = 0xC0;

// Flags
const FLAG_NONE: u8 = 0x00;
const FLAG_LZ77: u8 = 0x01;
const FLAG_RLE: u8 = 0x02;
const FLAG_CHECKSUM: u8 = 0x04;

pub const CompressionStats = struct {
    original_size: u64,
    compressed_size: u64,
    level: config.CompressionLevel,
    literals: u64,
    matches: u64,
    rle_runs: u64,

    pub fn ratio(self: CompressionStats) f64 {
        if (self.original_size == 0) return 1.0;
        return @as(f64, @floatFromInt(self.compressed_size)) / @as(f64, @floatFromInt(self.original_size));
    }

    pub fn savedPercent(self: CompressionStats) f64 {
        return (1.0 - self.ratio()) * 100.0;
    }
};

fn crc32(data: []const u8) u32 {
    const poly: u32 = 0xEDB88320;
    var crc: u32 = 0xFFFFFFFF;
    for (data) |byte| {
        crc ^= byte;
        inline for (0..8) |_| {
            crc = if (crc & 1 != 0) (crc >> 1) ^ poly else crc >> 1;
        }
    }
    return ~crc;
}

inline fn hash4(data: *const [4]u8) usize {
    const v = std.mem.readInt(u32, data, .little);
    const shift: u5 = @intCast(32 - @as(u6, HASH_BITS));
    return @intCast((v *% 0x1E35A7BD) >> shift);
}

// Level parameters - key fix: lazy is boolean, not threshold
const LevelParams = struct {
    nice: u16,
    chain: u16,
    lazy: bool,

    fn get(level: config.CompressionLevel) LevelParams {
        return switch (level) {
            .none => .{ .nice = 0, .chain = 0, .lazy = false },
            .fast, .level_4 => .{ .nice = 8, .chain = 4, .lazy = false },
            .level_5 => .{ .nice = 16, .chain = 8, .lazy = false },
            .default, .level_6 => .{ .nice = 32, .chain = 32, .lazy = false },
            .level_7 => .{ .nice = 64, .chain = 128, .lazy = true },
            .level_8 => .{ .nice = 128, .chain = 512, .lazy = true },
            .best, .level_9 => .{ .nice = 258, .chain = 4096, .lazy = true },
        };
    }
};

fn findBestMatch(data: []const u8, pos: usize, hash_head: []const u32, hash_chain: []const u32, params: LevelParams) struct { len: usize, dist: usize } {
    if (pos + 4 > data.len or params.chain == 0) return .{ .len = 0, .dist = 0 };

    const h = hash4(data[pos..][0..4]);
    var cur = hash_head[h];
    if (cur == 0) return .{ .len = 0, .dist = 0 };
    cur -= 1;

    const max_dist = @min(pos, WINDOW_SIZE - 1);
    var best_len: usize = MIN_MATCH - 1;
    var best_dist: usize = 0;
    var chain_count: u16 = 0;
    const data_end = data.len;

    while (chain_count < params.chain) : (chain_count += 1) {
        if (cur >= pos) break;
        const dist = pos - cur;
        if (dist > max_dist) break;

        // Quick check: compare first and last bytes (with bounds check)
        const check_pos = pos + best_len;
        const check_cur = cur + best_len;
        if (check_pos < data_end and check_cur < data_end and
            data[cur] == data[pos] and data[check_cur] == data[check_pos])
        {
            var len: usize = 0;
            const max_len = @min(data_end - pos, MAX_MATCH);
            while (len < max_len and cur + len < data_end and data[cur + len] == data[pos + len]) : (len += 1) {}

            if (len > best_len) {
                best_len = len;
                best_dist = dist;
                if (len >= params.nice or len == MAX_MATCH) break;
            }
        }

        const next = hash_chain[cur & WINDOW_MASK];
        if (next == 0) break;
        cur = next - 1;
    }

    return if (best_len >= MIN_MATCH) .{ .len = best_len, .dist = best_dist } else .{ .len = 0, .dist = 0 };
}

pub fn compress(data: []const u8, allocator: Allocator, level: ?config.CompressionLevel) CompressionError![]u8 {
    const comp_level = level orelse config.global.compression.level;
    return compressAdvanced(data, allocator, comp_level);
}

pub fn compressAdvanced(data: []const u8, allocator: Allocator, level: config.CompressionLevel) CompressionError![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);

    const estimated = if (level == .none) HEADER_SIZE + data.len else HEADER_SIZE + data.len / 2 + 64;
    output.ensureTotalCapacity(allocator, estimated) catch return CompressionError.OutOfMemory;

    // Write header
    output.appendSliceAssumeCapacity(&MAGIC);
    output.appendAssumeCapacity(VERSION);
    output.appendAssumeCapacity(if (level == .none) FLAG_NONE else FLAG_LZ77 | FLAG_RLE | FLAG_CHECKSUM);

    var size_buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &size_buf, @intCast(@min(data.len, std.math.maxInt(u32))), .little);
    output.appendSliceAssumeCapacity(&size_buf);

    const checksum = crc32(data);
    var crc_buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &crc_buf, checksum, .little);
    output.appendSliceAssumeCapacity(&crc_buf);

    if (data.len == 0) {
        return output.toOwnedSlice(allocator) catch return CompressionError.OutOfMemory;
    }

    if (level == .none) {
        output.appendSlice(allocator, data) catch return CompressionError.OutOfMemory;
        return output.toOwnedSlice(allocator) catch return CompressionError.OutOfMemory;
    }

    const hash_head = allocator.alloc(u32, HASH_SIZE) catch return CompressionError.OutOfMemory;
    defer allocator.free(hash_head);
    @memset(hash_head, 0);

    const hash_chain = allocator.alloc(u32, WINDOW_SIZE) catch return CompressionError.OutOfMemory;
    defer allocator.free(hash_chain);
    @memset(hash_chain, 0);

    const params = LevelParams.get(level);

    var pos: usize = 0;
    var lit_start: usize = 0;

    while (pos < data.len) {
        const rle_len = countRun(data, pos);
        if (rle_len >= 4) {
            if (pos > lit_start) {
                try emitLiterals(allocator, &output, data[lit_start..pos]);
            }
            try emitRLE(allocator, &output, data[pos], rle_len);
            updateHashChain(data, pos, pos + rle_len, hash_head, hash_chain);
            pos += rle_len;
            lit_start = pos;
            continue;
        }

        const match = findBestMatch(data, pos, hash_head, hash_chain, params);

        if (params.lazy and match.len >= MIN_MATCH and match.len < MAX_MATCH and pos + 1 < data.len) {
            updateHashPos(data, pos, hash_head, hash_chain);
            const next_match = findBestMatch(data, pos + 1, hash_head, hash_chain, params);
            if (next_match.len >= match.len + 2) {
                pos += 1;
                continue;
            }
        }

        if (match.len >= MIN_MATCH) {
            if (pos > lit_start) {
                try emitLiterals(allocator, &output, data[lit_start..pos]);
            }
            try emitMatch(allocator, &output, match.len, match.dist);
            updateHashChain(data, pos, pos + match.len, hash_head, hash_chain);
            pos += match.len;
            lit_start = pos;
        } else {
            updateHashPos(data, pos, hash_head, hash_chain);
            pos += 1;
        }
    }

    if (data.len > lit_start) {
        try emitLiterals(allocator, &output, data[lit_start..]);
    }

    return output.toOwnedSlice(allocator) catch return CompressionError.OutOfMemory;
}

fn updateHashPos(data: []const u8, pos: usize, hash_head: []u32, hash_chain: []u32) void {
    if (pos + 4 <= data.len) {
        const h = hash4(data[pos..][0..4]);
        hash_chain[pos & WINDOW_MASK] = hash_head[h];
        hash_head[h] = @intCast(pos + 1);
    }
}

fn updateHashChain(data: []const u8, start: usize, end: usize, hash_head: []u32, hash_chain: []u32) void {
    var i = start;
    while (i < end and i + 4 <= data.len) : (i += 1) {
        updateHashPos(data, i, hash_head, hash_chain);
    }
}

inline fn countRun(data: []const u8, pos: usize) usize {
    if (pos >= data.len) return 0;
    const byte = data[pos];
    var len: usize = 1;
    const max = @min(data.len - pos, 66);
    while (len < max and data[pos + len] == byte) : (len += 1) {}
    return len;
}

fn emitLiterals(allocator: Allocator, output: *std.ArrayList(u8), literals: []const u8) CompressionError!void {
    var i: usize = 0;
    while (i < literals.len) {
        const remaining = literals.len - i;
        const n = @min(remaining, 128);
        output.append(allocator, @intCast(n - 1)) catch return CompressionError.OutOfMemory;
        output.appendSlice(allocator, literals[i..][0..n]) catch return CompressionError.OutOfMemory;
        i += n;
    }
}

fn emitRLE(allocator: Allocator, output: *std.ArrayList(u8), byte: u8, len: usize) CompressionError!void {
    var remaining = len;
    while (remaining >= 3) {
        const run_len = @min(remaining, 66);
        output.append(allocator, RLE_FLAG | @as(u8, @intCast(run_len - 3))) catch return CompressionError.OutOfMemory;
        output.append(allocator, byte) catch return CompressionError.OutOfMemory;
        remaining -= run_len;
    }
    if (remaining > 0) {
        output.append(allocator, @intCast(remaining - 1)) catch return CompressionError.OutOfMemory;
        for (0..remaining) |_| {
            output.append(allocator, byte) catch return CompressionError.OutOfMemory;
        }
    }
}

fn emitMatch(allocator: Allocator, output: *std.ArrayList(u8), len: usize, dist: usize) CompressionError!void {
    // Single-byte encoding: len 3-65 -> token 0xC0-0xFE (0x3F reserved for extended)
    if (len < 66) {
        output.append(allocator, MATCH_FLAG | @as(u8, @intCast(len - 3))) catch return CompressionError.OutOfMemory;
    } else {
        // Extended encoding: len 66+ -> token 0xFF followed by (len - 66)
        output.append(allocator, MATCH_FLAG | 0x3F) catch return CompressionError.OutOfMemory;
        output.append(allocator, @intCast(len - 66)) catch return CompressionError.OutOfMemory;
    }
    var dist_buf: [2]u8 = undefined;
    std.mem.writeInt(u16, &dist_buf, @intCast(dist), .little);
    output.appendSlice(allocator, &dist_buf) catch return CompressionError.OutOfMemory;
}

pub fn decompress(data: []const u8, allocator: Allocator) CompressionError![]u8 {
    if (data.len < HEADER_SIZE) return CompressionError.InvalidData;

    if (!std.mem.eql(u8, data[0..4], &MAGIC)) {
        return CompressionError.InvalidMagic;
    }

    if (data[4] > VERSION) return CompressionError.UnsupportedVersion;

    const flags = data[5];
    const original_size = std.mem.readInt(u32, data[6..10], .little);
    const stored_checksum = std.mem.readInt(u32, data[10..14], .little);

    if (original_size == 0) {
        return allocator.alloc(u8, 0) catch return CompressionError.OutOfMemory;
    }

    const output = allocator.alloc(u8, original_size) catch return CompressionError.OutOfMemory;
    errdefer allocator.free(output);

    if (flags == FLAG_NONE) {
        if (data.len < HEADER_SIZE + original_size) return CompressionError.InvalidData;
        @memcpy(output, data[HEADER_SIZE..][0..original_size]);
    } else {
        var out_pos: usize = 0;
        var in_pos: usize = HEADER_SIZE;

        while (in_pos < data.len and out_pos < output.len) {
            const token = data[in_pos];
            in_pos += 1;

            if (token < 0x80) {
                // Literal: count = token + 1
                const count = @as(usize, token) + 1;
                if (in_pos + count > data.len or out_pos + count > output.len) {
                    return CompressionError.InvalidData;
                }
                @memcpy(output[out_pos..][0..count], data[in_pos..][0..count]);
                in_pos += count;
                out_pos += count;
            } else if (token < 0xC0) {
                // RLE: run_len = (token & 0x3F) + 3
                const run_len = @as(usize, token & 0x3F) + 3;
                if (in_pos >= data.len or out_pos + run_len > output.len) {
                    return CompressionError.InvalidData;
                }
                const byte = data[in_pos];
                in_pos += 1;
                @memset(output[out_pos..][0..run_len], byte);
                out_pos += run_len;
            } else {
                // Match: token 0xC0-0xFF
                var match_len: usize = @as(usize, token & 0x3F) + 3;
                // Extended encoding: 0x3F (63) means read another byte
                if ((token & 0x3F) == 0x3F) {
                    if (in_pos >= data.len) return CompressionError.InvalidData;
                    match_len = @as(usize, data[in_pos]) + 66;
                    in_pos += 1;
                }
                if (in_pos + 2 > data.len) return CompressionError.InvalidData;
                const dist = std.mem.readInt(u16, data[in_pos..][0..2], .little);
                in_pos += 2;

                if (dist == 0 or dist > out_pos or out_pos + match_len > output.len) {
                    return CompressionError.InvalidData;
                }

                const src = out_pos - dist;
                if (dist >= match_len) {
                    @memcpy(output[out_pos..][0..match_len], output[src..][0..match_len]);
                } else {
                    for (0..match_len) |i| {
                        output[out_pos + i] = output[src + (i % dist)];
                    }
                }
                out_pos += match_len;
            }
        }

        if (out_pos != original_size) return CompressionError.InvalidData;
    }

    if (flags & FLAG_CHECKSUM != 0) {
        const actual_checksum = crc32(output);
        if (actual_checksum != stored_checksum) {
            return CompressionError.ChecksumMismatch;
        }
    }

    return output;
}

pub const StreamingCompressor = struct {
    buf: std.ArrayList(u8),
    alloc: Allocator,
    level: config.CompressionLevel,

    pub fn init(allocator: Allocator, level: ?config.CompressionLevel) StreamingCompressor {
        return .{
            .buf = .empty,
            .alloc = allocator,
            .level = level orelse config.global.compression.level,
        };
    }

    pub fn deinit(self: *StreamingCompressor) void {
        self.buf.deinit(self.alloc);
    }

    pub fn write(self: *StreamingCompressor, data: []const u8) CompressionError!void {
        self.buf.appendSlice(self.alloc, data) catch return CompressionError.OutOfMemory;
    }

    pub fn finish(self: *StreamingCompressor, allocator: Allocator) CompressionError![]u8 {
        return compress(self.buf.items, allocator, self.level);
    }
};

pub const StreamingDecompressor = struct {
    alloc: Allocator,
    src: []const u8,
    out: ?[]u8,

    pub fn init(allocator: Allocator, data: []const u8) StreamingDecompressor {
        return .{ .alloc = allocator, .src = data, .out = null };
    }

    pub fn deinit(self: *StreamingDecompressor) void {
        if (self.out) |o| self.alloc.free(o);
    }

    pub fn readAll(self: *StreamingDecompressor) CompressionError![]const u8 {
        if (self.out) |o| return o;
        const r = try decompress(self.src, self.alloc);
        self.out = r;
        return r;
    }
};

pub fn getStats(original: []const u8, compressed: []const u8, level: config.CompressionLevel) CompressionStats {
    return .{
        .original_size = original.len,
        .compressed_size = compressed.len,
        .level = level,
        .literals = 0,
        .matches = 0,
        .rle_runs = 0,
    };
}

pub fn maxCompressedSize(size: usize) usize {
    return HEADER_SIZE + size + (size / 128) + 16;
}

pub fn estimateRatio(data: []const u8) f32 {
    if (data.len == 0) return 1.0;
    var counts: [256]u32 = @splat(0);
    for (data) |b| counts[b] += 1;
    var entropy: f32 = 0.0;
    const len_f: f32 = @floatFromInt(data.len);
    for (counts) |c| {
        if (c > 0) {
            const p: f32 = @as(f32, @floatFromInt(c)) / len_f;
            entropy -= p * @log2(p);
        }
    }
    return 1.0 - (entropy / 8.0) * 0.6;
}

test "empty" {
    const a = std.testing.allocator;
    const c = try compress("", a, null);
    defer a.free(c);
    try std.testing.expectEqual(@as(usize, HEADER_SIZE), c.len);
    const d = try decompress(c, a);
    defer a.free(d);
    try std.testing.expectEqual(@as(usize, 0), d.len);
}

test "roundtrip" {
    const a = std.testing.allocator;
    const orig = "Hello, this is a test! This is a test of compression.";
    const c = try compress(orig, a, null);
    defer a.free(c);
    const d = try decompress(c, a);
    defer a.free(d);
    try std.testing.expectEqualStrings(orig, d);
}

test "roundtrip_store" {
    const a = std.testing.allocator;
    const orig = "Hello, this is uncompressed data!";
    const c = try compress(orig, a, .none);
    defer a.free(c);
    const d = try decompress(c, a);
    defer a.free(d);
    try std.testing.expectEqualStrings(orig, d);
}

test "roundtrip_best" {
    const a = std.testing.allocator;
    const orig = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    const c = try compress(orig, a, .best);
    defer a.free(c);
    try std.testing.expect(c.len < orig.len);
    const d = try decompress(c, a);
    defer a.free(d);
    try std.testing.expectEqualStrings(orig, d);
}

test "repetitive" {
    const a = std.testing.allocator;
    const orig = try a.alloc(u8, 10000);
    defer a.free(orig);
    @memset(orig, 'X');
    const c = try compress(orig, a, null);
    defer a.free(c);
    try std.testing.expect(c.len < orig.len / 10);
    const d = try decompress(c, a);
    defer a.free(d);
    try std.testing.expectEqualSlices(u8, orig, d);
}

test "code" {
    const a = std.testing.allocator;
    const src =
        \\const std = @import("std");
        \\pub fn main() !void {
        \\    const stdout = std.io.getStdOut().writer();
        \\    try stdout.print("Hello!\n", .{});
        \\}
        \\const std = @import("std");
        \\pub fn main() !void {
        \\    const stdout = std.io.getStdOut().writer();
        \\    try stdout.print("Hello!\n", .{});
        \\}
    ;
    const c = try compress(src, a, null);
    defer a.free(c);
    try std.testing.expect(c.len < src.len);
    const d = try decompress(c, a);
    defer a.free(d);
    try std.testing.expectEqualStrings(src, d);
}

test "binary" {
    const a = std.testing.allocator;
    var b: [256]u8 = undefined;
    for (0..256) |i| b[i] = @intCast(i);
    const c = try compress(&b, a, null);
    defer a.free(c);
    const d = try decompress(c, a);
    defer a.free(d);
    try std.testing.expectEqualSlices(u8, &b, d);
}

test "streaming" {
    const a = std.testing.allocator;
    var sc = StreamingCompressor.init(a, null);
    defer sc.deinit();
    try sc.write("Hello ");
    try sc.write("World");
    const c = try sc.finish(a);
    defer a.free(c);
    const d = try decompress(c, a);
    defer a.free(d);
    try std.testing.expectEqualStrings("Hello World", d);
}

test "checksum" {
    const data = "test data for checksum";
    const checksum = crc32(data);
    try std.testing.expect(checksum != 0);
}

test "stats" {
    const stats = CompressionStats{
        .original_size = 1000,
        .compressed_size = 500,
        .level = .default,
        .literals = 100,
        .matches = 50,
        .rle_runs = 10,
    };
    try std.testing.expectEqual(@as(f64, 0.5), stats.ratio());
    try std.testing.expectEqual(@as(f64, 50.0), stats.savedPercent());
}

test "best_better_than_fast" {
    const a = std.testing.allocator;
    var data: [4096]u8 = undefined;
    for (0..data.len) |i| {
        data[i] = @intCast((i * 7 + i / 32) % 256);
    }

    const fast_c = try compress(&data, a, .fast);
    defer a.free(fast_c);

    const best_c = try compress(&data, a, .best);
    defer a.free(best_c);

    try std.testing.expect(best_c.len <= fast_c.len);

    const d = try decompress(best_c, a);
    defer a.free(d);
    try std.testing.expectEqualSlices(u8, &data, d);
}
