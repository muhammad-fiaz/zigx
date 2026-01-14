const std = @import("std");
const Allocator = std.mem.Allocator;
const format = @import("format.zig");
const parser = @import("parser.zig");
const bundler = @import("bundler.zig");
const extractor = @import("extractor.zig");
const validator = @import("validator.zig");
const utils = @import("utils.zig");
const compression = @import("compression.zig");
const security = @import("security.zig");
const zstd = @import("zstd");

/// Extended operations for managing ZIGX archives
pub const MetadataOp = union(enum) {
    set: []const u8,
    delete,
};

pub const MetadataUpdate = struct {
    key: []const u8,
    op: MetadataOp,
};

pub fn getMetadata(path: []const u8, key: []const u8, allocator: Allocator) ManagerError!?[]const u8 {
    var archive = parser.parse(path, allocator) catch |err| {
        return switch (err) {
            parser.ParseError.FileNotFound => ManagerError.ArchiveNotFound,
            else => ManagerError.OperationFailed,
        };
    };
    defer archive.deinit();

    if (archive.getMetadata(key)) |val| {
        return allocator.dupe(u8, val) catch return ManagerError.OutOfMemory;
    }
    return null;
}

pub fn getAllMetadata(path: []const u8, allocator: Allocator) ManagerError!std.StringHashMapUnmanaged([]const u8) {
    var archive = parser.parse(path, allocator) catch |err| {
        return switch (err) {
            parser.ParseError.FileNotFound => ManagerError.ArchiveNotFound,
            else => ManagerError.OperationFailed,
        };
    };
    defer archive.deinit();

    var map = std.StringHashMapUnmanaged([]const u8){};
    var it = archive.meta.entries.iterator();
    while (it.next()) |entry| {
        const k = try allocator.dupe(u8, entry.key_ptr.*);
        const v = try allocator.dupe(u8, entry.value_ptr.*);
        try map.put(allocator, k, v);
    }
    return map;
}

pub fn updateMetadata(archive_path: []const u8, updates: []const MetadataUpdate, allocator: Allocator) ManagerError!void {
    // Determine temp path early to allow scoping
    const temp_path = try std.fmt.allocPrint(allocator, "{s}.tmp.{d}", .{ archive_path, std.time.milliTimestamp() });
    defer allocator.free(temp_path);

    {
        // 1. Parse existing archive to get structures
        var archive = parser.parse(archive_path, allocator) catch |err| {
            return switch (err) {
                parser.ParseError.FileNotFound => ManagerError.ArchiveNotFound,
                else => ManagerError.OperationFailed,
            };
        };
        defer archive.deinit();

        // 2. Prepare new metadata map
        // Deep copy existing metadata because we'll need it after archive.deinit() potentially,
        // or rather, we will build the new metadata block in memory.

        var new_meta = format.Metadata.init(allocator);
        defer new_meta.deinit();

        // Copy existing
        var it = archive.meta.entries.iterator();
        while (it.next()) |entry| {
            try new_meta.set(entry.key_ptr.*, entry.value_ptr.*);
        }

        // Apply updates
        for (updates) |up| {
            switch (up.op) {
                .set => |val| try new_meta.set(up.key, val),
                .delete => {
                    if (new_meta.entries.fetchRemove(up.key)) |kv| {
                        allocator.free(kv.key);
                        allocator.free(kv.value);
                    }
                },
            }
        }

        // 3. Serialize new metadata
        const new_meta_bytes = try new_meta.serialize();
        defer allocator.free(new_meta_bytes);

        // 4. Create new temp file
        // temp_path created in outer scope

        const out_file = std.fs.cwd().createFile(temp_path, .{}) catch return ManagerError.IoError;
        var out_file_closed = false;
        defer if (!out_file_closed) out_file.close();

        // 5. Construct new header
        var new_header = archive.header;
        new_header.meta_length = @intCast(new_meta_bytes.len);
        // Determine offset of payload in OLD file
        const old_payload_offset = archive.getPayloadOffset();

        // Check checksums (we preserve them)
        // We need to re-serialize checksums because we don't have the raw bytes easily accessible
        // without reading them again, but parser read them into archive.checksums.
        const checksums_bytes = try archive.checksums.serialize();
        defer allocator.free(checksums_bytes);
        new_header.checksums_length = @intCast(checksums_bytes.len);

        // Invalidate signature on metadata update
        // Any change to header or metadata invalidates the signature
        new_header.signature_length = 0;
        new_header.flags.signed = 0;

        // Write Header
        const header_bytes = new_header.toBytes();
        try out_file.writeAll(&header_bytes);

        // Write New Metadata
        try out_file.writeAll(new_meta_bytes);

        // Write Checksums
        try out_file.writeAll(checksums_bytes);

        // 6. Streaming Copy Payload
        archive.file.seekTo(old_payload_offset) catch return ManagerError.IoError;

        // We can use sendfile or copy in chunks
        var buf: [utils.CHUNK_SIZE]u8 = undefined;
        var remaining = archive.header.payload_length;
        while (remaining > 0) {
            const to_read = @min(remaining, buf.len);
            const read = try archive.file.readAll(buf[0..to_read]);
            if (read < to_read) return ManagerError.Unexpected;
            try out_file.writeAll(buf[0..read]);
            remaining -= read;
        }

        out_file.close();
        out_file_closed = true;
    }
    // 7. Move temp file to original
    try std.fs.cwd().rename(temp_path, archive_path);
}

