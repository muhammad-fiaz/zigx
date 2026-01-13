# unbundle / extract

Extract files from a ZIGX archive.

## Functions

```zig
pub fn extract(options: ExtractOptions) ExtractionError!void
pub const unbundle = extract;  // Alias

pub fn extractWithResult(options: ExtractOptions) ExtractionError!ExtractResult
pub const unbundleWithResult = extractWithResult;  // Alias
```

## Options

```zig
pub const ExtractOptions = struct {
    /// Path to archive file (required)
    archive_path: []const u8,
    
    /// Output directory (required)
    output_dir: []const u8,
    
    /// Memory allocator (required)
    allocator: Allocator,
    
    /// Validate checksums during extraction
    validate: bool = true,
    
    /// Overwrite existing files
    overwrite: bool = false,
};
```

## Result

```zig
pub const ExtractResult = struct {
    files_extracted: usize,
    bytes_written: u64,
    files: []const []const u8,

    pub fn deinit(self: *ExtractResult) void;
};
```

## Usage

### Basic

```zig
try zigx.unbundle(.{
    .archive_path = "bundle.zigx",
    .output_dir = "output",
    .allocator = allocator,
});
```

### With Result

```zig
var result = try zigx.unbundleWithResult(.{
    .archive_path = "bundle.zigx",
    .output_dir = "output",
    .allocator = allocator,
    .validate = true,
    .overwrite = true,
});
defer result.deinit();

std.debug.print("Extracted {d} files ({d} bytes)\n", .{
    result.files_extracted,
    result.bytes_written,
});
```

## listFiles / list

List files in archive without extracting.

```zig
pub fn listFiles(archive_path: []const u8, allocator: Allocator) ![]const []const u8
pub const list = listFiles;  // Alias
```

### Usage

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

## Errors

| Error | Description |
|-------|-------------|
| `FileNotFound` | Archive not found |
| `InvalidFormat` | Not a valid ZIGX archive |
| `ChecksumMismatch` | File integrity error |
| `DecompressionFailed` | Decompression error |
| `CannotCreateDirectory` | Cannot create output dir |
| `CannotWriteFile` | Cannot write file |
| `FileExists` | File exists (overwrite=false) |
