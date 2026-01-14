---
layout: home
title: ZIGX - Fast and light-weight Compression for Zig
titleTemplate: ZIGX

hero:
  name: "ZIGX"
  text: "Fast and light-weight Compression"
  tagline: Fast and smaller compression file format for Zig
  image:
    src: /zigx.png
    alt: ZIGX Logo
  actions:
    - theme: brand
      text: Get Started
      link: /guide/getting-started
    - theme: alt
      text: View on GitHub
      link: https://github.com/muhammad-fiaz/zigx

features:
  - title: Zstandard Compression
    details: Industry-leading zstd compression via Zig bindings - 80%+ space savings on typical data.
    
  - title: Blazing Fast
    details: 94+ MB/s compression, 122+ MB/s decompression. Up to 99.9% compression on repetitive data.
    
  - title: Security First
    details: SHA-256 checksums, CRC32 verification, and secure path handling.
    
  - title: Multiple Modes
    details: ULTRA (zstd 22), BEST (zstd 19), BALANCED (zstd 6), DEFAULT (zstd 3), FAST (zstd 1), or custom levels 1-22.
    
  - title: Progress Callbacks
    details: Track bundling and extraction progress with detailed events for large archives.
    
  - title: Rich API
    details: Easy-to-use API with function aliases, OptionsBuilder fluent API, and preset configurations.

---

::: info
ZIGX is a new file format specifically designed for Zig distribution packages, but it can also be used as a compressed file format for any other projects.
:::

## Installation

### Release Installation (Recommended)

Install the latest stable release (v0.0.1):

```bash
zig fetch --save https://github.com/muhammad-fiaz/zigx/archive/refs/tags/v0.0.1.tar.gz
```

### Configure build.zig

```zig
const zigx_dep = b.dependency("zigx", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("zigx", zigx_dep.module("zigx"));
```

## Quick Start

```zig
const zigx = @import("zigx");

// Create an archive
const result = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{ "src", "build.zig", "README.md" },
    .exclude = &.{ "*.tmp", ".git" },
    .output_path = "archive.zigx",
    .level = .best,
});

// Get archive information
var info = try zigx.getArchiveInfo("archive.zigx", allocator);
defer info.deinit();

std.debug.print("Format: v{d}, Compression: v{d}\n", .{
    info.format_version,
    info.compression_version,
});
```

## Compression Levels

| Level | zstd | Ratio (lower=better) | Speed | Use Case |
|-------|:----:|-------|-------|----------|
| `.ultra` | 22 | ~17-22% | Slowest | Maximum compression |
| `.best` | 19 | ~19-25% | Slow | Distribution |
| `.balanced` | 6 | ~21-26% | Moderate | General purpose |
| `.default` | 3 | ~21-28% | Balanced | Default |
| `.fast` | 1 | ~25-33% | Fastest | Development |
| `.none` | - | 100% | Instant | Pre-compressed |
| `custom(n)` | 1-22 | Varies | Varies | Fine-grained control |

## Function Aliases

ZIGX provides intuitive function aliases:

| Primary | Alias | Description |
|---------|-------|-------------|
| `compress()` | `bundle()` | Create archives |
| `extract()` | `unbundle()` | Extract archives |
| `validate()` | `verify()` | Validate integrity |
| `listFiles()` | `list()` | List contents |
| `isValidArchive()` | `isValid()` | Quick validity check |

## Version Information

- **Library**: 0.0.1
- **Format**: v1
- **Compression**: v1
- **Zig**: 0.15.0+
