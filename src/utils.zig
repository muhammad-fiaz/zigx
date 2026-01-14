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

/// Compression algorithm version (1 = Zstandard)
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

/// Default I/O buffer size
pub const DEFAULT_IO_BUFFER_SIZE: usize = 64 * 1024;

/// Reusable buffer pool for efficient memory management
pub const BufferPool = struct {
    buffers: std.ArrayListUnmanaged([]u8),
    allocator: Allocator,
    default_size: usize,

    pub fn init(allocator: Allocator, default_size: usize) BufferPool {
        return .{
            .buffers = .{},
            .allocator = allocator,
            .default_size = default_size,
        };
    }

    pub fn deinit(self: *BufferPool) void {
        for (self.buffers.items) |buf| {
            self.allocator.free(buf);
        }
        self.buffers.deinit(self.allocator);
    }

    pub fn acquire(self: *BufferPool, size: usize) ![]u8 {
        const actual_size = @max(size, self.default_size);

        // Try to find an existing buffer of sufficient size
        for (self.buffers.items, 0..) |buf, i| {
            if (buf.len >= actual_size) {
                _ = self.buffers.orderedRemove(i);
                return buf;
            }
        }

        // Allocate new buffer
        return try self.allocator.alloc(u8, actual_size);
    }

    pub fn release(self: *BufferPool, buf: []u8) void {
        self.buffers.append(self.allocator, buf) catch {
            // If we can't store it, free it
            self.allocator.free(buf);
        };
    }
};

pub const SizeUnit = struct {
    value: f64,
    unit: []const u8,

    /// Format as string into buffer
    pub fn format(self: SizeUnit, buf: []u8) []const u8 {
        return std.fmt.bufPrint(buf, "{d:.2} {s}", .{ self.value, self.unit }) catch "?";
    }
};

/// Format bytes into human-readable size
pub fn formatSize(size: u64) SizeUnit {
    const units = [_][]const u8{ "B", "KB", "MB", "GB", "TB", "PB" };
    var value: f64 = @floatFromInt(size);
    var unit_idx: usize = 0;
    while (value >= 1024 and unit_idx < units.len - 1) {
        value /= 1024;
        unit_idx += 1;
    }
    return .{ .value = value, .unit = units[unit_idx] };
}

/// Format bytes into exact unit
pub fn formatSizeExact(size: u64, unit: SizeUnitType) SizeUnit {
    const divisor: f64 = switch (unit) {
        .bytes => 1,
        .kb => 1024,
        .mb => 1024 * 1024,
        .gb => 1024 * 1024 * 1024,
        .tb => 1024 * 1024 * 1024 * 1024,
    };
    const unit_str = switch (unit) {
        .bytes => "B",
        .kb => "KB",
        .mb => "MB",
        .gb => "GB",
        .tb => "TB",
    };
    return .{
        .value = @as(f64, @floatFromInt(size)) / divisor,
        .unit = unit_str,
    };
}

pub const SizeUnitType = enum {
    bytes,
    kb,
    mb,
    gb,
    tb,
};

/// Format percentage
pub fn formatPercent(value: f64) f64 {
    return @round(value * 1000) / 10;
}

/// Format duration in nanoseconds to human readable
pub fn formatDuration(ns: u64) struct { value: f64, unit: []const u8 } {
    if (ns < 1000) return .{ .value = @floatFromInt(ns), .unit = "ns" };
    if (ns < 1_000_000) return .{ .value = @as(f64, @floatFromInt(ns)) / 1000, .unit = "µs" };
    if (ns < 1_000_000_000) return .{ .value = @as(f64, @floatFromInt(ns)) / 1_000_000, .unit = "ms" };
    return .{ .value = @as(f64, @floatFromInt(ns)) / 1_000_000_000, .unit = "s" };
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

/// Create directory path if it doesn't exist
pub fn ensurePath(path: []const u8) !void {
    if (path.len > 0) {
        try std.fs.cwd().makePath(path);
    }
}

/// Create parent directory for a file path
/// Handles both forward and backward slashes
pub fn ensureParentDir(path: []const u8) !void {
    if (std.mem.lastIndexOf(u8, path, "/") orelse std.mem.lastIndexOf(u8, path, "\\")) |idx| {
        const dir = path[0..idx];
        if (dir.len > 0) {
            try ensurePath(dir);
        }
    }
}

/// Get file size without opening the full file
pub fn getFileSize(path: []const u8) !u64 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    return stat.size;
}

/// Check if path exists
pub fn pathExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

/// Check if path is a directory
pub fn isDirectory(path: []const u8) bool {
    var dir = std.fs.cwd().openDir(path, .{}) catch return false;
    dir.close();
    return true;
}

