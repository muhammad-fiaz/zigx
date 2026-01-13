# validate

Validate ZIGX archive integrity.

## isValidArchive

Quick check if a file is a valid ZIGX archive.

```zig
pub fn isValidArchive(path: []const u8) bool
```

### Usage

```zig
if (zigx.isValidArchive("bundle.zigx")) {
    std.debug.print("Valid archive\n", .{});
} else {
    std.debug.print("Invalid or corrupted\n", .{});
}
```

## validate

Validate archive and return pass/fail.

```zig
pub fn validate(
    path: []const u8,
    allocator: Allocator
) ValidationError!bool
```

### Usage

```zig
const is_valid = try zigx.validate("bundle.zigx", allocator);
if (is_valid) {
    std.debug.print("Archive is valid\n", .{});
}
```

## validateDetailed

Get detailed validation results.

```zig
pub fn validateDetailed(
    path: []const u8,
    allocator: Allocator
) ValidationError!ValidationResult
```

### ValidationResult

```zig
pub const ValidationResult = struct {
    is_valid: bool,
    errors: []const []const u8,
    warnings: []const []const u8,
};
```

### Usage

```zig
const result = try zigx.validateDetailed("bundle.zigx", allocator);

if (!result.is_valid) {
    std.debug.print("Validation failed:\n", .{});
    for (result.errors) |err| {
        std.debug.print("  Error: {s}\n", .{err});
    }
}

for (result.warnings) |warn| {
    std.debug.print("  Warning: {s}\n", .{warn});
}
```

## detectCorruption

Detect specific corruption type.

```zig
pub fn detectCorruption(
    path: []const u8,
    allocator: Allocator
) !?CorruptionInfo
```

### CorruptionInfo

```zig
pub const CorruptionInfo = struct {
    corruption_type: CorruptionType,
    offset: u64,
    description: []const u8,
};

pub const CorruptionType = enum {
    header_corruption,
    metadata_corruption,
    checksum_mismatch,
    payload_corruption,
    truncated,
};
```

### Usage

```zig
if (try zigx.detectCorruption("bundle.zigx", allocator)) |info| {
    std.debug.print("Corruption detected:\n", .{});
    std.debug.print("  Type: {s}\n", .{@tagName(info.corruption_type)});
    std.debug.print("  Offset: {d}\n", .{info.offset});
    std.debug.print("  Description: {s}\n", .{info.description});
}
```

## Errors

| Error | Description |
|-------|-------------|
| `FileNotFound` | Archive not found |
| `InvalidMagic` | Wrong magic bytes |
| `InvalidVersion` | Unsupported version |
| `ChecksumMismatch` | Data corruption |
| `Corrupted` | General corruption |

## Complete Example

```zig
const std = @import("std");
const zigx = @import("zigx");

pub fn validateArchive(path: []const u8, allocator: Allocator) !void {
    // Quick check
    if (!zigx.isValidArchive(path)) {
        std.debug.print("Not a valid ZIGX archive\n", .{});
        return;
    }

    // Detailed validation
    const result = try zigx.validateDetailed(path, allocator);
    
    if (result.is_valid) {
        std.debug.print("Archive is valid\n", .{});
    } else {
        std.debug.print("Validation failed:\n", .{});
        for (result.errors) |err| {
            std.debug.print("  - {s}\n", .{err});
        }
    }

    // Check for specific corruption
    if (try zigx.detectCorruption(path, allocator)) |info| {
        std.debug.print("\nCorruption details:\n", .{});
        std.debug.print("  Type: {s}\n", .{@tagName(info.corruption_type)});
        std.debug.print("  At offset: {d}\n", .{info.offset});
    }
}
```

## See Also

- [getArchiveInfo](/api/get-archive-info) - Get archive info
- [Validation Guide](/guide/validation) - Complete guide
