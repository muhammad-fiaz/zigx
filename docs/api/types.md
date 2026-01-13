# Types

Complete type reference for ZIGX.

## CompressionLevel

```zig
pub const CompressionLevel = enum(u4) {
    none = 0,     // No compression (store)
    fast = 0xb,   // Speed optimized
    default = 0xc, // Balanced
    best = 0xd,   // Maximum compression
};
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

    pub fn deinit(self: *CompressResult) void;
    pub fn getCompressionRatio(self: *const CompressResult) f64;
    pub fn getCompressionPercent(self: *const CompressResult) f64;
};
```

## ExtractOptions

```zig
pub const ExtractOptions = struct {
    archive_path: []const u8,
    output_dir: []const u8,
    allocator: Allocator,
    validate: bool = true,
    overwrite: bool = false,
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
