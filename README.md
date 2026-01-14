<div align="center">
<img width="500" height="500" alt="zigx logo" src="https://github.com/user-attachments/assets/828b304b-2a21-4edd-93a3-6bd184e1dadf" />

<a href="https://muhammad-fiaz.github.io/zigx/"><img src="https://img.shields.io/badge/docs-muhammad--fiaz.github.io-blue" alt="Documentation"></a>
<a href="https://ziglang.org/"><img src="https://img.shields.io/badge/Zig-0.15.2-orange.svg?logo=zig" alt="Zig Version"></a>
<a href="https://github.com/muhammad-fiaz/zigx"><img src="https://img.shields.io/github/stars/muhammad-fiaz/zigx" alt="GitHub stars"></a>
<a href="https://github.com/muhammad-fiaz/zigx/issues"><img src="https://img.shields.io/github/issues/muhammad-fiaz/zigx" alt="GitHub issues"></a>
<a href="https://github.com/muhammad-fiaz/zigx/pulls"><img src="https://img.shields.io/github/issues-pr/muhammad-fiaz/zigx" alt="GitHub pull requests"></a>
<a href="https://github.com/muhammad-fiaz/zigx"><img src="https://img.shields.io/github/last-commit/muhammad-fiaz/zigx" alt="GitHub last commit"></a>
<a href="https://github.com/muhammad-fiaz/zigx"><img src="https://img.shields.io/github/license/muhammad-fiaz/zigx" alt="License"></a>
<a href="https://github.com/muhammad-fiaz/zigx/actions/workflows/ci.yml"><img src="https://github.com/muhammad-fiaz/zigx/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
<img src="https://img.shields.io/badge/platforms-linux%20%7C%20windows%20%7C%20macos-blue" alt="Supported Platforms">
<a href="https://github.com/muhammad-fiaz/zigx/actions/workflows/release.yml"><img src="https://github.com/muhammad-fiaz/zigx/actions/workflows/release.yml/badge.svg" alt="Release"></a>
<a href="https://github.com/muhammad-fiaz/zigx/releases/latest"><img src="https://img.shields.io/github/v/release/muhammad-fiaz/zigx?label=Latest%20Release&style=flat-square" alt="Latest Release"></a>
<a href="https://pay.muhammadfiaz.com"><img src="https://img.shields.io/badge/Sponsor-pay.muhammadfiaz.com-ff69b4?style=flat&logo=heart" alt="Sponsor"></a>
<a href="https://github.com/sponsors/muhammad-fiaz"><img src="https://img.shields.io/badge/Sponsor-pink?style=social&logo=github" alt="GitHub Sponsors"></a>
<a href="https://hits.sh/github.com/muhammad-fiaz/zigx/"><img alt="Hits" src="https://hits.sh/github.com/muhammad-fiaz/zigx.svg"/></a>

<p><em>Fast and light-weight compression file format for Zig.</em></p>

<b><a href="https://muhammad-fiaz.github.io/zigx/">Documentation</a> |
<a href="https://muhammad-fiaz.github.io/zigx/api/">API Reference</a> |
<a href="https://muhammad-fiaz.github.io/zigx/guide/getting-started">Quick Start</a> |
<a href="docs/contributing.md">Contributing</a></b>

</div>

Fast and light-weight compression file format for Zig using **Zstandard (zstd)** compression for optimal compression ratios and speed.

> [!NOTE]
> ZIGX introduces a new archive format (.zigx) designed specifically for Zig projects. It uses industry-leading Zstandard compression with modern features like versioned format, SHA-256 checksums, and excellent compression ratios (up to 99.9% on repetitive data, ~80% space savings on typical data).

⭐ **If you find `zigx` useful, please give it a star!**

## Features

- **Zstandard Compression** - Industry-leading zstd algorithm via [zstd.zig](https://github.com/muhammad-fiaz/zstd.zig) bindings
- **Blazing Fast** - 130+ MB/s compression, 140+ MB/s decompression
- **Excellent Compression** - 99.9% saved on repetitive data, ~18% saved on text
- **Versioned Format** - Format v1 with Zstandard (zstd) compression for compatibility
- **Multiple Levels** - ULTRA (zstd 22), BEST (zstd 19), BALANCED (zstd 6), DEFAULT (zstd 3), FAST (zstd 1), and STORE modes
- **Progress Callbacks** - Track bundling and extraction progress for large archives
- **Security** - SHA-256 checksums, CRC32 payload verification, and Cryptographic Signing
- **Advanced Management** - Update metadata, file adding/removing, and repair corrupted archives in-place
- **Include/Exclude** - Pattern matching for files and directories
- **Rich API** - Simple client-side access to metadata and checksums
- **Cross-Platform** - Works on Linux, Windows, macOS via Zig build system
- **128-byte Header** - Compact binary format

## Installation


Install the latest stable release (v0.0.1):

```bash
zig fetch --save https://github.com/muhammad-fiaz/zigx/archive/refs/tags/v0.0.1.tar.gz
```

### Nightly Installation

Install the latest development version:

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/zigx
```


Then in `build.zig`:

```zig
const zigx = b.dependency("zigx", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("zigx", zigx.module("zigx"));
```

## Quick Start

### Create Archive

```zig
const zigx = @import("zigx");

const result = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{ "src", "build.zig", "README.md" },
    .exclude = &.{ "*.tmp", ".git", "zig-cache" },
    .output_path = "bundle.zigx",
    .level = .best,
});

