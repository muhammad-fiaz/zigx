const std = @import("std");
const Allocator = std.mem.Allocator;
const config = @import("config.zig");
const utils = @import("utils.zig");

// Re-export constants from utils for backward compatibility
pub const MAGIC = utils.MAGIC;
pub const FORMAT_VERSION = utils.FORMAT_VERSION;
pub const HEADER_SIZE = utils.HEADER_SIZE;
pub const MAX_FILE_SIZE = utils.MAX_FILE_SIZE;
pub const CHUNK_SIZE = utils.CHUNK_SIZE;

pub const CompressionType = enum(u4) {
    none = 0,
    deflate = 1,
    deflate_fast = 2,
    deflate_best = 3,

    pub fn fromLevel(level: config.CompressionLevel) CompressionType {
        return switch (level) {
            .none => .none,
            .fast, .level_4, .level_5 => .deflate_fast,
            .best, .level_8, .level_9 => .deflate_best,
            else => .deflate,
        };
    }
};

pub const FileType = enum(u8) {
    unknown = 0,
    text = 1,
    binary = 2,
    executable = 3,
    image = 4,
    audio = 5,
    video = 6,
    archive = 7,
    document = 8,
    source_code = 9,
    data = 10,
    config = 11,
};

pub const HeaderFlags = packed struct(u32) {
    compression: u4 = @intFromEnum(CompressionType.deflate),
    signed: u1 = 0,
    encrypted: u1 = 0,
    chunked: u1 = 0,
    streaming: u1 = 0,
    large_file: u1 = 0,
    has_index: u1 = 0,
    has_manifest: u1 = 0,
    metadata_compressed: u1 = 0,
    checksums_compressed: u1 = 0,
    reserved: u19 = 0,
};

pub const Header = extern struct {
    magic: [4]u8 = MAGIC,
    version: u16 = FORMAT_VERSION,
    flags: HeaderFlags = .{},
    meta_length: u32 = 0,
    checksums_length: u32 = 0,
    index_length: u32 = 0,
    payload_length: u64 = 0,
    original_size: u64 = 0,
    file_count: u32 = 0,
    chunk_count: u32 = 0,
    payload_hash: [32]u8 = .{0} ** 32,
    archive_hash: [32]u8 = .{0} ** 32,
    signature_length: u16 = 0,
    compression_level: u8 = 6,
    reserved: [29]u8 = .{0} ** 29,

    pub fn validate(self: *const Header) bool {
        if (!std.mem.eql(u8, &self.magic, &MAGIC)) return false;
        if (self.version > FORMAT_VERSION) return false;
        if (self.meta_length > 16 * 1024 * 1024) return false;
        if (self.checksums_length > 64 * 1024 * 1024) return false;
        return true;
    }

    pub fn getCompressionType(self: *const Header) CompressionType {
        return @enumFromInt(self.flags.compression);
    }

    pub fn isSigned(self: *const Header) bool {
        return self.flags.signed == 1;
    }

    pub fn isChunked(self: *const Header) bool {
        return self.flags.chunked == 1;
    }

    pub fn isLargeFile(self: *const Header) bool {
        return self.flags.large_file == 1;
    }

    pub fn toBytes(self: *const Header) [HEADER_SIZE]u8 {
        var bytes: [HEADER_SIZE]u8 = .{0} ** HEADER_SIZE;
        @memcpy(bytes[0..4], &self.magic);
        std.mem.writeInt(u16, bytes[4..6], self.version, .little);
        std.mem.writeInt(u32, bytes[6..10], @bitCast(self.flags), .little);
        std.mem.writeInt(u32, bytes[10..14], self.meta_length, .little);
        std.mem.writeInt(u32, bytes[14..18], self.checksums_length, .little);
        std.mem.writeInt(u32, bytes[18..22], self.index_length, .little);
        std.mem.writeInt(u64, bytes[22..30], self.payload_length, .little);
        std.mem.writeInt(u64, bytes[30..38], self.original_size, .little);
        std.mem.writeInt(u32, bytes[38..42], self.file_count, .little);
        std.mem.writeInt(u32, bytes[42..46], self.chunk_count, .little);
        @memcpy(bytes[46..78], &self.payload_hash);
        @memcpy(bytes[78..110], &self.archive_hash);
        std.mem.writeInt(u16, bytes[110..112], self.signature_length, .little);
        bytes[112] = self.compression_level;
        @memcpy(bytes[113..128][0..15], self.reserved[0..15]);
        return bytes;
    }

    pub fn fromBytes(bytes: *const [HEADER_SIZE]u8) Header {
        var h = Header{};
        h.magic = bytes[0..4].*;
        h.version = std.mem.readInt(u16, bytes[4..6], .little);
        h.flags = @bitCast(std.mem.readInt(u32, bytes[6..10], .little));
        h.meta_length = std.mem.readInt(u32, bytes[10..14], .little);
        h.checksums_length = std.mem.readInt(u32, bytes[14..18], .little);
        h.index_length = std.mem.readInt(u32, bytes[18..22], .little);
        h.payload_length = std.mem.readInt(u64, bytes[22..30], .little);
        h.original_size = std.mem.readInt(u64, bytes[30..38], .little);
        h.file_count = std.mem.readInt(u32, bytes[38..42], .little);
        h.chunk_count = std.mem.readInt(u32, bytes[42..46], .little);
        h.payload_hash = bytes[46..78].*;
        h.archive_hash = bytes[78..110].*;
        h.signature_length = std.mem.readInt(u16, bytes[110..112], .little);
        h.compression_level = bytes[112];
        return h;
    }

    pub fn getCompressionRatio(self: *const Header) f64 {
        if (self.original_size == 0) return 1.0;
        return @as(f64, @floatFromInt(self.payload_length)) / @as(f64, @floatFromInt(self.original_size));
    }
};

