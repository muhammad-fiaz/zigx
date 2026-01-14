# ZIGX Compression Benchmarks

This page provides detailed benchmark results for the ZIGX compression format.

## Quick Overview

| Metric | Value | Notes |
|:-------|------:|:------|
| **Best Compressed %** | 99.9% | Repetitive data (log files) |
| **Text Compressed %** | 18.6% | Source code |
| **Average Compressed %** | 18.7% | All test data |
| **Compression Speed** | 87+ MB/s | Average across all levels |
| **Decompression Speed** | 135+ MB/s | Average across all levels |
| **Compression Levels** | 0-22 | 23 levels available |

> **Note:** Higher compressed % = better compression. Lower output size = better. Higher speed = better.

## Benchmark Results

All benchmarks run on 64KB data with 5 iterations for accuracy.

### All Compression Levels (zstd 0-22)

| Level | Output | Compressed % | Comp Speed | Decomp Speed | Notes |
|:------|-------:|-------------:|----------:|-------------:|:------|
| | *(lower=better)* | *(higher=better)* | *(higher=better)* | *(higher=better)* | |
| Level 0 | 65,554 B | -0.0% | 161 MB/s | 157 MB/s | zstd 0 (store) |
| Level 1 | 53,314 B | 18.6% | 143 MB/s | 136 MB/s | zstd 1 (fast) |
| Level 2 | 53,314 B | 18.6% | 147 MB/s | 154 MB/s | zstd 2 |
| **Level 3** | 53,314 B | 18.6% | 131 MB/s | 145 MB/s | **zstd 3 (default)** |
| Level 4 | 53,314 B | 18.6% | 78 MB/s | 130 MB/s | zstd 4 |
| Level 5 | 53,314 B | 18.6% | 109 MB/s | 135 MB/s | zstd 5 |
| Level 6 | 53,314 B | 18.6% | 110 MB/s | 131 MB/s | zstd 6 |
| Level 7 | 53,314 B | 18.6% | 107 MB/s | 114 MB/s | zstd 7 |
| Level 8 | 53,314 B | 18.6% | 98 MB/s | 125 MB/s | zstd 8 |
| Level 9 | 53,314 B | 18.6% | 97 MB/s | 118 MB/s | zstd 9 |
| Level 10 | 53,314 B | 18.6% | 118 MB/s | 140 MB/s | zstd 10 |
| Level 11 | 53,314 B | 18.6% | 59 MB/s | 127 MB/s | zstd 11 |
| Level 12 | 53,314 B | 18.6% | 63 MB/s | 125 MB/s | zstd 12 |
| Level 13 | 53,337 B | 18.6% | 14 MB/s | 118 MB/s | zstd 13 |
| Level 14 | 53,400 B | 18.5% | 19 MB/s | 133 MB/s | zstd 14 |
| Level 15 | 53,400 B | 18.5% | 24 MB/s | 139 MB/s | zstd 15 |
| Level 16 | 53,356 B | 18.6% | 23 MB/s | 129 MB/s | zstd 16 |
| Level 17 | 53,356 B | 18.6% | 24 MB/s | 132 MB/s | zstd 17 |
| Level 18 | 53,356 B | 18.6% | 24 MB/s | 126 MB/s | zstd 18 |
| **Level 19** | 53,357 B | 18.6% | 15 MB/s | 146 MB/s | **zstd 19 (best)** |
| Level 20 | 53,357 B | 18.6% | 16 MB/s | 146 MB/s | zstd 20 |
| Level 21 | 53,357 B | 18.6% | 16 MB/s | 145 MB/s | zstd 21 |
| Level 22 | 53,357 B | 18.6% | 16 MB/s | 132 MB/s | zstd 22 (max) |

### File Type Performance

| Benchmark | Output | Compressed % | Comp Speed | Decomp Speed | Notes |
|:----------|-------:|-------------:|----------:|-------------:|:------|
| | *(lower=better)* | *(higher=better)* | *(higher=better)* | *(higher=better)* | |
| Text data (64KB) | 53,314 B | 18.6% | 126 MB/s | 135 MB/s | Source code |
| Binary data (64KB) | 65,564 B | -0.0% | 152 MB/s | 163 MB/s | Executables |
| **Repetitive data (64KB)** | **97 B** | **99.9%** | 155 MB/s | 143 MB/s | Log files |
| Random data (64KB) | 65,564 B | -0.0% | 139 MB/s | 144 MB/s | Encrypted |
| Mixed data (64KB) | 65,564 B | -0.0% | 150 MB/s | 164 MB/s | Archives |

