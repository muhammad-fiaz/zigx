const std = @import("std");
const Allocator = std.mem.Allocator;
const format = @import("format.zig");
const security = @import("security.zig");
const hash = @import("hash.zig");
const compression = @import("compression.zig");
const config = @import("config.zig");
const utils = @import("utils.zig");

const Header = format.Header;
const Metadata = format.Metadata;
const Checksum = format.Checksum;
const ChecksumList = format.ChecksumList;
const CompressError = format.CompressError;
const FileType = format.FileType;
const CompressionType = format.CompressionType;

/// Maximum file size for single-chunk processing (from utils)
pub const MAX_SINGLE_CHUNK_SIZE: u64 = utils.MAX_SINGLE_CHUNK_SIZE;
/// Chunk size for large file processing (from utils)
pub const LARGE_FILE_CHUNK_SIZE: usize = utils.CHUNK_SIZE;

pub const CompressResult = struct {
    output_path: []const u8,
    archive_size: u64,
    original_size: u64,
    file_count: usize,
    archive_hash: [64]u8,
    allocator: Allocator,
    stats: format.ArchiveStats,
    compression_enabled: bool,

    pub fn deinit(self: *CompressResult) void {
        self.allocator.free(self.output_path);
    }

    pub fn getCompressionRatio(self: *const CompressResult) f64 {
        if (self.original_size == 0) return 1.0;
        return @as(f64, @floatFromInt(self.archive_size)) / @as(f64, @floatFromInt(self.original_size));
    }

    pub fn getCompressionPercent(self: *const CompressResult) f64 {
        return (1.0 - self.getCompressionRatio()) * 100.0;
    }

    pub fn display(self: *const CompressResult, writer: anytype) !void {
        try writer.print("\n╔══════════════════════════════════════════════════════╗\n", .{});
        try writer.print("║               ZIGX ARCHIVE CREATED                   ║\n", .{});
        try writer.print("╠══════════════════════════════════════════════════════╣\n", .{});
        try writer.print("║ Archive: {s:<43} ║\n", .{self.output_path});
        try writer.print("║ Files:   {d:<43} ║\n", .{self.file_count});

        const orig = format.formatSize(self.original_size);
        const size = format.formatSize(self.archive_size);

        var orig_buf: [20]u8 = undefined;
        const orig_str = std.fmt.bufPrint(&orig_buf, "{d:.2} {s}", .{ orig.value, orig.unit }) catch "?";
        try writer.print("║ Original Size:    {s:<34} ║\n", .{orig_str});

        var size_buf: [20]u8 = undefined;
        const size_str = std.fmt.bufPrint(&size_buf, "{d:.2} {s}", .{ size.value, size.unit }) catch "?";
        try writer.print("║ Compressed Size:  {s:<34} ║\n", .{size_str});

        if (self.compression_enabled) {
            var ratio_buf: [20]u8 = undefined;
            const ratio_str = std.fmt.bufPrint(&ratio_buf, "{d:.1}% saved", .{self.getCompressionPercent()}) catch "?";
            try writer.print("║ Compression:      {s:<34} ║\n", .{ratio_str});
        } else {
            try writer.print("║ Compression:      {s:<34} ║\n", .{"disabled (store mode)"});
        }

        try writer.print("║ Hash:             {s:<34} ║\n", .{self.archive_hash[0..32]});
        try writer.print("╚══════════════════════════════════════════════════════╝\n\n", .{});
    }

    pub fn displayFileList(self: *const CompressResult, checksums: []const Checksum, writer: anytype) !void {
        try writer.print("Files in archive:\n", .{});
        try writer.print("─────────────────────────────────────────────────────────\n", .{});
        for (checksums) |item| {
            const fsize = format.formatSize(item.size);
            try writer.print("  {s:<40} {d:>8.2} {s}\n", .{ item.path, fsize.value, fsize.unit });
        }
        try writer.print("─────────────────────────────────────────────────────────\n", .{});
        _ = self;
    }
};