/// Read file with size limit
pub fn readFileLimited(path: []const u8, allocator: Allocator, max_size: usize) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    if (stat.size > max_size) return error.FileTooLarge;
    return try file.readToEndAlloc(allocator, max_size);
}

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

/// Join paths safely
pub fn joinPaths(allocator: Allocator, base: []const u8, path: []const u8) ![]u8 {
    if (base.len == 0) return try allocator.dupe(u8, path);
    if (path.len == 0) return try allocator.dupe(u8, base);

    var result = std.ArrayListUnmanaged(u8){};
    errdefer result.deinit(allocator);

    try result.appendSlice(allocator, base);
    if (!std.mem.endsWith(u8, base, "/") and !std.mem.endsWith(u8, base, "\\")) {
        try result.append(allocator, '/');
    }
    try result.appendSlice(allocator, path);

    return result.toOwnedSlice(allocator);
}

/// Get file extension (including the dot)
pub fn getExtension(path: []const u8) []const u8 {
    return std.fs.path.extension(path);
}

/// Get filename without directory
pub fn getFilename(path: []const u8) []const u8 {
    return std.fs.path.basename(path);
}

/// Get directory part of path
pub fn getDirname(path: []const u8) []const u8 {
    return std.fs.path.dirname(path) orelse "";
}


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

/// Advanced glob pattern matching with ** support
pub fn matchGlob(path: []const u8, pattern: []const u8) bool {
    return matchGlobInternal(path, pattern);
}

fn matchGlobInternal(path: []const u8, pattern: []const u8) bool {
    var p_idx: usize = 0;
    var s_idx: usize = 0;

    while (p_idx < pattern.len and s_idx < path.len) {
        if (pattern[p_idx] == '*') {
            // Check for **
            if (p_idx + 1 < pattern.len and pattern[p_idx + 1] == '*') {
                p_idx += 2;
                // Skip optional /
                if (p_idx < pattern.len and pattern[p_idx] == '/') p_idx += 1;

                // ** matches everything including /
                if (p_idx >= pattern.len) return true;

                // Try to match remaining pattern at each position
                while (s_idx <= path.len) {
                    if (matchGlobInternal(path[s_idx..], pattern[p_idx..])) return true;
                    if (s_idx < path.len) s_idx += 1 else break;
                }
                return false;
            } else {
                // Single * matches everything except /
                p_idx += 1;
                if (p_idx >= pattern.len) {
                    // * at end matches rest except /
                    return std.mem.indexOfScalar(u8, path[s_idx..], '/') == null;
                }

                // Find next match
                while (s_idx < path.len and path[s_idx] != '/') {
                    if (matchGlobInternal(path[s_idx..], pattern[p_idx..])) return true;
                    s_idx += 1;
                }
                return matchGlobInternal(path[s_idx..], pattern[p_idx..]);
            }
        } else if (pattern[p_idx] == '?') {
            if (path[s_idx] == '/') return false;
            p_idx += 1;
            s_idx += 1;
        } else if (pattern[p_idx] == path[s_idx]) {
            p_idx += 1;
            s_idx += 1;
        } else {
            return false;
        }
    }

    // Handle trailing *
    while (p_idx < pattern.len and pattern[p_idx] == '*') p_idx += 1;

    return p_idx >= pattern.len and s_idx >= path.len;
}

/// Check if path matches any of the patterns (supports glob)
pub fn matchesAnyGlob(path: []const u8, patterns: []const []const u8) bool {
    for (patterns) |pattern| {
        if (matchGlob(path, pattern)) return true;
    }
    return false;
}


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

/// Calculate CRC32 with streaming support
pub const Crc32Hasher = struct {
    crc: u32 = 0xFFFFFFFF,

    pub fn update(self: *Crc32Hasher, data: []const u8) void {
        const poly: u32 = 0xEDB88320;
        for (data) |byte| {
            self.crc ^= byte;
            for (0..8) |_| {
                self.crc = if (self.crc & 1 != 0) (self.crc >> 1) ^ poly else self.crc >> 1;
            }
        }
    }

    pub fn final(self: *Crc32Hasher) u32 {
        return ~self.crc;
    }

    pub fn reset(self: *Crc32Hasher) void {
        self.crc = 0xFFFFFFFF;
    }
};


/// Progress callback function type
pub const ProgressCallback = *const fn (current: u64, total: u64, context: ?*anyopaque) void;

