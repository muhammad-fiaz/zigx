# ZIGX Archive Format Benchmarks

This page provides detailed benchmark results for the **ZIGX archive format** (.zigx files).

## What's Being Tested

These benchmarks test the **complete ZIGX archive format**, including:

- `zigx.bundle()` - Create `.zigx` archives with header, metadata, checksums, and compressed payload
- `zigx.unbundle()` - Extract `.zigx` archives with validation and file restoration

The times include all ZIGX overhead: header generation, SHA-256 checksums, metadata handling, file I/O, and Zstandard compression.

## Quick Overview

| Metric | Value | Notes |
|:-------|------:|:------|
| **Best Space Saved** | ~99% | Repetitive data (log files) |
| **Real Project Saved** | ~82% | Source code (self-bundle) |
| **Average Space Saved** | ~25% | All test data |
| **Preset Levels** | 6 | `.none`, `.fast`, `.default`, `.balanced`, `.best`, `.ultra` |
| **Custom Levels** | 1-22 | Full zstd range via `CompressionLevel.custom(n)` |

> **Note:** Higher saved % = better compression. Lower archive size = better.

## ZIGX Archive Format

| Component | Description |
|:----------|:------------|
| **Header** | 128-byte binary header with magic, version, flags, checksums |
| **Metadata** | Variable key-value pairs (author, version, etc.) |
| **Checksums** | SHA-256 hash for each file in archive |
| **Payload** | Zstandard compressed file data with CRC32 |

## Benchmark Results

All benchmarks run on test data with 5 iterations for accuracy.

### Self-Bundle (Real Project)

Performance when bundling actual ZIGX project source files:

| Level | Original | Archive | Saved % | Bundle | Unbundle |
|:------|----------:|--------:|--------:|-------:|---------:|
| `.fast` | 212 KB | 52 KB | 75.5% | 11.5 MB/s | 22.4 MB/s |
| `.default` | 212 KB | 48 KB | 77.1% | 13.3 MB/s | 28.5 MB/s |
| `.best` | 212 KB | 39 KB | **81.7%** | 2.2 MB/s | 22.8 MB/s |

### ZIGX Compression Levels

| Level | zstd Level | Archive | Saved % | Bundle | Unbundle | Notes |
|:------|:----------:|--------:|--------:|-------:|---------:|:------|
| | | *(lower=better)* | *(higher=better)* | *(MB/s)* | *(MB/s)* | |
| `.none` | 0 | ~65 KB | ~0% | 5.8 | 41.2 | Store mode (no compression) |
| **`.fast`** | 1 | ~53 KB | ~18% | 7.1 | 44.4 | Speed optimized |
| **`.default`** | 3 | ~53 KB | ~18% | 6.9 | 42.5 | **Recommended for most use** |
| **`.balanced`** | 6 | ~53 KB | ~18% | 7.8 | 43.5 | Good speed/ratio balance |
| `custom(9)` | 9 | ~53 KB | ~18% | 6.6 | 38.2 | Custom level example |
| `custom(12)` | 12 | ~53 KB | ~18% | 6.8 | 43.5 | Custom level example |
| `custom(15)` | 15 | ~53 KB | ~18% | 4.3 | 38.4 | High compression |
| **`.best`** | 19 | ~53 KB | ~18% | 4.6 | 38.4 | High compression |
| **`.ultra`** | 22 | ~53 KB | ~18% | 4.7 | 43.2 | Maximum compression |

### Custom Compression Levels (1-22)

ZIGX supports all 22 zstd compression levels via `CompressionLevel.custom(n)`:

```zig
const zigx = @import("zigx");

// Use any zstd level from 1-22
const level_10 = zigx.CompressionLevel.custom(10);
const level_15 = zigx.CompressionLevel.custom(15);

// Using preset configurations
const config = zigx.configWithLevel(15);  // Config with custom level
const config_ldm = zigx.configWithLevelAndLdm(18);  // Level 18 + Long Distance Matching
```



### File Type Performance

