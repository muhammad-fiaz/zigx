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
| **Text Space Saved** | ~18% | Source code |
| **Average Space Saved** | ~18% | All test data |
| **Compression Levels** | 4 | `.none`, `.fast`, `.default`, `.best` |

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

### ZIGX Compression Levels

| Level | Archive | Saved % | Bundle | Unbundle | Notes |
|:------|--------:|--------:|-------:|---------:|:------|
| | *(lower=better)* | *(higher=better)* | *(MB/s)* | *(MB/s)* | |
| `.none` | ~65 KB | ~0% | Fast | Fast | Store mode (no compression) |
| **`.fast`** | ~53 KB | ~18% | Fast | Fast | Speed optimized |
| **`.default`** | ~53 KB | ~18% | Balanced | Fast | **Recommended for most use** |
| **`.best`** | ~53 KB | ~18% | Slower | Fast | Maximum compression |

### File Type Performance

| Benchmark | Archive | Saved % | Bundle | Unbundle | Notes |
|:----------|--------:|--------:|-------:|---------:|:------|
| | *(lower=better)* | *(higher=better)* | *(MB/s)* | *(MB/s)* | |
| Text data (64KB) | ~53 KB | ~18% | Good | Fast | Source code |
| Binary data (64KB) | ~65 KB | ~0% | Good | Fast | Executables |
| **Repetitive data (64KB)** | **~100 B** | **~99%** | Good | Fast | **Log files** |
| Random data (64KB) | ~65 KB | ~0% | Good | Fast | Encrypted |
| Mixed data (64KB) | ~65 KB | ~0% | Good | Fast | Archives |

### Scalability Test

| File Size | Archive | Saved % | Bundle | Unbundle | Notes |
|:----------|--------:|--------:|-------:|---------:|:------|
| | *(lower=better)* | *(higher=better)* | *(MB/s)* | *(MB/s)* | |
| 1 KB | ~1 KB | ~13% | - | - | Config files |
| 64 KB | ~53 KB | ~18% | Good | Good | Source files |
| 1 MB | ~852 KB | ~18% | Good | Good | Large source |
| 4 MB | ~3.4 MB | ~18% | Good | Good | Stress test |

## ZIGX Features

| Feature | ZIGX |
|:--------|:----:|
| **Format** | Full archive (.zigx) |
| **Compression** | Zstandard (zstd) |
| **Compression Levels** | `.none`, `.fast`, `.default`, `.best` |
| **Best Space Saved** | ✅ ~99% (repetitive data) |
| **Average Space Saved** | ~18% |
| **SHA-256 Checksum** | ✅ |
| **CRC32 Verification** | ✅ |
| **File Metadata** | ✅ |
| **Versioned Format** | ✅ |
| **Archive Validation** | ✅ Auto |
| **Multi-file Archive** | ✅ |

## Key Findings

### ZIGX Strengths

1. **Excellent on Repetitive Data** - Achieves **~99% space saved** on log files!
2. **Simple Compression Levels** - 4 easy-to-choose levels: `.none`, `.fast`, `.default`, `.best`
3. **Fast Unbundling** - Fast archive extraction on all levels
4. **Consistent Compression** - All compression levels achieve similar ratios on text
5. **Security Features** - SHA-256 checksums and CRC32 verification built-in
6. **Archive Format** - Supports multiple files, metadata, and versioning
7. **Scalable** - Works efficiently from 1KB to 4MB+ files

### Compression Levels Guide

| Level | Best For | Trade-off |
|:------|:---------|:----------|
| **`.none`** | No compression needed | Maximum speed, no size reduction |
| **`.fast`** | Speed priority | Fast bundling with good compression |
| **`.default`** | General use | Balanced speed and compression |
| **`.best`** | Maximum compression | Slower bundling, best size reduction |

## When to Use ZIGX

| Use Case | Recommended Level | Reason |
|:---------|:------------------|:-------|
| **Log file archival** | `.default` | ~99% space saved on repetitive data |
| **Maximum speed** | `.fast` | Fast bundling and unbundling |
| **Maximum compression** | `.best` | Best space savings |
| **No compression** | `.none` | Store mode for pre-compressed files |
| **Multi-file bundles** | `.default` | Built-in archive support |
| **Zig project distribution** | `.default` | Native format with versioning |
| **Large file processing** | `.fast` or `.default` | Good balance of speed and compression |

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

---

*Generated by ZIGX Benchmark Suite - Tests full archive format (bundle/unbundle)*
