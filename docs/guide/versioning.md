# Versioning

ZIGX uses versioning to ensure compatibility.

## Version Numbers

### Library Version

```zig
pub const VERSION = "0.0.1";
```

Follows Semantic Versioning:
- **Major**: Breaking API changes
- **Minor**: New features, backward compatible
- **Patch**: Bug fixes

### Format Version

```zig
pub const FORMAT_VERSION: u16 = 0x0001;  // v1
```

Stored in archive header. Changes when:
- Header structure changes
- New sections added
- Metadata format changes

### Compression Version

```zig
pub const COMPRESSION_VERSION: u8 = 1;
```

Stored in payload header. Changes when:
- Compression algorithm updated
- New compression features added
- Encoding changes

## Why Separate Versions?

1. **Independent Updates**: Improve compression without changing format
2. **Backward Compatibility**: Read old archives with new library
3. **Forward Compatibility**: Identify unsupported features
4. **Clear Tracking**: Know exactly what an archive supports

## Checking Versions

```zig
const zigx = @import("zigx");

// Library version
std.debug.print("Library: {s}\n", .{zigx.VERSION});

// From archive
var info = try zigx.getArchiveInfo("archive.zigx", allocator);
defer info.deinit();

std.debug.print("Format: v{d}\n", .{info.format_version});
std.debug.print("Compression: v{d}\n", .{info.compression_version});
```

## Compatibility

| Archive v | Library v | Compatible |
|-----------|-----------|------------|
| 1 | 0.0.1 | Yes |
| 1 | Future | Yes |
| Future | 0.0.1 | May need upgrade |