pub const CompressOptions = struct {
    metadata: std.StringHashMapUnmanaged([]const u8) = .{},
    /// Files and directories to include in archive
    /// Example: &.{ "src", "build.zig", "README.md" }
    include: ?[]const []const u8 = null,
    /// Deprecated: individual files (use 'include' instead)
    files: ?[]const []const u8 = null,
    /// Deprecated: directories (use 'include' instead)
    directories: ?[]const []const u8 = null,
    base_dir: []const u8 = ".",
    output_path: ?[]const u8 = null,
    allocator: Allocator,
    signature: ?[]const u8 = null,
    /// Compression level (use config.CompressionLevel)
    level: config.CompressionLevel = .best,
    /// Enable compression (false = store mode)
    compression_enabled: bool = true,
    /// Auto-generate metadata
    auto_metadata: bool = true,
    /// Exclude patterns - files/folders matching these patterns will be skipped
    /// Example: &.{ "node_modules", ".git", "*.tmp" }
    exclude: []const []const u8 = &.{},
    /// Deprecated: use 'exclude' instead
    exclude_patterns: []const []const u8 = &.{},
    /// Compress metadata section
    compress_metadata: bool = false,
    /// Compress checksums section
    compress_checksums: bool = false,
    /// Use global config defaults
    use_global_config: bool = true,

    /// Apply global configuration defaults
    pub fn applyGlobalConfig(self: *CompressOptions) void {
        if (self.use_global_config) {
            self.compression_enabled = config.global.compression.enabled;
            self.level = config.global.compression.level;
            self.compress_metadata = config.global.compression.compress_metadata;
            self.compress_checksums = config.global.compression.compress_checksums;
            self.auto_metadata = config.global.bundling.auto_metadata;
        }
    }
};

const FileToCompress = struct {
    relative_path: []const u8,
    content: []const u8,
    hash: [64]u8,
    file_type: FileType,
    size: u64,

    pub fn deinit(self: *FileToCompress, allocator: Allocator) void {
        allocator.free(self.relative_path);
        allocator.free(self.content);
    }
};