pub const Metadata = struct {
    entries: std.StringHashMapUnmanaged([]const u8),
    allocator: Allocator,

    pub fn init(allocator: Allocator) Metadata {
        return .{ .entries = .{}, .allocator = allocator };
    }

    pub fn deinit(self: *Metadata) void {
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.entries.deinit(self.allocator);
    }

    pub fn set(self: *Metadata, key: []const u8, value: []const u8) !void {
        const k = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(k);
        const v = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(v);
        if (self.entries.fetchRemove(k)) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
        try self.entries.put(self.allocator, k, v);
    }

    pub fn get(self: *const Metadata, key: []const u8) ?[]const u8 {
        return self.entries.get(key);
    }

    pub fn count(self: *const Metadata) usize {
        return self.entries.count();
    }

    pub fn serialize(self: *const Metadata) ![]u8 {
        var list = std.ArrayListUnmanaged(u8){};
        errdefer list.deinit(self.allocator);
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            var len_buf: [4]u8 = undefined;
            std.mem.writeInt(u32, &len_buf, @intCast(entry.key_ptr.len), .little);
            try list.appendSlice(self.allocator, &len_buf);
            try list.appendSlice(self.allocator, entry.key_ptr.*);
            std.mem.writeInt(u32, &len_buf, @intCast(entry.value_ptr.len), .little);
            try list.appendSlice(self.allocator, &len_buf);
            try list.appendSlice(self.allocator, entry.value_ptr.*);
        }
        return list.toOwnedSlice(self.allocator);
    }

    pub fn parse(data: []const u8, allocator: Allocator) !Metadata {
        var meta = Metadata.init(allocator);
        errdefer meta.deinit();
        var offset: usize = 0;
        while (offset + 4 <= data.len) {
            const key_len = std.mem.readInt(u32, data[offset..][0..4], .little);
            offset += 4;
            if (offset + key_len > data.len) break;
            const key = data[offset..][0..key_len];
            offset += key_len;
            if (offset + 4 > data.len) break;
            const val_len = std.mem.readInt(u32, data[offset..][0..4], .little);
            offset += 4;
            if (offset + val_len > data.len) break;
            const val = data[offset..][0..val_len];
            offset += val_len;
            try meta.set(key, val);
        }
        return meta;
    }

    pub fn display(self: *const Metadata, writer: anytype) !void {
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            try writer.print("{s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
    }
};

pub const FileInfo = struct {
    path: []const u8,
    size: u64,
    compressed_size: u64,
    hash: [64]u8,
    file_type: FileType,
    permissions: u32,
    modified_time: i64,
    chunk_offset: u64,
    chunk_count: u32,

    pub fn deinit(self: *FileInfo, allocator: Allocator) void {
        allocator.free(self.path);
    }

    pub fn getCompressionRatio(self: *const FileInfo) f64 {
        if (self.size == 0) return 1.0;
        return @as(f64, @floatFromInt(self.compressed_size)) / @as(f64, @floatFromInt(self.size));
    }
};

