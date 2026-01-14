# Types

Complete type reference for ZIGX.

## CompressionLevel

```zig
pub const CompressionLevel = enum(u8) {
    // Primary levels
    none = 0,      // No compression (store)
    fast = 1,      // Speed optimized (zstd 1)
    default = 3,   // Good balance (zstd 3)
    balanced = 6,  // Balanced (zstd 6)
    best = 19,     // High compression (zstd 19)
    ultra = 22,    // Maximum compression (zstd 22)
    
    // Fine-grained levels (2-22)
    level_2 = 2, level_4 = 4, level_5 = 5,
    level_7 = 7, level_8 = 8, level_9 = 9,
    level_10 = 10, level_11 = 11, level_12 = 12,
    level_13 = 13, level_14 = 14, level_15 = 15,
    level_16 = 16, level_17 = 17, level_18 = 18,
    level_20 = 20, level_21 = 21, level_22 = 22,
    
    // Aliases
    pub const level_1 = fast;
    pub const level_3 = default;
    pub const level_6 = balanced;
    pub const level_19 = best;
    pub const maximum = ultra;
    pub const turbo = fast;
    
    // Create custom level from integer (1-22)
    pub fn custom(level: u8) CompressionLevel;
    
    // Get the raw integer value
    pub fn toInt(self: CompressionLevel) u8;
    
    // Create from integer (with clamping)
    pub fn fromInt(level: u8) CompressionLevel;
};
```

### Usage Examples

```zig
// Named levels (recommended)
.level = .fast     // Speed priority
.level = .default  // Good balance
.level = .balanced // Speed/ratio balance
.level = .best     // High compression
.level = .ultra    // Maximum compression

// Numeric levels (fine control)
.level = .level_6  // Specific level
.level = CompressionLevel.fromInt(15)  // From integer

// Custom levels (1-22)
.level = CompressionLevel.custom(10)   // zstd level 10
.level = CompressionLevel.custom(15)   // zstd level 15
.level = CompressionLevel.custom(18)   // zstd level 18

// Get raw value
const level: CompressionLevel = .best;
const raw = level.toInt();  // Returns 19
```

### Custom Level Guidelines

| zstd Level | Speed | Ratio | Best For |
|:----------:|:-----:|:-----:|:---------|
| 1-3 | ★★★★★ | ★★☆☆☆ | Speed priority, real-time |
| 4-9 | ★★★★☆ | ★★★☆☆ | General purpose |
| 10-15 | ★★★☆☆ | ★★★★☆ | Balanced workloads |
| 16-19 | ★★☆☆☆ | ★★★★★ | High compression |
| 20-22 | ★☆☆☆☆ | ★★★★★ | Maximum compression |

## ContentType

```zig
pub const ContentType = enum {
    unknown,
    text,
    source_code,
    json,
    xml,
    binary,
    image,
    audio,
    video,
    archive,
    executable,
    
    pub fn detect(data: []const u8) ContentType;
    pub fn getRecommendedLevel(self: ContentType) CompressionLevel;
    pub fn name(self: ContentType) []const u8;
};
```

## AdvancedOptions

```zig
pub const AdvancedOptions = struct {
    level: CompressionLevel = .default,
    dictionary: ?*const Dictionary = null,
    long_distance_matching: bool = false,
    window_log: u6 = 0,    // 0 = auto
    hash_log: u6 = 0,      // 0 = auto
    chain_log: u6 = 0,     // 0 = auto
    search_log: u5 = 0,    // 0 = auto
    min_match: u4 = 0,     // 0 = auto
    target_length: u12 = 0, // 0 = auto
    strategy: Strategy = .default,
    threads: u8 = 0,       // 0 = auto
};
```

## Dictionary

```zig
pub const Dictionary = struct {
    data: []u8,
    allocator: Allocator,
    
    pub fn train(samples: []const []const u8, max_size: usize, allocator: Allocator) !Dictionary;
    pub fn load(path: []const u8, allocator: Allocator) !Dictionary;
    pub fn save(self: *const Dictionary, path: []const u8) !void;
    pub fn deinit(self: *Dictionary) void;
};
```

## Bundle Progress Types