pub fn compress(options: CompressOptions) CompressError!CompressResult {
    const allocator = options.allocator;

    // Merge exclude patterns from both 'exclude' and deprecated 'exclude_patterns'
    const exclude_list = if (options.exclude.len > 0) options.exclude else options.exclude_patterns;

    // Check if we have anything to bundle
    const has_include = options.include != null and options.include.?.len > 0;
    const has_files = options.files != null and options.files.?.len > 0;
    const has_dirs = options.directories != null and options.directories.?.len > 0;
    if (!has_include and !has_files and !has_dirs) return CompressError.NoFilesSpecified;

    var meta = Metadata.init(allocator);
    defer meta.deinit();

    var it = options.metadata.iterator();
    while (it.next()) |entry| {
        meta.set(entry.key_ptr.*, entry.value_ptr.*) catch return CompressError.OutOfMemory;
    }

    var files = std.ArrayListUnmanaged(FileToCompress){};
    defer {
        for (files.items) |*f| f.deinit(allocator);
        files.deinit(allocator);
    }

    // Process unified 'include' option (handles both files and directories)
    if (options.include) |include_list| {
        for (include_list) |path| {
            if (utils.matchesPattern(path, exclude_list)) continue;

            // Check if it's a directory or file
            var dir = std.fs.cwd().openDir(options.base_dir, .{}) catch continue;
            defer dir.close();

            const stat = dir.statFile(path) catch {
                // Try as directory
                collectDirectoryWithExcludes(options.base_dir, path, &files, allocator, exclude_list) catch {};
                continue;
            };

            if (stat.kind == .directory) {
                try collectDirectoryWithExcludes(options.base_dir, path, &files, allocator, exclude_list);
            } else {
                try collectFile(options.base_dir, path, &files, allocator);
            }
        }
    }

    // Deprecated: process 'files' option
    if (options.files) |file_list| {
        for (file_list) |file_path| {
            if (utils.matchesPattern(file_path, exclude_list)) continue;
            try collectFile(options.base_dir, file_path, &files, allocator);
        }
    }

    // Deprecated: process 'directories' option
    if (options.directories) |dir_list| {
        for (dir_list) |dir_path| {
            try collectDirectoryWithExcludes(options.base_dir, dir_path, &files, allocator, exclude_list);
        }
    }

    if (files.items.len == 0) return CompressError.NoFilesSpecified;

    // Auto-generate metadata if enabled
    if (options.auto_metadata) {
        var timestamp_buf: [32]u8 = undefined;
        const ts = std.time.timestamp();
        const ts_str = std.fmt.bufPrint(&timestamp_buf, "{d}", .{ts}) catch "0";
        meta.set("created_at", ts_str) catch {};
        meta.set("format", "zigx") catch {};
        meta.set("format_version", "1") catch {};

        var file_count_buf: [16]u8 = undefined;
        const fc_str = std.fmt.bufPrint(&file_count_buf, "{d}", .{files.items.len}) catch "0";
        meta.set("file_count", fc_str) catch {};

        // Detect file types summary
        var text_count: u32 = 0;
        var binary_count: u32 = 0;
        var source_count: u32 = 0;
        for (files.items) |f| {
            switch (f.file_type) {
                .text, .config => text_count += 1,
                .source_code => source_count += 1,
                else => binary_count += 1,
            }
        }
        var summary_buf: [64]u8 = undefined;
        const summary = std.fmt.bufPrint(&summary_buf, "src:{d},txt:{d},bin:{d}", .{ source_count, text_count, binary_count }) catch "";
        meta.set("file_types", summary) catch {};
    }

    std.mem.sort(FileToCompress, files.items, {}, struct {
        fn lessThan(_: void, a: FileToCompress, b: FileToCompress) bool {
            return std.mem.lessThan(u8, a.relative_path, b.relative_path);
        }
    }.lessThan);

    var checksums = std.ArrayListUnmanaged(Checksum){};
    errdefer {
        for (checksums.items) |*c| c.deinit(allocator);
        checksums.deinit(allocator);
    }

    var largest_file: u64 = 0;
    var smallest_file: u64 = std.math.maxInt(u64);
    const dir_count: u32 = 0;

    for (files.items) |file| {
        const path_copy = allocator.dupe(u8, file.relative_path) catch return CompressError.OutOfMemory;
        checksums.append(allocator, .{
            .path = path_copy,
            .size = file.content.len,
            .hash = file.hash,
        }) catch {
            allocator.free(path_copy);
            return CompressError.OutOfMemory;
        };
        if (file.size > largest_file) largest_file = file.size;
        if (file.size < smallest_file) smallest_file = file.size;
    }

    var checksum_list = ChecksumList{
        .items = checksums.toOwnedSlice(allocator) catch return CompressError.OutOfMemory,
        .allocator = allocator,
    };
    errdefer checksum_list.deinit(allocator);

    const meta_data = meta.serialize() catch return CompressError.OutOfMemory;
    defer allocator.free(meta_data);

    const checksums_data = checksum_list.serialize() catch return CompressError.OutOfMemory;
    defer allocator.free(checksums_data);

    var payload_data = std.ArrayListUnmanaged(u8){};
    defer payload_data.deinit(allocator);

    for (files.items) |file| {
        var path_len_buf: [4]u8 = undefined;
        std.mem.writeInt(u32, &path_len_buf, @intCast(file.relative_path.len), .little);
        payload_data.appendSlice(allocator, &path_len_buf) catch return CompressError.OutOfMemory;
        payload_data.appendSlice(allocator, file.relative_path) catch return CompressError.OutOfMemory;
        var content_len_buf: [8]u8 = undefined;
        std.mem.writeInt(u64, &content_len_buf, @intCast(file.content.len), .little);
        payload_data.appendSlice(allocator, &content_len_buf) catch return CompressError.OutOfMemory;
        payload_data.appendSlice(allocator, file.content) catch return CompressError.OutOfMemory;
    }

    const compressed_payload = if (options.compression_enabled)
        compression.compress(payload_data.items, allocator, options.level) catch {
            return CompressError.CompressionError;
        }
    else blk: {
        // Store mode - no compression
        const stored = compression.compress(payload_data.items, allocator, .none) catch {
            return CompressError.CompressionError;
        };
        break :blk stored;
    };
    defer allocator.free(compressed_payload);

    const payload_hash_hex = hash.hashHex(compressed_payload);
    const payload_hash = hash.hexToBytes(&payload_hash_hex) catch return CompressError.IoError;

    var header = Header{
        .meta_length = @intCast(meta_data.len),
        .checksums_length = @intCast(checksums_data.len),
        .payload_length = compressed_payload.len,
        .original_size = payload_data.items.len,
        .file_count = @intCast(files.items.len),
        .payload_hash = payload_hash,
        .compression_level = @intFromEnum(options.level),
    };

    // Set compression type in flags
    const comp_type = if (options.compression_enabled)
        CompressionType.fromLevel(options.level)
    else
        CompressionType.none;
    header.flags.compression = @intFromEnum(comp_type);

    if (payload_data.items.len > MAX_SINGLE_CHUNK_SIZE) {
        header.flags.large_file = 1;
    }

    if (options.compress_metadata) {
        header.flags.metadata_compressed = 1;
    }
    if (options.compress_checksums) {
        header.flags.checksums_compressed = 1;
    }

    if (options.signature) |sig| {
        header.flags.signed = 1;
        header.signature_length = @intCast(sig.len);
    }

    const output_path = if (options.output_path) |p|
        allocator.dupe(u8, p) catch return CompressError.OutOfMemory
    else blk: {
        var buf: [512]u8 = undefined;
        const name = meta.get("name") orelse "archive";
        const version = meta.get("version") orelse "0.0.0";
        const path = std.fmt.bufPrint(&buf, "{s}-{s}.zigx", .{ name, version }) catch {
            return CompressError.OutOfMemory;
        };
        break :blk allocator.dupe(u8, path) catch return CompressError.OutOfMemory;
    };
    errdefer allocator.free(output_path);

    utils.ensureParentDir(output_path) catch {};

    {
        const file = std.fs.cwd().createFile(output_path, .{}) catch {
            return CompressError.FileSystemError;
        };
        defer file.close();

        const header_bytes = header.toBytes();
        file.writeAll(&header_bytes) catch return CompressError.IoError;
        file.writeAll(meta_data) catch return CompressError.IoError;
        file.writeAll(checksums_data) catch return CompressError.IoError;
        file.writeAll(compressed_payload) catch return CompressError.IoError;

        if (options.signature) |sig| {
            file.writeAll(sig) catch return CompressError.IoError;
        }
    }

    const read_file = std.fs.cwd().openFile(output_path, .{}) catch {
        return CompressError.FileSystemError;
    };
    defer read_file.close();

    const stat = read_file.stat() catch return CompressError.FileSystemError;
    const archive_hash = hash.hashFile(read_file, allocator) catch return CompressError.IoError;

    const owned_items = checksum_list.items;
    checksum_list.items = &.{};
    for (owned_items) |*c| @constCast(c).deinit(allocator);
    allocator.free(owned_items);

    var original_size: u64 = 0;
    for (files.items) |file| original_size += file.content.len;

    return CompressResult{
        .output_path = output_path,
        .archive_size = stat.size,
        .original_size = original_size,
        .file_count = files.items.len,
        .archive_hash = archive_hash,
        .allocator = allocator,
        .compression_enabled = options.compression_enabled,
        .stats = .{
            .file_count = @intCast(files.items.len),
            .directory_count = dir_count,
            .total_size = original_size,
            .compressed_size = stat.size,
            .largest_file = largest_file,
            .smallest_file = if (smallest_file == std.math.maxInt(u64)) 0 else smallest_file,
            .compression_ratio = if (original_size > 0) @as(f64, @floatFromInt(stat.size)) / @as(f64, @floatFromInt(original_size)) else 1.0,
        },
    };
}