pub fn setSignature(archive_path: []const u8, signature: []const u8, allocator: Allocator) ManagerError!void {
    _ = allocator;
    // 1. Parse just the header to check validity
    const old_header = parser.readHeader(archive_path) catch return ManagerError.InvalidPath;

    // 2. We need to append signature and update header.
    const file = std.fs.cwd().openFile(archive_path, .{ .mode = .read_write }) catch return ManagerError.IoError;
    defer file.close();

    // Update Header
    var new_header = old_header;
    new_header.flags.signed = 1;
    new_header.signature_length = @intCast(signature.len);

    const header_bytes = new_header.toBytes();
    file.seekTo(0) catch return ManagerError.IoError;
    try file.writeAll(&header_bytes);

    // Append Signature to end
    // Calculate where signature should go: Header + Meta + Checksums + Payload
    const end_offset = format.HEADER_SIZE + old_header.meta_length + old_header.checksums_length + old_header.payload_length;
    file.seekTo(end_offset) catch return ManagerError.IoError;
    try file.writeAll(signature);

    // Truncate in case there was an old larger signature or garbage
    file.setEndPos(end_offset + signature.len) catch return ManagerError.IoError;
}

pub const ManagerError = error{
    ArchiveNotFound,
    OperationFailed,
    InvalidPath,
    UpdateFailed,
    RepairFailed,
    OutOfMemory,
    IoError,
    AccessDenied,
    SystemResources,
    ProcessNotFound,
    Unexpected,
    PermissionDenied,
    NoDevice,
    NameTooLong,
    InvalidUtf8,
    InvalidWtf8,
    BadPathName,
    NetworkNotFound,
    SymLinkLoop,
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    NotDir,
    DeviceBusy,
    FileTooBig,
    InputOutput,
    IsDir,
    NoSpaceLeft,
    NotOpenForReading,
    NotOpenForWriting,
    ReadOnlyFileSystem,
    RenameAcrossMountPoints,
    PathAlreadyExists,
    FileBusy,
    FileSystem,
    OperationAborted,
    BrokenPipe,
    ConnectionResetByPeer,
    ConnectionTimedOut,
    SocketNotConnected,
    WouldBlock,
    Canceled,
    LockViolation,
    SharingViolation,
    PipeBusy,
    AntivirusInterference,
    FileLocksNotSupported,
    DiskQuota,
    InvalidArgument,
    MessageTooBig,
    LinkQuotaExceeded,
} || parser.ParseError || format.CompressError || extractor.ExtractionError;

pub const UpdateOptions = struct {
    allocator: Allocator,
    archive_path: []const u8,
    add_files: ?[]const []const u8 = null,
    remove_patterns: ?[]const []const u8 = null,
    output_path: ?[]const u8 = null, // Optional: if null, overwrites in place
    compression_level: config.CompressionLevel = .best,
};

const config = @import("config.zig");

