# Custom Metadata

Add custom metadata to your archives.

## Basic Metadata

```zig
const std = @import("std");
const zigx = @import("zigx");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create metadata
    var metadata = zigx.Metadata.init(allocator);
    defer metadata.deinit();

    // Add project information
    try metadata.set("name", "my-project");
    try metadata.set("version", "1.0.0");
    try metadata.set("author", "Developer");
    try metadata.set("license", "Apache-2.0");

    // Create archive with metadata using bundle() alias
    _ = try zigx.bundle(.{
        .allocator = allocator,
        .include = &.{"src"},
        .output_path = "project.zigx",
        .metadata = metadata.entries,
    });
}
```

## Dynamic Metadata

```zig
// Add timestamp
const timestamp = std.time.timestamp();
var ts_buf: [20]u8 = undefined;
const ts_str = std.fmt.bufPrint(&ts_buf, "{d}", .{timestamp}) catch "0";
try metadata.set("built_at", ts_str);

// Add build type
try metadata.set("build_type", if (is_release) "release" else "debug");

// Add environment
try metadata.set("os", @tagName(builtin.os.tag));
try metadata.set("arch", @tagName(builtin.cpu.arch));
```

## Reading Metadata

```zig
var info = try zigx.getArchiveInfo("project.zigx", allocator);
defer info.deinit();

// Get specific value
if (info.metadata.get("version")) |version| {
    std.debug.print("Version: {s}\n", .{version});
}

// Iterate all metadata
var it = info.metadata.entries.iterator();
while (it.next()) |entry| {
    std.debug.print("{s}: {s}\n", .{
        entry.key_ptr.*,
        entry.value_ptr.*,
    });
}
```

## Auto-Generated Metadata

When `auto_metadata = true`, ZIGX adds:

| Key | Example Value |
|-----|---------------|
| `format` | `zigx` |
| `format_version` | `0.0.3` |
| `created_at` | `1768308178` |
| `file_count` | `14` |
| `file_types` | `src:11,txt:3,bin:0` |

## Complete Example

```zig
const std = @import("std");
const zigx = @import("zigx");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create comprehensive metadata
    var metadata = zigx.Metadata.init(allocator);
    defer metadata.deinit();

    // Project info
    try metadata.set("name", "awesome-app");
    try metadata.set("version", "2.0.0");
    try metadata.set("description", "An awesome application");
    try metadata.set("author", "Development Team");
    try metadata.set("license", "Apache-2.0");
    try metadata.set("homepage", "https://example.com");

    // Build info
    const timestamp = std.time.timestamp();
    var ts_buf: [20]u8 = undefined;
    const ts_str = std.fmt.bufPrint(&ts_buf, "{d}", .{timestamp}) catch "0";
    try metadata.set("built_at", ts_str);
    try metadata.set("build_type", "release");
    try metadata.set("zig_version", "0.15.0");

    // Custom application data
    try metadata.set("min_version", "1.5.0");
    try metadata.set("api_version", "3");
    try metadata.set("features", "compression,validation,metadata");

    // Create archive
    _ = try zigx.compress(.{
        .allocator = allocator,
        .directories = &.{"src"},
        .files = &.{"build.zig", "README.md"},
        .output_path = "release.zigx",
        .compression_level = .best,
        .metadata = metadata.entries,
        .auto_metadata = true,
    });

    // Read and display
    var info = try zigx.getArchiveInfo("release.zigx", allocator);
    defer info.deinit();

    std.debug.print("Archive Metadata:\n", .{});
    std.debug.print("─────────────────────────────────────\n", .{});

    var it = info.metadata.entries.iterator();
    while (it.next()) |entry| {
        std.debug.print("  {s:<15}: {s}\n", .{
            entry.key_ptr.*,
            entry.value_ptr.*,
        });
    }
}
```

## Best Practices

1. **Use consistent key names** - lowercase, underscore-separated
2. **Include version info** - Always add a version field
3. **Add timestamps** - Include creation/build time
4. **Keep values short** - Metadata stored as strings
5. **Document custom fields** - Note application-specific metadata
