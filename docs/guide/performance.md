# Performance

Optimize ZIGX for your use case.

## Compression Level Selection

| Level | Use Case | Speed | Ratio |
|-------|----------|-------|-------|
| `.best` | Distribution, storage | Slowest | Best |
| `.default` | General purpose | Balanced | Good |
| `.fast` | CI/CD, development | Fastest | Lower |
| `.store` | Pre-compressed files | Instant | None |

### Benchmark (Example Project)

| Mode | Size (bytes) | Ratio | Saved |
|------|-------------|-------|-------|
| BEST | 45,509 | 31.3% | 68.7% |
| DEFAULT | 41,558 | 28.6% | 71.4% |
| FAST | 48,658 | 33.5% | 66.5% |
| STORE | 147,201 | 101.3% | -1.3% |

## Memory Usage

| Component | Approximate Memory |
|-----------|-------------------|
| Sliding Window | 64 KB |
| Hash Table | 32 KB |
| Output Buffer | Variable |
| File Buffers | Per file |

### Estimate for Different Levels

| Level | Peak Memory |
|-------|-------------|
| BEST | ~256 KB |
| DEFAULT | ~128 KB |
| FAST | ~64 KB |
| STORE | ~16 KB |

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

### Low Compression (Consider `.store`)

- Already compressed (`.zip`, `.gz`, `.7z`)
- Media files (`.png`, `.jpg`, `.mp4`)
- Binary executables
- Encrypted data

## Extraction Performance

Extraction is typically faster than compression:

| Operation | Relative Speed |
|-----------|---------------|
| Extraction | ~3-5x faster than compression |
| Listing | Nearly instant |
| Validation | ~2x faster than compression |

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
