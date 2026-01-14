const std = @import("std");
const Allocator = std.mem.Allocator;
const format = @import("format.zig");
const parser = @import("parser.zig");
const hash = @import("hash.zig");
const compression = @import("compression.zig");

const Header = format.Header;
const HEADER_SIZE = format.HEADER_SIZE;
const CorruptionType = format.CorruptionType;
const CorruptionInfo = format.CorruptionInfo;

pub const ValidationError = error{
    FileNotFound,
    InvalidFormat,
    PayloadHashMismatch,
    FileChecksumMismatch,
    DecompressionFailed,
    OutOfMemory,
    IoError,
    UnexpectedEof,
    MissingFile,
    SignatureInvalid,
    Corrupted,
};

pub const ValidationResult = struct {
    is_valid: bool,
    header_valid: bool,
    payload_hash_valid: bool,
    file_checksums_valid: bool,
    signature_valid: bool,
    files_validated: usize,
    files_with_errors: usize,
    mismatched_files: []const []const u8,
    corruption_info: ?CorruptionInfo,
    allocator: Allocator,

    pub fn deinit(self: *ValidationResult) void {
        for (self.mismatched_files) |path| self.allocator.free(path);
        self.allocator.free(self.mismatched_files);
    }
};

pub fn validate(path: []const u8, allocator: Allocator) ValidationError!bool {
    var result = try validateDetailed(path, allocator);
    defer result.deinit();
    return result.is_valid;
}

pub fn validateDetailed(path: []const u8, allocator: Allocator) ValidationError!ValidationResult {
    var archive = parser.parse(path, allocator) catch |err| {
        return switch (err) {
            parser.ParseError.FileNotFound => ValidationError.FileNotFound,
            parser.ParseError.OutOfMemory => ValidationError.OutOfMemory,
            parser.ParseError.InvalidMagic, parser.ParseError.UnsupportedVersion, parser.ParseError.MalformedHeader => ValidationError.InvalidFormat,
            else => ValidationError.IoError,
        };
    };
    defer archive.deinit();

    var mismatched = std.ArrayListUnmanaged([]const u8){};
    errdefer {
        for (mismatched.items) |p| allocator.free(p);
        mismatched.deinit(allocator);
    }

    const payload_offset = archive.getPayloadOffset();
    archive.file.seekTo(payload_offset) catch return ValidationError.IoError;

    // Safely convert u64 to usize for 32-bit platforms
    const val_payload_len: usize = std.math.cast(usize, archive.header.payload_length) orelse {
        return ValidationError.OutOfMemory;
    };
    const compressed_payload = allocator.alloc(u8, val_payload_len) catch {
        return ValidationError.OutOfMemory;
    };
    defer allocator.free(compressed_payload);

    const bytes_read = archive.file.readAll(compressed_payload) catch return ValidationError.IoError;
    if (bytes_read < val_payload_len) return ValidationError.UnexpectedEof;

    const actual_payload_hash = hash.hashBytes(compressed_payload);
    const payload_hash_valid = std.mem.eql(u8, &actual_payload_hash, &archive.header.payload_hash);

    if (!payload_hash_valid) {
        return ValidationResult{
            .is_valid = false,
            .header_valid = true,
            .payload_hash_valid = false,
            .file_checksums_valid = false,
            .signature_valid = true,
            .files_validated = 0,
            .files_with_errors = 0,
            .mismatched_files = mismatched.toOwnedSlice(allocator) catch return ValidationError.OutOfMemory,
            .corruption_info = CorruptionInfo{
                .corruption_type = .payload_hash_mismatch,
                .offset = payload_offset,
                .expected = null,
                .actual = null,
                .file_path = null,
                .recoverable = false,
                .chunk_index = null,
            },
            .allocator = allocator,
        };
    }

    const decompressed = compression.decompress(compressed_payload, allocator) catch {
        return ValidationResult{
            .is_valid = false,
            .header_valid = true,
            .payload_hash_valid = true,
            .file_checksums_valid = false,
            .signature_valid = true,
            .files_validated = 0,
            .files_with_errors = 0,
            .mismatched_files = mismatched.toOwnedSlice(allocator) catch return ValidationError.OutOfMemory,
            .corruption_info = CorruptionInfo{
                .corruption_type = .decompression_failed,
                .offset = payload_offset,
                .expected = null,
                .actual = null,
                .file_path = null,
                .recoverable = false,
                .chunk_index = null,
            },
            .allocator = allocator,
        };
    };
    defer allocator.free(decompressed);

    var offset: usize = 0;
    var files_validated: usize = 0;
    var files_with_errors: usize = 0;

    for (archive.checksums.items) |expected| {
        if (offset + 4 > decompressed.len) return ValidationError.UnexpectedEof;

        const path_len = std.mem.readInt(u32, decompressed[offset..][0..4], .little);
        offset += 4;

        if (offset + path_len > decompressed.len) return ValidationError.UnexpectedEof;

        const file_path = decompressed[offset..][0..path_len];
        offset += path_len;

        if (!std.mem.eql(u8, file_path, expected.path)) return ValidationError.MissingFile;

        if (offset + 8 > decompressed.len) return ValidationError.UnexpectedEof;

        const content_len = std.mem.readInt(u64, decompressed[offset..][0..8], .little);
        offset += 8;

        if (offset + content_len > decompressed.len) return ValidationError.UnexpectedEof;

        const content = decompressed[offset..][0..content_len];
        offset += content_len;

        const actual_hash = hash.hashHex(content);
        files_validated += 1;

        if (!std.mem.eql(u8, &actual_hash, &expected.hash)) {
            files_with_errors += 1;
            const path_copy = allocator.dupe(u8, expected.path) catch return ValidationError.OutOfMemory;
            mismatched.append(allocator, path_copy) catch {
                allocator.free(path_copy);
                return ValidationError.OutOfMemory;
            };
        }
    }

    const file_checksums_valid = files_with_errors == 0;

    return ValidationResult{
        .is_valid = payload_hash_valid and file_checksums_valid,
        .header_valid = true,
        .payload_hash_valid = payload_hash_valid,
        .file_checksums_valid = file_checksums_valid,
        .signature_valid = true,
        .files_validated = files_validated,
        .files_with_errors = files_with_errors,
        .mismatched_files = mismatched.toOwnedSlice(allocator) catch return ValidationError.OutOfMemory,
        .corruption_info = if (files_with_errors > 0) CorruptionInfo{
            .corruption_type = .checksum_mismatch,
            .offset = 0,
            .expected = null,
            .actual = null,
            .file_path = null,
            .recoverable = true,
            .chunk_index = null,
        } else null,
        .allocator = allocator,
    };
}