/// Progress tracker for operations
pub const ProgressTracker = struct {
    total: u64,
    current: u64 = 0,
    callback: ?ProgressCallback = null,
    context: ?*anyopaque = null,
    last_report: u64 = 0,
    report_interval: u64 = 1024 * 1024, // Report every 1MB by default

    pub fn init(total: u64) ProgressTracker {
        return .{ .total = total };
    }

    pub fn withCallback(total: u64, callback: ProgressCallback, context: ?*anyopaque) ProgressTracker {
        return .{
            .total = total,
            .callback = callback,
            .context = context,
        };
    }

    pub fn advance(self: *ProgressTracker, amount: u64) void {
        self.current += amount;
        if (self.callback) |cb| {
            if (self.current - self.last_report >= self.report_interval or self.current >= self.total) {
                cb(self.current, self.total, self.context);
                self.last_report = self.current;
            }
        }
    }

    pub fn setProgress(self: *ProgressTracker, current: u64) void {
        self.current = current;
        if (self.callback) |cb| {
            if (self.current - self.last_report >= self.report_interval or self.current >= self.total) {
                cb(self.current, self.total, self.context);
                self.last_report = self.current;
            }
        }
    }

    pub fn getPercent(self: *const ProgressTracker) f64 {
        if (self.total == 0) return 100.0;
        return @as(f64, @floatFromInt(self.current)) / @as(f64, @floatFromInt(self.total)) * 100.0;
    }

    pub fn isComplete(self: *const ProgressTracker) bool {
        return self.current >= self.total;
    }
};


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

/// Get full version info as formatted string
pub fn getFullVersionInfo(buf: []u8) []const u8 {
    return std.fmt.bufPrint(buf, "zigx v{s} (format v{d}, compression v{d})", .{
        VERSION,
        FORMAT_VERSION,
        COMPRESSION_VERSION,
    }) catch VERSION;
}


/// Common error result type
pub fn Result(comptime T: type) type {
    return union(enum) {
        ok: T,
        err: anyerror,

        pub fn unwrap(self: @This()) !T {
            return switch (self) {
                .ok => |val| val,
                .err => |e| e,
            };
        }

        pub fn isOk(self: @This()) bool {
            return self == .ok;
        }

        pub fn isErr(self: @This()) bool {
            return self == .err;
        }
    };
}


test "format_size" {
    const size1 = formatSize(1024);
    try std.testing.expectEqual(@as(f64, 1.0), size1.value);
    try std.testing.expectEqualStrings("KB", size1.unit);

    const size2 = formatSize(1024 * 1024);
    try std.testing.expectEqual(@as(f64, 1.0), size2.value);
    try std.testing.expectEqualStrings("MB", size2.unit);
}

test "format_duration" {
    const dur1 = formatDuration(500);
    try std.testing.expectEqual(@as(f64, 500), dur1.value);
    try std.testing.expectEqualStrings("ns", dur1.unit);

    const dur2 = formatDuration(1_500_000);
    try std.testing.expectEqualStrings("ms", dur2.unit);
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

test "glob_matching" {
    try std.testing.expect(matchGlob("src/main.zig", "src/*.zig"));
    try std.testing.expect(matchGlob("src/utils/helper.zig", "src/**/*.zig"));
    try std.testing.expect(matchGlob("test.txt", "*.txt"));
    try std.testing.expect(!matchGlob("src/main.zig", "test/*.zig"));
}

test "crc32_check" {
    const crc = crc32("hello world");
    try std.testing.expectEqual(@as(u32, 0x0D4A1185), crc);
}

test "crc32_streaming" {
    var hasher = Crc32Hasher{};
    hasher.update("hello ");
    hasher.update("world");
    try std.testing.expectEqual(@as(u32, 0x0D4A1185), hasher.final());
}

test "version_constants" {
    try std.testing.expectEqualStrings("0.0.1", VERSION);
    try std.testing.expectEqual(@as(u16, 0x0001), FORMAT_VERSION);
    try std.testing.expectEqual(@as(u8, 1), COMPRESSION_VERSION);
}

test "progress_tracker" {
    var tracker = ProgressTracker.init(100);
    tracker.advance(50);
    try std.testing.expectEqual(@as(f64, 50.0), tracker.getPercent());
    try std.testing.expect(!tracker.isComplete());
    tracker.advance(50);
    try std.testing.expect(tracker.isComplete());
}

test "buffer_pool" {
    const allocator = std.testing.allocator;
    var pool = BufferPool.init(allocator, 1024);
    defer pool.deinit();

    const buf1 = try pool.acquire(512);
    pool.release(buf1);

    const buf2 = try pool.acquire(512);
    pool.release(buf2);
}

test "path_utilities" {
    const allocator = std.testing.allocator;

    const joined = try joinPaths(allocator, "src", "main.zig");
    defer allocator.free(joined);
    try std.testing.expectEqualStrings("src/main.zig", joined);
}
