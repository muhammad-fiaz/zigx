# Compression

ZIGX uses **Zstandard (zstd)** compression for optimal compression ratios and speed.

## Compression Algorithm

### Overview

ZIGX uses [Zstandard](https://facebook.github.io/zstd/) (zstd), developed by Facebook/Meta:

- **Industry-leading compression** - Better ratios than gzip/deflate
- **Extremely fast decompression** - 139+ MB/s on typical data
- **Flexible compression levels** - 1 (fastest) to 22 (best ratio)
- **Cross-platform** - Via [zstd.zig](https://github.com/muhammad-fiaz/zstd.zig) Zig bindings

### Key Features

- **Zstd Frame Format**: Built-in content size and checksums
- **Compression Levels 1-22**: Fine-grained control over speed vs ratio
- **CRC32 Checksums**: Additional integrity verification for ZIGX payload
- **SHA-256 Hashes**: File-level integrity in archive headers
- **Dictionary Support**: Train dictionaries for similar files
- **Long-Distance Matching**: Better compression for large files
- **Adaptive Compression**: Auto-detect content type and optimize settings
- **Progress Callbacks**: Track compression progress for large archives

## Compression Levels

ZIGX offers multiple compression modes mapped to zstd levels:

### ULTRA (zstd Level 22)

```zig
.level = .ultra
```

- **Ratio**: ~17-22% of original (78-83% space saved)
- **Speed**: Slowest (~5 MB/s compression)
- **Use Case**: Maximum compression, archival storage

Maximum compression with ultra-deep search.

### BEST (zstd Level 19)

```zig
.level = .best
```

- **Ratio**: ~19-25% of original (75-81% space saved)
- **Speed**: Slow (~14 MB/s compression)
- **Use Case**: Distribution packages, long-term storage

Maximum practical compression with extensive search.

### BALANCED (zstd Level 6)

```zig
.level = .balanced
```

- **Ratio**: ~21-26% of original (74-79% space saved)
- **Speed**: Moderate (~80 MB/s compression)
- **Use Case**: Good balance between speed and ratio

Good middle ground between fast and best compression.

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

### All 22 Levels

For fine-grained control, use `.level_1` through `.level_22` or `CompressionLevel.custom(n)`:

| Level Range | Description | Speed | Ratio |
|-------------|-------------|-------|-------|
| 1-3 | Fast | Very fast | Good |
| 4-9 | Balanced | Moderate | Better |
| 10-15 | High | Slow | Very Good |
| 16-19 | Best | Very slow | Excellent |
| 20-22 | Ultra | Extremely slow | Maximum |

### Custom Compression Levels (1-22)

Use `CompressionLevel.custom(n)` to specify any zstd level from 1-22:

```zig
const zigx = @import("zigx");

// Use any zstd level
const result = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{"src"},
    .output_path = "bundle.zigx",
    .level = zigx.CompressionLevel.custom(10),  // zstd level 10
});

// Using preset configurations
const config = zigx.configWithLevel(15);  // Config with custom level 15
const config_ldm = zigx.configWithLevelAndLdm(18);  // Level 18 + LDM

// Get raw level value
const level = zigx.CompressionLevel.best;
const raw_value = level.toInt();  // Returns 19
```

#### Custom Level Guidelines

| zstd Level | Speed | Ratio | Best For |
|:----------:|:-----:|:-----:|:---------|
| 1-3 | ★★★★★ | ★★☆☆☆ | Speed priority, real-time, CI/CD |
| 4-9 | ★★★★☆ | ★★★☆☆ | General purpose, balanced |
| 10-15 | ★★★☆☆ | ★★★★☆ | Good compression, reasonable speed |
| 16-19 | ★★☆☆☆ | ★★★★★ | High compression, distribution |
| 20-22 | ★☆☆☆☆ | ★★★★★ | Maximum compression, archival |

## Advanced Features

### Adaptive Compression

Automatically detect content type and select optimal settings:

```zig
// Let ZIGX analyze and choose optimal settings
const compressed = try zigx.compressDataAdaptive(data, allocator);

// Or get analysis first
const analysis = zigx.analyzeCompressibility(data);
if (analysis.is_likely_compressed) {
    // Use store mode for already-compressed data
    const result = try zigx.bundle(.{
        .allocator = allocator,
        .level = .none,
        // ...
    });
}
```

### Content Type Detection

ZIGX can detect content types to optimize compression:

| Content Type | Detection | Recommended |
|--------------|-----------|-------------|
| Source code | Keywords, patterns | `.best` |
| Text/Config | ASCII ratio | `.best` |
| JSON/XML | Magic bytes | `.best` |
| Images | PNG/JPEG headers | `.none` |
| Archives | ZIP/GZ headers | `.none` |
| Executables | ELF/PE headers | `.default` |

### Dictionary Compression

Train dictionaries from sample data for better compression of similar files:

```zig
// Train dictionary from sample files
var samples = [_][]const u8{ log1, log2, log3 };
var dict = try zigx.Dictionary.train(&samples, 32768, allocator);
defer dict.deinit();

// Save for reuse
try dict.save("logs.dict");

// Use in compression
const opts = zigx.AdvancedOptions{
    .level = .best,
    .dictionary = &dict,
};
```

**Best for**: Log files, config files, JSON documents, similar structured data.

### Long-Distance Matching

For large files with repeated patterns far apart:

```zig
const opts = zigx.AdvancedOptions{
    .level = .best,
    .long_distance_matching = true,
    .window_log = 25,  // 32MB window
};
```

**Best for**: Large log files, database dumps, backup archives.

### Progress Tracking

Monitor compression progress with detailed events:

```zig
fn onProgress(info: zigx.ProgressInfo, ctx: ?*anyopaque) void {
    _ = ctx;
    switch (info.event) {
        .scanning => std.debug.print("Scanning files...\n", .{}),
        .reading_file => {
            if (info.current_file) |file| {
                std.debug.print("\rReading: {s}", .{file});
            }
        },
        .compressing => {
            std.debug.print("\rCompressing... {d:.1}%", .{info.getPercent()});
        },
        .writing => std.debug.print("\rWriting archive...", .{}),
        .finalizing => std.debug.print("\rFinalizing...", .{}),
    }
}

const result = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{"src"},
    .output_path = "bundle.zigx",
    .progress_callback = onProgress,
    .progress_context = null,
});
```

#### Progress Events

| Event | Description |
|-------|-------------|
| `scanning` | Scanning directories for files |
| `reading_file` | Reading a file from disk |
| `compressing` | Compressing data with zstd |
| `writing` | Writing compressed data to archive |
| `finalizing` | Writing header and checksums |

## Preset Configurations

Use preset configurations for common scenarios:

```zig
// Quick presets (returns CompressionConfig)
const fast_config = zigx.configFast();        // Level 1
const balanced_config = zigx.configBalanced(); // Level 6
const best_config = zigx.configBest();         // Level 19
const ultra_config = zigx.configUltra();       // Level 22

// Custom level presets
const level_config = zigx.configWithLevel(15);          // Any level 1-22
const ldm_config = zigx.configWithLevelAndLdm(18);      // Level + LDM

// Scenario-specific presets
const archival = zigx.configForArchiving();      // Ultra + LDM
const large_files = zigx.configForLargeFiles();  // Best + LDM + 32MB window
const distribution = zigx.configForDistribution(); // Best, optimized for packages

// Adaptive compression
const adaptive = zigx.configAdaptive();  // Auto-detect content type
```

### Preset Configuration Table

| Preset | Level | LDM | Window | Best For |
|--------|:-----:|:---:|:------:|----------|
| `configFast()` | 1 | ❌ | Default | Speed priority |
| `configBalanced()` | 6 | ❌ | Default | General purpose |
| `configBest()` | 19 | ❌ | Default | Distribution |
| `configUltra()` | 22 | ✅ | 128MB | Maximum compression |
| `configAdaptive()` | Auto | ❌ | Default | Mixed content |
| `configForLargeFiles()` | 6 | ✅ | 32MB | Large files |
| `configForArchiving()` | 19 | ❌ | Default | Long-term storage |
| `configForDistribution()` | 19 | ❌ | Default | Package releases |
| `configWithLevel(n)` | n | ❌ | Default | Custom level |
| `configWithLevelAndLdm(n)` | n | ✅ | Default | Custom + LDM |

### ConfigBuilder Pattern

Build custom configurations with the fluent builder API:

```zig
var builder = zigx.ConfigBuilder.init();
const cfg = builder
    .compressionLevel(.best)
    .adaptive(true)
    .longDistanceMatching(true)
    .windowLog(25)  // 32MB window
    .threads(4)
    .verbose(true)
    .build();
```

#### ConfigBuilder Methods

| Method | Description |
|--------|-------------|
| `compressionLevel(level)` | Set compression level |
| `customLevel(n)` | Set custom level (1-22) |
| `compressionEnabled(bool)` | Enable/disable compression |
| `adaptive(bool)` | Enable adaptive compression |
| `longDistanceMatching(bool)` | Enable LDM |
| `windowLog(?u5)` | Set window size (10-31) |
| `excludePatterns([]const []const u8)` | Set exclude patterns |
| `includeHidden(bool)` | Include hidden files |
| `threads(u8)` | Set thread count (0=auto) |
| `verbose(bool)` | Enable verbose output |
| `build()` | Build final Config |

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
