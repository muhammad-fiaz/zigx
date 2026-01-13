# Basic Usage

Simple examples for compressing and extracting files.

## Create Archive

```zig
const std = @import("std");
const zigx = @import("zigx");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try zigx.bundle(.{
        .allocator = allocator,
        .include = &.{ "src", "build.zig", "README.md" },
        .output_path = "bundle.zigx",
        .level = .best,
    });
    defer result.deinit();

    std.debug.print("Archive: {s}\n", .{result.output_path});
    std.debug.print("Files: {d}\n", .{result.file_count});
    std.debug.print("Size: {d} bytes\n", .{result.archive_size});
    std.debug.print("Saved: {d:.1}%\n", .{result.getCompressionPercent()});
}
```

## Extract Archive

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try zigx.unbundle(.{
        .archive_path = "bundle.zigx",
        .output_dir = "extracted",
        .allocator = allocator,
    });

    std.debug.print("Extraction complete.\n", .{});
}
```

## List Files

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const files = try zigx.list("bundle.zigx", allocator);
    defer {
        for (files) |f| allocator.free(f);
        allocator.free(files);
    }

    std.debug.print("Files in archive:\n", .{});
    for (files) |file| {
        std.debug.print("  {s}\n", .{file});
    }
}
```

## Get Archive Info

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var info = try zigx.getArchiveInfo("bundle.zigx", allocator);
    defer info.deinit();

    std.debug.print("Format Version: v{d}\n", .{info.format_version});
    std.debug.print("Compression Version: v{d}\n", .{info.compression_version});
    std.debug.print("File Count: {d}\n", .{info.file_count});
    std.debug.print("Original Size: {d} bytes\n", .{info.original_size});
    std.debug.print("Compressed Size: {d} bytes\n", .{info.compressed_size});
}
```

## Validate Archive

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Quick check
    if (zigx.isValid("bundle.zigx")) {
        std.debug.print("Valid archive.\n", .{});
    }

    // Detailed validation
    const is_valid = try zigx.verify("bundle.zigx", allocator);
    if (is_valid) {
        std.debug.print("Archive integrity verified.\n", .{});
    }
}
```

## Error Handling

```zig
const result = zigx.bundle(.{
    .allocator = allocator,
    .include = &.{"nonexistent"},
    .output_path = "out.zigx",
}) catch |err| {
    switch (err) {
        error.FileNotFound => std.debug.print("File not found.\n", .{}),
        error.NoFilesSpecified => std.debug.print("No files to bundle.\n", .{}),
        else => std.debug.print("Error: {}\n", .{err}),
    }
    return;
};
defer result.deinit();
```