std.debug.print("Created: {d} files, {d} bytes\n", .{
    result.file_count,
    result.archive_size,
});
```

### Get Archive Info

```zig
var info = try zigx.getArchiveInfo("bundle.zigx", allocator);
defer info.deinit();

std.debug.print("Format: v{d}, Compression: v{d}\n", .{
    info.format_version,
    info.compression_version,
});
std.debug.print("Files: {d}, Saved: {d:.1}%\n", .{
    info.file_count,
    info.getSavedPercent(),
});
```

### Extract Archive

```zig
try zigx.unbundle(.{
    .archive_path = "bundle.zigx",
    .output_dir = "extracted",
    .allocator = allocator,
});
```

## CLI Example

```bash
# Run tests
zig build test

# Compare compression levels
zig build run-example

# Create archive
zig build run-example -- bundle

# Extract archive
zig build run-example -- unbundle archive.zigx output/

# Show archive info
zig build run-example -- info archive.zigx

# List files
zig build run-example -- list archive.zigx

# Help
zig build run-example -- help
```

## API

### Functions

| Function | Alias | Description |
|----------|-------|-------------|
| `compress()` | `bundle()` | Create archive |
| `extract()` | `unbundle()` | Extract archive |
| `extractWithResult()` | `unbundleWithResult()` | Extract with details |
| `validate()` | `verify()` | Validate archive |
| `validateDetailed()` | `verifyDetailed()` | Detailed validation |
| `listFiles()` | `list()` | List files |
| `isValidArchive()` | `isValid()` | Quick validity check |
| `getArchiveInfo()` | - | Get archive metadata |
| `detectCorruption()` | - | Detect corruption type |

### Compression Levels

| Level | zstd Level | Description | Typical Ratio |
|-------|------------|-------------|---------------|
| `.ultra` | 22 | Maximum compression | 17-22% |
| `.best` | 19 | High compression | 19-25% |
| `.balanced` | 6 | Good balance | 21-26% |
| `.default` | 3 | Balanced speed/ratio | 21-28% |
| `.fast` | 1 | Speed optimized | 25-33% |
| `.none` | - | No compression | 100%+ |
| `custom(n)` | 1-22 | Custom zstd level | Varies |

### Custom Compression Levels

Use any zstd level from 1-22 for fine-grained control:

```zig
const zigx = @import("zigx");

// Custom level using CompressionLevel.custom()
const result = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{"src"},
    .output_path = "bundle.zigx",
    .level = zigx.CompressionLevel.custom(15),  // zstd level 15
});

// Or use preset configurations
const config = zigx.configWithLevel(12);  // Config with level 12
const config_ldm = zigx.configWithLevelAndLdm(18);  // Level 18 + Long Distance Matching
```

### Level Aliases

```zig
CompressionLevel.turbo   // Same as .fast
CompressionLevel.maximum // Same as .ultra
```

### Progress Callbacks

Track progress for large archives with detailed events:

```zig
// Bundle progress callback
fn onProgress(info: zigx.ProgressInfo, ctx: ?*anyopaque) void {
    _ = ctx;
    switch (info.event) {
        .scanning => std.debug.print("Scanning...\n", .{}),
        .reading_file => {
            if (info.current_file) |file| {
                std.debug.print("\r[{d}/{d}] {s}", .{
                    info.files_processed, info.total_files, file,
                });
            }
        },
        .compressing => {
            std.debug.print("\rCompressing: {d:.1}%", .{info.getPercent()});
        },
        .finalizing => std.debug.print("\nFinalizing...", .{}),
        else => {},
    }
}

// Use in bundle()
const result = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{"src"},
    .output_path = "bundle.zigx",
    .progress_callback = onProgress,
});

// Extract progress callback
fn onExtractProgress(info: zigx.ExtractProgressInfo, ctx: ?*anyopaque) void {
    _ = ctx;
    switch (info.event) {
        .extracting_file => {
            std.debug.print("\r[{d}/{d}] {s}", .{
                info.files_extracted, info.total_files,
                info.current_file orelse "...",
            });
        },
        .completed => std.debug.print("\nDone!\n", .{}),
        else => {},
    }
}

// Use in unbundle()
try zigx.unbundle(.{
    .archive_path = "bundle.zigx",
    .output_dir = "output",
    .allocator = allocator,
    .progress_callback = onExtractProgress,
});
```

### OptionsBuilder (Fluent API)

```zig
var builder = zigx.OptionsBuilder.init(allocator);
const opts = builder
    .include(&.{ "src", "build.zig" })
    .exclude(&.{ "*.tmp", "zig-cache" })
    .outputPath("project.zigx")
    .ultra()  // Or .best(), .fast(), .balanced(), .customLevel(15)
    .progress(onProgress, null)
    .build();

