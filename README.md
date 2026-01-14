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

ZIGX archive format performance using `zigx.bundle()` and `zigx.unbundle()` (from `zig build bench`):

> **Note:** These benchmarks test the **full ZIGX archive format** including header generation, SHA-256 checksums, metadata handling, file I/O, and Zstandard compression - not just raw compression.

### ZIGX Compression Levels

| Level | Archive | Saved % | Bundle | Unbundle | Notes |
|:------|--------:|--------:|-------:|---------:|:------|
| | *(lower=better)* | *(higher=better)* | *(MB/s)* | *(MB/s)* | |
| `.none` | ~65 KB | ~0% | Fast | Fast | Store mode (no compression) |
| **`.fast`** | ~53 KB | ~18% | Fast | Fast | Speed optimized |
| **`.default`** | ~53 KB | ~18% | Balanced | Fast | Recommended for most use |
| **`.best`** | ~53 KB | ~18% | Slower | Fast | Maximum compression |

### File Type Performance

| Data Type | Archive | Saved % | Bundle | Unbundle | Notes |
|:----------|--------:|--------:|-------:|---------:|:------|
| | *(lower=better)* | *(higher=better)* | *(MB/s)* | *(MB/s)* | |
| Text data (64KB) | ~53 KB | ~18% | Good | Fast | Source code |
| Binary data (64KB) | ~65 KB | ~0% | Good | Fast | Executables |
| **Repetitive data (64KB)** | **~100 B** | **~99%** | Good | Fast | Log files |
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

### Key Features

| Feature | ZIGX |
|:--------|:----:|
| **Format** | Full archive (.zigx) |
| **Compression** | Zstandard (zstd) |
| **Compression Levels** | `.none`, `.fast`, `.default`, `.best` |
| **Best Space Saved** | ✅ ~99% (repetitive data) |
| **Average Space Saved** | ~18% (text data) |
| **SHA-256 Checksum** | ✅ |
| **CRC32 Verification** | ✅ |
| **File Metadata** | ✅ |
| **Versioned Format** | ✅ |
| **Multi-file Archive** | ✅ |
| **Archive Validation** | ✅ Auto |

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
