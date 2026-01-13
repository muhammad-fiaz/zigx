const std = @import("std");
const Allocator = std.mem.Allocator;
const format = @import("format.zig");
const security = @import("security.zig");

const Header = format.Header;
const Metadata = format.Metadata;
const Checksum = format.Checksum;
const ChecksumList = format.ChecksumList;
const HEADER_SIZE = format.HEADER_SIZE;
const MAGIC = format.MAGIC;

pub const ParseError = error{
    FileNotFound,
    InvalidMagic,
    UnsupportedVersion,
    MalformedHeader,
    InvalidMetadata,
    InvalidChecksums,
    OutOfMemory,
    IoError,
    UnexpectedEof,
    SecurityViolation,
    Corrupted,
};

pub const Archive = struct {
    header: Header,
    meta: Metadata,
    checksums: ChecksumList,
    signature: ?[]const u8,
    file: std.fs.File,
    path: []const u8,
    allocator: Allocator,

    pub fn deinit(self: *Archive) void {
        self.meta.deinit();
        self.checksums.deinit(self.allocator);
        if (self.signature) |sig| self.allocator.free(sig);
        self.file.close();
        self.allocator.free(self.path);
    }

    pub fn getFileList(self: *const Archive) []const Checksum {
        return self.checksums.items;
    }

    pub fn getTotalUncompressedSize(self: *const Archive) u64 {
        var total: u64 = 0;
        for (self.checksums.items) |item| total += item.size;
        return total;
    }

    pub fn getPayloadOffset(self: *const Archive) u64 {
        return HEADER_SIZE + self.header.meta_length + self.header.checksums_length;
    }

    pub fn isSigned(self: *const Archive) bool {
        return self.header.isSigned();
    }

    pub fn getMetadata(self: *const Archive, key: []const u8) ?[]const u8 {
        return self.meta.get(key);
    }
};

pub fn parse(path: []const u8, allocator: Allocator) ParseError!Archive {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        return switch (err) {
            error.FileNotFound => ParseError.FileNotFound,
            else => ParseError.IoError,
        };
    };
    errdefer file.close();

    var header_bytes: [HEADER_SIZE]u8 = undefined;
    const bytes_read = file.readAll(&header_bytes) catch return ParseError.IoError;
    if (bytes_read < HEADER_SIZE) return ParseError.UnexpectedEof;

    const header = Header.fromBytes(&header_bytes);

    if (!std.mem.eql(u8, &header.magic, &MAGIC)) return ParseError.InvalidMagic;
    if (header.version > format.FORMAT_VERSION) return ParseError.UnsupportedVersion;
    if (!header.validate()) return ParseError.MalformedHeader;

    const meta_buf = allocator.alloc(u8, header.meta_length) catch return ParseError.OutOfMemory;
    defer allocator.free(meta_buf);

    const meta_read = file.readAll(meta_buf) catch return ParseError.IoError;
    if (meta_read < header.meta_length) return ParseError.UnexpectedEof;

    var meta = Metadata.parse(meta_buf, allocator) catch {
        return ParseError.InvalidMetadata;
    };
    errdefer meta.deinit();

    const checksums_buf = allocator.alloc(u8, header.checksums_length) catch return ParseError.OutOfMemory;
    defer allocator.free(checksums_buf);

    const checksums_read = file.readAll(checksums_buf) catch return ParseError.IoError;
    if (checksums_read < header.checksums_length) return ParseError.UnexpectedEof;

    var checksums = ChecksumList.parse(checksums_buf, allocator) catch {
        return ParseError.InvalidChecksums;
    };
    errdefer checksums.deinit(allocator);

    for (checksums.items) |item| {
        security.validatePath(item.path) catch {
            return ParseError.SecurityViolation;
        };
    }

    var signature: ?[]const u8 = null;
    if (header.isSigned() and header.signature_length > 0) {
        const payload_end = HEADER_SIZE + header.meta_length + header.checksums_length + header.payload_length;
        file.seekTo(payload_end) catch return ParseError.IoError;
        const sig_buf = allocator.alloc(u8, header.signature_length) catch return ParseError.OutOfMemory;
        errdefer allocator.free(sig_buf);
        const sig_read = file.readAll(sig_buf) catch return ParseError.IoError;
        if (sig_read < header.signature_length) {
            allocator.free(sig_buf);
            return ParseError.UnexpectedEof;
        }
        signature = sig_buf;
    }

    const path_copy = allocator.dupe(u8, path) catch return ParseError.OutOfMemory;
    errdefer allocator.free(path_copy);

    return Archive{
        .header = header,
        .meta = meta,
        .checksums = checksums,
        .signature = signature,
        .file = file,
        .path = path_copy,
        .allocator = allocator,
    };
}

pub fn readHeader(path: []const u8) ParseError!Header {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        return switch (err) {
            error.FileNotFound => ParseError.FileNotFound,
            else => ParseError.IoError,
        };
    };
    defer file.close();

    var header_bytes: [HEADER_SIZE]u8 = undefined;
    const bytes_read = file.readAll(&header_bytes) catch return ParseError.IoError;
    if (bytes_read < HEADER_SIZE) return ParseError.UnexpectedEof;

    const header = Header.fromBytes(&header_bytes);

    if (!std.mem.eql(u8, &header.magic, &MAGIC)) return ParseError.InvalidMagic;

    return header;
}

pub fn isValidArchive(path: []const u8) bool {
    const header = readHeader(path) catch return false;
    return header.validate();
}

test "header_validation" {
    const valid = Header{ .meta_length = 100, .checksums_length = 200 };
    try std.testing.expect(valid.validate());
    const invalid_magic = Header{ .magic = .{ 'X', 'Y', 'Z', 'W' }, .meta_length = 100, .checksums_length = 200 };
    try std.testing.expect(!invalid_magic.validate());
}

test "imports" {
    _ = format;
    _ = security;
}
