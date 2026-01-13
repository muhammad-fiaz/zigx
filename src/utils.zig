const std = @import("std");
const Allocator = std.mem.Allocator;
const config = @import("config.zig");

// Library Constants (centralized)

/// Library version string
pub const VERSION = "0.0.1";

/// File extension for ZIGX archives
pub const FILE_EXTENSION = ".zigx";

/// Magic bytes identifying ZIGX archives
pub const MAGIC: [4]u8 = .{ 'Z', 'I', 'G', 'X' };

/// Format version (archive structure version)
pub const FORMAT_VERSION: u16 = 0x0001;

/// Compression algorithm version
pub const COMPRESSION_VERSION: u8 = 1;

/// Header size in bytes
pub const HEADER_SIZE: usize = 128;

/// Maximum supported file size (16TB)
pub const MAX_FILE_SIZE: u64 = 16 * 1024 * 1024 * 1024 * 1024;

/// Chunk size for large file processing (4MB)
pub const CHUNK_SIZE: usize = 4 * 1024 * 1024;

/// Maximum single-chunk file size (4GB)
pub const MAX_SINGLE_CHUNK_SIZE: u64 = 4 * 1024 * 1024 * 1024;

/// Hash size in bytes (SHA-256)
pub const HASH_SIZE: usize = 32;

/// Hash hex string size
pub const HASH_HEX_SIZE: usize = 64;

// Size Formatting Utilities

pub const SizeUnit = struct {
    value: f64,
    unit: []const u8,
};

/// Format bytes into human-readable size
pub fn formatSize(size: u64) SizeUnit {
    const units = [_][]const u8{ "B", "KB", "MB", "GB", "TB" };
    var value: f64 = @floatFromInt(size);
    var unit_idx: usize = 0;
    while (value >= 1024 and unit_idx < units.len - 1) {
        value /= 1024;
        unit_idx += 1;
    }
    return .{ .value = value, .unit = units[unit_idx] };
}

/// Format percentage
pub fn formatPercent(value: f64) f64 {
    return @round(value * 1000) / 10;
}

// Hex Encoding/Decoding Utilities

const hex_chars = "0123456789abcdef";

/// Convert bytes to hex string
pub fn bytesToHex(bytes: []const u8, out: []u8) void {
    std.debug.assert(out.len >= bytes.len * 2);
    for (bytes, 0..) |byte, i| {
        out[i * 2] = hex_chars[byte >> 4];
        out[i * 2 + 1] = hex_chars[byte & 0x0F];
    }
}

/// Convert 32-byte hash to 64-char hex string
pub fn hashBytesToHex(bytes: *const [HASH_SIZE]u8) [HASH_HEX_SIZE]u8 {
    var result: [HASH_HEX_SIZE]u8 = undefined;
    bytesToHex(bytes, &result);
    return result;
}

/// Convert hex char to nibble value
pub fn hexCharToNibble(c: u8) ?u4 {
    return switch (c) {
        '0'...'9' => @intCast(c - '0'),
        'a'...'f' => @intCast(c - 'a' + 10),
        'A'...'F' => @intCast(c - 'A' + 10),
        else => null,
    };
}

/// Convert hex string to bytes
pub fn hexToBytes(hex: []const u8, out: []u8) !void {
    if (hex.len != out.len * 2) return error.InvalidLength;
    for (0..out.len) |i| {
        const high = hexCharToNibble(hex[i * 2]) orelse return error.InvalidHexCharacter;
        const low = hexCharToNibble(hex[i * 2 + 1]) orelse return error.InvalidHexCharacter;
        out[i] = (@as(u8, high) << 4) | @as(u8, low);
    }
}

// Path Utilities

/// Maximum path length
pub const MAX_PATH_LENGTH: usize = config.global.security.max_path_length;

/// Maximum component length
pub const MAX_COMPONENT_LENGTH: usize = config.global.security.max_component_length;

/// Check if path is absolute
pub fn isAbsolutePath(path: []const u8) bool {
    if (path.len > 0 and path[0] == '/') return true;
    if (path.len >= 2) {
        if (std.ascii.isAlphabetic(path[0]) and path[1] == ':') return true;
    }
    if (path.len >= 2 and path[0] == '\\' and path[1] == '\\') return true;
    return false;
}

/// Check for path traversal attempts
pub fn containsPathTraversal(path: []const u8) bool {
    var normalized: [4096]u8 = undefined;
    const len = @min(path.len, 4096);
    for (path[0..len], 0..) |c, i| {
        normalized[i] = if (c == '\\') '/' else c;
    }
    const norm_path = normalized[0..len];
    if (std.mem.startsWith(u8, norm_path, "../")) return true;
    if (std.mem.eql(u8, norm_path, "..")) return true;
    if (std.mem.indexOf(u8, norm_path, "/../") != null) return true;
    if (std.mem.endsWith(u8, norm_path, "/..")) return true;
    return false;
}

