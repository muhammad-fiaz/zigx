# Compression

ZIGX uses an advanced LZ77+RLE hybrid compression algorithm with several optimization techniques.

## Compression Algorithm

### Overview

ZIGX combines two compression techniques:

1. **LZ77**: Finds repeated patterns and references them with offset/length pairs
2. **RLE (Run-Length Encoding)**: Efficiently compresses runs of repeated bytes

### Key Features

- **64KB Sliding Window**: Large window for finding distant matches
- **Lazy Matching**: Looks ahead to find potentially better matches
- **Huffman Coding**: Variable-length encoding for symbols
- **CRC32 Checksums**: Integrity verification for compressed data

## Compression Levels

ZIGX offers four compression modes:

### BEST (Level 13)

```zig
.level = .best
```

- **Ratio**: ~28-32% of original
- **Speed**: Slowest
- **Use Case**: Distribution packages, long-term storage

Maximum compression with extensive search for optimal matches.

### DEFAULT (Level 9)

```zig
.level = .default
```

- **Ratio**: ~28-35% of original
- **Speed**: Balanced
- **Use Case**: General purpose, most applications

Good balance between compression ratio and speed.

### FAST (Level 3)

```zig
.level = .fast
```

- **Ratio**: ~33-40% of original
- **Speed**: Fastest compression
- **Use Case**: Development, CI/CD pipelines

Prioritizes speed over compression ratio.

### STORE (Level 0)

```zig
.level = .store
```

- **Ratio**: 100%+ (header overhead)
- **Speed**: Instant
- **Use Case**: Already compressed files, archives

No compression, just packages files with headers.

## Compression Comparison

| Mode | Size (bytes) | Ratio | Saved |
|------|-------------|-------|-------|
| BEST | 45,509 | 31.3% | 68.7% |
| DEFAULT | 41,558 | 28.6% | 71.4% |
| FAST | 48,658 | 33.5% | 66.5% |
| STORE | 147,201 | 101.3% | -1.3% |

## Algorithm Versioning

ZIGX tracks compression algorithm versions to ensure compatibility:

```zig
const info = try zigx.getArchiveInfo("archive.zigx", allocator);
std.debug.print("Compression Version: v{d}\n", .{info.compression_version});
```

### Version 1 (Current)

- LZ77 with 64KB window
- Lazy matching enabled
- RLE integration
- CRC32 checksums

Future versions may introduce new algorithms while maintaining backward compatibility.

## Best Practices

### Choose the Right Level

| Scenario | Recommended Level |
|----------|------------------|
| Release builds | `.best` |
| Daily builds | `.default` |
| CI/CD | `.fast` |
| Pre-compressed files | `.store` |

### File Type Considerations

Some file types don't compress well:

- Already compressed: `.zip`, `.gz`, `.png`, `.jpg`
- Encrypted files
- Random binary data

For these, consider using `.store` to avoid overhead.

### Memory Usage

Higher compression levels use more memory:

| Level | Approximate Memory |
|-------|-------------------|
| BEST | ~256KB |
| DEFAULT | ~128KB |
| FAST | ~64KB |
| STORE | ~16KB |

## API Example

```zig
const zigx = @import("zigx");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Compare compression levels using bundle() alias
    const levels = [_]zigx.CompressionLevel{ .best, .default, .fast, .store };
    
    for (levels) |level| {
        const result = try zigx.bundle(.{
            .allocator = allocator,
            .include = &.{"src"},
            .output_path = "test.zigx",
            .level = level,
        });
        
        std.debug.print("{s}: {d} bytes ({d:.1}%)\n", .{
            @tagName(level),
            result.compressed_size,
            @as(f64, @floatFromInt(result.compressed_size)) /
            @as(f64, @floatFromInt(result.original_size)) * 100,
        });
    }
}
```

## Next Steps

- [Format Specification](/guide/format) - Archive format details
- [Performance](/guide/performance) - Optimization tips