/// Update an existing archive by adding or removing files
pub fn update(options: UpdateOptions) ManagerError!void {
    const allocator = options.allocator;

    // Use a timestamp based name to avoid collisions
    const timestamp = std.time.milliTimestamp();
    const temp_dir_name = try std.fmt.allocPrint(allocator, ".zigx_update_{d}", .{timestamp});
    defer allocator.free(temp_dir_name);

    // Clean up temp dir on exit
    defer {
        std.fs.cwd().deleteTree(temp_dir_name) catch {};
    }

    // Extract existing content to temporary directory for modification
    const extract_opts = extractor.ExtractOptions{
        .archive_path = options.archive_path,
        .output_dir = temp_dir_name,
        .allocator = allocator,
        .validate = true,
        .overwrite = true,
    };

    extractor.extract(extract_opts) catch |err| {
        std.debug.print("Failed to extract existing archive for update: {}\n", .{err});
        return ManagerError.UpdateFailed;
    };

    // Remove specified files if requested
    if (options.remove_patterns) |patterns| {
        if (patterns.len > 0) {
            var dir = try std.fs.cwd().openDir(temp_dir_name, .{ .iterate = true });
            defer dir.close();

            var walker = try dir.walk(allocator);
            defer walker.deinit();

            while (try walker.next()) |entry| {
                if (utils.matchesPattern(entry.path, patterns)) {
                    const full_path = try std.fs.path.join(allocator, &.{ temp_dir_name, entry.path });
                    defer allocator.free(full_path);

                    if (entry.kind == .directory) {
                        try std.fs.cwd().deleteTree(full_path);
                    } else {
                        try std.fs.cwd().deleteFile(full_path);
                    }
                }
            }
        }
    }

    // Add new files if requested by copying them to the temporary directory
    if (options.add_files) |files| {
        for (files) |path| {
            try copyRecursive(allocator, path, temp_dir_name);
        }
    }

    // Re-bundle the contents of the temporary directory into the final archive
    const final_output = options.output_path orelse options.archive_path;

    var target_output: []const u8 = undefined;
    var is_temp_output = false;

    // Use a temporary file for in-place updates to ensure atomicity
    if (options.output_path == null) {
        target_output = try std.fmt.allocPrint(allocator, "{s}.tmp", .{final_output});
        is_temp_output = true;
    } else {
        target_output = final_output;
    }
    defer if (is_temp_output) allocator.free(target_output);

    const bundle_opts = bundler.CompressOptions{
        .allocator = allocator,
        .base_dir = temp_dir_name,
        .include = &.{"."},
        .output_path = target_output,
        .level = options.compression_level,
    };

    var res = try bundler.compress(bundle_opts);
    res.deinit();

    // Finalize the update by renaming the temporary file if necessary
    if (options.output_path == null) {
        try std.fs.cwd().rename(target_output, options.archive_path);
    }
}

/// Helper to copy files/directories for the Update operation
fn copyRecursive(allocator: Allocator, src_path: []const u8, dest_base: []const u8) !void {
    // Get basename of src (e.g., "src/foo.txt" -> "foo.txt")
    const basename = std.fs.path.basename(src_path);
    const dest_path = try std.fs.path.join(allocator, &.{ dest_base, basename });
    defer allocator.free(dest_path);

    const stat = std.fs.cwd().statFile(src_path) catch |err| {
        std.debug.print("Could not access file to add: {s}\n", .{src_path});
        return err;
    };

    if (stat.kind == .directory) {
        try utils.ensurePath(dest_path);
        var dir = try std.fs.cwd().openDir(src_path, .{ .iterate = true });
        defer dir.close();
        var walker = try dir.walk(allocator);
        defer walker.deinit();

        while (try walker.next()) |entry| {
            // Reconstruct relative path
            const rel_path = entry.path;
            const sub_src = try std.fs.path.join(allocator, &.{ src_path, rel_path });
            defer allocator.free(sub_src);
            const sub_dest = try std.fs.path.join(allocator, &.{ dest_path, rel_path });
            defer allocator.free(sub_dest);

            if (entry.kind == .directory) {
                try utils.ensurePath(sub_dest);
            } else {
                try std.fs.cwd().copyFile(sub_src, std.fs.cwd(), sub_dest, .{});
            }
        }
    } else {
        try std.fs.cwd().copyFile(src_path, std.fs.cwd(), dest_path, .{});
    }
}

pub const RepairResult = struct {
    recovered_files: usize,
    was_corrupted: bool,
    path: []const u8,
};

/// Attempt to repair a corrupted archive
pub fn repair(archive_path: []const u8, output_path: []const u8, allocator: Allocator) !RepairResult {
    // Check if it is even corrupted
    const info = validator.detectCorruption(archive_path, allocator) catch null;

    if (info == null) {
        // Not corrupted, just copy
        try std.fs.cwd().copyFile(archive_path, std.fs.cwd(), output_path, .{});
        return RepairResult{ .recovered_files = 0, .was_corrupted = false, .path = output_path };
    }

    // It is corrupted. Let's try to salvage.
    // Use the same extraction-repacking strategy, but ignoring errors during extraction.

    const temp_dir_name = try std.fmt.allocPrint(allocator, ".zigx_repair_{d}", .{std.time.milliTimestamp()});
    defer allocator.free(temp_dir_name);
    defer std.fs.cwd().deleteTree(temp_dir_name) catch {};

    // Custom extraction logic for repair that ignores certain errors
    const files_recovered = try extractForRepair(archive_path, temp_dir_name, allocator);

    if (files_recovered == 0) {
        return ManagerError.RepairFailed;
    }

    // Re-bundle valid files
    const bundle_opts = bundler.CompressOptions{
        .allocator = allocator,
        .base_dir = temp_dir_name,
        .include = &.{"."},
        .output_path = output_path,
        .level = .best,
    };

    var res = try bundler.compress(bundle_opts);
    res.deinit();

    return RepairResult{
        .recovered_files = files_recovered,
        .was_corrupted = true,
        .path = output_path,
    };
}

