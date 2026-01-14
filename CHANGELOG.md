# Changelog

All notable changes to ZIGX are documented in this file.

## [Unreleased]

### Added
- **Metadata Management**: API and CLI commands (`get`, `set`, `delete`, `get-all`) for managing archive metadata without full decompression.
- **Signing Support**: `setSignature` API and `sign` CLI command.
- **Improved CLI**: New `metadata` and `sign` commands in example CLI.
- **Efficiency**: Optimized file operations using shared utilities.

### Fixed
- **32-bit Platform Support**: Fixed type mismatch error (`expected type 'usize', found 'u64'`) on 32-bit targets (x86-windows, arm-linux, x86-linux) in `manager.zig` and `validator.zig`.

### Changed
- **Compression**: Refactored internal configuration to strict Zstd levels (1-22).

## [0.0.1] - Initial Release

### Added

- **Format Version 1**: Stable archive format with versioning
  - 128-byte header with magic bytes, flags, and checksums
  - SHA-256 payload hash
  - Support for signing and encryption flags (reserved for future)

- **Compression Version 1**: Zstandard (zstd) algorithm
  - Industry-leading compression ratios via zstd.zig bindings
  - Levels 1-19 (fast to best compression)
  - Extremely fast decompression (~135 MB/s)
  - CRC32 checksums for integrity verification
  - Multiple compression levels: BEST, DEFAULT, FAST, STORE

- **Unified API**
  - `include` option for files and directories
  - `exclude` option for pattern-based filtering
  - Function aliases: `bundle()`, `unbundle()`, `verify()`, `list()`, `isValid()`

- **Core Functions**
  - `getArchiveInfo()`: Get comprehensive archive metadata
  - `bundle()` / `compress()`: Create archives
  - `unbundle()` / `extract()`: Extract archives
  - `verify()` / `validate()`: Validate archive integrity
  - `list()` / `listFiles()`: List archive contents
  - `isValid()` / `isValidArchive()`: Quick validity check
  - `detectCorruption()`: Detect corruption type

- **Exclude Patterns**
  - Glob-style pattern matching (`*.tmp`, `node_modules`)
  - Directory pattern support
  - Wildcard prefix and suffix patterns

- **Example Application** (`examples/self_bundle.zig`)
  - `bundle` command: Create archives
  - `debundle` command: Extract archives
  - `info` command: Display archive information
  - `list` command: List files in archive
  - `compare` command: Compare compression levels
  - `help` command: Show usage information

- **Build Integration**
  - Single executable with subcommands
  - Shortcut build steps: `zig build bundle`, `zig build debundle`
  - Test runner integration

- **Documentation**
  - VitePress documentation site
  - API reference
  - Usage guides and examples

### Technical Details

#### Format Specification

| Section | Size | Description |
|---------|------|-------------|
| Magic | 4 bytes | `ZIGX` |
| Version | 2 bytes | `0x0001` |
| Flags | 4 bytes | Compression type, signed, encrypted |
| Metadata | Variable | Key-value pairs |
| Checksums | Variable | File hashes |
| Payload | Variable | Compressed data |

#### Compression Performance

| Level | zstd Level | Typical Ratio | Use Case |
|-------|------------|---------------|----------|
| BEST | 19 | 19-25% | Distribution |
| DEFAULT | 3 | 21-28% | General use |
| FAST | 1 | 25-33% | Development |
| STORE | - | 100%+ | Pre-compressed |

#### Compatibility

- Zig 0.15.0 or later required
- Cross-platform: Windows, macOS, Linux

## Planned Features

- Digital signature implementation
- Encryption support
- Streaming compression API
- Progress callbacks
- Delta compression
- Multi-threaded compression
- Archive merging
- Partial extraction