| Benchmark | Archive | Saved % | Bundle | Unbundle | Notes |
|:----------|--------:|--------:|-------:|---------:|:------|
| | *(lower=better)* | *(higher=better)* | *(MB/s)* | *(MB/s)* | |
| Text data (64KB) | ~53 KB | ~18% | 5.9 | 40.9 | Source code |
| Binary data (64KB) | ~65 KB | ~0% | 6.9 | 46.3 | Executables |
| **Repetitive data (64KB)** | **~488 B** | **~99%** | 29.5 | 44.0 | **Log files** |
| Random data (64KB) | ~65 KB | ~0% | 6.2 | 38.6 | Encrypted |
| Mixed data (64KB) | ~65 KB | ~0% | 7.1 | 48.1 | Archives |

### Scalability Test

| File Size | Archive | Saved % | Bundle | Unbundle | Notes |
|:----------|--------:|--------:|-------:|---------:|:------|
| | *(lower=better)* | *(higher=better)* | *(MB/s)* | *(MB/s)* | |
| 1 KB | ~1.3 KB | -25% | 0.7 | 1.2 | Config files (header overhead) |
| 64 KB | ~53 KB | ~18% | 8.0 | 43.8 | Source files |
| 1 MB | ~853 KB | ~19% | 53.3 | 97.4 | Large source |
| 4 MB | ~3.4 MB | ~19% | 72.4 | 100.9 | Stress test |

## ZIGX Features

| Feature | ZIGX |
|:--------|:----:|
| **Format** | Full archive (.zigx) |
| **Compression** | Zstandard (zstd) |
| **Preset Levels** | `.none`, `.fast`, `.default`, `.balanced`, `.best`, `.ultra` |
| **Custom Levels** | 1-22 (full zstd range) |
| **Best Space Saved** | ✅ ~99% (repetitive data) |
| **Real Project Saved** | ✅ ~82% (source code) |
| **Average Space Saved** | ~25% |
| **SHA-256 Checksum** | ✅ |
| **CRC32 Verification** | ✅ |
| **File Metadata** | ✅ |
| **Versioned Format** | ✅ |
| **Archive Validation** | ✅ Auto |
| **Multi-file Archive** | ✅ |
| **Progress Callbacks** | ✅ |
| **Adaptive Compression** | ✅ |

## Key Findings

### ZIGX Strengths

1. **Excellent on Repetitive Data** - Achieves **~99% space saved** on log files!
2. **Simple Compression Levels** - 6 easy-to-choose levels: `.none`, `.fast`, `.default`, `.balanced`, `.best`, `.ultra`
3. **Fast Unbundling** - Fast archive extraction on all levels
4. **Consistent Compression** - All compression levels achieve similar ratios on text
5. **Security Features** - SHA-256 checksums and CRC32 verification built-in
6. **Archive Format** - Supports multiple files, metadata, and versioning
7. **Scalable** - Works efficiently from 1KB to 4MB+ files

### Compression Levels Guide

| Level | zstd | Best For | Trade-off |
|:------|:----:|:---------|:----------|
| **`.none`** | 0 | No compression needed | Maximum speed, no size reduction |
| **`.fast`** | 1 | Speed priority | Fast bundling with good compression |
| **`.default`** | 3 | General use | Good speed and compression |
| **`.balanced`** | 6 | Balanced workloads | Good balance of speed and ratio |
| **`.best`** | 19 | High compression | Slower bundling, best size reduction |
| **`.ultra`** | 22 | Maximum compression | Slowest, maximum size reduction |
| **`custom(n)`** | 1-22 | Fine-tuned control | Choose exact zstd level |

## Advanced Features

### Adaptive Compression

ZIGX can automatically detect content type and select optimal compression settings:

```zig
const zigx = @import("zigx");

// Auto-detect content and use optimal compression
const compressed = try zigx.compressDataAdaptive(data, allocator);

// Or analyze data first
const analysis = zigx.analyzeCompressibility(data);
std.debug.print("Recommended level: {s}\n", .{analysis.recommended_level.name()});
```

### Content Type Detection

