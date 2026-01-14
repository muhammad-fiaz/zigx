# Security Policy

## Supported Versions

ZIGX file format support policy:

| Version | Format | Status |
| :--- | :--- | :--- |
| 0.0.1 | v1 | :white_check_mark: Supported |

## Security Features

ZIGX includes built-in security features to detect data corruption and tampering:

1. **SHA-256 Payload Hash** - Verifies the entire payload integrity
2. **Per-File Checksums** - Validates individual file content
3. **CRC32 Compression Check** - Ensures compressed data validity
4. **Header Validation** - Magic bytes and structure verification
5. **Path Normalization** - Prevents directory traversal attacks
6. **Bounds Checking** - Memory-safe implementation in Zig
7. **Version Checking** - Prevents processing unsupported formats

## Reporting a Vulnerability

Please report vulnerabilities to the maintainers via GitHub Issues or private email.

## Validation & Corruption Detection

The library provides robust tools for validation and corruption recovery:

- `isValid(path)` - Quick header check
- `verify(options)` - Full cryptographic verification
- `detectCorruption(path)` - Identifies specific corruption types

### Error Handling

The library is designed to handle all exceptions gracefully:

- **InvalidMagic** - File is not a valid ZIGX archive
- **UnsupportedVersion** - Format version is not supported
- **ChecksumMismatch** - Data has been modified/corrupted
- **FileToLarge** - Data exceeds memory limits (memory-safe)
- **UnexpectedEndOfStream** - Truncated file detection

Attempts to read corrupt archives will return secure error codes rather than crashing. All buffer allocations are bounded and checked.

### How to Report

1. **Do not** open a public issue for security vulnerabilities
2. Email security concerns to the maintainer directly
3. Include detailed information about the vulnerability:
   - Description of the issue
   - Steps to reproduce
   - Potential impact
   - Any suggested fixes

### What to Expect

- Acknowledgment within 48 hours
- Regular updates on the fix progress
- Credit in the security advisory (if desired)

## Security Features

ZIGX implements several security measures:

### Integrity Verification

- **SHA-256 Checksums**: Every file has a cryptographic hash
- **CRC32 Verification**: Payload integrity checks during decompression
- **Payload Hash**: Complete payload is hashed for validation

### Path Security

- **Path Traversal Prevention**: Blocks `../` and absolute paths
- **Symlink Validation**: Prevents symlink escape attacks
- **Null Byte Detection**: Rejects paths with null bytes
- **Maximum Path Length**: Configurable limits (default 4096)

### Archive Validation

```zig
// Validate archive integrity before extraction
const is_valid = try zigx.validate("archive.zigx", allocator);

// Detailed validation with error information
const result = try zigx.validateDetailed("archive.zigx", allocator);
if (!result.is_valid) {
    for (result.errors) |err| {
        std.debug.print("Error: {s}\n", .{err});
    }
}
```

### Secure Extraction

```zig
// Extract with validation enabled (default)
try zigx.extract(.{
    .archive_path = "archive.zigx",
    .output_dir = "output",
    .allocator = allocator,
    .validate = true,  // Validates checksums during extraction
});
```

## Best Practices

### Creating Archives

1. Use checksums (enabled by default)
2. Validate source files before bundling
3. Use exclude patterns for sensitive files

```zig
const result = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{"src"},
    .exclude = &.{".env", "*.key", "secrets/"},
    .output_path = "bundle.zigx",
});
```

### Extracting Archives

1. Always validate archives from untrusted sources
2. Check archive info before extraction
3. Extract to isolated directories

```zig
// Check archive before extraction
var info = try zigx.getArchiveInfo("untrusted.zigx", allocator);
defer info.deinit();

// Verify it's a valid ZIGX archive
if (!zigx.isValid("untrusted.zigx")) {
    return error.InvalidArchive;
}

// Extract with validation
try zigx.extract(.{
    .archive_path = "untrusted.zigx",
    .output_dir = "isolated/output",
    .allocator = allocator,
    .validate = true,
});
```

## Future Security Features

Planned security enhancements:

- **Digital Signatures**: Sign archives with Ed25519
- **Encryption**: AES-256-GCM encryption support
- **Key Management**: Secure key derivation and storage

## Security Advisories

No security advisories at this time.

## Contact

For security-related inquiries, please contact the project maintainer through GitHub.
