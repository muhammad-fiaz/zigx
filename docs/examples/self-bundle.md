# Self-Bundling Example

Bundle your own project with ZIGX.

## Overview

This example shows how to create a tool that packages your project files.

## Example

```zig
const std = @import("std");
const zigx = @import("zigx");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("[ZIGX Bundle]\n", .{});
    std.debug.print("Format v{d}, Compression v{d}\n\n", .{
        zigx.FORMAT_VERSION,
        zigx.COMPRESSION_VERSION,
    });

    var result = try zigx.bundle(.{
        .allocator = allocator,
        .include = &.{
            "src",
            "build.zig",
            "build.zig.zon",
            "LICENSE",
            "README.md",
        },
        .exclude = &.{
            "*.tmp",
            ".git",
            "zig-cache",
            "zig-out",
        },
        .output_path = "dist/project.zigx",
        .level = .best,
    });
    defer result.deinit();

    std.debug.print("Result:\n", .{});
    std.debug.print("  Archive: {s}\n", .{result.output_path});
    std.debug.print("  Files: {d}\n", .{result.file_count});
    std.debug.print("  Size: {d} bytes\n", .{result.archive_size});
    std.debug.print("  Saved: {d:.1}%\n", .{result.getCompressionPercent()});
    std.debug.print("  Hash: {s}...\n", .{result.archive_hash[0..32]});
}
```

## Running the Example

ZIGX includes a built-in example:

```bash
# Create a bundle
zig build run-example -- bundle
```

Output:
```
[ZIGX Bundle]
Format v1, Compression v1

Creating archive with BEST compression...
Include: src, build.zig, build.zig.zon, LICENSE, README.md
Output:  dist/zigx-bundle.zigx

Result:
  Archive:    dist/zigx-bundle.zigx
  Files:      14
  Size:       45509 bytes
  Saved:      68.7%
  Hash:       2fafa37b70f9891accdfa9f59352a02d...

Bundle created successfully.
```

## Inspecting the Bundle

```bash
# View archive info
zig build run-example -- info dist/zigx-bundle.zigx

# List files
zig build run-example -- list dist/zigx-bundle.zigx
```

## Extracting the Bundle

```bash
# Extract to directory
zig build run-example -- unbundle dist/zigx-bundle.zigx ./extracted
```

## Advanced Operations

The example tool also supports advanced management features.

### Updating Metadata

```bash
# Set author
zig build run-example -- metadata dist/zigx-bundle.zigx set author "ZIGX Team"

# Get author
zig build run-example -- metadata dist/zigx-bundle.zigx get author
```

### Signing

```bash
# Sign the archive
zig build run-example -- sign dist/zigx-bundle.zigx "my-signature"
```

### Updating Content

```bash
# Add a new file
zig build run-example -- update dist/zigx-bundle.zigx -add EXTRA.md

# Remove source files
zig build run-example -- update dist/zigx-bundle.zigx -rm "src/*"
```

### Repairing

```bash
# Attempt to repair a corrupted file
zig build run-example -- repair broken.zigx fixed.zigx
```

