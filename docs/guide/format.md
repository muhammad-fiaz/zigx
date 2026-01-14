# Format Specification

This document describes the ZIGX archive format (version 1).

## Overview

ZIGX archives consist of four main sections:

1. **Header** (128 bytes) - Fixed-size metadata
2. **Metadata** (variable) - Key-value pairs
3. **Checksums** (variable) - File integrity data
4. **Compressed Payload** - File contents

## Header Format

The header is exactly 128 bytes:

| Offset | Size | Field | Description |
|--------|------|-------|-------------|
| 0 | 4 | Magic | `ZIGX` (0x5A494758) |
| 4 | 2 | Version | Format version (0x0001) |
| 6 | 4 | Flags | Feature flags |
| 10 | 4 | File Count | Number of files |
| 14 | 8 | Original Size | Uncompressed size |
| 22 | 8 | Payload Length | Compressed size |
| 30 | 8 | Meta Length | Metadata section size |
| 38 | 8 | Checksums Length | Checksums section size |
| 46 | 32 | Payload Hash | SHA-256 of payload |
| 78 | 1 | Compression Level | 0-13 |
| 79 | 49 | Reserved | Future use |

### Magic Number

```zig
pub const MAGIC: [4]u8 = .{ 'Z', 'I', 'G', 'X' };
```

### Flags

| Bit | Description |
|-----|-------------|
| 0 | Signed |
| 1 | Encrypted |
| 2-31 | Reserved |

## Metadata Section

Metadata is stored as key-value pairs:

| Field | Size | Description |
|-------|------|-------------|
| Key Length | 2 bytes | Little-endian |
| Key Data | variable | UTF-8 string |
| Value Length | 4 bytes | Little-endian |
| Value Data | variable | UTF-8 string |

### Standard Metadata Keys

| Key | Description |
|-----|-------------|
| `format` | Always "zigx" |
| `format_version` | Version string |
| `created_at` | Unix timestamp |
| `file_count` | Number of files |
| `file_types` | File type statistics |

## Checksums Section

Each file has an entry:

| Field | Size | Description |
|-------|------|-------------|
| Path Length | 2 bytes | Little-endian |
| Path Data | variable | UTF-8 string |
| File Size | 8 bytes | Little-endian |
| SHA-256 Hash | 32 bytes | File checksum |

## Compressed Payload

The payload starts with a compression header:

| Field | Size | Description |
|-------|------|-------------|
| Magic | 4 bytes | `ZXCM` |
| Version | 1 byte | Compression version |
| Entries | variable | Compressed files |

### Compression Version

| Version | Algorithm |
|---------|-----------|
| 1 | **Zstandard (zstd)** - levels 1-19, frame format with content size |

### File Entry Format

| Field | Size | Description |
|-------|------|-------------|
| Path Length | 4 bytes | Compressed path size |
| Path Data | variable | Compressed path |
| Original Size | 8 bytes | Uncompressed size |
| Compressed Size | 4 bytes | Compressed size |
| CRC32 | 4 bytes | Integrity check |
| Content | variable | Compressed data |

## Versioning Strategy

ZIGX uses two version numbers:

### Format Version

Tracks changes to the archive structure:

```zig
pub const FORMAT_VERSION: u16 = 0x0001;  // v1
```

- Breaking changes increment major version
- New features increment minor version

### Compression Version

Tracks changes to the compression algorithm:

```zig
pub const COMPRESSION_VERSION: u8 = 1;  // Zstandard (zstd)
```

| Version | Algorithm | Notes |
|---------|-----------|-------|
| 1 | **Zstandard (zstd)** | Current, levels 1-19 |

This allows:
- Algorithm updates without format changes
- Backward compatibility
- Clear capability tracking

## Reading Archive Information

```zig
const zigx = @import("zigx");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var info = try zigx.getArchiveInfo("archive.zigx", allocator);
    defer info.deinit();

    std.debug.print("Format Version:      v{d}\n", .{info.format_version});
    std.debug.print("Compression Version: v{d}\n", .{info.compression_version});
    std.debug.print("File Count:          {d}\n", .{info.file_count});
    std.debug.print("Original Size:       {d} bytes\n", .{info.original_size});
    std.debug.print("Compressed Size:     {d} bytes\n", .{info.compressed_size});
}
```

## File Extension

The recommended extension is `.zigx`:

```
myproject.zigx
bundle.zigx
release-v0.0.1.zigx
```

## MIME Type

```
application/x-zigx
```

## Next Steps

- [Versioning](/guide/versioning) - Version compatibility
- [API Reference](/api/) - Full API documentation
