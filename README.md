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
<a href="https://hits.sh/muhammad-fiaz/zigx/"><img src="https://hits.sh/muhammad-fiaz/zigx.svg?label=Visitors&extraCount=0&color=green" alt="Repo Visitors"></a>

<p><em>Fast and light-weight compression file format for Zig.</em></p>

<b><a href="https://muhammad-fiaz.github.io/zigx/">Documentation</a> |
<a href="https://muhammad-fiaz.github.io/zigx/api/">API Reference</a> |
<a href="https://muhammad-fiaz.github.io/zigx/guide/getting-started">Quick Start</a> |
<a href="docs/contributing.md">Contributing</a></b>

</div>

Fast and smaller compression file format for Zig features LZ77+RLE hybrid compression with 64KB sliding window and lazy matching optimization.

> [!NOTE]
> ZIGX introduces a new archive format (.zigx) designed specifically for Zig projects. As a new format, it is not yet widely adopted, but offers modern features like versioned format, SHA-256 checksums, and excellent compression ratios.

⭐ **If you find `zigx` useful, please give it a star!**

## Features

- **LZ77+RLE Hybrid** - Advanced compression with 64KB sliding window
- **Versioned Format** - Format v1 with compression versioning for compatibility
- **Multiple Levels** - BEST, DEFAULT, FAST, and STORE modes
- **Security** - SHA-256 checksums, CRC32 verification
- **Include/Exclude** - Pattern matching for files and directories
- **Rich API** - Simple client-side access to metadata and checksums
- **Pure Zig** - Zero external dependencies
- **128-byte Header** - Compact binary format

## Version

| Component | Version |
|-----------|---------|
| Library | 0.0.1 |
| Format | 1 |
| Compression | 1 |

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

| Level | Description | Typical Ratio |
|-------|-------------|---------------|
| `.best` | Maximum compression | 28-32% |
| `.default` | Balanced | 28-35% |
| `.fast` | Speed optimized | 33-40% |
| `.none` | No compression | 100%+ |

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
  Compression Version: 1
  LZ77+RLE compressed data
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
