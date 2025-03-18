const std = @import("std");

pub fn main() !void {
    std.debug.print("{}, {}\n", .{ @import("builtin").target.cpu.arch.endian(), 15 << -1 });
}