fn collectFile(
    base_dir: []const u8,
    relative_path: []const u8,
    files: *std.ArrayListUnmanaged(FileToCompress),
    allocator: Allocator,
) CompressError!void {
    security.validatePath(relative_path) catch return CompressError.SecurityViolation;
    var dir = std.fs.cwd().openDir(base_dir, .{}) catch {
        return CompressError.FileSystemError;
    };
    defer dir.close();
    // Support large files - use platform-appropriate max (2GB on 32-bit, 4GB on 64-bit)
    const max_file_size: usize = if (@sizeOf(usize) >= 8) 4 * 1024 * 1024 * 1024 else 2 * 1024 * 1024 * 1024;
    const content = dir.readFileAlloc(allocator, relative_path, max_file_size) catch |err| {
        return switch (err) {
            error.FileNotFound => CompressError.FileNotFound,
            error.OutOfMemory => CompressError.OutOfMemory,
            else => CompressError.IoError,
        };
    };
    errdefer allocator.free(content);
    const file_hash = hash.hashHex(content);
    const file_type = format.detectFileType(relative_path, content);
    const path_copy = allocator.dupe(u8, relative_path) catch return CompressError.OutOfMemory;
    errdefer allocator.free(path_copy);
    files.append(allocator, .{
        .relative_path = path_copy,
        .content = content,
        .hash = file_hash,
        .file_type = file_type,
        .size = content.len,
    }) catch return CompressError.OutOfMemory;
}

