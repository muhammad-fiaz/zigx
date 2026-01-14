const std = @import("std");
const Allocator = std.mem.Allocator;

// Core modules
pub const utils = @import("utils.zig");
pub const format = @import("format.zig");
pub const bundler = @import("bundler.zig");
pub const parser = @import("parser.zig");
pub const extractor = @import("extractor.zig");
pub const validator = @import("validator.zig");
pub const security = @import("security.zig");
pub const hash = @import("hash.zig");
pub const compression = @import("compression.zig");
pub const config = @import("config.zig");
pub const manager = @import("manager.zig");

// Re-export config types
pub const Config = config.Config;
pub const CompressionLevel = config.CompressionLevel;

// Re-export format types
pub const Header = format.Header;
pub const Checksum = format.Checksum;
pub const ChecksumList = format.ChecksumList;
pub const FileEntry = format.FileEntry;
pub const Metadata = format.Metadata;
pub const FileType = format.FileType;
pub const FileInfo = format.FileInfo;
pub const ChunkInfo = format.ChunkInfo;
pub const ArchiveStats = format.ArchiveStats;
pub const CorruptionType = format.CorruptionType;
pub const CorruptionInfo = format.CorruptionInfo;
pub const CompressionType = format.CompressionType;

// Re-export error types
pub const CompressError = format.CompressError;
pub const ParseError = parser.ParseError;
pub const ValidationError = validator.ValidationError;
pub const ExtractionError = extractor.ExtractionError;

// Re-export result types
pub const CompressResult = bundler.CompressResult;
pub const CompressOptions = bundler.CompressOptions;
pub const ExtractOptions = extractor.ExtractOptions;
pub const ExtractResult = extractor.ExtractResult;

// Library Constants (from utils.zig)

/// Library version
pub const VERSION = utils.VERSION;
/// Alias for VERSION
pub const version = VERSION;
/// File extension for zigx archives
pub const FILE_EXTENSION = utils.FILE_EXTENSION;
/// Alias for FILE_EXTENSION
pub const file_extension = FILE_EXTENSION;
/// Header size in bytes
pub const HEADER_SIZE = utils.HEADER_SIZE;
/// Format version (archive format)
pub const FORMAT_VERSION = utils.FORMAT_VERSION;
/// Compression algorithm version
pub const COMPRESSION_VERSION = utils.COMPRESSION_VERSION;
/// Maximum supported file size
pub const MAX_FILE_SIZE = utils.MAX_FILE_SIZE;
/// Chunk size for large file processing
pub const CHUNK_SIZE = utils.CHUNK_SIZE;

/// Archive information for client-side access
pub const ArchiveInfo = struct {
    /// Archive format version
    format_version: u16,
    /// Compression algorithm version
    compression_version: u8,
    /// Compression type used
    compression_type: CompressionType,
    /// Number of files in archive
    file_count: u32,
    /// Total original size (uncompressed)
    original_size: u64,
    /// Compressed payload size
    compressed_size: u64,
    /// Whether archive is signed
    is_signed: bool,
    /// Whether archive is encrypted
    is_encrypted: bool,
    /// Payload hash (SHA-256 hex)
    payload_hash: [64]u8,
    /// Archive hash (SHA-256 hex)
    archive_hash: [64]u8,
    /// Compression level used
    compression_level: u8,
    /// Metadata entries
    metadata: Metadata,
    /// File checksums
    checksums: ChecksumList,

    allocator: Allocator,

    pub fn deinit(self: *ArchiveInfo) void {
        self.metadata.deinit();
        self.checksums.deinit(self.allocator);
    }

    /// Get compression ratio (0.0 - 1.0)
    pub fn getCompressionRatio(self: *const ArchiveInfo) f64 {
        if (self.original_size == 0) return 1.0;
        return @as(f64, @floatFromInt(self.compressed_size)) / @as(f64, @floatFromInt(self.original_size));
    }

    /// Get space saved percentage (0.0 - 100.0)
    pub fn getSavedPercent(self: *const ArchiveInfo) f64 {
        return (1.0 - self.getCompressionRatio()) * 100.0;
    }

    /// Get metadata value by key
    pub fn getMetadata(self: *const ArchiveInfo, key: []const u8) ?[]const u8 {
        return self.metadata.get(key);
    }

    /// Get list of file paths
    pub fn getFiles(self: *const ArchiveInfo) []const Checksum {
        return self.checksums.items;
    }
};

