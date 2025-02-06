const WallpaperManager = @This();

const std = @import("std");
const obfuscation = @import("obfuscation");

pub fn SetWallpaper(allocator: std.mem.Allocator, wallpaper_path: []const u8) !void {
    const wallpaper = try std.unicode.utf8ToUtf16LeWithNull(allocator, wallpaper_path);
    defer allocator.free(wallpaper);
}

pub fn GetUsername(_: std.mem.Allocator) []const u8 {
    return "";
}

pub fn GetHostname(_: std.mem.Allocator) []const u8 {
    return "";
}
