# Installation

This guide covers different ways to install ZIGX in your Zig project.

## Requirements

- **Zig**: Version 0.14.0 or later (0.15.x recommended)
- **Platform**: Windows, macOS, or Linux

## Using Zig Package Manager (Recommended)

### Step 1: Add Dependency

Add ZIGX to your `build.zig.zon`:

```zig
.{
    .name = "your-project",
    .version = "0.1.0",
    .dependencies = .{
        .zigx = .{
            .url = "https://github.com/muhammad-fiaz/zigx/archive/refs/tags/v0.0.1.tar.gz",
            .hash = "1220...", // Hash will be provided by zig fetch
        },
    },
    .paths = .{"."},
}
```

### Step 2: Fetch the Package

Run this command to get the correct hash:

```bash
zig fetch https://github.com/muhammad-fiaz/zigx/archive/refs/tags/v0.0.1.tar.gz
```

Copy the output hash into your `build.zig.zon`.

### Step 3: Configure build.zig

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add ZIGX dependency
    const zigx = b.dependency("zigx", .{
        .target = target,
        .optimize = optimize,
    });

    // Create your executable
    const exe = b.addExecutable(.{
        .name = "your-app",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Import ZIGX module
    exe.root_module.addImport("zigx", zigx.module("zigx"));

    b.installArtifact(exe);
}
```

## Manual Installation

If you prefer not to use the package manager:

### Step 1: Clone Repository

```bash
git clone https://github.com/muhammad-fiaz/zigx.git
# or download and extract a release
```

### Step 2: Add as Local Module

In your `build.zig`:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create ZIGX module from local path
    const zigx_module = b.addModule("zigx", .{
        .root_source_file = b.path("vendor/zigx/src/zigx.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "your-app",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("zigx", zigx_module);

    b.installArtifact(exe);
}
```

## Verification

Test your installation:

```zig
// src/main.zig
const std = @import("std");
const zigx = @import("zigx");

pub fn main() !void {
    std.debug.print("ZIGX Version: {s}\n", .{zigx.VERSION});
    std.debug.print("Format Version: {d}\n", .{zigx.FORMAT_VERSION});
    std.debug.print("Compression Version: {d}\n", .{zigx.COMPRESSION_VERSION});
}
```

Build and run:

```bash
zig build run
```

Expected output:
```
ZIGX Version: 0.0.1
Format Version: 1
Compression Version: 1
```

## Troubleshooting

### Hash Mismatch

If you get a hash mismatch error:

```bash
# Re-fetch with --debug-hash to see the correct hash
zig fetch --debug-hash https://github.com/muhammad-fiaz/zigx/archive/refs/tags/v0.0.1.tar.gz
```

### Module Not Found

Ensure the path in `root_source_file` is correct:

```zig
// Check if zigx.zig exists at this path
.root_source_file = b.path("path/to/zigx/src/zigx.zig"),
```

### Zig Version Compatibility

ZIGX 0.0.1 requires Zig 0.14.0+. Check your version:

```bash
zig version
```

## Next Steps

- [Getting Started](/guide/getting-started) - Create your first archive
- [Compression](/guide/compression) - Learn about compression modes
