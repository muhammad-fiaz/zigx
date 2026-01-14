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

| Level | Ratio (lower is better) | Speed | Use Case |
|-------|-------|-------|----------|
| BEST | ~30% | Slower | Distribution |
| DEFAULT | ~28% | Balanced | General use |
| FAST | ~34% | Fastest | Development |
| STORE | 100% | Instant | Pre-compressed |

```zig
.level = .best,    // Maximum compression (default)
.level = .default, // Balanced
.level = .fast,    // Speed optimized
.level = .none,    // No compression (store)
```

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