### Scalability Test

| File Size | Output | Compressed % | Comp Speed | Decomp Speed | Notes |
|:----------|-------:|-------------:|----------:|-------------:|:------|
| | *(lower=better)* | *(higher=better)* | *(higher=better)* | *(higher=better)* | |
| 1 KB | 891 B | 13.0% | 56 MB/s | 80 MB/s | Config files |
| 64 KB | 53,314 B | 18.6% | 118 MB/s | 124 MB/s | Source files |
| 1 MB | 852,610 B | 18.7% | 128 MB/s | 136 MB/s | Large source |
| 4 MB | 3,410,254 B | 18.7% | 141 MB/s | 147 MB/s | Stress test |

## ZIGX Features

| Feature | ZIGX |
|:--------|:----:|
| **Algorithm** | Zstandard (zstd) |
| **Compression Levels** | 0-22 (23 levels) |
| **Best Compressed %** | ✅ 99.9% (repetitive data) |
| **Average Compressed %** | 18.7% |
| **Fast Compression** | ✅ 87+ MB/s average |
| **Fast Decompression** | ✅ 135+ MB/s average |
| **SHA-256 Checksum** | ✅ |
| **CRC32 Verification** | ✅ |
| **File Metadata** | ✅ |
| **Versioned Format** | ✅ |
| **Archive Validation** | ✅ Auto |
| **Multi-file Archive** | ✅ |

## Key Findings

### ZIGX Strengths

1. **Excellent on Repetitive Data** - Achieves **99.9% compressed** on log files!
2. **23 Compression Levels** - Fine-grained control from 0 (store) to 22 (max)
3. **Fast Decompression** - 135+ MB/s average decompression speed
4. **Consistent Compression** - Levels 1-22 achieve ~18.6% compressed on text
5. **Security Features** - SHA-256 checksums and CRC32 verification built-in
6. **Archive Format** - Supports multiple files, metadata, and versioning
7. **Scalable** - Speed scales from 1KB to 4MB+ files

### Compression Levels

| Level | Best For | Trade-off |
|:------|:---------|:----------|
| **0 (Store)** | No compression | Maximum speed (161 MB/s) |
| **1 (Fast)** | Speed priority | 143 MB/s, 18.6% compressed |
| **3 (Default)** | Balanced | 131 MB/s, 18.6% compressed |
| **5** | Optimal speed/ratio | 109 MB/s, 18.6% compressed |
| **10** | Higher compression | 118 MB/s, 18.6% compressed |
| **19 (Best)** | Maximum compression | 15 MB/s, 18.6% compressed |
| **22 (Max)** | Ultra compression | 16 MB/s, 18.6% compressed |

## When to Use ZIGX

| Use Case | Recommended Level | Reason |
|:---------|:------------------|:-------|
| **Log file archival** | Level 3 (default) | 99.9% compressed on repetitive data |
| **Maximum speed** | Level 1-2 | 143-147 MB/s compression |
| **Maximum compression** | Level 19-22 | Best compressed % for small files |
| **No compression** | Level 0 | Store mode at 161 MB/s |
| **Multi-file bundles** | Level 3 (default) | Built-in archive support |
| **Zig project distribution** | Level 3 (default) | Native format with versioning |
| **Large file processing** | Level 1-5 | Fast with good compression |

## Run Your Own Benchmarks

```bash
# Clone and build
git clone https://github.com/muhammad-fiaz/zigx.git
cd zigx

# Run benchmarks
zig build bench

# Results saved to benchmark-results.md
```

## Technical Notes

- **Test Data**: Generated text data simulating source code
- **Iterations**: 5 iterations per test for accuracy
- **Timing**: Using `std.time.Timer` for nanosecond precision
- **Algorithm**: Zstandard (zstd) via zstd.zig C bindings
- **Platform**: Tested on Windows x86_64, cross-platform via Zig build system

---

*Generated from ZIGX Benchmark Suite - See [benchmark-results.md](/benchmark-results.md) for full data*
