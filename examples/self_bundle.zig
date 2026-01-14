//! ZIGX Example
//!
//! Demonstrates all features of the zigx library:
//! - bundle: Create .zigx archives from files/directories
//! - unbundle: Extract .zigx archives
//! - info: View archive metadata and version
//! - list: List files in archive
//! - compare: Compare compression levels
//!
//! Run: zig build run-example

const std = @import("std");
const zigx = @import("zigx");

const Command = enum {
    bundle,
    unbundle,
    info,
    list,
    compare,
    help,
    repair,
    update,
    validate,
    metadata,
    sign,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const command = parseCommand(args);

    switch (command) {
        .bundle => try runBundle(allocator, args),
        .unbundle => try runUnbundle(allocator, args),
        .info => try runInfo(allocator, args),
        .list => try runList(allocator, args),
        .compare => try runCompare(allocator),
        .help => printHelp(),
        .repair => try runRepair(allocator, args),
        .update => try runUpdate(allocator, args),
        .validate => try runValidate(allocator, args),
        .metadata => try runMetadata(allocator, args),
        .sign => try runSign(allocator, args),
    }
}

fn parseCommand(args: []const []const u8) Command {
    if (args.len < 2) return .compare;

    const cmd = args[1];
    if (std.mem.eql(u8, cmd, "bundle") or std.mem.eql(u8, cmd, "b") or std.mem.eql(u8, cmd, "compress")) return .bundle;
    if (std.mem.eql(u8, cmd, "unbundle") or std.mem.eql(u8, cmd, "extract") or std.mem.eql(u8, cmd, "x")) return .unbundle;
    if (std.mem.eql(u8, cmd, "info") or std.mem.eql(u8, cmd, "i")) return .info;
    if (std.mem.eql(u8, cmd, "list") or std.mem.eql(u8, cmd, "l") or std.mem.eql(u8, cmd, "ls")) return .list;
    if (std.mem.eql(u8, cmd, "compare") or std.mem.eql(u8, cmd, "c")) return .compare;
    if (std.mem.eql(u8, cmd, "help") or std.mem.eql(u8, cmd, "-h") or std.mem.eql(u8, cmd, "--help")) return .help;
    if (std.mem.eql(u8, cmd, "repair") or std.mem.eql(u8, cmd, "fix")) return .repair;
    if (std.mem.eql(u8, cmd, "update") or std.mem.eql(u8, cmd, "up")) return .update;
    if (std.mem.eql(u8, cmd, "validate") or std.mem.eql(u8, cmd, "check") or std.mem.eql(u8, cmd, "v")) return .validate;
    if (std.mem.eql(u8, cmd, "metadata") or std.mem.eql(u8, cmd, "meta")) return .metadata;
    if (std.mem.eql(u8, cmd, "sign")) return .sign;

    return .compare;
}

fn printHelp() void {
    std.debug.print(
        \\
        \\ZIGX - High-performance compression for Zig projects
        \\
        \\Version: {s}
        \\Format:  v{d} (Compression v{d})
        \\
        \\Usage: zigx <command> [options]
        \\
        \\Commands:
        \\  bundle, b       Create a .zigx archive
        \\  unbundle, x     Extract a .zigx archive
        \\  info, i         Show archive information
        \\  list, ls        List files in archive
        \\  compare, c      Compare compression levels (default)
        \\  update, up      Add/Remove files from archive
        \\  repair, fix     Auto-fix corrupted archive
        \\  validate, v     Verify archive integrity
        \\  metadata, meta  Manage archive metadata
        \\  sign            Sign archive
        \\  help, -h        Show this help
        \\
        \\Examples:
        \\  zig build run-example                        Run comparison demo
        \\  zig build run-example -- bundle              Create archive
        \\  zig build run-example -- unbundle a.zigx .   Extract archive
        \\  zig build run-example -- update a.zigx -add "new.txt"
        \\  zig build run-example -- repair broken.zigx fixed.zigx
        \\  zig build run-example -- metadata a.zigx set key "value"
        \\
        \\Features:
        \\  Zstandard (zstd) Compression
        \\  Modern compression with high ratios
        \\  SHA-256 checksums, CRC32 verification
        \\  Auto-repair functionality
        \\  Include/exclude patterns for files
        \\  Versioned format for compatibility
        \\  Metadata management & Signing
        \\
        \\
    , .{ zigx.VERSION, zigx.FORMAT_VERSION, zigx.COMPRESSION_VERSION });
}

