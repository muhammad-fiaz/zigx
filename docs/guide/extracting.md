# Extracting

This guide covers extracting files from ZIGX archives.

## Basic Extraction

```zig
const zigx = @import("zigx");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Using the unbundle() alias (same as extract())
    try zigx.unbundle(.{
        .archive_path = "bundle.zigx",
        .output_dir = "extracted",
        .allocator = allocator,
    });

    std.debug.print("Extraction complete!\n", .{});
}
```

## Extract Options

| Option | Type | Description |
|--------|------|-------------|
| `archive_path` | `[]const u8` | Path to archive (required) |
| `output_dir` | `[]const u8` | Output directory (required) |
| `allocator` | `Allocator` | Memory allocator (required) |
| `overwrite` | `bool` | Overwrite existing files |
| `preserve_paths` | `bool` | Keep directory structure |

## Extract with Result

Get detailed information about the extraction:

```zig
const result = try zigx.extractWithResult(.{
    .archive_path = "bundle.zigx",
    .output_dir = "extracted",
    .allocator = allocator,
});

std.debug.print(
    \\Extracted:
    \\  Files:       {d}
    \\  Total Size:  {d} bytes
    \\
, .{
    result.file_count,
    result.total_size,
});
```

## Listing Files

List files without extracting:

```zig
const files = try zigx.listFiles("bundle.zigx", allocator);
defer {
    for (files) |f| allocator.free(f);
    allocator.free(files);
}

std.debug.print("Files in archive:\n", .{});
for (files) |file| {
    std.debug.print("  - {s}\n", .{file});
}
```

## Getting Archive Info

Read archive metadata before extracting:

```zig
var info = try zigx.getArchiveInfo("bundle.zigx", allocator);
defer info.deinit();

std.debug.print(
    \\Archive Info:
    \\  Format Version:      v{d}
    \\  Compression Version: v{d}
    \\  Files:               {d}
    \\  Original Size:       {d} bytes
    \\  Compressed Size:     {d} bytes
    \\
, .{
    info.format_version,
    info.compression_version,
    info.file_count,
    info.original_size,
    info.compressed_size,
});

// Check metadata
var it = info.metadata.entries.iterator();
while (it.next()) |entry| {
    std.debug.print("  {s}: {s}\n", .{
        entry.key_ptr.*,
        entry.value_ptr.*,
    });
}
```

## Validation Before Extraction

```zig
// Quick validation
const is_valid = zigx.isValidArchive("bundle.zigx");
if (!is_valid) {
    std.debug.print("Invalid archive!\n", .{});
    return;
}

// Detailed validation
const validation = try zigx.validateDetailed("bundle.zigx", allocator);
if (!validation.is_valid) {
    std.debug.print("Validation failed:\n", .{});
    for (validation.errors) |err| {
        std.debug.print("  - {s}\n", .{err});
    }
    return;
}

// Safe to extract
try zigx.extract(.{
    .archive_path = "bundle.zigx",
    .output_dir = "extracted",
    .allocator = allocator,
});
```

## Complete Example

```zig
const std = @import("std");
const zigx = @import("zigx");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const archive_path = "bundle.zigx";
    const output_dir = "extracted";

    // Step 1: Validate archive
    if (!zigx.isValidArchive(archive_path)) {
        std.debug.print("Error: Invalid or corrupted archive\n", .{});
        return;
    }

    // Step 2: Get archive info
    var info = try zigx.getArchiveInfo(archive_path, allocator);
    defer info.deinit();

    std.debug.print(
        \\Extracting: {s}
        \\
        \\Archive Info:
        \\  Format:      v{d}
        \\  Compression: v{d}
        \\  Files:       {d}
        \\  Size:        {d} bytes -> {d} bytes
        \\
    , .{
        archive_path,
        info.format_version,
        info.compression_version,
        info.file_count,
        info.compressed_size,
        info.original_size,
    });

    // Step 3: Extract
    try zigx.extract(.{
        .archive_path = archive_path,
        .output_dir = output_dir,
        .allocator = allocator,
    });

    // Step 4: List extracted files
    const files = try zigx.listFiles(archive_path, allocator);
    defer {
        for (files) |f| allocator.free(f);
        allocator.free(files);
    }

    std.debug.print("\nExtracted to: {s}\n", .{output_dir});
    std.debug.print("\nFiles:\n", .{});
    for (files) |file| {
        std.debug.print("  - {s}\n", .{file});
    }
}
```

## Error Handling

```zig
zigx.extract(.{
    .archive_path = "bundle.zigx",
    .output_dir = "extracted",
    .allocator = allocator,
}) catch |err| switch (err) {
    error.FileNotFound => {
        std.debug.print("Error: Archive not found\n", .{});
    },
    error.InvalidFormat => {
        std.debug.print("Error: Invalid archive format\n", .{});
    },
    error.ChecksumMismatch => {
        std.debug.print("Error: Archive corrupted\n", .{});
    },
    error.AccessDenied => {
        std.debug.print("Error: Permission denied\n", .{});
    },
    else => {
        std.debug.print("Error: {any}\n", .{err});
    },
};
```

## Next Steps

- [Validation](/guide/validation) - Archive validation
- [API Reference](/api/extract) - Complete API docs
