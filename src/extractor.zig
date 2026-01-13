const std = @import("std");
const Allocator = std.mem.Allocator;
const format = @import("format.zig");
const parser = @import("parser.zig");
const security = @import("security.zig");
const hash = @import("hash.zig");
const compression = @import("compression.zig");

pub const ExtractionError = error{
    FileNotFound,
    InvalidFormat,
    PathTraversal,
    AbsolutePath,
    DuplicatePath,
    ChecksumMismatch,
    DecompressionFailed,
    CannotCreateDirectory,
    CannotWriteFile,
    FileExists,
    OutOfMemory,
    IoError,
    UnexpectedEof,
    PayloadHashMismatch,
    Corrupted,
};

pub const ExtractOptions = struct {
    archive_path: []const u8,
    output_dir: []const u8,
    allocator: Allocator,
    validate: bool = true,
    overwrite: bool = false,
};

pub const ExtractResult = struct {
    files_extracted: usize,
    bytes_written: u64,
    files: []const []const u8,
    allocator: Allocator,

    pub fn deinit(self: *ExtractResult) void {
        for (self.files) |path| self.allocator.free(path);
        self.allocator.free(self.files);
    }
};

pub fn extract(options: ExtractOptions) ExtractionError!void {
    var result = try extractWithResult(options);
    result.deinit();
}

pub fn extractWithResult(options: ExtractOptions) ExtractionError!ExtractResult {
    const allocator = options.allocator;

    var archive = parser.parse(options.archive_path, allocator) catch |err| {
        return switch (err) {
            parser.ParseError.FileNotFound => ExtractionError.FileNotFound,
            parser.ParseError.InvalidMagic, parser.ParseError.UnsupportedVersion, parser.ParseError.MalformedHeader => ExtractionError.InvalidFormat,
            parser.ParseError.OutOfMemory => ExtractionError.OutOfMemory,
            parser.ParseError.SecurityViolation => ExtractionError.PathTraversal,
            else => ExtractionError.IoError,
        };
    };
    defer archive.deinit();

    const payload_offset = archive.getPayloadOffset();
    archive.file.seekTo(payload_offset) catch return ExtractionError.IoError;

    const compressed = allocator.alloc(u8, archive.header.payload_length) catch {
        return ExtractionError.OutOfMemory;
    };
    defer allocator.free(compressed);

    const bytes_read = archive.file.readAll(compressed) catch return ExtractionError.IoError;
    if (bytes_read < archive.header.payload_length) return ExtractionError.UnexpectedEof;

    if (options.validate) {
        const actual_hash = hash.hashBytes(compressed);
        if (!std.mem.eql(u8, &actual_hash, &archive.header.payload_hash)) {
            return ExtractionError.PayloadHashMismatch;
        }
    }

    const decompressed = compression.decompress(compressed, allocator) catch {
        return ExtractionError.DecompressionFailed;
    };
    defer allocator.free(decompressed);

    std.fs.cwd().makePath(options.output_dir) catch {
        return ExtractionError.CannotCreateDirectory;
    };

    var output_dir = std.fs.cwd().openDir(options.output_dir, .{}) catch {
        return ExtractionError.CannotCreateDirectory;
    };
    defer output_dir.close();

    var extracted_files: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (extracted_files.items) |p| allocator.free(p);
        extracted_files.deinit(allocator);
    }

    var path_tracker = security.DuplicateTracker.init(allocator);
    defer path_tracker.deinit();

    var bytes_written: u64 = 0;
    var checksum_index: usize = 0;

    var offset: usize = 0;
    while (offset < decompressed.len) {
        if (offset + 4 > decompressed.len) break;

        const path_len = std.mem.readInt(u32, decompressed[offset..][0..4], .little);
        offset += 4;

        if (offset + path_len > decompressed.len) return ExtractionError.UnexpectedEof;

        const file_path = decompressed[offset..][0..path_len];
        offset += path_len;

        security.validatePath(file_path) catch |err| {
            return switch (err) {
                security.SecurityError.PathTraversal => ExtractionError.PathTraversal,
                security.SecurityError.AbsolutePath => ExtractionError.AbsolutePath,
                security.SecurityError.DuplicatePath => ExtractionError.DuplicatePath,
                else => ExtractionError.PathTraversal,
            };
        };

        path_tracker.addPath(file_path) catch {
            return ExtractionError.DuplicatePath;
        };

        if (offset + 8 > decompressed.len) return ExtractionError.UnexpectedEof;

        const content_len = std.mem.readInt(u64, decompressed[offset..][0..8], .little);
        offset += 8;

        if (offset + content_len > decompressed.len) return ExtractionError.UnexpectedEof;

        const content = decompressed[offset..][0..content_len];
        offset += content_len;

        if (options.validate and checksum_index < archive.checksums.items.len) {
            const expected = archive.checksums.items[checksum_index];
            const actual_hash = hash.hashHex(content);
            if (!std.mem.eql(u8, &actual_hash, &expected.hash)) {
                return ExtractionError.ChecksumMismatch;
            }
        }
        checksum_index += 1;

        if (std.fs.path.dirname(file_path)) |dir| {
            output_dir.makePath(dir) catch {
                return ExtractionError.CannotCreateDirectory;
            };
        }

        if (!options.overwrite) {
            output_dir.access(file_path, .{}) catch |err| {
                if (err != error.FileNotFound) {
                    return ExtractionError.FileExists;
                }
            };
        }

        const file = output_dir.createFile(file_path, .{ .truncate = true }) catch {
            return ExtractionError.CannotWriteFile;
        };
        defer file.close();

        file.writeAll(content) catch return ExtractionError.CannotWriteFile;
        bytes_written += content.len;

        const path_copy = allocator.dupe(u8, file_path) catch return ExtractionError.OutOfMemory;
        extracted_files.append(allocator, path_copy) catch {
            allocator.free(path_copy);
            return ExtractionError.OutOfMemory;
        };
    }

    return ExtractResult{
        .files_extracted = extracted_files.items.len,
        .bytes_written = bytes_written,
        .files = extracted_files.toOwnedSlice(allocator) catch return ExtractionError.OutOfMemory,
        .allocator = allocator,
    };
}

