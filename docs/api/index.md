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
pub const CompressionLevel = enum {
    none,     // Store only, no compression
    fast,     // Speed optimized
    default,  // Balanced
    best,     // Maximum compression
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
};
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
