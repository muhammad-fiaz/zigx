const std = @import("std");

/// Global configuration for the zigx library.
/// Users can modify these values to change default behavior.
/// These can also be overridden per-operation using method parameters.
pub const Config = struct {
    /// Compression settings
    compression: CompressionConfig = .{},
    /// Bundling settings
    bundling: BundlingConfig = .{},
    /// Security settings
    security: SecurityConfig = .{},
    /// Output settings
    output: OutputConfig = .{},
};

/// Compression configuration
pub const CompressionConfig = struct {
    /// Whether compression is enabled by default
    enabled: bool = true,
    /// Default compression level (4-9, or fast/default/best)
    level: CompressionLevel = .default,
    /// Compress metadata section
    compress_metadata: bool = false,
    /// Compress checksums section
    compress_checksums: bool = false,
    /// Container format for deflate
    container: Container = .raw,
};

/// Bundling configuration
pub const BundlingConfig = struct {
    /// Auto-generate metadata (timestamps, file counts, etc.)
    auto_metadata: bool = true,
    /// Include file hashes/checksums
    include_checksums: bool = true,
    /// Verify checksums on extraction
    verify_on_extract: bool = true,
    /// Sort files in archive for deterministic output
    sort_files: bool = true,
    /// Maximum file size to read (16GB default)
    max_file_size: u64 = 16 * 1024 * 1024 * 1024,
    /// File extension for archives
    file_extension: []const u8 = ".zigx",
    /// Exclude patterns - files/folders matching these patterns will be skipped
    /// Example: &.{ "node_modules", ".git", "*.tmp", "build/" }
    exclude_patterns: []const []const u8 = &.{},
};

/// Security configuration
pub const SecurityConfig = struct {
    /// Maximum path length
    max_path_length: usize = 4096,
    /// Maximum path component length
    max_component_length: usize = 255,
    /// Reject absolute paths
    reject_absolute_paths: bool = true,
    /// Reject path traversal attempts
    reject_path_traversal: bool = true,
    /// Reject symlinks that escape
    reject_symlink_escape: bool = true,
};

/// Output configuration
pub const OutputConfig = struct {
    /// Default output directory for archives (relative to cwd)
    default_output_dir: []const u8 = "dist",
    /// Default output filename (null = auto-generate from project name)
    default_output_name: ?[]const u8 = null,
    /// Show verbose output
    verbose: bool = false,
    /// Show file sizes in human-readable format
    human_readable_sizes: bool = true,
    /// Show compression ratio
    show_compression_ratio: bool = true,
    /// Show hashes
    show_hashes: bool = true,
    /// Show file list
    show_file_list: bool = true,
};

/// Compression levels for Zstandard (zstd) compression
/// Maps directly to zstd levels 1-22
pub const CompressionLevel = enum(u8) {
    none = 0,
    fast = 1, // zstd 1
    level_2 = 2,
    default = 3, // zstd 3
    level_4 = 4,
    level_5 = 5,
    level_6 = 6,
    level_7 = 7,
    level_8 = 8,
    level_9 = 9,
    level_10 = 10,
    level_11 = 11,
    level_12 = 12,
    level_13 = 13,
    level_14 = 14,
    level_15 = 15,
    level_16 = 16,
    level_17 = 17,
    level_18 = 18,
    best = 19, // zstd 19
    level_20 = 20,
    level_21 = 21,
    level_22 = 22,

    // Aliases for compatibility/clarity
    pub const level_1 = @This().fast;
    pub const level_3 = @This().default;
    pub const level_19 = @This().best;

    /// Convert to zstd compression level (1-22)
    pub fn toZstdLevel(self: CompressionLevel) c_int {
        return @intCast(@intFromEnum(self));
    }

    pub fn name(self: CompressionLevel) []const u8 {
        return switch (self) {
            .none => "none (store)",
            .fast => "fast (zstd 1)",
            .default => "default (zstd 3)",
            .best => "best (zstd 19)",
            else => "level custom",
        };
    }
};

/// Container format (Deprecated/Unused for Zstd)
pub const Container = enum {
    raw,
};

/// Global default configuration instance.
/// Modify this to change library-wide defaults.
pub var global: Config = .{};

/// Reset global configuration to defaults
pub fn reset() void {
    global = .{};
}

/// Create a configuration with compression disabled
pub fn uncompressed() Config {
    var config = Config{};
    config.compression.enabled = false;
    return config;
}

/// Create a configuration optimized for speed
pub fn fast() Config {
    var config = Config{};
    config.compression.level = .fast;
    return config;
}

/// Create a configuration optimized for size
pub fn best() Config {
    var config = Config{};
    config.compression.level = .best;
    return config;
}

/// Create a configuration with metadata compression
pub fn withCompressedMetadata() Config {
    var config = Config{};
    config.compression.compress_metadata = true;
    config.compression.compress_checksums = true;
    return config;
}

test "default_config" {
    const config = Config{};
    try std.testing.expect(config.compression.enabled);
    try std.testing.expectEqual(CompressionLevel.default, config.compression.level);
    try std.testing.expect(config.bundling.auto_metadata);
}

test "compression_level_names" {
    try std.testing.expectEqualStrings("fast (zstd 1)", CompressionLevel.fast.name());
    try std.testing.expectEqualStrings("best (zstd 19)", CompressionLevel.best.name());
    try std.testing.expectEqualStrings("none (store)", CompressionLevel.none.name());
}

test "preset_configs" {
    const uncomp = uncompressed();
    try std.testing.expect(!uncomp.compression.enabled);

    const fast_config = fast();
    try std.testing.expectEqual(CompressionLevel.fast, fast_config.compression.level);

    const best_config = best();
    try std.testing.expectEqual(CompressionLevel.best, best_config.compression.level);
}

test "global_reset" {
    global.compression.enabled = false;
    reset();
    try std.testing.expect(global.compression.enabled);
}