```zig
/// Progress event types for bundle operations
pub const ProgressEvent = enum {
    scanning,       // Scanning directory for files
    reading_file,   // Reading a file from disk
    compressing,    // Compressing data
    writing,        // Writing to archive
    finalizing,     // Writing header/checksums
};

/// Progress info for bundle callbacks
pub const ProgressInfo = struct {
    event: ProgressEvent,
    current_file: ?[]const u8 = null,
    files_processed: usize = 0,
    total_files: usize = 0,
    bytes_processed: u64 = 0,
    total_bytes: u64 = 0,

    /// Get progress percentage (0-100)
    pub fn getPercent(self: *const ProgressInfo) f64 {
        if (self.total_bytes == 0) return 0;
        return @as(f64, @floatFromInt(self.bytes_processed)) / 
               @as(f64, @floatFromInt(self.total_bytes)) * 100.0;
    }
};

/// Progress callback function type for bundling
pub const ProgressCallback = *const fn (info: ProgressInfo, context: ?*anyopaque) void;
```

## Extract Progress Types

```zig
/// Progress event types for extraction operations
pub const ExtractProgressEvent = enum {
    started,          // Extraction started
    reading_archive,  // Reading archive file
    decompressing,    // Decompressing data
    extracting_file,  // Extracting a file
    verifying,        // Verifying checksums
    completed,        // Extraction completed
};

/// Progress info for extraction callbacks
pub const ExtractProgressInfo = struct {
    event: ExtractProgressEvent,
    current_file: ?[]const u8 = null,
    files_extracted: usize = 0,
    total_files: usize = 0,
    bytes_written: u64 = 0,
    total_bytes: u64 = 0,

    /// Get progress percentage (0-100)
    pub fn getPercent(self: *const ExtractProgressInfo) f64 {
        if (self.total_bytes == 0) return 0;
        return @as(f64, @floatFromInt(self.bytes_written)) / 
               @as(f64, @floatFromInt(self.total_bytes)) * 100.0;
    }
};

/// Progress callback function type for extraction
pub const ExtractProgressCallback = *const fn (info: ExtractProgressInfo, context: ?*anyopaque) void;
```

## CompressOptions

```zig
pub const CompressOptions = struct {
    allocator: Allocator,
    include: ?[]const []const u8 = null,
    exclude: []const []const u8 = &.{},
    output_path: ?[]const u8 = null,
    base_dir: []const u8 = ".",
    level: CompressionLevel = .best,
    compression_enabled: bool = true,
    auto_metadata: bool = true,
    metadata: StringHashMap = .{},
    
    // Progress tracking
    progress_callback: ?ProgressCallback = null,
    progress_context: ?*anyopaque = null,
    
    // Advanced options
    adaptive_compression: bool = false,
    long_distance_matching: bool = false,
    include_hidden: bool = false,
    follow_symlinks: bool = false,
    dictionary: ?*const Dictionary = null,
    verify_after_compress: bool = false,
    preserve_timestamps: bool = true,
};
```

## CompressResult

```zig
pub const CompressResult = struct {
    output_path: []const u8,
    archive_size: u64,
    original_size: u64,
    file_count: usize,
    archive_hash: [64]u8,
    compression_enabled: bool,
    content_type_summary: ?ContentTypeSummary,

    pub fn deinit(self: *CompressResult) void;
    pub fn getCompressionRatio(self: *const CompressResult) f64;
    pub fn getCompressionPercent(self: *const CompressResult) f64;
};

pub const ContentTypeSummary = struct {
    source_code_count: usize,
    text_count: usize,
    binary_count: usize,
    image_count: usize,
    archive_count: usize,
    other_count: usize,
};
```

## CompressibilityAnalysis

```zig
pub const CompressibilityAnalysis = struct {
    estimated_ratio: f64,
    entropy: f64,
    recommended_level: CompressionLevel,
    is_likely_compressed: bool,
    content_type: ContentType,
};
```

## ConfigBuilder

Builder pattern for creating custom configurations:

```zig
pub const ConfigBuilder = struct {
    cfg: Config,
    
    pub fn init() ConfigBuilder;
    pub fn compressionLevel(self: *ConfigBuilder, level: CompressionLevel) *ConfigBuilder;
    pub fn customLevel(self: *ConfigBuilder, level: u8) *ConfigBuilder;
    pub fn compressionEnabled(self: *ConfigBuilder, enabled: bool) *ConfigBuilder;
    pub fn adaptive(self: *ConfigBuilder, enable: bool) *ConfigBuilder;
    pub fn longDistanceMatching(self: *ConfigBuilder, enable: bool) *ConfigBuilder;
    pub fn windowLog(self: *ConfigBuilder, log: ?u5) *ConfigBuilder;
    pub fn excludePatterns(self: *ConfigBuilder, patterns: []const []const u8) *ConfigBuilder;
    pub fn includeHidden(self: *ConfigBuilder, include: bool) *ConfigBuilder;
    pub fn threads(self: *ConfigBuilder, count: u8) *ConfigBuilder;
    pub fn verbose(self: *ConfigBuilder, enable: bool) *ConfigBuilder;
    pub fn build(self: *ConfigBuilder) Config;
};
```