pub const Checksum = struct {
    path: []const u8,
    size: u64,
    hash: [64]u8,

    pub fn deinit(self: *Checksum, allocator: Allocator) void {
        allocator.free(self.path);
    }
};

pub const ChecksumList = struct {
    items: []Checksum,
    allocator: Allocator,

    pub fn init(allocator: Allocator) ChecksumList {
        return .{ .items = &.{}, .allocator = allocator };
    }

    pub fn deinit(self: *ChecksumList, allocator: Allocator) void {
        for (self.items) |*item| item.deinit(allocator);
        allocator.free(self.items);
    }

    pub fn serialize(self: *const ChecksumList) ![]u8 {
        var list = std.ArrayListUnmanaged(u8){};
        errdefer list.deinit(self.allocator);
        for (self.items) |item| {
            try list.appendSlice(self.allocator, &item.hash);
            var size_buf: [8]u8 = undefined;
            std.mem.writeInt(u64, &size_buf, item.size, .little);
            try list.appendSlice(self.allocator, &size_buf);
            var path_len_buf: [4]u8 = undefined;
            std.mem.writeInt(u32, &path_len_buf, @intCast(item.path.len), .little);
            try list.appendSlice(self.allocator, &path_len_buf);
            try list.appendSlice(self.allocator, item.path);
        }
        return list.toOwnedSlice(self.allocator);
    }

    pub fn parse(data: []const u8, allocator: Allocator) !ChecksumList {
        var items = std.ArrayListUnmanaged(Checksum){};
        errdefer {
            for (items.items) |*item| item.deinit(allocator);
            items.deinit(allocator);
        }
        var offset: usize = 0;
        while (offset + 76 <= data.len) {
            const hash_part = data[offset..][0..64];
            offset += 64;
            const size = std.mem.readInt(u64, data[offset..][0..8], .little);
            offset += 8;
            const path_len = std.mem.readInt(u32, data[offset..][0..4], .little);
            offset += 4;
            if (offset + path_len > data.len) break;
            const path = try allocator.dupe(u8, data[offset..][0..path_len]);
            offset += path_len;
            try items.append(allocator, .{ .path = path, .size = size, .hash = hash_part[0..64].* });
        }
        return ChecksumList{ .items = try items.toOwnedSlice(allocator), .allocator = allocator };
    }

    pub fn display(self: *const ChecksumList, writer: anytype) !void {
        for (self.items) |item| {
            try writer.print("{s}  {d} bytes  {s}\n", .{ item.hash[0..16], item.size, item.path });
        }
    }

    pub fn totalSize(self: *const ChecksumList) u64 {
        var total: u64 = 0;
        for (self.items) |item| total += item.size;
        return total;
    }
};

pub const FileEntry = struct {
    path: []const u8,
    content: []const u8,
    is_directory: bool,
};

pub const ChunkInfo = struct {
    index: u32,
    offset: u64,
    size: u32,
    compressed_size: u32,
    hash: [32]u8,
};

pub const ArchiveStats = struct {
    file_count: u32,
    directory_count: u32,
    total_size: u64,
    compressed_size: u64,
    largest_file: u64,
    smallest_file: u64,
    compression_ratio: f64,

    pub fn display(self: *const ArchiveStats, writer: anytype) !void {
        try writer.print("Files: {d}\n", .{self.file_count});
        try writer.print("Directories: {d}\n", .{self.directory_count});
        try writer.print("Total Size: {d} bytes\n", .{self.total_size});
        try writer.print("Compressed: {d} bytes\n", .{self.compressed_size});
        try writer.print("Ratio: {d:.2}%\n", .{(1.0 - self.compression_ratio) * 100.0});
        try writer.print("Largest: {d} bytes\n", .{self.largest_file});
        try writer.print("Smallest: {d} bytes\n", .{self.smallest_file});
    }
};

pub const CompressError = error{
    NoFilesSpecified,
    FileNotFound,
    DirectoryNotFound,
    FileSystemError,
    CompressionError,
    PathValidationError,
    DuplicatePath,
    OutOfMemory,
    IoError,
    SecurityViolation,
    SigningError,
    FileTooLarge,
    UnsupportedFormat,
    InvalidChunk,
};