fn runBundle(allocator: std.mem.Allocator, args: []const []const u8) !void {
    std.debug.print("\n[ZIGX Bundle]\n", .{});
    std.debug.print("Format v{d}, Compression v{d}\n\n", .{ zigx.FORMAT_VERSION, zigx.COMPRESSION_VERSION });

    // Parse output path from args or use default
    var output_path: []const u8 = "dist/zigx-bundle.zigx";

    var i: usize = 2;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "-o") or std.mem.eql(u8, args[i], "--output")) {
            if (i + 1 < args.len) {
                output_path = args[i + 1];
                i += 1;
            }
        }
    }

    // Create output directory if needed
    try zigx.utils.ensureParentDir(output_path);

    std.debug.print("Creating archive with BEST compression...\n", .{});
    std.debug.print("Include: src, build.zig, build.zig.zon, LICENSE, README.md\n", .{});
    std.debug.print("Output:  {s}\n\n", .{output_path});

    var result = zigx.bundle(.{
        .allocator = allocator,
        .include = &.{ "src", "build.zig", "build.zig.zon", "LICENSE", "README.md" },
        .output_path = output_path,
        .compression_enabled = true,
        .level = .best,
        // Example: .exclude = &.{ "*.tmp", "zig-cache", ".git" },
    }) catch |err| {
        std.debug.print("Error: {}\n", .{err});
        return;
    };
    defer result.deinit();

    displayResult(&result);
    std.debug.print("\nBundle created successfully.\n\n", .{});
}

fn runUnbundle(allocator: std.mem.Allocator, args: []const []const u8) !void {
    std.debug.print("\n[ZIGX Unbundle]\n", .{});
    std.debug.print("Format v{d}, Compression v{d}\n\n", .{ zigx.FORMAT_VERSION, zigx.COMPRESSION_VERSION });

    if (args.len < 3) {
        std.debug.print("Usage: zigx unbundle <archive.zigx> [output_dir]\n", .{});
        std.debug.print("Example: zig build run-example -- unbundle dist/zigx-bundle.zigx ./extracted\n\n", .{});
        return;
    }

    const archive_path = args[2];
    const output_dir = if (args.len > 3) args[3] else "extracted";

    std.debug.print("Archive: {s}\n", .{archive_path});
    std.debug.print("Output:  {s}\n\n", .{output_dir});

    var info = zigx.getArchiveInfo(archive_path, allocator) catch |err| {
        std.debug.print("Error reading archive: {}\n", .{err});
        return;
    };
    defer info.deinit();

    std.debug.print("Archive Info:\n", .{});
    std.debug.print("  Format Version:      v{d}\n", .{info.format_version});
    std.debug.print("  Compression Version: v{d}\n", .{info.compression_version});
    std.debug.print("  Files:               {d}\n", .{info.file_count});
    std.debug.print("  Original Size:       {d} bytes\n", .{info.original_size});
    std.debug.print("  Compressed Size:     {d} bytes\n", .{info.compressed_size});
    std.debug.print("  Saved:               {d:.1}%\n\n", .{info.getSavedPercent()});

    var extract_result = zigx.unbundleWithResult(.{
        .archive_path = archive_path,
        .output_dir = output_dir,
        .allocator = allocator,
        .validate = true,
        .overwrite = true,
    }) catch |err| {
        std.debug.print("Error extracting: {}\n", .{err});
        return;
    };
    defer extract_result.deinit();

    std.debug.print("Extracted {d} files ({d} bytes) to {s}\n\n", .{
        extract_result.files_extracted,
        extract_result.bytes_written,
        output_dir,
    });

    std.debug.print("Files:\n", .{});
    for (extract_result.files) |file| {
        std.debug.print("  {s}\n", .{file});
    }
    std.debug.print("\n", .{});
}

