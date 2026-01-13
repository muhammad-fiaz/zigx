# Examples

Practical examples demonstrating ZIGX features.

## Quick Examples

### Create Archive

```zig
const zigx = @import("zigx");

var result = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{ "src", "build.zig" },
    .output_path = "bundle.zigx",
});
defer result.deinit();
```

### Extract Archive

```zig
try zigx.unbundle(.{
    .archive_path = "bundle.zigx",
    .output_dir = "output",
    .allocator = allocator,
});
```

### Get Archive Info

```zig
var info = try zigx.getArchiveInfo("bundle.zigx", allocator);
defer info.deinit();

std.debug.print("Format: v{d}, Files: {d}\n", .{
    info.format_version,
    info.file_count,
});
```

### List Files

```zig
const files = try zigx.list("bundle.zigx", allocator);
defer {
    for (files) |f| allocator.free(f);
    allocator.free(files);
}

for (files) |file| {
    std.debug.print("  {s}\n", .{file});
}
```

## CLI Example

ZIGX includes an example in `examples/self_bundle.zig`:

```bash
# Help
zig build run-example -- help

# Compare compression levels
zig build run-example

# Create archive
zig build run-example -- bundle

# Extract archive
zig build run-example -- unbundle dist/zigx-bundle.zigx ./extracted

# Show archive info
zig build run-example -- info dist/zigx-bundle.zigx

# List files
zig build run-example -- list dist/zigx-bundle.zigx
```

## More Examples

- [Basic Usage](/examples/basic) - Simple operations
- [Self-Bundling](/examples/self-bundle) - Bundle your project
- [Custom Metadata](/examples/metadata) - Add metadata
- [Exclude Patterns](/examples/exclude) - Filter files