### Usage

```zig
var builder = zigx.ConfigBuilder.init();
const cfg = builder
    .compressionLevel(.best)
    .adaptive(true)
    .longDistanceMatching(true)
    .build();
```

## OptionsBuilder (Fluent API)

```zig
pub const OptionsBuilder = struct {
    options: CompressOptions,
    
    pub fn init(allocator: Allocator) OptionsBuilder;
    
    // Path configuration
    pub fn include(self: *OptionsBuilder, paths: []const []const u8) *OptionsBuilder;
    pub fn exclude(self: *OptionsBuilder, patterns: []const []const u8) *OptionsBuilder;
    pub fn outputPath(self: *OptionsBuilder, path: []const u8) *OptionsBuilder;
    
    // Compression level
    pub fn level(self: *OptionsBuilder, lvl: CompressionLevel) *OptionsBuilder;
    pub fn customLevel(self: *OptionsBuilder, lvl: u8) *OptionsBuilder;
    
    // Preset shortcuts
    pub fn ultra(self: *OptionsBuilder) *OptionsBuilder;  // Level 22
    pub fn best(self: *OptionsBuilder) *OptionsBuilder;   // Level 19
    pub fn fast(self: *OptionsBuilder) *OptionsBuilder;   // Level 1
    pub fn balanced(self: *OptionsBuilder) *OptionsBuilder; // Level 6
    pub fn adaptive(self: *OptionsBuilder, enable: bool) *OptionsBuilder; // Enable adaptive
    
    // Progress callback
    pub fn progress(self: *OptionsBuilder, callback: ProgressCallback, context: ?*anyopaque) *OptionsBuilder;
    
    // Build final options
    pub fn build(self: *const OptionsBuilder) CompressOptions;
};
```

### OptionsBuilder Usage

```zig
var builder = zigx.OptionsBuilder.init(allocator);
const opts = builder
    .include(&.{ "src", "build.zig" })
    .exclude(&.{ "*.tmp", "zig-cache" })
    .outputPath("project.zigx")
    .ultra()
    .progress(myCallback, null)
    .build();

try zigx.bundle(opts);
```

## ExtractOptions

```zig
pub const ExtractOptions = struct {
    archive_path: []const u8,
    output_dir: []const u8,
    allocator: Allocator,
    validate: bool = true,
    overwrite: bool = false,
    
    // Progress tracking
    progress_callback: ?ExtractProgressCallback = null,
    progress_context: ?*anyopaque = null,
};
```

## ExtractResult

```zig
pub const ExtractResult = struct {
    files_extracted: usize,
    bytes_written: u64,
    files: []const []const u8,

    pub fn deinit(self: *ExtractResult) void;
};
```

## ArchiveInfo

```zig
pub const ArchiveInfo = struct {
    format_version: u16,
    compression_version: u8,
    compression_type: CompressionType,
    file_count: u32,
    original_size: u64,
    compressed_size: u64,
    is_signed: bool,
    is_encrypted: bool,
    payload_hash: [64]u8,
    archive_hash: [64]u8,
    compression_level: u8,
    metadata: Metadata,
    checksums: ChecksumList,

    pub fn deinit(self: *ArchiveInfo) void;
    pub fn getCompressionRatio(self: *const ArchiveInfo) f64;
    pub fn getSavedPercent(self: *const ArchiveInfo) f64;
    pub fn getMetadata(self: *const ArchiveInfo, key: []const u8) ?[]const u8;
    pub fn getFiles(self: *const ArchiveInfo) []const Checksum;
};
```

## Metadata

```zig
pub const Metadata = struct {
    entries: StringHashMap,

    pub fn init(allocator: Allocator) Metadata;
    pub fn deinit(self: *Metadata) void;
    pub fn set(self: *Metadata, key: []const u8, value: []const u8) !void;
    pub fn get(self: *const Metadata, key: []const u8) ?[]const u8;
    pub fn count(self: *const Metadata) usize;
};
```

## Checksum

```zig
pub const Checksum = struct {
    path: []const u8,
    size: u64,
    hash: [64]u8,
};
```

## ValidationResult

```zig
pub const ValidationResult = struct {
    is_valid: bool,
    header_valid: bool,
    payload_hash_valid: bool,
    errors: []const []const u8,
    warnings: []const []const u8,
};
```

## CorruptionInfo

```zig
pub const CorruptionInfo = struct {
    corruption_type: CorruptionType,
    offset: u64,
    description: []const u8,
};

pub const CorruptionType = enum {
    header_corruption,
    metadata_corruption,
    checksum_corruption,
    payload_corruption,
    truncated,
};
```
