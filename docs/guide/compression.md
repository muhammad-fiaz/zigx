# Compression

ZIGX uses **Zstandard (zstd)** compression for optimal compression ratios and speed.

## Compression Algorithm

### Overview

ZIGX uses [Zstandard](https://facebook.github.io/zstd/) (zstd), developed by Facebook/Meta:

- **Industry-leading compression** - Better ratios than gzip/deflate
- **Extremely fast decompression** - 139+ MB/s on typical data
- **Flexible compression levels** - 1 (fastest) to 19 (best ratio)
- **Cross-platform** - Via [zstd.zig](https://github.com/muhammad-fiaz/zstd.zig) Zig bindings

### Key Features

- **Zstd Frame Format**: Built-in content size and checksums
- **Compression Levels 1-19**: Fine-grained control over speed vs ratio
- **CRC32 Checksums**: Additional integrity verification for ZIGX payload
- **SHA-256 Hashes**: File-level integrity in archive headers

## Compression Levels

ZIGX offers four compression modes mapped to zstd levels:

### BEST (zstd Level 19)

```zig
.level = .best
```

- **Ratio**: ~19-25% of original (75-81% space saved)
- **Speed**: Slowest (~14 MB/s compression)
- **Use Case**: Distribution packages, long-term storage

Maximum compression with extensive search for optimal matches.

### DEFAULT (zstd Level 3)

```zig
.level = .default
```

- **Ratio**: ~21-28% of original (72-79% space saved)
- **Speed**: Balanced (~120 MB/s compression)
- **Use Case**: General purpose, most applications

Zstd's default level - excellent balance between ratio and speed.

### FAST (zstd Level 1)

```zig
.level = .fast
```

- **Ratio**: ~25-33% of original (67-75% space saved)
- **Speed**: Fastest compression (~130 MB/s)
- **Use Case**: Development, CI/CD pipelines

Prioritizes speed while still achieving good compression.

### STORE (No compression)

```zig
.level = .none
```

- **Ratio**: 100%+ (header overhead only)
- **Speed**: Instant
- **Use Case**: Already compressed files, archives

No compression, just packages files with headers.

## Compression Comparison

Benchmark results on typical project files:

| Mode | Size (bytes) | Ratio | Space Saved |
|------|-------------|-------|-------------|
| BEST | 30,142 | 19.3% | 80.7% |
| DEFAULT | 33,351 | 21.4% | 78.6% |
| FAST | 39,346 | 25.2% | 74.8% |
| STORE | 157,833 | 101.3% | -1.3% |

### By Data Type

| Data Type | Compression Ratio | Notes |
|-----------|------------------|-------|
| Text/Source | ~18-19% | Excellent |
| Log files | Up to 99.9% | Outstanding (repetitive) |
| Random/Encrypted | ~0% | Incompressible |
| Mixed/Binary | ~0-18% | Varies |

## Algorithm Versioning

ZIGX tracks compression algorithm versions to ensure compatibility:

```zig
const info = try zigx.getArchiveInfo("archive.zigx", allocator);
std.debug.print("Compression Version: v{d}\n", .{info.compression_version});
```

### Version 1 (Current)

- **Zstandard (zstd)** compression
- Levels 1-19 via `zstd.c.ZSTD_compress()`
- Built-in frame format with content size
- CRC32 payload checksums

## Best Practices

### Choose the Right Level

| Scenario | Recommended Level | Why |
|----------|------------------|-----|
| Release builds | `.best` | Maximum compression |
| Daily builds | `.default` | Good ratio, fast |
| CI/CD pipelines | `.fast` | Speed priority |
| Pre-compressed files | `.none` | Avoid overhead |

### File Type Considerations

Some file types don't compress well:

- **Already compressed**: `.zip`, `.gz`, `.zst`, `.png`, `.jpg`, `.mp4`
- **Encrypted files**: Random byte distribution
- **Random binary data**: No patterns to compress

For these, zstd will automatically detect incompressibility and store with minimal overhead.

### Performance Tips

1. **Use `.default` for most cases** - zstd level 3 is well-optimized
2. **Reserve `.best` for final releases** - Much slower but best ratio
3. **Use `.fast` in development** - Quick iteration cycles
4. **Batch similar files** - Better compression on similar content

## API Example

```zig
const zigx = @import("zigx");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Compare compression levels using bundle() alias
    const levels = [_]zigx.CompressionLevel{ .best, .default, .fast, .none };
    
    for (levels) |level| {
        const result = try zigx.bundle(.{
            .allocator = allocator,
            .include = &.{"src"},
            .output_path = "test.zigx",
            .level = level,
        });
        defer result.deinit();
        
        std.debug.print("{s}: {d} bytes ({d:.1}% - saved {d:.1}%)\n", .{
            level.name(),
            result.archive_size,
            result.getCompressionRatio() * 100,
            result.getCompressionPercent(),
        });
    }
}
```

## Comparison with Other Formats

| Format | Typical Ratio | Compression Speed | Decompression Speed |
|--------|--------------|-------------------|---------------------|
| **ZIGX** | 19-25% | 117+ MB/s | 139+ MB/s |
| ZIP (deflate) | 60-70% | Medium | Medium |
| GZIP | 60-70% | Medium | Medium |
| 7-Zip (LZMA) | 70-80% | Slow | Slow |
| LZ4 | 50-60% | Very Fast | Very Fast |
| Zstd | 65-75% | Fast | Very Fast |

*ZIGX uses zstd internally, achieving excellent ratios with fast decompression.*

## Next Steps

- [Format Specification](/guide/format) - Archive format details
- [Performance](/guide/performance) - Optimization tips and benchmarks