/// Permissive extractor that attempts to recover files from a potentially corrupted archive.
/// It employs a best-effort approach to extract data even if metadata or checksums are invalid.
fn extractForRepair(archive_path: []const u8, output_dir: []const u8, allocator: Allocator) !usize {
    // Attempt standard parsing first. If strict parsing fails, advanced recovery techniques
    // (like raw payload scanning) would be implemented here in future versions.
    var archive = parser.parse(archive_path, allocator) catch {
        return 0;
    };
    defer archive.deinit();

    const payload_offset = archive.getPayloadOffset();
    archive.file.seekTo(payload_offset) catch return 0;

    const payload_len_safe: usize = std.math.cast(usize, archive.header.payload_length) orelse return 0;

    const compressed = allocator.alloc(u8, payload_len_safe) catch return 0;
    defer allocator.free(compressed);

    // Read available payload data
    const bytes_read = archive.file.readAll(compressed) catch 0;
    if (bytes_read == 0) return 0;

    // Try decompress
    // If validation failed, hash might be wrong, but zstd might still work
    const decompressed = compression.decompress(compressed[0..bytes_read], allocator) catch |err| {
        std.debug.print("Repair Warning: Decompression failed ({}), cannot recover content.\n", .{err});
        return 0;
    };
    defer allocator.free(decompressed);

    try utils.ensurePath(output_dir);

    var count: usize = 0;
    var offset: usize = 0;

    // Iterate files based on ChecksumList order (which corresponds to data order if sequential)
    // If checksums are corrupt, we fall back to metadata if available, or fail.

    const num_files = archive.checksums.items.len;

    for (0..num_files) |i| {
        if (offset >= decompressed.len) break;

        const checksum = archive.checksums.items[i];

        // Verify size bounds to prevent buffer overruns
        if (offset + checksum.size > decompressed.len) {
            break;
        }

        const file_data = decompressed[offset .. offset + checksum.size];
        const file_path = checksum.path;

        // In repair mode, even if hash verification fails, we attempt to save the file
        // to recover maximum possible data. Sanitize path to prevent traversal vulnerabilities.
        if (security.validatePath(file_path)) |_| {
            const full_path = try std.fs.path.join(allocator, &.{ output_dir, file_path });
            defer allocator.free(full_path);

            if (std.fs.path.dirname(full_path)) |d| {
                try utils.ensurePath(d);
            }

            const f = std.fs.cwd().createFile(full_path, .{}) catch continue;
            defer f.close();

            f.writeAll(file_data) catch continue;
            count += 1;
        } else |_| {
            // Invalid path detected, skipping file for security
        }

        offset += checksum.size;
    }

    return count;
}