pub fn validateQuick(path: []const u8, allocator: Allocator) ValidationError!bool {
    var archive = parser.parse(path, allocator) catch |err| {
        return switch (err) {
            parser.ParseError.FileNotFound => ValidationError.FileNotFound,
            parser.ParseError.OutOfMemory => ValidationError.OutOfMemory,
            else => ValidationError.InvalidFormat,
        };
    };
    defer archive.deinit();

    if (!archive.header.validate()) return false;

    const payload_offset = archive.getPayloadOffset();
    archive.file.seekTo(payload_offset) catch return ValidationError.IoError;

    // Safely convert u64 to usize for 32-bit platforms
    const vp_payload_len: usize = std.math.cast(usize, archive.header.payload_length) orelse {
        return ValidationError.OutOfMemory;
    };
    const compressed_payload = allocator.alloc(u8, vp_payload_len) catch {
        return ValidationError.OutOfMemory;
    };
    defer allocator.free(compressed_payload);

    const bytes_read = archive.file.readAll(compressed_payload) catch return ValidationError.IoError;
    if (bytes_read < vp_payload_len) return ValidationError.UnexpectedEof;

    const actual_hash = hash.hashBytes(compressed_payload);
    return std.mem.eql(u8, &actual_hash, &archive.header.payload_hash);
}

pub fn validateFile(
    archive_path: []const u8,
    file_path: []const u8,
    allocator: Allocator,
) ValidationError!bool {
    var archive = parser.parse(archive_path, allocator) catch |err| {
        return switch (err) {
            parser.ParseError.FileNotFound => ValidationError.FileNotFound,
            parser.ParseError.OutOfMemory => ValidationError.OutOfMemory,
            else => ValidationError.InvalidFormat,
        };
    };
    defer archive.deinit();

    var expected_hash: ?[64]u8 = null;
    for (archive.checksums.items) |item| {
        if (std.mem.eql(u8, item.path, file_path)) {
            expected_hash = item.hash;
            break;
        }
    }

    if (expected_hash == null) return ValidationError.MissingFile;

    const payload_offset = archive.getPayloadOffset();
    archive.file.seekTo(payload_offset) catch return ValidationError.IoError;

    // Safely convert u64 to usize for 32-bit platforms
    const vf_payload_len: usize = std.math.cast(usize, archive.header.payload_length) orelse {
        return ValidationError.OutOfMemory;
    };
    const compressed = allocator.alloc(u8, vf_payload_len) catch {
        return ValidationError.OutOfMemory;
    };
    defer allocator.free(compressed);

    _ = archive.file.readAll(compressed) catch return ValidationError.IoError;

    const decompressed = compression.decompress(compressed, allocator) catch {
        return ValidationError.DecompressionFailed;
    };
    defer allocator.free(decompressed);

    var offset: usize = 0;
    while (offset < decompressed.len) {
        if (offset + 4 > decompressed.len) break;

        const path_len = std.mem.readInt(u32, decompressed[offset..][0..4], .little);
        offset += 4;

        if (offset + path_len > decompressed.len) break;

        const current_path = decompressed[offset..][0..path_len];
        offset += path_len;

        if (offset + 8 > decompressed.len) break;

        const content_len = std.mem.readInt(u64, decompressed[offset..][0..8], .little);
        offset += 8;

        if (offset + content_len > decompressed.len) break;

        const content = decompressed[offset..][0..content_len];
        offset += content_len;

        if (std.mem.eql(u8, current_path, file_path)) {
            const actual_hash = hash.hashHex(content);
            return std.mem.eql(u8, &actual_hash, &expected_hash.?);
        }
    }

    return ValidationError.MissingFile;
}

