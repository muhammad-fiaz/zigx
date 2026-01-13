# Exclude Patterns

Filter files during bundling with exclude patterns.

## Basic Usage

```zig
const result = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{"src"},
    .output_path = "bundle.zigx",
    .exclude = &.{
        "*.tmp",
        "*.log",
        ".git",
    },
});
```

## Pattern Types

### Exact Match

```zig
.exclude = &.{
    ".git",           // Exact directory name
    "README.md",      // Exact file name
    ".gitignore",     // Exact file name
}
```

### Wildcard Suffix

```zig
.exclude = &.{
    "*.tmp",          // All .tmp files
    "*.log",          // All .log files
    "*.bak",          // All .bak files
    "*.o",            // All .o files
}
```

### Wildcard Prefix

```zig
.exclude = &.{
    "test_*",         // Files starting with test_
    "._*",            // macOS resource forks
}
```

### Directory Names

```zig
.exclude = &.{
    "node_modules",   // Any node_modules directory
    "zig-cache",      // Any zig-cache directory
    "__pycache__",    // Any __pycache__ directory
}
```

## Common Patterns

### Development Files

```zig
const DEV_PATTERNS = [_][]const u8{
    // Build artifacts
    "zig-cache",
    "zig-out",
    "*.o",
    "*.obj",
    "*.exe",
    "*.dll",
    "*.so",
    "*.dylib",

    // Editor files
    ".vscode",
    ".idea",
    "*.swp",
    "*.swo",
    "*~",

    // Temporary files
    "*.tmp",
    "*.temp",
    "*.log",
    "*.bak",
};

_ = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{"project"},
    .output_path = "project.zigx",
    .exclude = &DEV_PATTERNS,
});
```

### Node.js Project

```zig
const NODE_EXCLUDE = [_][]const u8{
    "node_modules",
    ".npm",
    "*.log",
    ".env",
    ".env.local",
    "coverage",
    ".nyc_output",
    "dist",
    "build",
};

_ = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{"my-app"},
    .output_path = "my-app.zigx",
    .exclude = &NODE_EXCLUDE,
});
```

### Git Repository

```zig
const GIT_EXCLUDE = [_][]const u8{
    ".git",
    ".gitignore",
    ".gitattributes",
    ".gitmodules",
};

_ = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{"repo"},
    .output_path = "repo.zigx",
    .exclude = &GIT_EXCLUDE,
});
```

## Pattern Matching Examples

| Pattern | Matches | Doesn't Match |
|---------|---------|---------------|
| `*.tmp` | `file.tmp`, `test.tmp` | `tmp`, `file.tmp.bak` |
| `test_*` | `test_file.zig`, `test_1` | `testing.zig`, `file_test.zig` |
| `.git` | `.git` directory | `.github`, `git-config` |
| `node_modules` | `node_modules/...` | `old_node_modules` |

## Combining Include and Exclude

```zig
// Include multiple paths, exclude patterns from all
_ = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{
        "src",
        "lib",
        "build.zig",
        "build.zig.zon",
        "README.md",
    },
    .exclude = &.{
        "*.tmp",
        "*.log",
        "test_*",
        ".git",
    },
    .output_path = "release.zigx",
    .level = .best,
});
```

## Complete Example

```zig
const std = @import("std");
const zigx = @import("zigx");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const result = try zigx.bundle(.{
        .allocator = allocator,
        .include = &.{
            "src",
            "build.zig",
            "build.zig.zon",
        },
        .exclude = &.{
            "*.tmp",
            "*.log",
            ".git",
            "zig-cache",
            "zig-out",
        },
        .output_path = "project.zigx",
        .level = .default,
    });

    std.debug.print("Files bundled: {d}\n", .{result.file_count});
    std.debug.print("Compressed size: {d} bytes\n", .{result.compressed_size});
}
```

## See Also

- [Bundling](/guide/bundling) - Complete bundling guide
- [API Reference](/api/compress) - Compress API details
