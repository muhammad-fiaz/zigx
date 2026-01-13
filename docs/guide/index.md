# What is ZIGX?

ZIGX is a high-performance compression library written in Zig for bundling files and directories.

## Features

- **LZ77+RLE Hybrid**: Advanced compression combining LZ77 with Run-Length Encoding
- **64KB Sliding Window**: Large window for better compression of repetitive data
- **Lazy Matching**: Optimized match finding for improved ratios
- **Versioned Format**: Track format and compression versions
- **Security**: SHA-256 checksums and CRC32 verification
- **Simple API**: Easy-to-use with function aliases

## Why ZIGX?

### Performance

| Mode | Ratio | Description |
|------|-------|-------------|
| BEST | ~30% | Maximum compression |
| DEFAULT | ~28% | Balanced |
| FAST | ~34% | Speed optimized |

### Versioning

ZIGX uses dual versioning:

1. **Format Version** (v1): Archive container format
2. **Compression Version** (v1): Compression algorithm

This ensures:
- Future compatibility
- Easy migration when algorithms improve
- Clear tracking of capabilities

### Security

- SHA-256 checksums for file integrity
- CRC32 verification for payload validation
- Path traversal protection