// Core functions

/// Create a .zigx archive from files and directories
pub fn compress(options: CompressOptions) CompressError!CompressResult {
    return bundler.compress(options);
}

/// Alias for compress() - create a .zigx archive
pub const bundle = compress;

/// Parse a .zigx archive header
pub fn parse(path: []const u8, allocator: Allocator) ParseError!parser.Archive {
    return parser.parse(path, allocator);
}

/// Get detailed information from a .zigx archive (client-side API)
/// Returns version, metadata, hash, file list, and compression details
pub fn getArchiveInfo(archive_path: []const u8, allocator: Allocator) !ArchiveInfo {
    var archive = try parser.parse(archive_path, allocator);
    defer archive.deinit();

    // Read archive hash
    const file = try std.fs.cwd().openFile(archive_path, .{});
    defer file.close();
    const archive_hash = try hash.hashFile(file, allocator);

    // Get compression version from payload
    var comp_version: u8 = 0;
    if (archive.header.payload_length >= 5) {
        const payload_offset = archive.getPayloadOffset();
        try archive.file.seekTo(payload_offset);
        var magic_buf: [5]u8 = undefined;
        _ = try archive.file.readAll(&magic_buf);
        if (std.mem.eql(u8, magic_buf[0..4], "ZXCM")) {
            comp_version = magic_buf[4];
        }
    }

    // Clone metadata
    var meta = Metadata.init(allocator);
    var it = archive.meta.entries.iterator();
    while (it.next()) |entry| {
        try meta.set(entry.key_ptr.*, entry.value_ptr.*);
    }

    // Clone checksums
    var checksums_list = std.ArrayListUnmanaged(Checksum){};
    for (archive.checksums.items) |item| {
        const path_copy = try allocator.dupe(u8, item.path);
        try checksums_list.append(allocator, .{
            .path = path_copy,
            .size = item.size,
            .hash = item.hash,
        });
    }

    return ArchiveInfo{
        .format_version = archive.header.version,
        .compression_version = comp_version,
        .compression_type = archive.header.getCompressionType(),
        .file_count = archive.header.file_count,
        .original_size = archive.header.original_size,
        .compressed_size = archive.header.payload_length,
        .is_signed = archive.header.isSigned(),
        .is_encrypted = archive.header.flags.encrypted == 1,
        .payload_hash = format.bytesToHex(&archive.header.payload_hash),
        .archive_hash = archive_hash,
        .compression_level = archive.header.compression_level,
        .metadata = meta,
        .checksums = .{
            .items = checksums_list.toOwnedSlice(allocator) catch return error.OutOfMemory,
            .allocator = allocator,
        },
        .allocator = allocator,
    };
}

/// Validate archive integrity
pub fn validate(path: []const u8, allocator: Allocator) ValidationError!bool {
    return validator.validate(path, allocator);
}

/// Alias for validate()
pub const verify = validate;

/// Get detailed validation results
pub fn validateDetailed(path: []const u8, allocator: Allocator) ValidationError!validator.ValidationResult {
    return validator.validateDetailed(path, allocator);
}

/// Alias for validateDetailed()
pub const verifyDetailed = validateDetailed;

/// Extract files from a .zigx archive
pub fn extract(options: ExtractOptions) ExtractionError!void {
    return extractor.extract(options);
}

/// Alias for extract() - extract a .zigx archive
pub const unbundle = extract;

/// Update an existing archive (Add/Remove files)
pub fn update(options: manager.UpdateOptions) manager.ManagerError!void {
    return manager.update(options);
}

/// Repair a corrupted archive
pub fn repair(archive_path: []const u8, output_path: []const u8, allocator: Allocator) !manager.RepairResult {
    return manager.repair(archive_path, output_path, allocator);
}

/// Extract files and return detailed result
pub fn extractWithResult(options: ExtractOptions) ExtractionError!ExtractResult {
    return extractor.extractWithResult(options);
}

/// Alias for extractWithResult()
pub const unbundleWithResult = extractWithResult;

/// List files in archive without extracting
pub fn listFiles(archive_path: []const u8, allocator: Allocator) ExtractionError![]const []const u8 {
    return extractor.listFiles(archive_path, allocator);
}

