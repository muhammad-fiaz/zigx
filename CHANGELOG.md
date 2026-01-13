# Changelog

All notable changes to ZIGX are documented in this file.

## [0.0.1] - Initial Release

### Added

- Stable 128-byte archive header
- Magic bytes: `ZIGX`
- SHA-256 payload hash
- Signing and encryption flags (reserved for future use)
- Metadata key-value storage
- File checksums with SHA-256
- LZ77+RLE hybrid compression algorithm
- 64KB sliding window
- Lazy matching optimization
- CRC32 checksums for integrity
- Four compression levels: BEST, DEFAULT, FAST, STORE
- Simplified `include` option for files and directories
- Simplified `exclude` option for patterns
- Function aliases: `bundle()`, `unbundle()`, `verify()`, `list()`, `isValid()`
- Core functions: `getArchiveInfo()`, `compress()`, `extract()`, `listFiles()`, `validate()`, `detectCorruption()`
- Glob-style pattern matching for exclude patterns
- Error handling for corrupted files and unsupported formats
- VitePress documentation site
- Build integration with Zig build system