fn runInfo(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 3) {
        std.debug.print("\nUsage: zigx info <archive.zigx>\n\n", .{});
        return;
    }

    const archive_path = args[2];

    std.debug.print("\n[Archive Info]\n\n", .{});

    var info = zigx.getArchiveInfo(archive_path, allocator) catch |err| {
        std.debug.print("Error reading archive: {}\n", .{err});
        return;
    };
    defer info.deinit();

    std.debug.print("Archive: {s}\n\n", .{archive_path});

    std.debug.print("Version:\n", .{});
    std.debug.print("  Format Version:         v{d}\n", .{info.format_version});
    std.debug.print("  Compression Version:    v{d}\n", .{info.compression_version});
    std.debug.print("  Compression Type:       {s}\n", .{@tagName(info.compression_type)});
    std.debug.print("  Compression Level:      {d}\n\n", .{info.compression_level});

    std.debug.print("Size:\n", .{});
    const orig = zigx.formatSize(info.original_size);
    const comp = zigx.formatSize(info.compressed_size);
    std.debug.print("  Original Size:          {d:.2} {s} ({d} bytes)\n", .{ orig.value, orig.unit, info.original_size });
    std.debug.print("  Compressed Size:        {d:.2} {s} ({d} bytes)\n", .{ comp.value, comp.unit, info.compressed_size });
    std.debug.print("  Compression Ratio:      {d:.1}%\n", .{info.getCompressionRatio() * 100});
    std.debug.print("  Space Saved:            {d:.1}%\n\n", .{info.getSavedPercent()});

    std.debug.print("Security:\n", .{});
    std.debug.print("  Signed:                 {s}\n", .{if (info.is_signed) "yes" else "no"});
    std.debug.print("  Encrypted:              {s}\n", .{if (info.is_encrypted) "yes" else "no"});
    std.debug.print("  Payload Hash:           {s}...\n", .{info.payload_hash[0..32]});
    std.debug.print("  Archive Hash:           {s}...\n\n", .{info.archive_hash[0..32]});

    std.debug.print("Content:\n", .{});
    std.debug.print("  File Count:             {d}\n", .{info.file_count});

    if (info.metadata.count() > 0) {
        std.debug.print("\nMetadata:\n", .{});
        var it = info.metadata.entries.iterator();
        while (it.next()) |entry| {
            std.debug.print("  {s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
    }

    std.debug.print("\n", .{});
}

fn runList(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 3) {
        std.debug.print("\nUsage: zigx list <archive.zigx>\n\n", .{});
        return;
    }

    const archive_path = args[2];

    std.debug.print("\n[Files in {s}]\n\n", .{archive_path});

    var info = zigx.getArchiveInfo(archive_path, allocator) catch |err| {
        std.debug.print("Error reading archive: {}\n", .{err});
        return;
    };
    defer info.deinit();

    var total_size: u64 = 0;
    for (info.checksums.items) |item| {
        const fsize = zigx.formatSize(item.size);
        std.debug.print("  {s:<45} {d:>8.2} {s}\n", .{ item.path, fsize.value, fsize.unit });
        total_size += item.size;
    }

    const total = zigx.formatSize(total_size);
    std.debug.print("\n  {d} files, {d:.2} {s} total\n\n", .{ info.file_count, total.value, total.unit });
}

fn runCompare(allocator: std.mem.Allocator) !void {
    std.debug.print("\n[ZIGX Compression Comparison]\n", .{});
    std.debug.print("Format v{d}, Compression v{d}\n\n", .{ zigx.FORMAT_VERSION, zigx.COMPRESSION_VERSION });

    const configs = [_]struct {
        name: []const u8,
        level: zigx.CompressionLevel,
        enabled: bool,
    }{
        .{ .name = "BEST", .level = .best, .enabled = true },
        .{ .name = "DEFAULT", .level = .default, .enabled = true },
        .{ .name = "FAST", .level = .fast, .enabled = true },
        .{ .name = "STORE", .level = .none, .enabled = false },
    };

    var results: [4]struct {
        size: u64,
        original: u64,
        ratio: f64,
    } = undefined;

    for (configs, 0..) |cfg, i| {
        std.debug.print("Creating archive with {s} compression...\n", .{cfg.name});

        var path_buf: [128]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "zigx-{s}.zigx", .{cfg.name}) catch "test.zigx";

        var result = zigx.bundle(.{
            .allocator = allocator,
            .include = &.{ "src", "build.zig", "build.zig.zon", "LICENSE", "README.md" },
            .output_path = path,
            .compression_enabled = cfg.enabled,
            .level = cfg.level,
        }) catch |err| {
            std.debug.print("  Error: {}\n", .{err});
            continue;
        };
        defer result.deinit();

        results[i] = .{
            .size = result.archive_size,
            .original = result.original_size,
            .ratio = result.getCompressionRatio(),
        };

        std.debug.print("  Size: {d} bytes ({d:.1}% of original)\n\n", .{
            result.archive_size,
            result.getCompressionRatio() * 100,
        });
    }

    std.debug.print("\nComparison Results:\n\n", .{});
    std.debug.print("  Mode        Size (bytes)     Ratio      Saved\n", .{});

    for (configs, 0..) |cfg, i| {
        const saved = (1.0 - results[i].ratio) * 100.0;
        std.debug.print("  {s:<8}  {d:>12}    {d:>6.1}%    {d:>5.1}%\n", .{
            cfg.name,
            results[i].size,
            results[i].ratio * 100,
            saved,
        });
    }

    if (results[0].size < results[1].size and results[0].size < results[2].size) {
        std.debug.print("\nBEST compression produces smallest output.\n", .{});
    }

    // Cleanup
    for (configs) |cfg| {
        var path_buf: [128]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "zigx-{s}.zigx", .{cfg.name}) catch continue;
        std.fs.cwd().deleteFile(path) catch {};
    }

    std.debug.print("Test files cleaned up.\n\n", .{});
}

