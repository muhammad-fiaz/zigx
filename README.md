# ZIGX

High-performance compression library for Zig projects.

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Zig](https://img.shields.io/badge/Zig-0.14%2B-orange.svg)](https://ziglang.org)
[![Version](https://img.shields.io/badge/Version-0.0.1-green.svg)](CHANGELOG.md)

## Features

- **LZ77+RLE Hybrid** - Advanced compression with 64KB sliding window
- **Versioned Format** - Format v1 with compression versioning
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

### Options

```zig
// Compress/Bundle options
.{
    .allocator = allocator,          // Required
    .include = &.{"src", "lib"},     // Files and directories
    .exclude = &.{"*.tmp", ".git"},  // Exclude patterns
    .output_path = "out.zigx",       // Output file
    .level = .best,                  // Compression level
}

// Extract/Unbundle options
.{
    .archive_path = "in.zigx",       // Required
    .output_dir = "output",          // Required
    .allocator = allocator,          // Required
    .validate = true,                // Validate checksums
    .overwrite = false,              // Overwrite existing
}
```

### Compression Levels

| Level | Description |
|-------|-------------|
| `.best` | Maximum compression |
| `.default` | Balanced |
| `.fast` | Speed optimized |
| `.none` / `.store` | No compression |

## Format

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

- [Getting Started](docs/guide/getting-started.md)
- [API Reference](docs/api/index.md)
- [Examples](docs/examples/index.md)

## Contributing

See [CONTRIBUTING.md](docs/contributing.md).

## Security

See [SECURITY.md](SECURITY.md).

## License

MIT License - see [LICENSE](LICENSE).

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