pub const CorruptionType = enum {
    none,
    magic_mismatch,
    version_unsupported,
    header_invalid,
    payload_hash_mismatch,
    checksum_mismatch,
    truncated,
    decompression_failed,
    chunk_corrupted,
    index_corrupted,
};

pub const CorruptionInfo = struct {
    corruption_type: CorruptionType,
    offset: u64,
    expected: ?[]const u8,
    actual: ?[]const u8,
    file_path: ?[]const u8,
    recoverable: bool,
    chunk_index: ?u32,
};

pub fn detectFileType(path: []const u8, content: []const u8) FileType {
    const ext = std.fs.path.extension(path);
    if (ext.len > 0) {
        const e = ext[1..];
        if (std.mem.eql(u8, e, "zig") or std.mem.eql(u8, e, "c") or std.mem.eql(u8, e, "cpp") or
            std.mem.eql(u8, e, "h") or std.mem.eql(u8, e, "rs") or std.mem.eql(u8, e, "go") or
            std.mem.eql(u8, e, "py") or std.mem.eql(u8, e, "js") or std.mem.eql(u8, e, "ts"))
        {
            return .source_code;
        }
        if (std.mem.eql(u8, e, "txt") or std.mem.eql(u8, e, "md") or std.mem.eql(u8, e, "rst")) {
            return .text;
        }
        if (std.mem.eql(u8, e, "json") or std.mem.eql(u8, e, "yaml") or std.mem.eql(u8, e, "yml") or
            std.mem.eql(u8, e, "toml") or std.mem.eql(u8, e, "ini") or std.mem.eql(u8, e, "xml"))
        {
            return .config;
        }
        if (std.mem.eql(u8, e, "exe") or std.mem.eql(u8, e, "dll") or std.mem.eql(u8, e, "so") or
            std.mem.eql(u8, e, "dylib") or std.mem.eql(u8, e, "bin"))
        {
            return .executable;
        }
        if (std.mem.eql(u8, e, "png") or std.mem.eql(u8, e, "jpg") or std.mem.eql(u8, e, "jpeg") or
            std.mem.eql(u8, e, "gif") or std.mem.eql(u8, e, "bmp") or std.mem.eql(u8, e, "webp") or
            std.mem.eql(u8, e, "svg") or std.mem.eql(u8, e, "ico"))
        {
            return .image;
        }
        if (std.mem.eql(u8, e, "mp3") or std.mem.eql(u8, e, "wav") or std.mem.eql(u8, e, "flac") or
            std.mem.eql(u8, e, "ogg") or std.mem.eql(u8, e, "aac") or std.mem.eql(u8, e, "m4a"))
        {
            return .audio;
        }
        if (std.mem.eql(u8, e, "mp4") or std.mem.eql(u8, e, "mkv") or std.mem.eql(u8, e, "avi") or
            std.mem.eql(u8, e, "webm") or std.mem.eql(u8, e, "mov") or std.mem.eql(u8, e, "wmv"))
        {
            return .video;
        }
        if (std.mem.eql(u8, e, "zip") or std.mem.eql(u8, e, "tar") or std.mem.eql(u8, e, "gz") or
            std.mem.eql(u8, e, "7z") or std.mem.eql(u8, e, "rar") or std.mem.eql(u8, e, "xz") or
            std.mem.eql(u8, e, "bz2") or std.mem.eql(u8, e, "zst"))
        {
            return .archive;
        }
        if (std.mem.eql(u8, e, "pdf") or std.mem.eql(u8, e, "doc") or std.mem.eql(u8, e, "docx") or
            std.mem.eql(u8, e, "odt") or std.mem.eql(u8, e, "rtf"))
        {
            return .document;
        }
        if (std.mem.eql(u8, e, "csv") or std.mem.eql(u8, e, "db") or std.mem.eql(u8, e, "sqlite") or
            std.mem.eql(u8, e, "parquet") or std.mem.eql(u8, e, "arrow"))
        {
            return .data;
        }
    }
    if (content.len > 0) {
        var binary_count: usize = 0;
        const check_len = @min(content.len, 8192);
        for (content[0..check_len]) |b| {
            if (b < 0x09 or (b > 0x0D and b < 0x20 and b != 0x1B)) binary_count += 1;
        }
        if (binary_count * 100 / check_len > 10) return .binary;
        return .text;
    }
    return .unknown;
}