/// Alias for listFiles()
pub const list = listFiles;

/// Quick check if file is a valid .zigx archive
pub fn isValidArchive(path: []const u8) bool {
    return parser.isValidArchive(path);
}

/// Alias for isValidArchive()
pub const isValid = isValidArchive;

/// Detect corruption type in archive
pub fn detectCorruption(path: []const u8, allocator: Allocator) !?CorruptionInfo {
    return validator.detectCorruption(path, allocator);
}

pub fn hashData(data: []const u8) [64]u8 {
    return hash.hashHex(data);
}

pub fn hashFile(file: std.fs.File, allocator: Allocator) ![64]u8 {
    return hash.hashFile(file, allocator);
}

pub fn compressData(data: []const u8, allocator: Allocator) ![]u8 {
    return compression.compress(data, allocator, null);
}

pub fn decompressData(data: []const u8, allocator: Allocator) ![]u8 {
    return compression.decompress(data, allocator);
}

pub fn createMetadata(allocator: Allocator) Metadata {
    return Metadata.init(allocator);
}

pub fn detectFileType(path: []const u8, content: []const u8) FileType {
    return format.detectFileType(path, content);
}

/// Format a byte size into human-readable format
pub fn formatSize(size: u64) struct { value: f64, unit: []const u8 } {
    const result = format.formatSize(size);
    return .{ .value = result.value, .unit = result.unit };
}

test "imports" {
    _ = format;
    _ = bundler;
    _ = parser;
    _ = extractor;
    _ = validator;
    _ = security;
    _ = hash;
    _ = compression;
    _ = manager;
}

test "header_constants" {
    try std.testing.expectEqual(@as(usize, 4), format.MAGIC.len);
    try std.testing.expectEqualStrings("ZIGX", &format.MAGIC);
    try std.testing.expectEqual(@as(usize, 128), format.HEADER_SIZE);
}

test "version_string" {
    try std.testing.expectEqualStrings("0.0.1", VERSION);
}

test "compression_version" {
    try std.testing.expectEqual(@as(u8, 1), COMPRESSION_VERSION);
}

test "format_version" {
    try std.testing.expectEqual(@as(u16, 0x0001), FORMAT_VERSION);
}

test "file_extension" {
    try std.testing.expectEqualStrings(".zigx", file_extension);
}

test "compress_options_defaults" {
    const allocator = std.testing.allocator;
    const options = CompressOptions{ .allocator = allocator };
    try std.testing.expect(options.output_path == null);
    try std.testing.expect(options.include == null);
    try std.testing.expect(options.files == null);
    try std.testing.expect(options.directories == null);
}

test "extract_options_defaults" {
    const allocator = std.testing.allocator;
    const options = ExtractOptions{
        .archive_path = "test.zigx",
        .output_dir = "./out",
        .allocator = allocator,
    };
    try std.testing.expect(options.validate == true);
    try std.testing.expect(options.overwrite == false);
}

test "format_module" {
    _ = @import("format.zig");
}

test "security_module" {
    _ = @import("security.zig");
}

test "hash_module" {
    _ = @import("hash.zig");
}

test "compression_module" {
    _ = @import("compression.zig");
}

test "bundler_module" {
    _ = @import("bundler.zig");
}

test "parser_module" {
    _ = @import("parser.zig");
}

test "validator_module" {
    _ = @import("validator.zig");
}

test "extractor_module" {
    _ = @import("extractor.zig");
}

test "hash_data" {
    const h = hashData("hello world");
    try std.testing.expectEqualStrings("b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9", &h);
}

test "compress_decompress_roundtrip" {
    const allocator = std.testing.allocator;
    const original = "Hello, this is a test! This is a test of compression.";
    const compressed = try compressData(original, allocator);
    defer allocator.free(compressed);
    const decompressed = try decompressData(compressed, allocator);
    defer allocator.free(decompressed);
    try std.testing.expectEqualStrings(original, decompressed);
}

test "metadata_create" {
    const allocator = std.testing.allocator;
    var meta = createMetadata(allocator);
    defer meta.deinit();
    try meta.set("name", "testpkg");
    try meta.set("version", "1.0.0");
    try std.testing.expectEqualStrings("testpkg", meta.get("name").?);
    try std.testing.expectEqualStrings("1.0.0", meta.get("version").?);
}
