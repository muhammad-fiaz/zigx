# Metadata

ZIGX archives support custom key-value metadata for storing additional information.

## Overview

Metadata is stored in the archive header and can include:
- Project information (name, version, author)
- Build information (timestamp, environment)
- Custom application data

## Adding Metadata

```zig
const zigx = @import("zigx");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create metadata
    var metadata = zigx.Metadata.init(allocator);
    defer metadata.deinit();

    // Add key-value pairs
    try metadata.set("name", "my-project");
    try metadata.set("version", "1.0.0");
    try metadata.set("author", "Developer");

    // Create archive with metadata using bundle() alias
    _ = try zigx.bundle(.{
        .allocator = allocator,
        .include = &.{"src"},
        .output_path = "bundle.zigx",
        .metadata = metadata.entries,
    });
}
```

## Auto-Generated Metadata

When `auto_metadata = true`, ZIGX automatically adds:

| Key | Description |
|-----|-------------|
| `format` | Always "zigx" |
| `format_version` | Format version string |
| `created_at` | Unix timestamp |
| `file_count` | Number of files |
| `file_types` | File type statistics |

```zig
_ = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{"src"},
    .output_path = "bundle.zigx",
    .auto_metadata = true,
});
```

## Reading Metadata

```zig
var info = try zigx.getArchiveInfo("bundle.zigx", allocator);
defer info.deinit();

// Iterate all metadata
var it = info.metadata.entries.iterator();
while (it.next()) |entry| {
    std.debug.print("{s}: {s}\n", .{
        entry.key_ptr.*,
        entry.value_ptr.*,
    });
}

// Get specific value
if (info.metadata.get("version")) |version| {
    std.debug.print("Version: {s}\n", .{version});
}
```

## Common Metadata Fields

### Project Information

```zig
try metadata.set("name", "my-app");
try metadata.set("version", "2.0.0");
try metadata.set("description", "My awesome application");
try metadata.set("author", "John Doe");
try metadata.set("license", "MIT");
try metadata.set("homepage", "https://example.com");
```

### Build Information

```zig
// Timestamp
const timestamp = std.time.timestamp();
var ts_buf: [20]u8 = undefined;
const ts_str = std.fmt.bufPrint(&ts_buf, "{d}", .{timestamp}) catch "0";
try metadata.set("built_at", ts_str);

// Build type
try metadata.set("build_type", "release");

// Git commit (if available)
try metadata.set("git_commit", "abc123");

// Platform
try metadata.set("platform", "x86_64-linux");
```

## Updating Metadata

You can update metadata in an existing archive without extracting/re-compressing using the `manager` client-side API.

```zig
const manager = zigx.manager;

// Define updates
var updates = [_]manager.MetadataUpdate{
    .{ .key = "version", .op = .{ .set = "1.0.1" } },
    .{ .key = "temp", .op = .delete },
};

// Apply updates
try manager.updateMetadata("archive.zigx", &updates, allocator);
```

### Custom Application Data

```zig
// Any string key-value pairs
try metadata.set("api_version", "3");
try metadata.set("min_client", "1.5.0");
try metadata.set("features", "compression,encryption");
```

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
    try metadata.set("name", "my-project");
    try metadata.set("version", "1.0.0");
    try metadata.set("author", "Development Team");
    try metadata.set("license", "MIT");

    // Build info
    const timestamp = std.time.timestamp();
    var ts_buf: [20]u8 = undefined;
    const ts_str = std.fmt.bufPrint(&ts_buf, "{d}", .{timestamp}) catch "0";
    try metadata.set("built_at", ts_str);
    try metadata.set("zig_version", "0.15.0");

    // Custom fields
    try metadata.set("release_notes", "Initial release");

    // Create archive
    _ = try zigx.compress(.{
        .allocator = allocator,
        .directories = &.{"src"},
        .files = &.{"build.zig", "README.md"},
        .output_path = "release.zigx",
        .compression_level = .best,
        .metadata = metadata.entries,
        .auto_metadata = true, // Also add auto metadata
    });

    // Read back and display
    var info = try zigx.getArchiveInfo("release.zigx", allocator);
    defer info.deinit();

    std.debug.print("Archive Metadata:\n", .{});
    std.debug.print("─────────────────\n", .{});

    var it = info.metadata.entries.iterator();
    while (it.next()) |entry| {
        std.debug.print("  {s}: {s}\n", .{
            entry.key_ptr.*,
            entry.value_ptr.*,
        });
    }
}
```

## Best Practices

1. **Keep Keys Short**: Use concise, lowercase keys
2. **Use Standard Names**: Follow common conventions
3. **Include Version**: Always include a version field
4. **Add Timestamps**: Include creation/build time
5. **Document Custom Fields**: Note any application-specific fields

## Next Steps

- [API Reference](/api/types) - Metadata type documentation
- [Extracting](/guide/extracting) - Reading metadata from archives


## Managing Metadata (CLI)

You can manage metadata in existing archives using the `zigx` CLI tool:

### View Metadata
```bash
# View all metadata
zigx metadata archive.zigx get-all

# View specific key
zigx metadata archive.zigx get "version"
```

### Edit Metadata
```bash
# Set a new value
zigx metadata archive.zigx set "build_id" "b123"

# Delete a key
zigx metadata archive.zigx delete "temp_key"
```