pub fn formatSize(size: u64) struct { value: f64, unit: []const u8 } {
    if (size < 1024) return .{ .value = @floatFromInt(size), .unit = "B" };
    if (size < 1024 * 1024) return .{ .value = @as(f64, @floatFromInt(size)) / 1024.0, .unit = "KB" };
    if (size < 1024 * 1024 * 1024) return .{ .value = @as(f64, @floatFromInt(size)) / (1024.0 * 1024.0), .unit = "MB" };
    return .{ .value = @as(f64, @floatFromInt(size)) / (1024.0 * 1024.0 * 1024.0), .unit = "GB" };
}

/// Convert bytes to hex string
pub fn bytesToHex(bytes: []const u8) [64]u8 {
    const hex_chars = "0123456789abcdef";
    var result: [64]u8 = [_]u8{'0'} ** 64; // Initialize with zeros
    const len = @min(bytes.len, 32);
    for (0..len) |i| {
        result[i * 2] = hex_chars[bytes[i] >> 4];
        result[i * 2 + 1] = hex_chars[bytes[i] & 0x0F];
    }
    return result;
}

test "header_size" {
    try std.testing.expectEqual(@as(usize, 128), HEADER_SIZE);
}

test "header_roundtrip" {
    const original = Header{
        .meta_length = 100,
        .checksums_length = 200,
        .payload_length = 1000,
        .original_size = 5000,
        .file_count = 10,
        .payload_hash = [_]u8{0xAB} ** 32,
        .signature_length = 64,
    };
    const bytes = original.toBytes();
    const restored = Header.fromBytes(&bytes);
    try std.testing.expectEqual(original.version, restored.version);
    try std.testing.expectEqual(original.meta_length, restored.meta_length);
    try std.testing.expectEqual(original.original_size, restored.original_size);
    try std.testing.expectEqual(original.file_count, restored.file_count);
}

test "header_validation" {
    const valid = Header{ .meta_length = 100, .checksums_length = 200 };
    try std.testing.expect(valid.validate());
    const invalid_magic = Header{ .magic = .{ 'X', 'Y', 'Z', 'W' }, .meta_length = 100, .checksums_length = 200 };
    try std.testing.expect(!invalid_magic.validate());
}

test "metadata_roundtrip" {
    const allocator = std.testing.allocator;
    var meta = Metadata.init(allocator);
    defer meta.deinit();
    try meta.set("name", "testpkg");
    try meta.set("version", "1.2.3");
    try meta.set("author", "test");
    const serialized = try meta.serialize();
    defer allocator.free(serialized);
    var parsed = try Metadata.parse(serialized, allocator);
    defer parsed.deinit();
    try std.testing.expectEqualStrings("testpkg", parsed.get("name").?);
    try std.testing.expectEqualStrings("1.2.3", parsed.get("version").?);
}

test "checksum_roundtrip" {
    const allocator = std.testing.allocator;
    var items = try allocator.alloc(Checksum, 2);
    items[0] = .{ .path = try allocator.dupe(u8, "src/main.zig"), .size = 1234, .hash = [_]u8{'a'} ** 64 };
    items[1] = .{ .path = try allocator.dupe(u8, "build.zig"), .size = 5678, .hash = [_]u8{'b'} ** 64 };
    var list = ChecksumList{ .items = items, .allocator = allocator };
    defer list.deinit(allocator);
    const serialized = try list.serialize();
    defer allocator.free(serialized);
    var parsed = try ChecksumList.parse(serialized, allocator);
    defer parsed.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), parsed.items.len);
    try std.testing.expectEqualStrings("src/main.zig", parsed.items[0].path);
}

test "detect_file_type" {
    try std.testing.expectEqual(FileType.source_code, detectFileType("main.zig", "const std"));
    try std.testing.expectEqual(FileType.image, detectFileType("photo.png", ""));
    try std.testing.expectEqual(FileType.config, detectFileType("config.json", ""));
    try std.testing.expectEqual(FileType.executable, detectFileType("app.exe", ""));
}

test "format_size" {
    const kb = formatSize(2048);
    try std.testing.expectEqualStrings("KB", kb.unit);
    const mb = formatSize(5 * 1024 * 1024);
    try std.testing.expectEqualStrings("MB", mb.unit);
}
