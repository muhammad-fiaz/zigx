# Exclude Patterns

Filter files and directories during bundling.

## Basic Usage

```zig
var result = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{"src", "lib"},
    .exclude = &.{
        "*.tmp",
        ".git",
        "node_modules",
    },
    .output_path = "bundle.zigx",
});
```

## Pattern Types

### Exact Match

```zig
.exclude = &.{
    ".git",           // Exact directory
    ".gitignore",     // Exact file
    "config.json",    // Exact file
}
```

### Wildcard Suffix

```zig
.exclude = &.{
    "*.tmp",          // All .tmp files
    "*.log",          // All .log files
    "*.bak",          // All .bak files
}
```

### Wildcard Prefix

```zig
.exclude = &.{
    "test_*",         // Files starting with test_
    "._*",            // macOS resource forks
}
```

### Directories

Patterns match directory names at any level:

```zig
.exclude = &.{
    "node_modules",   // Any node_modules/
    "__pycache__",    // Any __pycache__/
    "build",          // Any build/
}
```

## Common Patterns

### Development

```zig
.exclude = &.{
    // Build artifacts
    "zig-cache",
    "zig-out",
    "build",
    "dist",
    
    // Temp files
    "*.tmp",
    "*.log",
    "*.bak",
}
```

### Version Control

```zig
.exclude = &.{
    ".git",
    ".gitignore",
    ".svn",
    ".hg",
}
```

### Dependencies

```zig
.exclude = &.{
    "node_modules",
    "vendor",
    ".venv",
    "__pycache__",
}
```

### Sensitive Files

```zig
.exclude = &.{
    ".env",
    "*.key",
    "*.pem",
    "secrets",
}
```

## Complete Example

```zig
var result = try zigx.bundle(.{
    .allocator = allocator,
    .include = &.{"src", "lib", "build.zig", "README.md"},
    .exclude = &.{
        // Version control
        ".git",
        ".gitignore",
        
        // Build artifacts
        "zig-cache",
        "zig-out",
        
        // Dependencies
        "node_modules",
        
        // Temp files
        "*.tmp",
        "*.log",
        "*.bak",
        
        // Sensitive
        ".env",
        "*.key",
    },
    .output_path = "project.zigx",
});
```
