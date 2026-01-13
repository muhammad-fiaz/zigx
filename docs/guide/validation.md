# Validation

Ensure archive integrity with ZIGX validation tools.

## Quick Validation

```zig
const zigx = @import("zigx");

// Quick check using isValid() alias - returns bool
if (zigx.isValid("archive.zigx")) {
    std.debug.print("Valid archive\n", .{});
}
```

## Detailed Validation

```zig
// Using verify() alias for full validation
const result = try zigx.verify(.{
    .allocator = allocator,
    .archive_path = "archive.zigx",
});

if (result) {
    std.debug.print("Archive is valid\n", .{});
}
```

## Validation Checks

ZIGX performs these validation checks:

1. **Magic Bytes**: Verify `ZIGX` header
2. **Format Version**: Check supported version
3. **Header Integrity**: Validate header fields
4. **Payload Hash**: Verify SHA-256 hash
5. **File Checksums**: Validate each file's hash
6. **CRC32**: Check compression integrity

## Corruption Detection

```zig
if (try zigx.detectCorruption("archive.zigx", allocator)) |info| {
    std.debug.print("Corruption detected:\n", .{});
    std.debug.print("  Type: {s}\n", .{@tagName(info.corruption_type)});
    std.debug.print("  Offset: {d}\n", .{info.offset});
    std.debug.print("  Details: {s}\n", .{info.description});
}
```

### Corruption Types

| Type | Description |
|------|-------------|
| `header_corruption` | Invalid header data |
| `metadata_corruption` | Malformed metadata |
| `checksum_mismatch` | File hash doesn't match |
| `payload_corruption` | Compressed data corrupted |
| `truncated` | Archive incomplete |

## Complete Example

```zig
const std = @import("std");
const zigx = @import("zigx");

pub fn validateArchive(path: []const u8, allocator: Allocator) !void {
    // Step 1: Quick check
    if (!zigx.isValid(path)) {
        std.debug.print("Not a valid ZIGX archive\n", .{});
        return error.InvalidArchive;
    }

    // Step 2: Full validation with verify()
    const valid = try zigx.verify(.{
        .allocator = allocator,
        .archive_path = path,
    });

    if (valid) {
        std.debug.print("Archive passed all validation checks\n", .{});
    } else {
        std.debug.print("Validation failed\n", .{});
        return error.ValidationFailed;
    }

    // Step 3: Check for specific corruption
    if (try zigx.detectCorruption(path, allocator)) |info| {
        std.debug.print("\nCorruption details:\n", .{});
        std.debug.print("  Type: {s}\n", .{@tagName(info.corruption_type)});
        std.debug.print("  Location: offset {d}\n", .{info.offset});
    }

    // Step 4: Show archive info
    var info = try zigx.getArchiveInfo(path, allocator);
    defer info.deinit();

    std.debug.print("\nArchive Info:\n", .{});
    std.debug.print("  Format: v{d}\n", .{info.format_version});
    std.debug.print("  Files: {d}\n", .{info.file_count});
    std.debug.print("  Payload Hash: {s}...\n", .{info.payload_hash[0..16]});
}
```

## Best Practices

1. **Always validate before extraction**
2. **Use detailed validation for debugging**
3. **Log validation errors for troubleshooting**
4. **Check version compatibility**

## See Also

- [Security](/guide/security) - Security features
- [API Reference](/api/validate) - Validation API
