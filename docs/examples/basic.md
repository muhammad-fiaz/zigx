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

## Create Archive with Progress

```zig
fn onProgress(info: zigx.ProgressInfo, ctx: ?*anyopaque) void {
    _ = ctx;
    switch (info.event) {
        .scanning => std.debug.print("Scanning...\n", .{}),
        .reading_file => {
            if (info.current_file) |file| {
                std.debug.print("\r[{d}/{d}] {s}", .{
                    info.files_processed, info.total_files, file,
                });
            }
        },
        .compressing => {
            std.debug.print("\rCompressing: {d:.1}%", .{info.getPercent()});
        },
        .finalizing => std.debug.print("\nFinalizing...", .{}),
        else => {},
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var result = try zigx.bundle(.{
        .allocator = allocator,
        .include = &.{ "src", "build.zig" },
        .output_path = "bundle.zigx",
        .level = .best,
        .progress_callback = onProgress,
    });
    defer result.deinit();

    std.debug.print("\nCreated: {s} ({d} bytes)\n", .{
        result.output_path, result.archive_size,
    });
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

## Extract with Progress

```zig
fn onExtractProgress(info: zigx.ExtractProgressInfo, ctx: ?*anyopaque) void {
    _ = ctx;
    switch (info.event) {
        .started => std.debug.print("Starting...\n", .{}),
        .extracting_file => {
            if (info.current_file) |file| {
                std.debug.print("\r[{d}/{d}] {s}", .{
                    info.files_extracted, info.total_files, file,
                });
            }
        },
        .completed => std.debug.print("\nDone!\n", .{}),
        else => {},
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try zigx.unbundle(.{
        .archive_path = "bundle.zigx",
        .output_dir = "extracted",
        .allocator = allocator,
        .progress_callback = onExtractProgress,
    });
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

## Custom Compression Levels

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Using named levels
    _ = try zigx.bundle(.{
        .allocator = allocator,
        .include = &.{"src"},
        .output_path = "fast.zigx",
        .level = .fast,  // zstd level 1
    });

    // Using custom level (any value 1-22)
    _ = try zigx.bundle(.{
        .allocator = allocator,
        .include = &.{"src"},
        .output_path = "custom.zigx",
        .level = zigx.CompressionLevel.custom(15),  // zstd level 15
    });

    // Convert level to integer
    const level = zigx.CompressionLevel.best;
    const raw = level.toInt();  // Returns 19
    std.debug.print("Best level = {d}\n", .{raw});
}
```

## Using OptionsBuilder

```zig
fn onProgress(info: zigx.ProgressInfo, ctx: ?*anyopaque) void {
    _ = ctx;
    if (info.current_file) |file| {
        std.debug.print("\r[{d}/{d}] {s}", .{
            info.files_processed, info.total_files, file,
        });
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var builder = zigx.OptionsBuilder.init(allocator);
    const opts = builder
        .include(&.{ "src", "build.zig" })
        .exclude(&.{ "*.tmp", "zig-cache" })
        .outputPath("project.zigx")
        .ultra()  // Maximum compression (level 22)
        .progress(onProgress, null)
        .build();

    var result = try zigx.bundle(opts);
    defer result.deinit();
}
```

## Using ConfigBuilder

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Build a custom configuration
    var cfgBuilder = zigx.ConfigBuilder.init();
    const cfg = cfgBuilder
        .compressionLevel(.best)
        .adaptive(true)
        .longDistanceMatching(true)
        .verbose(true)
        .build();

    // Use configuration with bundle options
    const opts = zigx.CompressOptions.fromConfig(cfg, allocator);
    // Then set include/output_path manually or use OptionsBuilder
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
