---
layout: home
title: ZIGX - Fast and Smaller Compression for Zig
titleTemplate: ZIGX

hero:
  name: "ZIGX"
  text: "Fast and Smaller Compression"
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
  - title: High Performance
    details: Optimized LZ77+RLE hybrid algorithm with 64KB sliding window and lazy matching.
    
  - title: Versioned Format
    details: Format v1 with compression versioning ensures future compatibility.
    
  - title: Security First
    details: SHA-256 checksums, CRC32 verification, and secure path handling.
    
  - title: Multiple Modes
    details: BEST, DEFAULT, FAST, or STORE compression based on your needs.
    
  - title: Include/Exclude
    details: Simple pattern matching to include or exclude files and directories.
    
  - title: Rich API
    details: Easy-to-use API with function aliases for all operations.

---

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

| Level | Ratio | Speed | Use Case |
|-------|-------|-------|----------|
| BEST | ~30% | Slower | Distribution |
| DEFAULT | ~28% | Balanced | General use |
| FAST | ~34% | Fastest | Development |
| STORE | 100% | Instant | Pre-compressed |

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
- **Zig**: 0.14.0+ (0.15.x recommended)