/// Normalize path separators
pub fn normalizePath(allocator: Allocator, path: []const u8) ![]u8 {
    var result = std.ArrayListUnmanaged(u8){};
    errdefer result.deinit(allocator);
    var iter = std.mem.splitScalar(u8, path, '/');
    var first = true;
    while (iter.next()) |component| {
        if (component.len == 0 or std.mem.eql(u8, component, ".")) continue;
        if (!first) try result.append(allocator, '/');
        try result.appendSlice(allocator, component);
        first = false;
    }
    return result.toOwnedSlice(allocator);
}

// Pattern Matching Utilities

/// Check if a path matches any exclude pattern
pub fn matchesPattern(path: []const u8, patterns: []const []const u8) bool {
    for (patterns) |pattern| {
        if (matchesSinglePattern(path, pattern)) return true;
    }
    return false;
}

/// Check if path matches a single pattern
pub fn matchesSinglePattern(path: []const u8, pattern: []const u8) bool {
    // Direct match
    if (std.mem.eql(u8, path, pattern)) return true;

    // Wildcard suffix (*.ext)
    if (pattern.len > 1 and pattern[0] == '*') {
        const suffix = pattern[1..];
        if (std.mem.endsWith(u8, path, suffix)) return true;
    }

    // Wildcard prefix (prefix*)
    if (pattern.len > 1 and pattern[pattern.len - 1] == '*') {
        const prefix = pattern[0 .. pattern.len - 1];
        if (std.mem.startsWith(u8, path, prefix)) return true;
        // Check basename
        if (std.mem.lastIndexOfScalar(u8, path, '/')) |idx| {
            if (std.mem.startsWith(u8, path[idx + 1 ..], prefix)) return true;
        }
    }

    // Directory/file name match (e.g., "node_modules" matches "src/node_modules/file.js")
    if (std.mem.indexOf(u8, path, pattern)) |idx| {
        const before_ok = idx == 0 or path[idx - 1] == '/';
        const after_idx = idx + pattern.len;
        const after_ok = after_idx >= path.len or path[after_idx] == '/';
        if (before_ok and after_ok) return true;
    }

    return false;
}

// CRC32 Checksum

/// Calculate CRC32 checksum
pub fn crc32(data: []const u8) u32 {
    const poly: u32 = 0xEDB88320;
    var crc: u32 = 0xFFFFFFFF;
    for (data) |byte| {
        crc ^= byte;
        for (0..8) |_| {
            crc = if (crc & 1 != 0) (crc >> 1) ^ poly else crc >> 1;
        }
    }
    return ~crc;
}

// Version Display Utilities

/// Get version display string
pub fn getVersionString() []const u8 {
    return VERSION;
}

/// Get format version as display number
pub fn getFormatVersionDisplay() u16 {
    return FORMAT_VERSION;
}

/// Get compression version as display number
pub fn getCompressionVersionDisplay() u8 {
    return COMPRESSION_VERSION;
}

// Tests

test "format_size" {
    const size1 = formatSize(1024);
    try std.testing.expectEqual(@as(f64, 1.0), size1.value);
    try std.testing.expectEqualStrings("KB", size1.unit);

    const size2 = formatSize(1024 * 1024);
    try std.testing.expectEqual(@as(f64, 1.0), size2.value);
    try std.testing.expectEqualStrings("MB", size2.unit);
}

test "hex_conversion" {
    const bytes = [_]u8{ 0x12, 0x34, 0xAB, 0xCD };
    var hex: [8]u8 = undefined;
    bytesToHex(&bytes, &hex);
    try std.testing.expectEqualStrings("1234abcd", &hex);
}

test "path_checks" {
    try std.testing.expect(isAbsolutePath("/etc/passwd"));
    try std.testing.expect(isAbsolutePath("C:\\Windows"));
    try std.testing.expect(!isAbsolutePath("src/main.zig"));

    try std.testing.expect(containsPathTraversal("../escape"));
    try std.testing.expect(containsPathTraversal("src/../../../etc"));
    try std.testing.expect(!containsPathTraversal("src/main.zig"));
}

test "pattern_matching" {
    try std.testing.expect(matchesSinglePattern("file.tmp", "*.tmp"));
    try std.testing.expect(matchesSinglePattern("test_file.zig", "test_*"));
    try std.testing.expect(matchesSinglePattern("src/node_modules/pkg", "node_modules"));
    try std.testing.expect(!matchesSinglePattern("file.txt", "*.tmp"));
}

test "crc32_check" {
    const crc = crc32("hello world");
    try std.testing.expectEqual(@as(u32, 0x0D4A1185), crc);
}

test "version_constants" {
    try std.testing.expectEqualStrings("0.0.1", VERSION);
    try std.testing.expectEqual(@as(u16, 0x0001), FORMAT_VERSION);
    try std.testing.expectEqual(@as(u8, 1), COMPRESSION_VERSION);
}
