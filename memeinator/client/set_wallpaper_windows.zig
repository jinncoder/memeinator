const WallpaperManager = @This();

const std = @import("std");
const obfuscation = @import("obfuscation");

pub const UNICODE = true;

const win32 = struct {
    usingnamespace @import("win32").system.com;
    usingnamespace @import("win32").system.windows_programming;
    usingnamespace @import("win32").zig;
    usingnamespace @import("win32").ui.shell;
    usingnamespace @import("win32").foundation;
};

const INFO_BUFFER_SIZE: u32 = 32767;
const MAX_COMPUTERNAME_LENGTH: u32 = 1024 + 1;

pub fn GetUsername(allocator: std.mem.Allocator) []const u8 {
    var infoBuf: [INFO_BUFFER_SIZE]u8 = std.mem.zeroes([INFO_BUFFER_SIZE]u8);
    var bufCharCount: u32 = INFO_BUFFER_SIZE;

    // https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getusernamea
    if (0 == win32.GetUserNameA(@ptrCast(&infoBuf), &bufCharCount)) {
        std.log.err("[!] Failed GetUserNameA :: error code ({d})", .{@intFromEnum(win32.GetLastError())});
        return "unknownuser";
    }

    return std.fmt.allocPrintZ(allocator, "{s}", .{infoBuf[0..bufCharCount]}) catch "";
}

pub fn GetHostname(allocator: std.mem.Allocator) []const u8 {
    var infoBuf: [MAX_COMPUTERNAME_LENGTH]u8 = std.mem.zeroes([MAX_COMPUTERNAME_LENGTH]u8);
    var bufCharCount: u32 = MAX_COMPUTERNAME_LENGTH;

    // https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getcomputernamea
    if (0 == win32.GetComputerNameA(@ptrCast(&infoBuf), &bufCharCount)) {
        std.log.err("[!] Failed GetComputerNameA :: error code ({d})", .{@intFromEnum(win32.GetLastError())});
        return "unknownhost";
    }

    return std.fmt.allocPrintZ(allocator, "{s}", .{infoBuf[0..bufCharCount]}) catch "";
}

pub fn SetWallpaper(allocator: std.mem.Allocator, wallpaper_path: []const u8) !void {
    {
        // https://learn.microsoft.com/en-us/windows/win32/api/objbase/nf-objbase-coinitialize
        const status = win32.CoInitialize(
            null, //    [in, optional] LPVOID pvReserved
        );
        if (win32.FAILED(status)) {
            std.log.err("CoInitialize FAILED: {d}", .{status});
            return error.Failed;
        }
    }
    // https://learn.microsoft.com/en-us/windows/win32/api/combaseapi/nf-combaseapi-couninitialize
    defer win32.CoUninitialize();

    var ppv: *win32.IDesktopWallpaper = undefined;
    {
        // https://learn.microsoft.com/en-us/windows/win32/api/combaseapi/nf-combaseapi-cocreateinstance
        const status = win32.CoCreateInstance(
            win32.CLSID_DesktopWallpaper, //       [in]  REFCLSID  rclsid
            null, //                            [in]  LPUNKNOWN pUnkOuter
            win32.CLSCTX_ALL, //             [in]  DWORD     dwClsContext
            win32.IID_IDesktopWallpaper, //          [in]  REFIID    riid
            @ptrCast(&ppv), //                        [out] LPVOID    *ppv
        );
        if (win32.FAILED(status)) {
            std.log.err("CoCreateInstance FAILED: {d}", .{status});
            return error.Failed;
        }
    }
    // https://learn.microsoft.com/en-us/windows/win32/api/unknwn/nf-unknwn-iunknown-release
    defer _ = win32.IUnknown.Release(@ptrCast(ppv));

    {
        const wallpaper = try std.unicode.utf8ToUtf16LeWithNull(allocator, wallpaper_path);
        defer allocator.free(wallpaper);

        // https://learn.microsoft.com/en-us/windows/win32/api/shobjidl_core/nf-shobjidl_core-idesktopwallpaper-setwallpaper
        const status = ppv.SetWallpaper(@ptrFromInt(0), wallpaper);

        if (win32.FAILED(status)) {
            std.log.err("IDesktopWallpaper_SetWallpaper FAILED: {d}", .{status});
            return error.Failed;
        }
    }
}
