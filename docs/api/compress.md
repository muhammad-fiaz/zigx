# bundle / compress

Create a ZIGX archive from files and directories.

## Functions

```zig
pub fn compress(options: CompressOptions) CompressError!CompressResult
pub const bundle = compress;  // Alias
```

## Options

```zig
pub const CompressOptions = struct {
    /// Memory allocator (required)
    allocator: Allocator,
    
    /// Files and directories to include
    /// Example: &.{ "src", "build.zig", "README.md" }
    include: ?[]const []const u8 = null,
    
    /// Exclude patterns (glob-style)
    /// Example: &.{ "*.tmp", ".git", "node_modules" }
    exclude: []const []const u8 = &.{},
    
    /// Output archive path
    output_path: ?[]const u8 = null,
    
    /// Base directory for relative paths
    base_dir: []const u8 = ".",
    
    /// Compression level
    level: CompressionLevel = .best,
    
    /// Enable compression (false = store mode)
    compression_enabled: bool = true,
    
    /// Auto-generate metadata
    auto_metadata: bool = true,
    
    /// Custom metadata
    metadata: StringHashMap = .{},
    
    /// Progress callback for tracking operation progress
    progress_callback: ?ProgressCallback = null,
    
    /// Context for progress callback
    progress_context: ?*anyopaque = null,
    
    /// Enable adaptive compression (auto-detect content type)
    adaptive_compression: bool = false,
    
    /// Enable long-distance matching for better compression
    long_distance_matching: bool = false,
    
    /// Include hidden files (starting with .)
    include_hidden: bool = false,
    
    /// Follow symbolic links
    follow_symlinks: bool = false,
    
    /// Dictionary for better compression of similar files
    dictionary: ?*const Dictionary = null,
};
```

## Progress Callback Types

```zig
/// Progress event types for bundling operations
pub const ProgressEvent = enum {
    scanning,       // Scanning directories for files
    reading_file,   // Reading a file
    compressing,    // Compressing data
    writing,        // Writing to archive
    finalizing,     // Finalizing archive
};

/// Progress info passed to callback
pub const ProgressInfo = struct {
    event: ProgressEvent,
    current_file: ?[]const u8 = null,
    files_processed: usize = 0,
    total_files: usize = 0,
    bytes_processed: u64 = 0,
    total_bytes: u64 = 0,

    /// Get progress percentage (0-100)
    pub fn getPercent(self: *const ProgressInfo) f64;
};

/// Progress callback function type
pub const ProgressCallback = *const fn (info: ProgressInfo, context: ?*anyopaque) void;
```

## Result

```zig
pub const CompressResult = struct {
    output_path: []const u8,
    archive_size: u64,
    original_size: u64,
    file_count: usize,
    archive_hash: [64]u8,
    compression_enabled: bool,

    pub fn deinit(self: *CompressResult) void;
    pub fn getCompressionRatio(self: *const CompressResult) f64;
    pub fn getCompressionPercent(self: *const CompressResult) f64;
};
```

## Usage

### Basic

```zig
const result = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{ "src", "build.zig" },
    .output_path = "bundle.zigx",
});
defer result.deinit();

std.debug.print("Created: {d} files, {d} bytes\n", .{
    result.file_count,
    result.archive_size,
});
```

### With Options

```zig
const result = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{ "src", "lib", "build.zig", "README.md" },
    .exclude = &.{ "*.tmp", ".git", "zig-cache", "node_modules" },
    .output_path = "project.zigx",
    .level = .best,
    .compression_enabled = true,
    .auto_metadata = true,
});
```

### With Metadata

```zig
var metadata = zigx.createMetadata(allocator);
defer metadata.deinit();
try metadata.set("name", "my-project");
try metadata.set("version", "1.0.0");

const result = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{"src"},
    .output_path = "project.zigx",
    .metadata = metadata.entries,
});
```

## Compression Levels

| Level | Description |
|-------|-------------|
| `.none` | No compression (store) |
| `.fast` | Speed optimized (zstd 1) |
| `.default` | Good balance (zstd 3) |
| `.balanced` | Speed/ratio balance (zstd 6) |
| `.best` | High compression (zstd 19) |
| `.ultra` | Maximum compression (zstd 22) |
| `custom(n)` | Custom zstd level (1-22) |

### Custom Compression Levels

Use `CompressionLevel.custom(n)` for fine-grained control over compression:

```zig
// Use any zstd level from 1-22
const result = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{"src"},
    .output_path = "bundle.zigx",
    .level = zigx.CompressionLevel.custom(15),  // zstd level 15
});

// Using configWithLevel preset
const config = zigx.configWithLevel(12);  // Config with level 12

// Using configWithLevelAndLdm for large files
const config_ldm = zigx.configWithLevelAndLdm(18);  // Level 18 + LDM
```

### All Zstandard Levels

Levels `.level_1` through `.level_22` are available for fine-grained control:
- Levels 1-3: Fast compression
- Levels 4-9: Balanced compression
- Levels 10-19: High compression
- Levels 20-22: Ultra compression

### Level Aliases

