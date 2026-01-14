# API Reference

Complete API documentation for ZIGX.

## Core Functions

### Compression

| Function | Alias | Description |
|----------|-------|-------------|
| [`compress`](/api/compress) | `bundle` | Create an archive |
| [`compressData`](/api/compress#compressdata) | - | Compress raw data |

### Extraction

| Function | Alias | Description |
|----------|-------|-------------|
| [`extract`](/api/extract) | `unbundle` | Extract an archive |
| [`extractWithResult`](/api/extract#extractwithresult) | `unbundleWithResult` | Extract with details |
| [`listFiles`](/api/extract#listfiles) | `list` | List files in archive |

### Archive Info

| Function | Description |
|----------|-------------|
| [`getArchiveInfo`](/api/get-archive-info) | Get archive metadata |
| [`isValidArchive`](/api/validate#isvalidarchive) | Quick validity check |

### Validation

| Function | Alias | Description |
|----------|-------|-------------|
| [`validate`](/api/validate) | `verify` | Validate archive |
| [`validateDetailed`](/api/validate#validatedetailed) | `verifyDetailed` | Detailed validation |
| [`detectCorruption`](/api/validate#detectcorruption) | - | Detect corruption type |

### Management

| Function | Alias | Description |
|----------|-------|-------------|
| [`manager.update`](/api/manager#update) | `update` | Add/remove files |
| [`manager.repair`](/api/manager#repair) | `repair` | Repair corrupted archive |
| [`manager.getMetadata`](/api/manager#metadata) | - | Get specific metadata value |
| [`manager.getAllMetadata`](/api/manager#metadata) | - | Get all metadata |
| [`manager.updateMetadata`](/api/manager#metadata) | - | Key-value CRUD for metadata |
| [`manager.setSignature`](/api/manager#signing) | - | Sign an archive |

## Constants

```zig
// Library version
pub const VERSION = "0.0.1";

// Archive format version
pub const FORMAT_VERSION: u16 = 0x0001;  // v1

// Compression algorithm version
pub const COMPRESSION_VERSION: u8 = 1;

// File extension
pub const FILE_EXTENSION = ".zigx";
```

## Types

### CompressionLevel

```zig
pub const CompressionLevel = enum(u8) {
    none = 0,      // Store only, no compression
    fast = 1,      // Speed optimized (zstd 1)
    default = 3,   // Balanced (zstd 3)
    balanced = 6,  // Good balance (zstd 6)
    best = 19,     // High compression (zstd 19)
    ultra = 22,    // Maximum compression (zstd 22)
    
    // Fine-grained levels: level_2 through level_22
    
    pub fn custom(level: u8) CompressionLevel;  // Any level 1-22
    pub fn toInt(self: CompressionLevel) u8;    // Get raw value
    pub fn fromInt(level: u8) CompressionLevel; // From integer
};
```

### CompressOptions

```zig
pub const CompressOptions = struct {
    allocator: Allocator,                    // Required
    include: ?[]const []const u8 = null,     // Files/directories
    exclude: []const []const u8 = &.{},      // Exclude patterns
    output_path: ?[]const u8 = null,         // Output file
    level: CompressionLevel = .best,         // Compression level
    compression_enabled: bool = true,        // Enable compression
    auto_metadata: bool = true,              // Auto-generate metadata
    progress_callback: ?ProgressCallback = null,    // Progress tracking
    progress_context: ?*anyopaque = null,           // Callback context
    adaptive_compression: bool = false,      // Auto-detect content type
    long_distance_matching: bool = false,    // Better for large files
};
```

### ExtractOptions

```zig
pub const ExtractOptions = struct {
    archive_path: []const u8,                // Required
    output_dir: []const u8,                  // Required
    allocator: Allocator,                    // Required
    validate: bool = true,                   // Validate checksums
    overwrite: bool = false,                 // Overwrite existing
    progress_callback: ?ExtractProgressCallback = null,  // Progress tracking
    progress_context: ?*anyopaque = null,                // Callback context
};
```

### Progress Types

```zig
// Bundle progress
pub const ProgressEvent = enum { scanning, reading_file, compressing, writing, finalizing };
pub const ProgressInfo = struct {
    event: ProgressEvent,
    current_file: ?[]const u8,
    files_processed: usize,
    total_files: usize,
    bytes_processed: u64,
    total_bytes: u64,
    pub fn getPercent(self: *const ProgressInfo) f64;
};
pub const ProgressCallback = *const fn (info: ProgressInfo, context: ?*anyopaque) void;

// Extract progress
pub const ExtractProgressEvent = enum { started, reading_archive, decompressing, extracting_file, verifying, completed };
pub const ExtractProgressInfo = struct {
    event: ExtractProgressEvent,
    current_file: ?[]const u8,
    files_extracted: usize,
    total_files: usize,
    bytes_written: u64,
    total_bytes: u64,
    pub fn getPercent(self: *const ExtractProgressInfo) f64;
};
pub const ExtractProgressCallback = *const fn (info: ExtractProgressInfo, context: ?*anyopaque) void;
```

### ArchiveInfo

```zig
pub const ArchiveInfo = struct {
    format_version: u16,
    compression_version: u8,
    file_count: u32,
    original_size: u64,
    compressed_size: u64,
    payload_hash: [64]u8,
    archive_hash: [64]u8,
    metadata: Metadata,
    checksums: ChecksumList,

    pub fn deinit(self: *ArchiveInfo) void;
    pub fn getCompressionRatio(self: *const ArchiveInfo) f64;
    pub fn getSavedPercent(self: *const ArchiveInfo) f64;
};
```