fn displayResult(result: *const zigx.CompressResult) void {
    const orig = zigx.formatSize(result.original_size);
    const comp = zigx.formatSize(result.archive_size);

    std.debug.print("Result:\n", .{});
    std.debug.print("  Archive:    {s}\n", .{result.output_path});
    std.debug.print("  Files:      {d}\n", .{result.file_count});
    std.debug.print("  Original:   {d:.2} {s} ({d} bytes)\n", .{ orig.value, orig.unit, result.original_size });
    std.debug.print("  Compressed: {d:.2} {s} ({d} bytes)\n", .{ comp.value, comp.unit, result.archive_size });
    if (result.compression_enabled) {
        std.debug.print("  Saved:      {d:.1}%\n", .{result.getCompressionPercent()});
    } else {
        std.debug.print("  Mode:       store (no compression)\n", .{});
    }
    std.debug.print("  Hash:       {s}...\n", .{result.archive_hash[0..32]});
}

fn runRepair(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 3) {
        std.debug.print("\nUsage: zigx repair <corrupted.zigx> [repaired.zigx]\n\n", .{});
        return;
    }

    const archive_path = args[2];
    const output_path = if (args.len > 3) args[3] else "repaired.zigx";

    std.debug.print("\n[ZIGX Repair]\n", .{});
    std.debug.print("Attempting to repair: {s}\n", .{archive_path});
    std.debug.print("Output path:        {s}\n", .{output_path});

    const result = zigx.repair(archive_path, output_path, allocator) catch |err| {
        std.debug.print("\nRepair failed: {}\n", .{err});
        return;
    };

    if (!result.was_corrupted) {
        std.debug.print("\nFile was valid! Simply copied to output.\n", .{});
    } else {
        std.debug.print("\nRepair complete!\n", .{});
        std.debug.print("Recovered {d} files.\n", .{result.recovered_files});
    }
}

fn runUpdate(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 3) {
        std.debug.print("\nUsage: zigx update <archive.zigx> [actions...]\n", .{});
        std.debug.print("Actions:\n", .{});
        std.debug.print("  -add <file>      Add file to archive\n", .{});
        std.debug.print("  -rm <pattern>    Remove files matching pattern\n\n", .{});
        return;
    }

    const archive_path = args[2];
    var add_list = std.ArrayListUnmanaged([]const u8){};
    defer add_list.deinit(allocator);
    var rm_list = std.ArrayListUnmanaged([]const u8){};
    defer rm_list.deinit(allocator);

    var i: usize = 3;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-add") and i + 1 < args.len) {
            try add_list.append(allocator, args[i + 1]);
            i += 1;
        } else if (std.mem.eql(u8, arg, "-rm") and i + 1 < args.len) {
            try rm_list.append(allocator, args[i + 1]);
            i += 1;
        }
    }

    if (add_list.items.len == 0 and rm_list.items.len == 0) {
        std.debug.print("No actions specified.\n", .{});
        return;
    }

    std.debug.print("\n[ZIGX Update]\n", .{});
    std.debug.print("Archive: {s}\n", .{archive_path});
    if (add_list.items.len > 0) std.debug.print("Adding:  {d} files\n", .{add_list.items.len});
    if (rm_list.items.len > 0) std.debug.print("Removing: patterns {s}\n", .{rm_list.items[0]}); // Simple display for now

    zigx.update(.{
        .allocator = allocator,
        .archive_path = archive_path,
        .add_files = if (add_list.items.len > 0) add_list.items else null,
        .remove_patterns = if (rm_list.items.len > 0) rm_list.items else null,
    }) catch |err| {
        std.debug.print("\nUpdate failed: {}\n", .{err});
        return;
    };

    std.debug.print("\nArchive updated successfully.\n", .{});
}