fn collectDirectory(
    base_dir: []const u8,
    dir_path: []const u8,
    files: *std.ArrayListUnmanaged(FileToCompress),
    allocator: Allocator,
) CompressError!void {
    return collectDirectoryWithExcludes(base_dir, dir_path, files, allocator, &.{});
}

fn collectDirectoryWithExcludes(
    base_dir: []const u8,
    dir_path: []const u8,
    files: *std.ArrayListUnmanaged(FileToCompress),
    allocator: Allocator,
    exclude_patterns: []const []const u8,
) CompressError!void {
    security.validatePath(dir_path) catch return CompressError.SecurityViolation;
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    var root_dir = std.fs.cwd().openDir(base_dir, .{}) catch {
        return CompressError.FileSystemError;
    };
    defer root_dir.close();
    var dir = root_dir.openDir(dir_path, .{ .iterate = true }) catch {
        return CompressError.DirectoryNotFound;
    };
    defer dir.close();
    var walker = dir.walk(allocator) catch return CompressError.OutOfMemory;
    defer walker.deinit();
    while (walker.next() catch return CompressError.FileSystemError) |entry| {
        if (entry.kind == .directory) continue;
        const relative = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ dir_path, entry.path }) catch {
            return CompressError.OutOfMemory;
        };
        // Check exclude patterns
        if (utils.matchesPattern(relative, exclude_patterns)) continue;
        if (utils.matchesPattern(entry.path, exclude_patterns)) continue;

        security.validatePath(relative) catch return CompressError.SecurityViolation;
        // Support large files - use platform-appropriate max (2GB on 32-bit, 4GB on 64-bit)
        const dir_max_file_size: usize = if (@sizeOf(usize) >= 8) 4 * 1024 * 1024 * 1024 else 2 * 1024 * 1024 * 1024;
        const content = dir.readFileAlloc(allocator, entry.path, dir_max_file_size) catch |err| {
            return switch (err) {
                error.OutOfMemory => CompressError.OutOfMemory,
                else => CompressError.IoError,
            };
        };
        errdefer allocator.free(content);
        const file_hash = hash.hashHex(content);
        const file_type = format.detectFileType(relative, content);
        const path_copy = allocator.dupe(u8, relative) catch return CompressError.OutOfMemory;
        errdefer allocator.free(path_copy);
        files.append(allocator, .{
            .relative_path = path_copy,
            .content = content,
            .hash = file_hash,
            .file_type = file_type,
            .size = content.len,
        }) catch return CompressError.OutOfMemory;
    }
}

test "imports" {
    _ = format;
    _ = security;
    _ = hash;
    _ = compression;
}

test "options_defaults" {
    const allocator = std.testing.allocator;
    const options = CompressOptions{ .allocator = allocator };
    try std.testing.expectEqualStrings(".", options.base_dir);
    try std.testing.expect(options.output_path == null);
    try std.testing.expect(options.include == null);
    try std.testing.expect(options.files == null);
    try std.testing.expect(options.directories == null);
}
