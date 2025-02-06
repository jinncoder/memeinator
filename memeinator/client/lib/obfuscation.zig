const native_os = @import("builtin").os.tag;
const std = @import("std");

// set log level by build type
pub const default_level: std.Level = switch (std.builtin.mode) {
    .Debug => .debug,
    .ReleaseSafe, .ReleaseFast, .ReleaseSmall => .info,
};

// go read: https://protectionbynofunction.com/2024/07/20/zig-shellcode-obfuscation
//encrypt is a function that takes a compile time known string, and returns it encrypted
pub fn encrypt(comptime string: []const u8, k: u8) [string.len]u8 {
    // Zig has a default compilation timeout
    // We override it  to a big number so that the whole encryption can happen
    @setEvalBranchQuota(100000000);
    var encrypted_string: [string.len]u8 = undefined;
    // This loops over all characters of string - chr, and idx is the index
    for (string, 0..) |chr, idx| {
        // We do not want to xor with a single value, so we use also the index
        const key: u8 = @truncate((idx * 83) % 256);
        encrypted_string[idx] = chr ^ key ^ k;
    }
    return encrypted_string;
}

// This is very similar to the encrypt function
pub fn decrypt(mem: []u8, s: []const u8, k: u8) void {
    for (s, 0..) |chr, idx| {
        const key: u8 = @truncate((idx * 83) % 256);
        // The one difference is that this function also calls shouldRun, which should return 0
        // shouldRun is a function that ensures this is evaluated during runtime
        // this is how we prevent Zig from optimizing decryption out
        mem[idx] = chr ^ key ^ k + 1;
    }
}

pub fn comptimeObfuscation(comptime s: []const u8) [s.len]u8 {
    const key = 0x42;
    // We call encrypt at comptime
    const enc_str = comptime encrypt(s, key);
    var ret_array: [s.len]u8 = [_]u8{0} ** s.len;
    decrypt(&ret_array, &enc_str, key);

    return ret_array;
}
