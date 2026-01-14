# Repair and Update

ZIGX provides powerful tools for managing your archives after creation, including updating contents and repairing corrupted files.

## Updating Archives

You can add or remove files from an existing `.zigx` archive without manually extracting and re-bundling.

### Adding Files

To add files to an existing archive:

```zig
const zigx = @import("zigx");

try zigx.update(.{
    .allocator = allocator,
    .archive_path = "archive.zigx",
    .add_files = &.{ "new_file.txt", "extras/" },
});
```

Using CLI:
```bash
zigx update archive.zigx -add new_file.txt
```

### Removing Files

To remove files matching specific patterns:

```zig
try zigx.update(.{
    .allocator = allocator,
    .archive_path = "archive.zigx",
    .remove_patterns = &.{ "*.tmp", "old_folder/" },
});
```

Using CLI:
```bash
zigx update archive.zigx -rm "*.tmp"
```

## Reparing Corrupted Archives

If a `.zigx` archive becomes corrupted (e.g. truncated download, bit rot), the repair tool attempts to salvage as much data as possible.

### How Repair Works

1. **Validation**: Checks if the file is actually corrupted.
2. **Salvage**: Attempts to extract all files that are still structurally intact, correcting stream errors where possible.
3. **Re-bundle**: Creates a new valid archive containing the recovered files.

### Usage

```zig
const result = try zigx.repair("broken.zigx", "fixed.zigx", allocator);

if (result.was_corrupted) {
    std.debug.print("Repaired! Recovered {d} files.\n", .{result.recovered_files});
}
```

Using CLI:
```bash
zigx repair broken.zigx fixed.zigx
```

::: warning Limitations
Repair cannot recover data that is physically missing or completely scrambled by compression errors. It is a "best effort" tool to save what remains.
:::
