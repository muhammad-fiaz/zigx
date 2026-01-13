# getArchiveInfo

Get comprehensive information about a ZIGX archive without extracting it.

## Signature

```zig
pub fn getArchiveInfo(
    path: []const u8,
    allocator: Allocator
) !ArchiveInfo
```

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `path` | `[]const u8` | Path to the archive file |
| `allocator` | `Allocator` | Memory allocator |

## Returns

Returns an `ArchiveInfo` struct containing:

```zig
pub const ArchiveInfo = struct {
    /// Archive format version (e.g., 1)
    format_version: u16,
    
    /// Compression algorithm version (e.g., 1)
    compression_version: u8,
    
    /// Compression type (deflate_best, deflate_fast, etc.)
    compression_type: CompressionType,
    
    /// Number of files in archive
    file_count: u32,
    
    /// Total uncompressed size in bytes
    original_size: u64,
    
    /// Compressed payload size in bytes
    compressed_size: u64,
    
    /// Whether archive is digitally signed
    is_signed: bool,
    
    /// Whether archive is encrypted
    is_encrypted: bool,
    
    /// SHA-256 hash of payload (hex string)
    payload_hash: [64]u8,
    
    /// SHA-256 hash of entire archive (hex string)
    archive_hash: [64]u8,
    
    /// Compression level (0-13)
    compression_level: u8,
    
    /// Custom metadata key-value pairs
    metadata: Metadata,
    
    /// File checksums list
    checksums: ChecksumList,
    
    /// Allocator used (for deinit)
    allocator: Allocator,

    /// Free allocated resources
    pub fn deinit(self: *ArchiveInfo) void;
};
```

## Usage

### Basic Usage

```zig
const zigx = @import("zigx");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var info = try zigx.getArchiveInfo("archive.zigx", allocator);
    defer info.deinit();

    std.debug.print("Format: v{d}, Compression: v{d}\n", .{
        info.format_version,
        info.compression_version,
    });
}
```

### Complete Example

```zig
const std = @import("std");
const zigx = @import("zigx");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var info = try zigx.getArchiveInfo("archive.zigx", allocator);
    defer info.deinit();

    // Version information
    std.debug.print(
        \\VERSION INFO:
        \\  Format Version:         v{d}
        \\  Compression Version:    v{d}
        \\  Compression Type:       {s}
        \\  Compression Level:      {d}
        \\
    , .{
        info.format_version,
        info.compression_version,
        @tagName(info.compression_type),
        info.compression_level,
    });

    // Size information
    const ratio = @as(f64, @floatFromInt(info.compressed_size)) /
                  @as(f64, @floatFromInt(info.original_size)) * 100;
    
    std.debug.print(
        \\SIZE INFO:
        \\  Original Size:          {d} bytes
        \\  Compressed Size:        {d} bytes
        \\  Compression Ratio:      {d:.1}%
        \\  Space Saved:            {d:.1}%
        \\
    , .{
        info.original_size,
        info.compressed_size,
        ratio,
        100 - ratio,
    });

    // Security info
    std.debug.print(
        \\SECURITY:
        \\  Signed:                 {s}
        \\  Encrypted:              {s}
        \\  Payload Hash:           {s}...
        \\  Archive Hash:           {s}...
        \\
    , .{
        if (info.is_signed) "yes" else "no",
        if (info.is_encrypted) "yes" else "no",
        info.payload_hash[0..32],
        info.archive_hash[0..32],
    });

    // Content info
    std.debug.print(
        \\CONTENT:
        \\  File Count:             {d}
        \\
    , .{info.file_count});

    // Metadata
    std.debug.print("METADATA:\n", .{});
    var it = info.metadata.entries.iterator();
    while (it.next()) |entry| {
        std.debug.print("  {s}: {s}\n", .{
            entry.key_ptr.*,
            entry.value_ptr.*,
        });
    }

    // File list
    std.debug.print("\nFILES:\n", .{});
    for (info.checksums.items) |item| {
        const size = zigx.formatSize(item.size);
        std.debug.print("  {s} ({d:.2} {s})\n", .{
            item.path,
            size.value,
            size.unit,
        });
    }
}
```

### Checking Compatibility

```zig
var info = try zigx.getArchiveInfo("archive.zigx", allocator);
defer info.deinit();

// Check format compatibility
if (info.format_version > zigx.FORMAT_VERSION) {
    std.debug.print("Warning: Archive uses newer format (v{d})\n", .{
        info.format_version
    });
    return error.UnsupportedFormat;
}

// Check compression compatibility
if (info.compression_version > zigx.COMPRESSION_VERSION) {
    std.debug.print("Warning: Archive uses newer compression (v{d})\n", .{
        info.compression_version
    });
    return error.UnsupportedCompression;
}
```

### Reading Specific Metadata

```zig
var info = try zigx.getArchiveInfo("archive.zigx", allocator);
defer info.deinit();

if (info.metadata.get("version")) |version| {
    std.debug.print("Project version: {s}\n", .{version});
}

if (info.metadata.get("created_at")) |created| {
    std.debug.print("Created: {s}\n", .{created});
}
```

## Errors

| Error | Description |
|-------|-------------|
| `FileNotFound` | Archive file doesn't exist |
| `InvalidFormat` | Not a valid ZIGX archive |
| `InvalidMagic` | Wrong magic bytes |
| `OutOfMemory` | Allocation failed |
| `IoError` | File read error |

## Notes

- Always call `deinit()` to free resources
- The returned hashes are hex-encoded strings
- Checksums list contains all file paths and their SHA-256 hashes
- Metadata includes both auto-generated and custom fields

## See Also

- [API Overview](/api/) - All API functions
- [Format Specification](/guide/format) - Archive format details
- [Versioning](/guide/versioning) - Version compatibility