| Alias | Maps To | Description |
|-------|---------|-------------|
| `.turbo` | `.fast` | Speed priority |
| `.level_1` | `.fast` | zstd level 1 |
| `.level_3` | `.default` | zstd level 3 |
| `.level_6` | `.balanced` | zstd level 6 |
| `.level_19` | `.best` | zstd level 19 |
| `.maximum` | `.ultra` | Maximum compression |

## Progress Tracking

Track compression progress for large archives:

```zig
fn onProgress(info: zigx.ProgressInfo, ctx: ?*anyopaque) void {
    _ = ctx;
    std.debug.print("\r[{d}/{d}] {d:.1}% - {s}", .{
        info.files_processed,
        info.total_files,
        info.getPercent(),
        info.current_file orelse "...",
    });
}

const result = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{"src"},
    .output_path = "bundle.zigx",
    .progress_callback = onProgress,
    .progress_context = null,
});
```

### Progress Events

| Event | Description |
|-------|-------------|
| `scanning` | Scanning directories for files |
| `reading_file` | Reading a source file |
| `compressing` | Compressing file data |
| `writing` | Writing to archive |
| `finalizing` | Finalizing archive (checksums, header) |

## OptionsBuilder (Fluent API)

Build options using a fluent builder pattern:

```zig
var builder = zigx.OptionsBuilder.init(allocator);
const opts = builder
    .include(&.{"src", "docs"})
    .exclude(&.{"*.tmp", ".git"})
    .outputPath("bundle.zigx")
    .best()              // Use .best compression
    .progress(onProgress, null)
    .build();

const result = try zigx.bundle(opts);

// Or with custom level
var builder2 = zigx.OptionsBuilder.init(allocator);
const opts2 = builder2
    .include(&.{"src"})
    .outputPath("custom.zigx")
    .customLevel(15)     // zstd level 15
    .adaptive(true)
    .build();

const result2 = try zigx.bundle(opts2);
```

### Builder Methods

| Method | Description |
|--------|-------------|
| `.include(paths)` | Set files/directories to include |
| `.exclude(patterns)` | Set exclude patterns |
| `.outputPath(path)` | Set output archive path |
| `.level(lvl)` | Set compression level |
| `.customLevel(n)` | Set custom level (1-22) |
| `.fast()` | Use fast compression (level 1) |
| `.balanced()` | Use balanced compression (level 6) |
| `.best()` | Use best compression (level 19) |
| `.ultra()` | Use ultra compression (level 22) |
| `.adaptive(bool)` | Enable adaptive compression |
| `.progress(cb, ctx)` | Set progress callback |
| `.build()` | Build final options |

## Preset Configurations

Use preset config functions for common scenarios:

```zig
// Speed priority
const fast_config = zigx.configFast();

// Size priority
const best_config = zigx.configBest();

// Maximum compression + LDM
const ultra_config = zigx.configUltra();

// Balanced speed/ratio
const balanced_config = zigx.configBalanced();

// Auto-detect content type
const adaptive_config = zigx.configAdaptive();

// Custom level (1-22)
const custom_config = zigx.configWithLevel(15);

// Custom level + Long Distance Matching
const ldm_config = zigx.configWithLevelAndLdm(18);

// Optimized for large files
const large_config = zigx.configForLargeFiles();

// Preserve metadata (archiving)
const archive_config = zigx.configForArchiving();

// Small + fast extraction (distribution)
const dist_config = zigx.configForDistribution();
```

### Preset Summary

| Preset | Level | LDM | Best For |
|--------|-------|-----|----------|
| `configFast()` | 1 | No | Speed priority |
| `configBalanced()` | 6 | No | General use |
| `configBest()` | 19 | No | Size priority |
| `configUltra()` | 22 | Yes | Maximum compression |
| `configAdaptive()` | Auto | No | Mixed content |
| `configWithLevel(n)` | n | No | Custom level |
| `configWithLevelAndLdm(n)` | n | Yes | Custom + large files |
| `configForLargeFiles()` | 6 | Yes | Large files |
| `configForArchiving()` | 19 | No | Long-term storage |
| `configForDistribution()` | 19 | No | Package distribution |

## Advanced Options

For fine-tuned compression:

```zig
const advanced = zigx.AdvancedOptions{
    .level = .best,
    .long_distance_matching = true,  // Better for large files
    .window_log = 25,                // 32MB window
    .hash_log = 22,                  // Hash table size
    .chain_log = 24,                 // Chain table size
    .search_log = 6,                 // Search depth
};
```

## Dictionary Compression

For many similar files:

```zig
// Train dictionary from samples
var dict = try zigx.Dictionary.train(&sample_data, 32768, allocator);
defer dict.deinit();

// Save dictionary for reuse
try dict.save("my.dict");

// Use in compression
const opts = zigx.AdvancedOptions{
    .level = .best,
    .dictionary = &dict,
};
```

## Errors

| Error | Description |
|-------|-------------|
| `NoFilesSpecified` | No files to compress |
| `FileNotFound` | Source file not found |
| `CompressionError` | Compression failed |
| `FileSystemError` | Cannot create output |
| `IoError` | Read/write error |
| `SecurityViolation` | Path security issue |
