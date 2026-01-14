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
    /// Performance settings
    performance: PerformanceConfig = .{},
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
    /// Enable adaptive compression (auto-detect content type)
    adaptive: bool = false,
    /// Enable long-distance matching for better compression of large files
    long_distance_matching: bool = false,
    /// Window log size (10-31, higher = more memory, better compression)
    window_log: ?u5 = null,
    /// Content checksum in compressed frames
    content_checksum: bool = true,
    /// Skip compression for already-compressed content types
    skip_compressed_content: bool = true,
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
    /// Include hidden files (starting with .)
    include_hidden: bool = false,
    /// Follow symbolic links
    follow_symlinks: bool = false,
    /// Preserve file permissions (Unix)
    preserve_permissions: bool = true,
    /// Preserve modification times
    preserve_timestamps: bool = true,
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
    /// Validate checksums on extraction
    validate_checksums: bool = true,
    /// Maximum decompressed size (prevents zip bombs)
    max_decompressed_size: u64 = 16 * 1024 * 1024 * 1024,
    /// Maximum compression ratio allowed (prevents zip bombs)
    max_compression_ratio: f64 = 1000.0,
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
    /// Show progress during operations
    show_progress: bool = true,
    /// Color output (when supported)
    color_output: bool = true,
};

/// Performance configuration
pub const PerformanceConfig = struct {
    /// Number of threads for parallel operations (0 = auto)
    threads: u8 = 0,
    /// Buffer size for I/O operations
    io_buffer_size: usize = 64 * 1024,
    /// Enable memory mapping for large files
    use_mmap: bool = true,
    /// Memory limit for operations (0 = no limit)
    memory_limit: u64 = 0,
    /// Chunk size for streaming operations
    chunk_size: usize = 4 * 1024 * 1024,
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
    pub const ultra = @This().level_22;
    pub const maximum = @This().level_22;
    pub const balanced = @This().level_6;
    pub const turbo = @This().fast;

    /// Convert to zstd compression level (1-22)
    pub fn toZstdLevel(self: CompressionLevel) c_int {
        return @intCast(@intFromEnum(self));
    }

    /// Create from raw level number
    pub fn fromInt(level: u8) CompressionLevel {
        if (level > 22) return .level_22;
        if (level == 0) return .none;
        return @enumFromInt(level);
    }

    /// Create a custom level (1-22), clamped to valid range
    pub fn custom(level: u8) CompressionLevel {
        if (level == 0) return .none;
        if (level > 22) return .level_22;
        return @enumFromInt(level);
    }

    /// Get the raw integer value (0-22)
    pub fn toInt(self: CompressionLevel) u8 {
        return @intFromEnum(self);
    }

    pub fn name(self: CompressionLevel) []const u8 {
        return switch (self) {
            .none => "none (store)",
            .fast => "fast (zstd 1)",
            .level_2 => "level 2",
            .default => "default (zstd 3)",
            .level_4 => "level 4",
            .level_5 => "level 5",
            .level_6 => "balanced (zstd 6)",
            .level_7 => "level 7",
            .level_8 => "level 8",
            .level_9 => "level 9",
            .level_10 => "level 10",
            .level_11 => "level 11",
            .level_12 => "level 12",
            .level_13 => "level 13",
            .level_14 => "level 14",
            .level_15 => "level 15",
            .level_16 => "level 16",
            .level_17 => "level 17",
            .level_18 => "level 18",
            .best => "best (zstd 19)",
            .level_20 => "level 20",
            .level_21 => "level 21",
            .level_22 => "ultra (zstd 22)",
        };
    }

    /// Get approximate compression speed (MB/s)
    pub fn approximateSpeed(self: CompressionLevel) []const u8 {
        const level = @intFromEnum(self);
        if (level == 0) return "max (no compression)";
        if (level <= 3) return "500+ MB/s";
        if (level <= 6) return "200-500 MB/s";
        if (level <= 10) return "50-200 MB/s";
        if (level <= 15) return "10-50 MB/s";
        return "<10 MB/s";
    }

    /// Check if this level is considered "fast"
    pub fn isFast(self: CompressionLevel) bool {
        return @intFromEnum(self) <= 3;
    }

    /// Check if this level provides high compression
    pub fn isHighCompression(self: CompressionLevel) bool {
        return @intFromEnum(self) >= 15;
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
    var cfg = Config{};
    cfg.compression.enabled = false;
    return cfg;
}

/// Create a configuration optimized for speed
pub fn fast() Config {
    var cfg = Config{};
    cfg.compression.level = .fast;
    return cfg;
}

/// Create a configuration optimized for size
pub fn best() Config {
    var cfg = Config{};
    cfg.compression.level = .best;
    return cfg;
}

/// Create a configuration with ultra compression (maximum size reduction)
pub fn ultra() Config {
    var cfg = Config{};
    cfg.compression.level = .level_22;
    cfg.compression.long_distance_matching = true;
    cfg.compression.window_log = 27; // 128MB window
    return cfg;
}

/// Create a balanced configuration (good speed and compression)
pub fn balanced() Config {
    var cfg = Config{};
    cfg.compression.level = .level_6;
    return cfg;
}

/// Create a configuration with adaptive compression
pub fn adaptive() Config {
    var cfg = Config{};
    cfg.compression.adaptive = true;
    cfg.compression.skip_compressed_content = true;
    return cfg;
}

/// Create a configuration with metadata compression
pub fn withCompressedMetadata() Config {
    var cfg = Config{};
    cfg.compression.compress_metadata = true;
    cfg.compression.compress_checksums = true;
    return cfg;
}

/// Create a configuration optimized for large files
pub fn forLargeFiles() Config {
    var cfg = Config{};
    cfg.compression.level = .level_6;
    cfg.compression.long_distance_matching = true;
    cfg.compression.window_log = 25; // 32MB window
    cfg.performance.chunk_size = 16 * 1024 * 1024; // 16MB chunks
    cfg.performance.use_mmap = true;
    return cfg;
}

/// Create a configuration for archiving (preserves metadata)
pub fn forArchiving() Config {
    var cfg = Config{};
    cfg.compression.level = .best;
    cfg.bundling.preserve_permissions = true;
    cfg.bundling.preserve_timestamps = true;
    cfg.bundling.include_checksums = true;
    return cfg;
}

/// Create a configuration for distribution (small size, fast extraction)
pub fn forDistribution() Config {
    var cfg = Config{};
    cfg.compression.level = .best;
    cfg.compression.content_checksum = true;
    cfg.bundling.auto_metadata = true;
    return cfg;
}

/// Create a configuration with a custom compression level (1-22)
pub fn withLevel(level: u8) Config {
    var cfg = Config{};
    cfg.compression.level = CompressionLevel.custom(level);
    return cfg;
}

/// Create a configuration with custom level and long-distance matching
pub fn withLevelAndLdm(level: u8) Config {
    var cfg = Config{};
    cfg.compression.level = CompressionLevel.custom(level);
    cfg.compression.long_distance_matching = true;
    return cfg;
}

/// Builder pattern for creating custom configurations
pub const ConfigBuilder = struct {
    cfg: Config = .{},

    pub fn init() ConfigBuilder {
        return .{};
    }

    pub fn compressionLevel(self: *ConfigBuilder, level: CompressionLevel) *ConfigBuilder {
        self.cfg.compression.level = level;
        return self;
    }

    /// Set a custom compression level (1-22)
    pub fn customLevel(self: *ConfigBuilder, level: u8) *ConfigBuilder {
        self.cfg.compression.level = CompressionLevel.custom(level);
        return self;
    }

    pub fn compressionEnabled(self: *ConfigBuilder, enabled: bool) *ConfigBuilder {
        self.cfg.compression.enabled = enabled;
        return self;
    }

    pub fn adaptive(self: *ConfigBuilder, enable: bool) *ConfigBuilder {
        self.cfg.compression.adaptive = enable;
        return self;
    }

    pub fn longDistanceMatching(self: *ConfigBuilder, enable: bool) *ConfigBuilder {
        self.cfg.compression.long_distance_matching = enable;
        return self;
    }

    pub fn windowLog(self: *ConfigBuilder, log: ?u5) *ConfigBuilder {
        self.cfg.compression.window_log = log;
        return self;
    }

    pub fn excludePatterns(self: *ConfigBuilder, patterns: []const []const u8) *ConfigBuilder {
        self.cfg.bundling.exclude_patterns = patterns;
        return self;
    }

    pub fn includeHidden(self: *ConfigBuilder, include: bool) *ConfigBuilder {
        self.cfg.bundling.include_hidden = include;
        return self;
    }

    pub fn threads(self: *ConfigBuilder, count: u8) *ConfigBuilder {
        self.cfg.performance.threads = count;
        return self;
    }

    pub fn verbose(self: *ConfigBuilder, enable: bool) *ConfigBuilder {
        self.cfg.output.verbose = enable;
        return self;
    }

    pub fn build(self: *ConfigBuilder) Config {
        return self.cfg;
    }
};

test "default_config" {
    const cfg = Config{};
    try std.testing.expect(cfg.compression.enabled);
    try std.testing.expectEqual(CompressionLevel.default, cfg.compression.level);
    try std.testing.expect(cfg.bundling.auto_metadata);
}

test "compression_level_names" {
    try std.testing.expectEqualStrings("fast (zstd 1)", CompressionLevel.fast.name());
    try std.testing.expectEqualStrings("best (zstd 19)", CompressionLevel.best.name());
    try std.testing.expectEqualStrings("none (store)", CompressionLevel.none.name());
    try std.testing.expectEqualStrings("ultra (zstd 22)", CompressionLevel.level_22.name());
}

test "preset_configs" {
    const uncomp = uncompressed();
    try std.testing.expect(!uncomp.compression.enabled);

    const fast_config = fast();
    try std.testing.expectEqual(CompressionLevel.fast, fast_config.compression.level);

    const best_config = best();
    try std.testing.expectEqual(CompressionLevel.best, best_config.compression.level);

    const ultra_config = ultra();
    try std.testing.expectEqual(CompressionLevel.level_22, ultra_config.compression.level);
    try std.testing.expect(ultra_config.compression.long_distance_matching);

    const adaptive_config = adaptive();
    try std.testing.expect(adaptive_config.compression.adaptive);
}

test "config_builder" {
    var builder = ConfigBuilder.init();
    const cfg = builder
        .compressionLevel(.best)
        .adaptive(true)
        .verbose(true)
        .build();

    try std.testing.expectEqual(CompressionLevel.best, cfg.compression.level);
    try std.testing.expect(cfg.compression.adaptive);
    try std.testing.expect(cfg.output.verbose);
}

test "global_reset" {
    global.compression.enabled = false;
    reset();
    try std.testing.expect(global.compression.enabled);
}

test "compression_level_from_int" {
    try std.testing.expectEqual(CompressionLevel.fast, CompressionLevel.fromInt(1));
    try std.testing.expectEqual(CompressionLevel.best, CompressionLevel.fromInt(19));
    try std.testing.expectEqual(CompressionLevel.level_22, CompressionLevel.fromInt(100)); // Clamped
}

test "compression_level_helpers" {
    try std.testing.expect(CompressionLevel.fast.isFast());
    try std.testing.expect(CompressionLevel.default.isFast());
    try std.testing.expect(!CompressionLevel.best.isFast());

    try std.testing.expect(CompressionLevel.best.isHighCompression());
    try std.testing.expect(CompressionLevel.level_22.isHighCompression());
    try std.testing.expect(!CompressionLevel.fast.isHighCompression());
}
