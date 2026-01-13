# bundle / compress

Create a ZIGX archive from files and directories.

## Functions

```zig
pub fn compress(options: CompressOptions) CompressError!CompressResult
pub const bundle = compress;  // Alias
```

## Options

```zig
pub const CompressOptions = struct {
    /// Memory allocator (required)
    allocator: Allocator,
    
    /// Files and directories to include
    /// Example: &.{ "src", "build.zig", "README.md" }
    include: ?[]const []const u8 = null,
    
    /// Exclude patterns (glob-style)
    /// Example: &.{ "*.tmp", ".git", "node_modules" }
    exclude: []const []const u8 = &.{},
    
    /// Output archive path
    output_path: ?[]const u8 = null,
    
    /// Base directory for relative paths
    base_dir: []const u8 = ".",
    
    /// Compression level
    level: CompressionLevel = .best,
    
    /// Enable compression (false = store mode)
    compression_enabled: bool = true,
    
    /// Auto-generate metadata
    auto_metadata: bool = true,
    
    /// Custom metadata
    metadata: StringHashMap = .{},
};
```

## Result

```zig
pub const CompressResult = struct {
    output_path: []const u8,
    archive_size: u64,
    original_size: u64,
    file_count: usize,
    archive_hash: [64]u8,
    compression_enabled: bool,

    pub fn deinit(self: *CompressResult) void;
    pub fn getCompressionRatio(self: *const CompressResult) f64;
    pub fn getCompressionPercent(self: *const CompressResult) f64;
};
```

## Usage

### Basic

```zig
const result = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{ "src", "build.zig" },
    .output_path = "bundle.zigx",
});
defer result.deinit();

std.debug.print("Created: {d} files, {d} bytes\n", .{
    result.file_count,
    result.archive_size,
});
```

### With Options

```zig
const result = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{ "src", "lib", "build.zig", "README.md" },
    .exclude = &.{ "*.tmp", ".git", "zig-cache", "node_modules" },
    .output_path = "project.zigx",
    .level = .best,
    .compression_enabled = true,
    .auto_metadata = true,
});
```

### With Metadata

```zig
var metadata = zigx.createMetadata(allocator);
defer metadata.deinit();
try metadata.set("name", "my-project");
try metadata.set("version", "1.0.0");

const result = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{"src"},
    .output_path = "project.zigx",
    .metadata = metadata.entries,
});
```

## Compression Levels

| Level | Description |
|-------|-------------|
| `.best` | Maximum compression (default) |
| `.default` | Balanced compression/speed |
| `.fast` | Speed optimized |
| `.none` | No compression (store) |

## Errors

| Error | Description |
|-------|-------------|
| `NoFilesSpecified` | No files to compress |
| `FileNotFound` | Source file not found |
| `CompressionError` | Compression failed |
| `FileSystemError` | Cannot create output |
| `IoError` | Read/write error |
| `SecurityViolation` | Path security issue |
