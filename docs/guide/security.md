# Security

ZIGX security features and best practices.

## Integrity Verification

### SHA-256 Hashes

Every file in the archive has a SHA-256 checksum:

```zig
var info = try zigx.getArchiveInfo("archive.zigx", allocator);
defer info.deinit();

for (info.checksums.items) |item| {
    std.debug.print("{s}: {x}\n", .{item.path, item.hash});
}
```

### Payload Hash

The entire compressed payload is hashed:

```zig
std.debug.print("Payload Hash: {s}\n", .{info.payload_hash[0..64]});
```

### Archive Hash

The complete archive file hash:

```zig
std.debug.print("Archive Hash: {s}\n", .{info.archive_hash[0..64]});
```

## CRC32 Verification

Each compressed block has a CRC32 checksum for quick integrity checks during decompression.

## Signing

Archive signing is supported via CLI or API. The signature is appended to the archive and the header is updated to reflect its presence.

### Sign with CLI

```bash
# Sign an archive
zigx sign archive.zigx "my-signature-data"
```

### Sign with API

```zig
const zigx = @import("zigx");

try zigx.manager.setSignature("archive.zigx", "my-secure-signature-bytes", allocator);
```

### Sign with API

```zig
try zigx.manager.setSignature("archive.zigx", "signature-bytes", allocator);
```

Check signature status:

```zig
var info = try zigx.getArchiveInfo("archive.zigx", allocator);
if (info.is_signed) {
    std.debug.print("Archive is signed\n", .{});
}
```

## Encryption (Future)

Encryption support is planned:

```zig
// Future API
_ = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{"src"},
    .output_path = "encrypted.zigx",
    .encrypt_with = key,
});

// Decrypt
try zigx.unbundle(.{
    .archive_path = "encrypted.zigx",
    .output_dir = "decrypted",
    .allocator = allocator,
    .decrypt_with = key,
});
```

Check encryption status:

```zig
if (info.is_encrypted) {
    std.debug.print("Archive is encrypted\n", .{});
}
```

## Security Best Practices

### 1. Validate Before Extraction

```zig
// Quick check using isValid() alias
if (!zigx.isValid(path)) {
    return error.InvalidArchive;
}

// Full validation using verify() alias
const valid = try zigx.verify(.{
    .allocator = allocator,
    .archive_path = path,
});
if (!valid) {
    return error.ValidationFailed;
}
```

### 2. Verify Checksums

```zig
var info = try zigx.getArchiveInfo(path, allocator);
defer info.deinit();

// Compare against known hash
if (!std.mem.eql(u8, &info.archive_hash, expected_hash)) {
    return error.HashMismatch;
}
```

### 3. Check Version Compatibility

```zig
if (info.format_version > zigx.FORMAT_VERSION) {
    std.debug.print("Warning: Newer format version\n", .{});
}
```

### 4. Use Safe Extraction Paths

```zig
// Using unbundle() alias with safe options
try zigx.unbundle(.{
    .archive_path = path,
    .output_dir = "/safe/path",  // Use absolute paths
    .allocator = allocator,
    .overwrite = false,  // Don't overwrite by default
});
```

### 5. Limit Resource Usage

```zig
// Check archive size before extraction
if (info.original_size > MAX_ALLOWED_SIZE) {
    return error.ArchiveTooLarge;
}
```

## Path Traversal Protection

ZIGX automatically prevents path traversal attacks:

- Strips `../` sequences
- Validates path components
- Rejects absolute paths in archives

## Memory Safety

ZIGX is written in Zig with:

- No hidden memory allocations
- Explicit error handling
- Bounds checking
- No undefined behavior

## See Also

- [Validation](/guide/validation) - Integrity checking
- [Format Specification](/guide/format) - Security fields