| Content Type | Detection Method | Recommended Level |
|:-------------|:-----------------|:------------------|
| Source code | File patterns, keywords | `.best` |
| Text/Config | Byte analysis | `.best` |
| JSON/XML | Magic bytes | `.best` |
| Images | Magic bytes (PNG, JPEG, etc.) | `.fast` (already compressed) |
| Archives | Magic bytes (ZIP, GZIP, etc.) | `.none` (already compressed) |
| Binary/Executable | ELF/PE headers | `.default` |

### Dictionary Compression

For compressing many similar files (e.g., log files, config files):

```zig
// Train dictionary from sample data
var dict = try zigx.Dictionary.train(&samples, 32768, allocator);
defer dict.deinit();

// Use dictionary for better compression
const options = zigx.AdvancedOptions{
    .level = .best,
    .dictionary = &dict,
};
const compressed = try zigx.compressDataWithOptions(data, allocator, options);
```

### Long-Distance Matching

For large files with repeated patterns far apart:

```zig
const options = zigx.AdvancedOptions{
    .level = .best,
    .long_distance_matching = true,
    .window_log = 25, // 32MB window
};
```

### Progress Tracking

Track bundling progress for large archives:

```zig
fn progressCallback(info: zigx.ProgressInfo, context: ?*anyopaque) void {
    std.debug.print("\rProgress: {d:.1}% ({s})", .{
        info.getPercent(),
        info.current_file orelse "...",
    });
}

var opts = zigx.CompressOptions{
    .allocator = allocator,
    .include = &.{"src", "docs"},
    .progress_callback = progressCallback,
};
```

## Preset Configurations

| Preset | Use Case | Settings |
|:-------|:---------|:---------|
| `configFast()` | Speed priority | Level 1 |
| `configBalanced()` | General use | Level 6 |
| `configBest()` | Size priority | Level 19 |
| `configUltra()` | Maximum compression | Level 22 + LDM |
| `configWithLevel(n)` | Custom level | Level n (1-22) |
| `configWithLevelAndLdm(n)` | Custom + LDM | Level n + Long Distance Matching |
| `configAdaptive()` | Auto-detect content | Varies by content |
| `configForLargeFiles()` | Large files | Level 6 + LDM + 32MB window |
| `configForArchiving()` | Preserve metadata | Level 19 + timestamps |
| `configForDistribution()` | Small & fast extract | Level 19 + checksums |

## When to Use ZIGX

| Use Case | Recommended Level | Reason |
|:---------|:------------------|:-------|
| **Log file archival** | `.default` | ~99% space saved on repetitive data |
| **Maximum speed** | `.fast` | Fast bundling and unbundling |
| **Maximum compression** | `.ultra` | Best space savings |
| **Custom tuning** | `custom(n)` | Fine-grained control over speed/ratio |
| **No compression** | `.none` | Store mode for pre-compressed files |
| **Multi-file bundles** | `.default` | Built-in archive support |
| **Zig project distribution** | `.default` | Native format with versioning |
| **Large file processing** | `.fast` or `.default` | Good balance of speed and compression |
| **Similar files** | Dictionary + `.best` | Use dictionary compression |
| **Real-time processing** | `custom(1-3)` | Fastest compression levels |
| **Archive distribution** | `custom(15-19)` | Good ratio for sharing |

## Run Your Own Benchmarks

```bash
# Clone and build
git clone https://github.com/muhammad-fiaz/zigx.git
cd zigx

# Run benchmarks
zig build bench

# Results saved to docs/benchmark-results.md
```

## Technical Notes

- **What's Tested**: Full ZIGX archive format (bundle/unbundle), not raw compression
- **Test Data**: Generated data simulating various file types
- **Iterations**: 5 iterations per test for accuracy
- **Timing**: Using `std.time.Timer` for nanosecond precision
- **Compression**: Zstandard (zstd) algorithm inside ZIGX payload
- **Platform**: Cross-platform via Zig build system
- **Format Version**: 1
- **Compression Version**: 1

---

*Generated by ZIGX Benchmark Suite - Tests full archive format (bundle/unbundle)*