fn runValidate(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 3) {
        std.debug.print("\nUsage: zigx validate <archive.zigx>\n\n", .{});
        return;
    }

    const archive_path = args[2];
    std.debug.print("\n[ZIGX Validation]\n", .{});
    std.debug.print("Checking: {s}\n\n", .{archive_path});

    var result = zigx.validateDetailed(archive_path, allocator) catch |err| {
        std.debug.print("Validation/IO error: {}\n", .{err});
        return;
    };
    defer result.deinit();

    if (result.is_valid) {
        std.debug.print("PASS: Archive is valid.\n", .{});
        std.debug.print("  Headers:      OK\n", .{});
        std.debug.print("  Payload Hash: OK\n", .{});
        std.debug.print("  Files:        {d} OK\n", .{result.files_validated});
    } else {
        std.debug.print("FAIL: Archive is corrupted.\n", .{});
        if (result.corruption_info) |info| {
            std.debug.print("  Reason:       {s}\n", .{@tagName(info.corruption_type)});
        }
        if (!result.header_valid) std.debug.print("  Headers:      INVALID\n", .{});
        if (!result.payload_hash_valid) std.debug.print("  Payload Hash: MISMATCH\n", .{});
        if (result.files_with_errors > 0) {
            std.debug.print("  Files Bad:    {d}\n", .{result.files_with_errors});
        }
    }
}

fn runMetadata(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 4) {
        std.debug.print("Usage: zigx metadata <archive> <action> [key] [value]\n", .{});
        std.debug.print("Actions: get, get-all, set, delete\n", .{});
        return;
    }
    const archive_path = args[2];
    const action = args[3];

    if (std.mem.eql(u8, action, "get-all")) {
        var map = try zigx.manager.getAllMetadata(archive_path, allocator);
        defer {
            var it = map.iterator();
            while (it.next()) |entry| {
                allocator.free(entry.key_ptr.*);
                allocator.free(entry.value_ptr.*);
            }
            map.deinit(allocator);
        }
        var it = map.iterator();
        while (it.next()) |entry| {
            std.debug.print("{s} = {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
    } else if (std.mem.eql(u8, action, "get")) {
        if (args.len < 5) {
            std.debug.print("Missing key\n", .{});
            return;
        }
        const key = args[4];
        if (try zigx.manager.getMetadata(archive_path, key, allocator)) |val| {
            std.debug.print("{s}\n", .{val});
            allocator.free(val);
        } else {
            std.debug.print("Key not found\n", .{});
        }
    } else if (std.mem.eql(u8, action, "set")) {
        if (args.len < 6) {
            std.debug.print("Missing value\n", .{});
            return;
        }
        const key = args[4];
        const val = args[5];
        const update = zigx.manager.MetadataUpdate{ .key = key, .op = .{ .set = val } };
        try zigx.manager.updateMetadata(archive_path, &.{update}, allocator);
        std.debug.print("Metadata set.\n", .{});
    } else if (std.mem.eql(u8, action, "delete")) {
        if (args.len < 5) {
            std.debug.print("Missing key\n", .{});
            return;
        }
        const key = args[4];
        const update = zigx.manager.MetadataUpdate{ .key = key, .op = .delete };
        try zigx.manager.updateMetadata(archive_path, &.{update}, allocator);
        std.debug.print("Metadata deleted.\n", .{});
    }
}

fn runSign(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 3) {
        std.debug.print("Usage: zigx sign <archive> <signature_string>\n", .{});
        return;
    }
    const archive_path = args[2];
    const signature = if (args.len > 3) args[3] else "default_signature_123";
    try zigx.manager.setSignature(archive_path, signature, allocator);
    std.debug.print("Archive signed.\n", .{});
}
