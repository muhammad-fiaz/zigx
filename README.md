<div align="center">

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
- **Multiple Levels** - BEST (zstd 19), DEFAULT (zstd 3), FAST (zstd 1), and STORE modes
- **Security** - SHA-256 checksums, CRC32 payload verification, and Cryptographic Signing
- **Advanced Management** - Update metadata, file adding/removing, and repair corrupted archives in-place
- **Include/Exclude** - Pattern matching for files and directories
- **Rich API** - Simple client-side access to metadata and checksums
- **Cross-Platform** - Works on Linux, Windows, macOS via Zig build system
- **128-byte Header** - Compact binary format

## Installation

Add to `build.zig.zon`:

```zig
.dependencies = .{
    .zigx = .{
        .url = "https://github.com/muhammad-fiaz/zigx/archive/refs/tags/v0.0.1.tar.gz",
        .hash = "...", // Run: zig fetch <url>
    },
},
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
| `.best` | 19 | Maximum compression | 19-25% |
| `.default` | 3 | Balanced speed/ratio | 21-28% |
| `.fast` | 1 | Speed optimized | 25-33% |
| `.none` | - | No compression | 100%+ |

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

ZIGX compression performance on various data types (from `zig build bench`):

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

| Data Type | Output | Compressed % | Comp Speed | Decomp Speed | Notes |
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

### Key Features

| Feature | ZIGX |
|:--------|:----:|
| **Algorithm** | Zstandard (zstd) |
| **Compression Levels** | 0-22 (23 levels) |
| **Best Compressed %** | ✅ 99.9% (repetitive data) |
| **Average Compressed %** | 18.7% (text data) |
| **Fast Compression** | ✅ 87+ MB/s average |
| **Fast Decompression** | ✅ 135+ MB/s average |
| **SHA-256 Checksum** | ✅ |
| **CRC32 Verification** | ✅ |
| **File Metadata** | ✅ |
| **Versioned Format** | ✅ |
| **Multi-file Archive** | ✅ |
| **Archive Validation** | ✅ Auto |

> [!NOTE]
> **ZIGX excels on repetitive data** - Achieves **99.9% compressed** on log files, configs, etc. Higher compressed % = better compression. Lower output size = better.
>
> Benchmark results for each release can be found at [github.com/muhammad-fiaz/zigx/releases](https://github.com/muhammad-fiaz/zigx/releases).

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


## Version

| Component | Version | Description |
|-----------|---------|-------------|
| Library | 0.0.1 | ZIGX library version |
| Format | 1 | Archive structure version |
| Compression | 1 | Zstandard (zstd) algorithm |

## License

this project is licensed under the Apache License 2.0 - see [LICENSE](LICENSE).

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
