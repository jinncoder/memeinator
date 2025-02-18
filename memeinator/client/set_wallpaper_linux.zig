const WallpaperManager = @This();

const std = @import("std");
const obfuscation = @import("obfuscation");

pub fn SetWallpaper(allocator: std.mem.Allocator, wallpaper_path: []const u8) !void {
    const wallpaper = try std.fmt.allocPrint(allocator, "file://", .{wallpaper_path});
    defer allocator.free(wallpaper);

    const process: std.process.Child = std.process.Child.init(&[_][]const u8{ "gsettings", "set", "org.gnome.desktop.background", "picture-uri", wallpaper }, allocator);

    process.stderr_behavior = .Pipe;
    process.stdout_behavior = .Pipe;

    try process.spawn();

    _ = try process.wait();
}

pub fn GetUsername(_: std.mem.Allocator) []const u8 {
    var username = std.posix.getenv("USER");

    if (username == null) {
        username = std.posix.getenv("USERNAME");
    }

    if (username == null) {
        return "UNKNOWN USER";
    } else {
        return username.?;
    }
}

pub fn GetHostname(_: std.mem.Allocator) []const u8 {
    const hostname = std.posix.getenv("HOSTNAME");

    if (hostname == null) {
        return "UNKNOWN HOSTNAME";
    } else {
        return hostname.?;
    }
}