test "update_add_remove" {
    const testing_allocator = std.testing.allocator;

    // Setup mock environment
    const test_dir = "test_manager_env";
    utils.ensurePath(test_dir) catch {};
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    const src_dir = try std.fs.path.join(testing_allocator, &.{ test_dir, "src" });
    defer testing_allocator.free(src_dir);
    const file1 = try std.fs.path.join(testing_allocator, &.{ src_dir, "file1.txt" });
    defer testing_allocator.free(file1);
    const file2 = try std.fs.path.join(testing_allocator, &.{ test_dir, "file2.txt" });
    defer testing_allocator.free(file2);
    const new_file = try std.fs.path.join(testing_allocator, &.{ test_dir, "new_file.txt" });
    defer testing_allocator.free(new_file);

    utils.ensurePath(src_dir) catch {};

    {
        const f1 = try std.fs.cwd().createFile(file1, .{});
        try f1.writeAll("content1");
        f1.close();

        const f2 = try std.fs.cwd().createFile(file2, .{});
        try f2.writeAll("content2");
        f2.close();

        const f3 = try std.fs.cwd().createFile(new_file, .{});
        try f3.writeAll("content_new");
        f3.close();
    }

    const archive_path = try std.fs.path.join(testing_allocator, &.{ test_dir, "archive.zigx" });
    defer testing_allocator.free(archive_path);

    // Create initial archive
    const bundler_opts = bundler.CompressOptions{
        .allocator = testing_allocator,
        .base_dir = test_dir,
        .include = &.{ "src", "file2.txt" },
        .output_path = archive_path,
    };
    var bundle_res = try bundler.compress(bundler_opts);
    bundle_res.deinit();

    // Update operation: Add 'new_file.txt' and Remove 'file2.txt'
    try update(.{
        .allocator = testing_allocator,
        .archive_path = archive_path,
        .add_files = &.{new_file},
        .remove_patterns = &.{"file2.txt"},
    });

    // Verification
    const extract_dir = try std.fs.path.join(testing_allocator, &.{ test_dir, "extracted" });
    defer testing_allocator.free(extract_dir);

    var extract_res = try extractor.extractWithResult(.{
        .allocator = testing_allocator,
        .archive_path = archive_path,
        .output_dir = extract_dir,
    });
    extract_res.deinit();

    // Check file1 exists (preserved)
    const check1 = try std.fs.path.join(testing_allocator, &.{ extract_dir, "src", "file1.txt" });
    defer testing_allocator.free(check1);
    try std.fs.cwd().access(check1, .{});

    // Check file2 gone (removed)
    const check2 = try std.fs.path.join(testing_allocator, &.{ extract_dir, "file2.txt" });
    defer testing_allocator.free(check2);
    const access_file2 = std.fs.cwd().access(check2, .{});
    try std.testing.expectError(error.FileNotFound, access_file2);

    // Check new_file exists (added)
    const check3 = try std.fs.path.join(testing_allocator, &.{ extract_dir, "new_file.txt" });
    defer testing_allocator.free(check3);
    try std.fs.cwd().access(check3, .{});
}

test "metadata update" {
    const allocator = std.testing.allocator;
    const test_dir = "test_metadata_update";
    try std.fs.cwd().makePath(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    const archive_path = try std.fs.path.join(allocator, &.{ test_dir, "test.zigx" });
    defer allocator.free(archive_path);

    // Create dummy content
    const dummy_path = try std.fs.path.join(allocator, &.{ test_dir, "dummy.txt" });
    const f = try std.fs.cwd().createFile(dummy_path, .{});
    f.close();
    allocator.free(dummy_path);

    const includes = [_][]const u8{"dummy.txt"};

    // Create dummy archive
    const opts = bundler.CompressOptions{
        .allocator = allocator,
        .output_path = archive_path,
        .base_dir = test_dir,
        .include = &includes,
        .auto_metadata = true,
    };
    var res = try bundler.compress(opts);
    res.deinit();

    // Initial check
    var initial_map = try getAllMetadata(archive_path, allocator);
    var it = initial_map.iterator();
    while (it.next()) |entry| {
        allocator.free(entry.key_ptr.*);
        allocator.free(entry.value_ptr.*);
    }
    initial_map.deinit(allocator);

    // Update metadata
    const key = "custom_key";
    const val = "custom_value";

    var updates = [_]MetadataUpdate{
        .{ .key = key, .op = .{ .set = val } },
    };

    try updateMetadata(archive_path, &updates, allocator);

    // Verify
    const read_val = try getMetadata(archive_path, key, allocator);
    try std.testing.expect(read_val != null);
    try std.testing.expectEqualStrings(val, read_val.?);
    allocator.free(read_val.?);

    // Delete metadata
    var del_updates = [_]MetadataUpdate{
        .{ .key = key, .op = .delete },
    };
    try updateMetadata(archive_path, &del_updates, allocator);

    const check_val = try getMetadata(archive_path, key, allocator);
    try std.testing.expect(check_val == null);
}

test "signature" {
    const allocator = std.testing.allocator;
    const test_dir = "test_signature";
    try std.fs.cwd().makePath(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    const archive_path = try std.fs.path.join(allocator, &.{ test_dir, "signed.zigx" });
    defer allocator.free(archive_path);

    // Create dummy content
    const dummy_path = try std.fs.path.join(allocator, &.{ test_dir, "dummy.txt" });
    const f = try std.fs.cwd().createFile(dummy_path, .{});
    f.close();
    allocator.free(dummy_path);

    const includes = [_][]const u8{"dummy.txt"};

    // Create dummy archive
    const opts = bundler.CompressOptions{
        .allocator = allocator,
        .output_path = archive_path,
        .base_dir = test_dir,
        .include = &includes,
    };
    var res = try bundler.compress(opts);
    res.deinit();

    // Set signature
    const signature = "test_signature_bytes";
    try setSignature(archive_path, signature, allocator);

    // Verify header flag
    const header = try parser.readHeader(archive_path);
    try std.testing.expect(header.isSigned());
    try std.testing.expectEqual(signature.len, header.signature_length);
}