const result = try zigx.bundle(opts);
```

### Preset Configurations

```zig
// Quick presets (returns CompressionConfig)
const fast_config = zigx.configFast();        // Level 1
const balanced_config = zigx.configBalanced(); // Level 6
const best_config = zigx.configBest();         // Level 19
const ultra_config = zigx.configUltra();       // Level 22 + LDM

// Custom level presets
const level_config = zigx.configWithLevel(15);          // Any level 1-22
const ldm_config = zigx.configWithLevelAndLdm(18);      // Level + LDM

// Scenario presets
const archival = zigx.configForArchiving();      // Best, preserves metadata
const large_files = zigx.configForLargeFiles();  // Level 6 + LDM + 32MB window
const distribution = zigx.configForDistribution(); // Best, optimized for packages

// ConfigBuilder for custom configs
var builder = zigx.ConfigBuilder.init();
const custom_cfg = builder
    .compressionLevel(.best)
    .adaptive(true)
    .longDistanceMatching(true)
    .build();
```

## Format Specification

```
Header (128 bytes)
  Magic: ZIGX
  Format Version: 1
  Payload Hash: SHA-256

Metadata (variable)
  Key-value pairs

Checksums (variable)
  File paths + SHA-256 hashes

Payload (variable)
  Magic: ZXCM
  Compression Version: 1 (Zstandard)
  Zstd compressed data with CRC32
```

## Benchmark Results

ZIGX archive format performance using `zigx.bundle()` and `zigx.unbundle()` (from `zig build bench`):

> [!Note] 
> These benchmarks test the **full ZIGX archive format** including header generation, SHA-256 checksums, metadata handling, file I/O, and Zstandard compression - not just raw compression.

### Self-Bundle (Real Project)

Performance when bundling actual ZIGX project source files:

| Level | Original | Archive | Saved % | Bundle | Unbundle |
|:------|----------:|--------:|--------:|-------:|---------:|
| `.fast` | 212 KB | 52 KB | 75.5% | 11.5 MB/s | 22.4 MB/s |
| `.default` | 212 KB | 48 KB | 77.1% | 13.3 MB/s | 28.5 MB/s |
| `.best` | 212 KB | 39 KB | **81.7%** | 2.2 MB/s | 22.8 MB/s |

### ZIGX Compression Levels

| Level | zstd | Archive | Saved % | Bundle | Unbundle | Notes |
|:------|:----:|--------:|--------:|-------:|---------:|:------|
| | | *(lower=better)* | *(higher=better)* | *(MB/s)* | *(MB/s)* | |
| `.none` | 0 | ~65 KB | ~0% | 5.8 | 41.2 | Store mode |
| **`.fast`** | 1 | ~53 KB | ~18% | 7.1 | 44.4 | Speed optimized |
| **`.default`** | 3 | ~53 KB | ~18% | 6.9 | 42.5 | **Recommended** |
| **`.balanced`** | 6 | ~53 KB | ~18% | 7.8 | 43.5 | Balanced |
| `custom(9)` | 9 | ~53 KB | ~18% | 6.6 | 38.2 | Custom |
| `custom(12)` | 12 | ~53 KB | ~18% | 6.8 | 43.5 | Custom |
| `custom(15)` | 15 | ~53 KB | ~18% | 4.3 | 38.4 | Custom |
| **`.best`** | 19 | ~53 KB | ~18% | 4.6 | 38.4 | High compression |
| **`.ultra`** | 22 | ~53 KB | ~18% | 4.7 | 43.2 | Maximum |

### File Type Performance

| Data Type | Archive | Saved % | Bundle | Unbundle | Notes |
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

### Key Features

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
| **Multi-file Archive** | ✅ |
| **Archive Validation** | ✅ Auto |
| **Progress Callbacks** | ✅ |

> [!NOTE]
> **ZIGX excels on repetitive data** - Achieves **~99% space saved** on log files, configs, etc. Higher saved % = better compression. Lower archive size = better.
>
> Run `zig build bench` to generate fresh benchmark results on your system.

Run benchmarks yourself:
```bash
zig build bench
```


## Documentation

Full documentation: [muhammad-fiaz.github.io/zigx](https://muhammad-fiaz.github.io/zigx)

- [Getting Started](https://muhammad-fiaz.github.io/zigx/guide/getting-started)
- [API Reference](https://muhammad-fiaz.github.io/zigx/api/)
- [Examples](https://muhammad-fiaz.github.io/zigx/examples/)

## Contributing

See [CONTRIBUTING.md](docs/contributing.md).

## Security

See [SECURITY.md](SECURITY.md).

## License

this project is licensed under the Apache License 2.0 - see [LICENSE](LICENSE).

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
