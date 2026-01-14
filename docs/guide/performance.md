# Performance

Optimize ZIGX for your use case. ZIGX uses **Zstandard (zstd)** compression for excellent speed and ratios.

## Compression Level Selection

| Level | zstd Level | Use Case | Comp Speed | Decomp Speed | Ratio |
|-------|------------|----------|------------|--------------|-------|
| `.best` | 19 | Distribution, storage | ~14 MB/s | ~131 MB/s | ~19% |
| `.default` | 3 | General purpose | ~120 MB/s | ~132 MB/s | ~21% |
| `.fast` | 1 | CI/CD, development | ~132 MB/s | ~135 MB/s | ~25% |
| `.none` | - | Pre-compressed files | ~148 MB/s | ~148 MB/s | 100% |

### Benchmark Results (64KB Text)

| Mode | Size (bytes) | Ratio | Space Saved |
|------|-------------|-------|-------------|
| BEST | 53,357 | 18.6% | 81.4% |
| DEFAULT | 53,314 | 18.6% | 81.4% |
| FAST | 53,314 | 18.6% | 81.4% |
| STORE | 65,554 | 100% | 0% |

> **Note:** Lower ratio = better compression. Higher saved % = better compression.
| STORE | 157,833 | 101.3% | -1.3% |

### By Data Type

| Data Type | Compression | Speed | Notes |
|-----------|-------------|-------|-------|
| Text/Source | 18.6% | 124 MB/s | Excellent |
| Repetitive (logs) | 99.9% | 148 MB/s | Outstanding |
| Binary | ~0% | 138 MB/s | Incompressible |
| Random | ~0% | 138 MB/s | Incompressible |

## Memory Usage

Zstd memory usage depends on compression level:

| Level | Compression Memory | Decompression Memory |
|-------|-------------------|---------------------|
| BEST (19) | ~64 MB | ~128 KB |
| DEFAULT (3) | ~1 MB | ~128 KB |
| FAST (1) | ~256 KB | ~128 KB |
| STORE | ~16 KB | ~16 KB |

*Decompression is always fast and low-memory regardless of compression level used.*

## Optimization Tips

### 1. Choose Appropriate Level

```zig
// For releases - maximum compression
.level = .best

// For CI/CD - balance speed and size
.level = .default

// For development - fast iteration
.level = .fast
```

### 2. Exclude Non-Compressible Files

```zig
.exclude = &.{
    "*.zip",   // Already compressed
    "*.gz",
    "*.png",
    "*.jpg",
    "*.mp4",
}
```

### 3. Use Store for Pre-Compressed

```zig
// For archives containing only images/videos
.level = .store
```

### 4. Batch Operations

When bundling multiple projects:

```zig
const projects = [_][]const u8{ "project_a", "project_b", "project_c" };

for (projects) |project| {
    _ = try zigx.bundle(.{
        .allocator = allocator,
        .include = &.{project},
        .output_path = try std.fmt.allocPrint(allocator, "{s}.zigx", .{project}),
        .level = .fast,  // Use fast for batch
    });
}
```

## Optimal File Types

### High Compression (Good for ZIGX)

- Source code (`.zig`, `.c`, `.py`, `.js`)
- Text files (`.txt`, `.md`, `.json`)
- Configuration files
- Documentation

### Low Compression (Consider `.none`)

- Already compressed (`.zip`, `.gz`, `.7z`, `.zst`)
- Media files (`.png`, `.jpg`, `.mp4`)
- Binary executables
- Encrypted data

## Extraction Performance

Zstd decompression is extremely fast - typically 139+ MB/s:

| Operation | Speed | Notes |
|-----------|-------|-------|
| Decompression | 139+ MB/s | Constant regardless of level |
| Listing | Nearly instant | Header only |
| Validation | ~2x faster than compression | Hash verification |

### Optimize Extraction

```zig
// Extract without validation for speed
try zigx.unbundle(.{
    .archive_path = "archive.zigx",
    .output_dir = "output",
    .allocator = allocator,
    .validate = false,  // Skip validation
});
```

## Profiling Example

```zig
const std = @import("std");
const zigx = @import("zigx");

pub fn benchmark() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const levels = [_]zigx.CompressionLevel{ .best, .default, .fast, .store };
    
    for (levels) |level| {
        const start = std.time.milliTimestamp();
        
        const result = try zigx.bundle(.{
            .allocator = allocator,
            .include = &.{"src"},
            .output_path = "bench.zigx",
            .level = level,
        });
        
        const duration = std.time.milliTimestamp() - start;
        
        std.debug.print("{s}: {d}ms, {d} bytes\n", .{
            @tagName(level),
            duration,
            result.compressed_size,
        });
    }
}
```

## See Also

- [Compression](/guide/compression) - Compression details
- [Format](/guide/format) - Archive format specification
