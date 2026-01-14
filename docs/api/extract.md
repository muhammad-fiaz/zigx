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
    
    /// Progress callback for tracking extraction progress
    progress_callback: ?ExtractProgressCallback = null,
    
    /// Context for progress callback
    progress_context: ?*anyopaque = null,
};
```

## Progress Callback Types

```zig
/// Progress event types for extraction operations
pub const ExtractProgressEvent = enum {
    started,          // Extraction started
    reading_archive,  // Reading archive file
    decompressing,    // Decompressing data
    extracting_file,  // Extracting a file
    verifying,        // Verifying checksums
    completed,        // Extraction completed
};

/// Progress info for extraction callbacks
pub const ExtractProgressInfo = struct {
    event: ExtractProgressEvent,
    current_file: ?[]const u8 = null,
    files_extracted: usize = 0,
    total_files: usize = 0,
    bytes_written: u64 = 0,
    total_bytes: u64 = 0,

    /// Get progress percentage (0-100)
    pub fn getPercent(self: *const ExtractProgressInfo) f64;
};

/// Progress callback function type for extraction
pub const ExtractProgressCallback = *const fn (info: ExtractProgressInfo, context: ?*anyopaque) void;
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

### With Progress Callback

```zig
fn onExtractProgress(info: zigx.ExtractProgressInfo, ctx: ?*anyopaque) void {
    _ = ctx;
    switch (info.event) {
        .started => std.debug.print("Starting extraction...\n", .{}),
        .extracting_file => {
            std.debug.print("\r[{d}/{d}] {d:.1}% - {s}", .{
                info.files_extracted,
                info.total_files,
                info.getPercent(),
                info.current_file orelse "...",
            });
        },
        .completed => std.debug.print("\nExtraction complete!\n", .{}),
        else => {},
    }
}

try zigx.unbundle(.{
    .archive_path = "bundle.zigx",
    .output_dir = "output",
    .allocator = allocator,
    .progress_callback = onExtractProgress,
    .progress_context = null,
});
```

### Progress Events

| Event | Description |
|-------|-------------|
| `started` | Extraction started |
| `reading_archive` | Reading archive header/metadata |
| `decompressing` | Decompressing payload |
| `extracting_file` | Writing a file to disk |
| `verifying` | Verifying file checksums |
| `completed` | Extraction completed |

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
| `FileNotFound` | Archive file not found |
| `InvalidFormat` | Invalid ZIGX format |
| `PathTraversal` | Path traversal attack detected |
| `ChecksumMismatch` | File checksum verification failed |
| `DecompressionFailed` | Decompression error |
| `FileExists` | Output file exists (overwrite=false) |
| `IoError` | Read/write error |

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
