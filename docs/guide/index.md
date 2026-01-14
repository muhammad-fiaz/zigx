# What is ZIGX?

ZIGX is a high-performance compression library written in Zig for bundling files and directories.

## Features

- **Zstandard Compression**: Industry-leading zstd algorithm via Zig bindings
- **Excellent Ratios**: ~80% space savings on typical data, up to 99.9% on repetitive data
- **Blazing Fast**: 115+ MB/s compression, 135+ MB/s decompression
- **Versioned Format**: Track format and compression versions
- **Security**: SHA-256 checksums and CRC32 verification
- **Simple API**: Easy-to-use with function aliases

## Why ZIGX?

### Performance

| Mode | zstd Level | Ratio | Description |
|------|------------|-------|-------------|
| BEST | 19 | ~19% | Maximum compression |
| DEFAULT | 3 | ~21% | Balanced |
| FAST | 1 | ~25% | Speed optimized |

### Versioning

ZIGX uses dual versioning:

1. **Format Version** (v1): Archive container format
2. **Compression Version** (v1): Zstandard (zstd) algorithm

This ensures:
- Future compatibility
- Easy migration when algorithms improve
- Clear tracking of capabilities

### Security

- SHA-256 checksums for file integrity
- CRC32 verification for payload validation
- Path traversal protection
