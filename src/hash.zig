const std = @import("std");
const Allocator = std.mem.Allocator;
const utils = @import("utils.zig");

// Re-export constants from utils
pub const HASH_SIZE = utils.HASH_SIZE;
pub const HASH_HEX_SIZE = utils.HASH_HEX_SIZE;
pub const Sha256 = std.crypto.hash.sha2.Sha256;

pub fn hashBytes(data: []const u8) [HASH_SIZE]u8 {
    var hasher = Sha256.init(.{});
    hasher.update(data);
    return hasher.finalResult();
}

pub fn hashHex(data: []const u8) [HASH_HEX_SIZE]u8 {
    const bytes = hashBytes(data);
    return bytesToHex(&bytes);
}

pub fn bytesToHex(bytes: *const [HASH_SIZE]u8) [HASH_HEX_SIZE]u8 {
    return utils.hashBytesToHex(bytes);
}

pub fn hexToBytes(hex: *const [HASH_HEX_SIZE]u8) ![HASH_SIZE]u8 {
    var result: [HASH_SIZE]u8 = undefined;
    try utils.hexToBytes(hex, &result);
    return result;
}

pub const StreamingHasher = struct {
    hasher: Sha256,

    pub fn init() StreamingHasher {
        return .{ .hasher = Sha256.init(.{}) };
    }

    pub fn update(self: *StreamingHasher, data: []const u8) void {
        self.hasher.update(data);
    }

    pub fn finalBytes(self: *StreamingHasher) [HASH_SIZE]u8 {
        return self.hasher.finalResult();
    }

    pub fn finalHex(self: *StreamingHasher) [HASH_HEX_SIZE]u8 {
        const bytes = self.finalBytes();
        return bytesToHex(&bytes);
    }
};

pub fn hashFile(file: std.fs.File, allocator: Allocator) ![HASH_HEX_SIZE]u8 {
    const buffer_size = 64 * 1024;
    const buffer = try allocator.alloc(u8, buffer_size);
    defer allocator.free(buffer);
    var hasher = StreamingHasher.init();
    while (true) {
        const bytes_read = try file.read(buffer);
        if (bytes_read == 0) break;
        hasher.update(buffer[0..bytes_read]);
    }
    return hasher.finalHex();
}

pub fn hashFilePath(path: []const u8, allocator: Allocator) ![HASH_HEX_SIZE]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    return hashFile(file, allocator);
}

pub fn verifyHash(data: []const u8, expected: *const [HASH_HEX_SIZE]u8) bool {
    const actual = hashHex(data);
    return std.mem.eql(u8, &actual, expected);
}

pub fn verifyFileHash(file: std.fs.File, expected: *const [HASH_HEX_SIZE]u8, allocator: Allocator) !bool {
    const actual = try hashFile(file, allocator);
    return std.mem.eql(u8, &actual, expected);
}

test "hash_bytes_empty" {
    const empty_hash = hashBytes("");
    const expected_empty: [HASH_SIZE]u8 = .{
        0xe3, 0xb0, 0xc4, 0x42, 0x98, 0xfc, 0x1c, 0x14,
        0x9a, 0xfb, 0xf4, 0xc8, 0x99, 0x6f, 0xb9, 0x24,
        0x27, 0xae, 0x41, 0xe4, 0x64, 0x9b, 0x93, 0x4c,
        0xa4, 0x95, 0x99, 0x1b, 0x78, 0x52, 0xb8, 0x55,
    };
    try std.testing.expectEqualSlices(u8, &expected_empty, &empty_hash);
}

test "hash_hex_empty" {
    const hex = hashHex("");
    try std.testing.expectEqualStrings("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", &hex);
}

test "hash_hex_hello" {
    const hex = hashHex("hello world");
    try std.testing.expectEqualStrings("b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9", &hex);
}

test "hex_roundtrip" {
    const original: [HASH_SIZE]u8 = .{
        0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0,
        0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0,
        0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0,
        0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0,
    };
    const hex = bytesToHex(&original);
    const restored = try hexToBytes(&hex);
    try std.testing.expectEqualSlices(u8, &original, &restored);
}

test "streaming_hasher" {
    var hasher = StreamingHasher.init();
    hasher.update("hello");
    hasher.update(" ");
    hasher.update("world");
    const result = hasher.finalHex();
    const direct = hashHex("hello world");
    try std.testing.expectEqualStrings(&direct, &result);
}

test "verify_hash" {
    const data = "test data";
    const correct_hash = hashHex(data);
    try std.testing.expect(verifyHash(data, &correct_hash));
    var wrong_hash = correct_hash;
    wrong_hash[0] = 'x';
    try std.testing.expect(!verifyHash(data, &wrong_hash));
}