pub fn detectCorruption(path: []const u8, allocator: Allocator) !?CorruptionInfo {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        return switch (err) {
            error.FileNotFound => CorruptionInfo{
                .corruption_type = .none,
                .offset = 0,
                .expected = null,
                .actual = null,
                .file_path = null,
                .recoverable = false,
                .chunk_index = null,
            },
            else => null,
        };
    };
    defer file.close();

    var header_bytes: [HEADER_SIZE]u8 = undefined;
    const bytes_read = file.readAll(&header_bytes) catch {
        return CorruptionInfo{
            .corruption_type = .truncated,
            .offset = 0,
            .expected = null,
            .actual = null,
            .file_path = null,
            .recoverable = false,
            .chunk_index = null,
        };
    };

    if (bytes_read < HEADER_SIZE) {
        return CorruptionInfo{
            .corruption_type = .truncated,
            .offset = bytes_read,
            .expected = null,
            .actual = null,
            .file_path = null,
            .recoverable = false,
            .chunk_index = null,
        };
    }

    const header = Header.fromBytes(&header_bytes);

    if (!std.mem.eql(u8, &header.magic, &format.MAGIC)) {
        return CorruptionInfo{
            .corruption_type = .magic_mismatch,
            .offset = 0,
            .expected = null,
            .actual = null,
            .file_path = null,
            .recoverable = false,
            .chunk_index = null,
        };
    }

    if (header.version > format.FORMAT_VERSION) {
        return CorruptionInfo{
            .corruption_type = .version_unsupported,
            .offset = 4,
            .expected = null,
            .actual = null,
            .file_path = null,
            .recoverable = false,
            .chunk_index = null,
        };
    }

    if (!header.validate()) {
        return CorruptionInfo{
            .corruption_type = .header_invalid,
            .offset = 0,
            .expected = null,
            .actual = null,
            .file_path = null,
            .recoverable = false,
            .chunk_index = null,
        };
    }

    const payload_offset = HEADER_SIZE + header.meta_length + header.checksums_length;
    file.seekTo(payload_offset) catch {
        return CorruptionInfo{
            .corruption_type = .truncated,
            .offset = payload_offset,
            .expected = null,
            .actual = null,
            .file_path = null,
            .recoverable = false,
            .chunk_index = null,
        };
    };

    // Safely convert u64 to usize for 32-bit platforms
    const dc_payload_len: usize = std.math.cast(usize, header.payload_length) orelse {
        return null; // File too large for this platform
    };
    const compressed_payload = allocator.alloc(u8, dc_payload_len) catch {
        return null;
    };
    defer allocator.free(compressed_payload);

    const payload_read = file.readAll(compressed_payload) catch {
        return CorruptionInfo{
            .corruption_type = .truncated,
            .offset = payload_offset,
            .expected = null,
            .actual = null,
            .file_path = null,
            .recoverable = false,
            .chunk_index = null,
        };
    };

    if (payload_read < dc_payload_len) {
        return CorruptionInfo{
            .corruption_type = .truncated,
            .offset = payload_offset + payload_read,
            .expected = null,
            .actual = null,
            .file_path = null,
            .recoverable = false,
            .chunk_index = null,
        };
    }

    const actual_hash = hash.hashBytes(compressed_payload);
    if (!std.mem.eql(u8, &actual_hash, &header.payload_hash)) {
        return CorruptionInfo{
            .corruption_type = .payload_hash_mismatch,
            .offset = payload_offset,
            .expected = null,
            .actual = null,
            .file_path = null,
            .recoverable = false,
            .chunk_index = null,
        };
    }

    const decompressed = compression.decompress(compressed_payload, allocator) catch {
        return CorruptionInfo{
            .corruption_type = .decompression_failed,
            .offset = payload_offset,
            .expected = null,
            .actual = null,
            .file_path = null,
            .recoverable = false,
            .chunk_index = null,
        };
    };
    allocator.free(decompressed);

    return null;
}

test "imports" {
    _ = format;
    _ = parser;
    _ = hash;
    _ = compression;
}