pub fn extractFile(
    archive_path: []const u8,
    file_path: []const u8,
    output_path: []const u8,
    allocator: Allocator,
) ExtractionError!void {
    security.validatePath(file_path) catch |err| {
        return switch (err) {
            security.SecurityError.PathTraversal => ExtractionError.PathTraversal,
            security.SecurityError.AbsolutePath => ExtractionError.AbsolutePath,
            else => ExtractionError.PathTraversal,
        };
    };

    var archive = parser.parse(archive_path, allocator) catch |err| {
        return switch (err) {
            parser.ParseError.FileNotFound => ExtractionError.FileNotFound,
            parser.ParseError.OutOfMemory => ExtractionError.OutOfMemory,
            else => ExtractionError.InvalidFormat,
        };
    };
    defer archive.deinit();

    const payload_offset = archive.getPayloadOffset();
    archive.file.seekTo(payload_offset) catch return ExtractionError.IoError;

    const compressed = allocator.alloc(u8, archive.header.payload_length) catch {
        return ExtractionError.OutOfMemory;
    };
    defer allocator.free(compressed);

    _ = archive.file.readAll(compressed) catch return ExtractionError.IoError;

    const decompressed = compression.decompress(compressed, allocator) catch {
        return ExtractionError.DecompressionFailed;
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
            if (std.fs.path.dirname(output_path)) |dir| {
                std.fs.cwd().makePath(dir) catch {
                    return ExtractionError.CannotCreateDirectory;
                };
            }

            const file = std.fs.cwd().createFile(output_path, .{}) catch {
                return ExtractionError.CannotWriteFile;
            };
            defer file.close();

            file.writeAll(content) catch return ExtractionError.CannotWriteFile;
            return;
        }
    }

    return ExtractionError.IoError;
}

pub fn listFiles(archive_path: []const u8, allocator: Allocator) ExtractionError![]const []const u8 {
    var archive = parser.parse(archive_path, allocator) catch |err| {
        return switch (err) {
            parser.ParseError.FileNotFound => ExtractionError.FileNotFound,
            parser.ParseError.OutOfMemory => ExtractionError.OutOfMemory,
            else => ExtractionError.InvalidFormat,
        };
    };
    defer archive.deinit();

    var files: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (files.items) |p| allocator.free(p);
        files.deinit(allocator);
    }

    for (archive.checksums.items) |item| {
        const path_copy = allocator.dupe(u8, item.path) catch return ExtractionError.OutOfMemory;
        files.append(allocator, path_copy) catch {
            allocator.free(path_copy);
            return ExtractionError.OutOfMemory;
        };
    }

    return files.toOwnedSlice(allocator) catch return ExtractionError.OutOfMemory;
}

test "imports" {
    _ = format;
    _ = parser;
    _ = security;
    _ = hash;
    _ = compression;
}
