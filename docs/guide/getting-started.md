# Getting Started

Get started with ZIGX in your Zig project.

## Requirements

- Zig 0.14.0 or later (0.15.x recommended)
- A Zig project with `build.zig`

## Installation

### Stable Release (Recommended)

Run this command in your project root:

```bash
zig fetch --save https://github.com/muhammad-fiaz/zigx/archive/refs/tags/v0.0.1.tar.gz
```

### Nightly (Bleeding Edge)

If you want the latest features:

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/zigx
```

### Configure build.zig

Then in `build.zig`:

```zig
const zigx = b.dependency("zigx", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("zigx", zigx.module("zigx"));
```

## Create an Archive

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
        .exclude = &.{ "*.tmp", ".git" },
        .output_path = "bundle.zigx",
        .level = .best,
    });
    defer result.deinit();

    std.debug.print("Created: {d} files, {d} bytes\n", .{
        result.file_count,
        result.archive_size,
    });
}
```

## Extract an Archive

```zig
try zigx.unbundle(.{
    .archive_path = "bundle.zigx",
    .output_dir = "extracted",
    .allocator = allocator,
});
```

## Get Archive Info

```zig
var info = try zigx.getArchiveInfo("bundle.zigx", allocator);
defer info.deinit();

std.debug.print("Format: v{d}, Files: {d}\n", .{
    info.format_version,
    info.file_count,
});
```

## Next Steps

- [Bundling Guide](/guide/bundling) - Learn about compression options
- [Extracting Guide](/guide/extracting) - Extraction options
- [API Reference](/api/) - Complete API documentation
