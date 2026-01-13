const std = @import("std");
const Allocator = std.mem.Allocator;
const utils = @import("utils.zig");
const config = @import("config.zig");

pub const SecurityError = error{
    PathTraversal,
    AbsolutePath,
    SymlinkEscape,
    DuplicatePath,
    NullBytesInPath,
    EmptyPath,
    InvalidPathCharacters,
    PathTooLong,
};

// Use compile-time default values from SecurityConfig
const default_security = config.SecurityConfig{};
pub const MAX_PATH_LENGTH: usize = default_security.max_path_length;
pub const MAX_COMPONENT_LENGTH: usize = default_security.max_component_length;

pub fn validatePath(path: []const u8) SecurityError!void {
    if (path.len == 0) return SecurityError.EmptyPath;
    if (path.len > MAX_PATH_LENGTH) return SecurityError.PathTooLong;
    if (std.mem.indexOfScalar(u8, path, 0) != null) return SecurityError.NullBytesInPath;
    if (utils.isAbsolutePath(path)) return SecurityError.AbsolutePath;
    if (utils.containsPathTraversal(path)) return SecurityError.PathTraversal;
    var iter = std.mem.splitScalar(u8, path, '/');
    while (iter.next()) |component| {
        if (component.len == 0) continue;
        if (component.len > MAX_COMPONENT_LENGTH) return SecurityError.PathTooLong;
        if (std.mem.indexOfScalar(u8, component, '\\') != null) {
            if (utils.containsPathTraversal(component)) return SecurityError.PathTraversal;
        }
    }
}

fn isAbsolutePath(path: []const u8) bool {
    return utils.isAbsolutePath(path);
}

fn isAbsolutePathLocal(path: []const u8) bool {
    if (path.len > 0 and path[0] == '/') return true;
    if (path.len >= 2) {
        if (std.ascii.isAlphabetic(path[0]) and path[1] == ':') return true;
    }
    if (path.len >= 2 and path[0] == '\\' and path[1] == '\\') return true;
    return false;
}

fn containsPathTraversal(path: []const u8) bool {
    var normalized: [MAX_PATH_LENGTH]u8 = undefined;
    const len = @min(path.len, MAX_PATH_LENGTH);
    for (path[0..len], 0..) |c, i| {
        normalized[i] = if (c == '\\') '/' else c;
    }
    const norm_path = normalized[0..len];
    if (std.mem.startsWith(u8, norm_path, "../")) return true;
    if (std.mem.eql(u8, norm_path, "..")) return true;
    if (std.mem.indexOf(u8, norm_path, "/../") != null) return true;
    if (std.mem.endsWith(u8, norm_path, "/..")) return true;
    return false;
}

pub fn validateSymlinkTarget(symlink_path: []const u8, target: []const u8, project_root: []const u8) SecurityError!void {
    _ = symlink_path;
    _ = project_root;
    try validatePath(target);
    if (isAbsolutePath(target)) return SecurityError.SymlinkEscape;
    var depth: i32 = 0;
    var iter = std.mem.splitScalar(u8, target, '/');
    while (iter.next()) |component| {
        if (component.len == 0) continue;
        if (std.mem.eql(u8, component, "..")) {
            depth -= 1;
            if (depth < 0) return SecurityError.SymlinkEscape;
        } else if (!std.mem.eql(u8, component, ".")) {
            depth += 1;
        }
    }
}

pub const DuplicateTracker = struct {
    paths: std.StringHashMapUnmanaged(void),
    allocator: Allocator,

    pub fn init(allocator: Allocator) DuplicateTracker {
        return .{ .paths = .{}, .allocator = allocator };
    }

    pub fn deinit(self: *DuplicateTracker) void {
        self.paths.deinit(self.allocator);
    }

    pub fn addPath(self: *DuplicateTracker, path: []const u8) SecurityError!void {
        const result = self.paths.getOrPut(self.allocator, path) catch return SecurityError.DuplicatePath;
        if (result.found_existing) return SecurityError.DuplicatePath;
    }

    pub fn contains(self: *const DuplicateTracker, path: []const u8) bool {
        return self.paths.contains(path);
    }
};

pub fn normalizePath(allocator: Allocator, path: []const u8) Allocator.Error![]u8 {
    var result = std.ArrayListUnmanaged(u8){};
    errdefer result.deinit(allocator);
    var iter = std.mem.splitScalar(u8, path, '/');
    var first = true;
    while (iter.next()) |component| {
        if (component.len == 0 or std.mem.eql(u8, component, ".")) continue;
        if (!first) try result.append(allocator, '/');
        try result.appendSlice(allocator, component);
        first = false;
    }
    return result.toOwnedSlice(allocator);
}

test "valid_paths" {
    try validatePath("src/main.zig");
    try validatePath("build.zig");
    try validatePath("src/utils/helper.zig");
    try validatePath("LICENSE");
}

test "path_traversal" {
    try std.testing.expectError(SecurityError.PathTraversal, validatePath("../escape.txt"));
    try std.testing.expectError(SecurityError.PathTraversal, validatePath("src/../../../etc/passwd"));
    try std.testing.expectError(SecurityError.PathTraversal, validatePath(".."));
    try std.testing.expectError(SecurityError.PathTraversal, validatePath("src/.."));
}

test "absolute_paths" {
    try std.testing.expectError(SecurityError.AbsolutePath, validatePath("/etc/passwd"));
    try std.testing.expectError(SecurityError.AbsolutePath, validatePath("C:\\Windows\\System32"));
    try std.testing.expectError(SecurityError.AbsolutePath, validatePath("\\\\server\\share"));
}

test "empty_path" {
    try std.testing.expectError(SecurityError.EmptyPath, validatePath(""));
}

test "null_bytes" {
    try std.testing.expectError(SecurityError.NullBytesInPath, validatePath("src\x00/main.zig"));
}

test "duplicate_tracker" {
    var tracker = DuplicateTracker.init(std.testing.allocator);
    defer tracker.deinit();
    try tracker.addPath("src/main.zig");
    try tracker.addPath("build.zig");
    try std.testing.expectError(SecurityError.DuplicatePath, tracker.addPath("src/main.zig"));
}

test "normalize_path" {
    const allocator = std.testing.allocator;
    const result1 = try normalizePath(allocator, "src//main.zig");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("src/main.zig", result1);
    const result2 = try normalizePath(allocator, "./src/./utils/./file.zig");
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("src/utils/file.zig", result2);
}

test "symlink_valid" {
    try validateSymlinkTarget("src/link", "utils/helper.zig", "/project");
    try validateSymlinkTarget("src/link", "file.zig", "/project");
}

test "symlink_escape" {
    try std.testing.expectError(SecurityError.AbsolutePath, validateSymlinkTarget("src/link", "/etc/passwd", "/project"));
}
