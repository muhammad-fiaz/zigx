# Archive Manager API

The `zigx.manager` namespace provides advanced operations for manipulating existing archives without full re-creation.

## Update

Modify an existing archive by adding or removing files. This operation extracts the archive to a temporary directory, modifies the files, and re-bundles it.

### `manager.update`

```zig
pub fn update(options: UpdateOptions) ManagerError!void
```

**Parameters** (`UpdateOptions`):

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `allocator` | `Allocator` | Required | Memory allocator |
| `archive_path` | `[]const u8` | Required | Path to the archive to update |
| `add_files` | `?[]const []const u8` | `null` | List of file paths to add |
| `remove_patterns` | `?[]const []const u8` | `null` | List of patterns to remove results for |
| `output_path` | `?[]const u8` | `null` | Output path (if null, updates in-place) |
| `compression_level` | `CompressionLevel` | `.best` | Compression level for re-bundling |

**Example**:

```zig
const zigx = @import("zigx");

// Add 'new_file.txt' and remove all '.tmp' files
try zigx.manager.update(.{
    .allocator = allocator,
    .archive_path = "archive.zigx",
    .add_files = &.{"new_file.txt"},
    .remove_patterns = &.{"*.tmp"},
});
```

---

## Repair

Attempt to recover a corrupted archive. This scans for valid headers and file boundaries.

### `manager.repair`

```zig
pub fn repair(archive_path: []const u8, output_path: []const u8, allocator: Allocator) ManagerError!RepairResult
```

**Parameters**:

- `archive_path`: Path to corrupted archive.
- `output_path`: Where to save the repaired archive.
- `allocator`: Memory allocator.

**Returns** `RepairResult`:

```zig
pub const RepairResult = struct {
    was_corrupted: bool,      // True if the original file had issues
    recovered_files: usize,   // Number of files successfully recovered
    total_bytes: u64,         // Total size of recovered payload
};
```

**Example**:

```zig
const result = try zigx.manager.repair("corrupt.zigx", "fixed.zigx", allocator);
if (result.was_corrupted) {
    std.debug.print("Repaired! Recovered {d} files.\n", .{result.recovered_files});
}
```

---

## Metadata

Perform efficient, in-place updates of the archive metadata (key-value pairs) without re-compressing the payload.

### `manager.getMetadata`

Retrieve a single metadata value.

```zig
pub fn getMetadata(path: []const u8, key: []const u8, allocator: Allocator) ManagerError!?[]const u8
```

- Returns the value as a new allocated string, or `null` if the key is missing.
- Caller owns the returned memory.

### `manager.getAllMetadata`

Retrieve all metadata entries.

```zig
pub fn getAllMetadata(path: []const u8, allocator: Allocator) ManagerError!std.StringHashMapUnmanaged([]const u8)
```

- Returns a hash map of all keys and values.
- keys and values are allocated duplicates; caller must free them and the map.

### `manager.updateMetadata`

Update metadata entries (set or delete).

```zig
pub fn updateMetadata(archive_path: []const u8, updates: []const MetadataUpdate, allocator: Allocator) ManagerError!void
```

**Parameters**:

- `archive_path`: Path to the archive.
- `updates`: Slice of `MetadataUpdate` structs.

```zig
pub const MetadataOp = union(enum) {
    set: []const u8,
    delete,
};

pub const MetadataUpdate = struct {
    key: []const u8,
    op: MetadataOp,
};
```

**Behavior**:
- Rewrites the archive header and metadata block.
- Streams the existing compressed payload (zero-copy) to a new temporary file, then renames it.
- **Note**: This operation invalidates any existing signature.

**Example**:

```zig
// Set 'author' and delete 'temp_key'
const updates = &[_]zigx.manager.MetadataUpdate{
    .{ .key = "author", .op = .{ .set = "Alice" } },
    .{ .key = "temp_key", .op = .delete },
};

try zigx.manager.updateMetadata("archive.zigx", updates, allocator);
```

---

## Signing

Cryptographically sign the archive for tamper evidence.

### `manager.setSignature`

Appends a signature to the archive and updates the header flags.

```zig
pub fn setSignature(archive_path: []const u8, signature: []const u8, allocator: Allocator) ManagerError!void
```

**Behavior**:
- Updates the header to set `flags.signed = 1` and `signature_length`.
- Appends the raw signature bytes to the end of the file.
- Truncates any existing data after the calculated end of the archive (removes old signature/garbage).

**Example**:

```zig
try zigx.manager.setSignature("archive.zigx", "my-secure-signature-bytes", allocator);
```
