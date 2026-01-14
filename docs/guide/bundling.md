# Bundling

Create ZIGX archives from files and directories.

## Basic Usage

```zig
const zigx = @import("zigx");

var result = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{ "src", "build.zig", "README.md" },
    .output_path = "bundle.zigx",
});
defer result.deinit();
```

## Options

| Option | Type | Description |
|--------|------|-------------|
| `allocator` | `Allocator` | Memory allocator (required) |
| `include` | `[]const []const u8` | Files and directories |
| `exclude` | `[]const []const u8` | Exclude patterns |
| `output_path` | `[]const u8` | Output archive path |
| `base_dir` | `[]const u8` | Base directory (default: ".") |
| `level` | `CompressionLevel` | Compression level |
| `auto_metadata` | `bool` | Auto-generate metadata |

## Compression Levels

| Level | zstd | Ratio (lower is better) | Speed | Use Case |
|-------|:----:|-------|-------|----------|
| `.ultra` | 22 | ~19% | Slowest | Archival, maximum compression |
| `.best` | 19 | ~20% | Slower | Distribution |
| `.balanced` | 6 | ~22% | Moderate | Good balance |
| `.default` | 3 | ~25% | Good | General use |
| `.fast` | 1 | ~30% | Fast | Development |
| `.none` | 0 | 100% | Instant | Pre-compressed |
| `custom(n)` | 1-22 | Varies | Varies | Fine-grained control |

```zig
.level = .ultra,    // Maximum compression (zstd 22)
.level = .best,     // High compression (zstd 19)
.level = .balanced, // Good balance (zstd 6)
.level = .default,  // General use (zstd 3)
.level = .fast,     // Speed optimized (zstd 1)
.level = .none,     // No compression (store)

// Custom levels (1-22) for fine-grained control
.level = CompressionLevel.custom(10),  // zstd level 10
.level = CompressionLevel.custom(15),  // zstd level 15
.level = CompressionLevel.custom(18),  // zstd level 18
```

### Custom Levels (1-22)

Use `CompressionLevel.custom(n)` to specify any zstd level:

| zstd Level | Speed | Ratio | Best For |
|:----------:|:-----:|:-----:|:---------|
| 1-3 | ★★★★★ | ★★☆☆☆ | Speed priority, CI/CD |
| 4-9 | ★★★★☆ | ★★★☆☆ | General purpose |
| 10-15 | ★★★☆☆ | ★★★★☆ | Balanced workloads |
| 16-19 | ★★☆☆☆ | ★★★★★ | Distribution |
| 20-22 | ★☆☆☆☆ | ★★★★★ | Maximum compression |

### Level Aliases

```zig
.level = CompressionLevel.turbo,   // Same as .fast
.level = CompressionLevel.maximum, // Same as .ultra
```

## Progress Tracking

Track progress for large archives with detailed events:

```zig
fn onProgress(info: zigx.ProgressInfo, ctx: ?*anyopaque) void {
    _ = ctx;
    switch (info.event) {
        .scanning => std.debug.print("Scanning files...\n", .{}),
        .reading_file => {
            if (info.current_file) |file| {
                std.debug.print("\r[{d}/{d}] Reading: {s}", .{
                    info.files_processed,
                    info.total_files,
                    file,
                });
            }
        },
        .compressing => {
            std.debug.print("\rCompressing... {d:.1}%", .{info.getPercent()});
        },
        .writing => std.debug.print("\rWriting archive...", .{}),
        .finalizing => std.debug.print("\rFinalizing...", .{}),
    }
}

var result = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{"src"},
    .output_path = "bundle.zigx",
    .progress_callback = onProgress,
    .progress_context = null,  // Optional context pointer
});
```

### Progress Events

| Event | Description |
|-------|-------------|
| `scanning` | Scanning directories for files |
| `reading_file` | Reading a file from disk |
| `compressing` | Compressing data with zstd |
| `writing` | Writing compressed data to archive |
| `finalizing` | Writing header and checksums |

### Progress Info Fields

| Field | Type | Description |
|-------|------|-------------|
| `event` | `ProgressEvent` | Current operation |
| `current_file` | `?[]const u8` | Current file path |
| `files_processed` | `usize` | Files completed |
| `total_files` | `usize` | Total file count |
| `bytes_processed` | `u64` | Bytes processed |
| `total_bytes` | `u64` | Total bytes |
| `getPercent()` | `f64` | Progress 0-100% |

## Include/Exclude

```zig
var result = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{
        "src",           // Directory
        "lib",           // Directory
        "build.zig",     // File
        "README.md",     // File
    },
    .exclude = &.{
        "*.tmp",         // All .tmp files
        ".git",          // .git directory
        "zig-cache",     // zig-cache directory
        "node_modules",  // node_modules directory
    },
    .output_path = "project.zigx",
});
```

## Custom Metadata

```zig
var metadata = zigx.createMetadata(allocator);
defer metadata.deinit();
try metadata.set("name", "my-project");
try metadata.set("version", "1.0.0");
try metadata.set("author", "Your Name");

var result = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{"src"},
    .output_path = "project.zigx",
    .metadata = metadata.entries,
    .auto_metadata = true,  // Also includes auto-generated metadata
});
```

## Result

```zig
var result = try zigx.bundle(.{...});
defer result.deinit();

std.debug.print("Archive: {s}\n", .{result.output_path});
std.debug.print("Files: {d}\n", .{result.file_count});
std.debug.print("Size: {d} bytes\n", .{result.archive_size});
std.debug.print("Original: {d} bytes\n", .{result.original_size});
std.debug.print("Ratio: {d:.1}%\n", .{result.getCompressionRatio() * 100});
std.debug.print("Saved: {d:.1}%\n", .{result.getCompressionPercent()});
std.debug.print("Hash: {s}\n", .{result.archive_hash[0..32]});
```
