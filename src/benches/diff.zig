const std = @import("std");
const builtin = @import("builtin");
const alloc = std.testing.allocator;
const c = @cImport({
    @cInclude("stdlib.h");
    @cInclude("string.h");
    @cInclude("c_func.h");
});
const c_trans = @import("c_func.zig");

pub const diff_best = diff_std;
const testing_fn = diff_c_wrapper;

const diff_exp2 = @import("diff.zig").diff_exp2;

fn diff_std(p1: []const i16, p2: []const i16) bool {
    return !std.mem.eql(i16, p1, p2);
}

//// doesn't work for zero
fn diff_exp(p1: []const i16, p2: []const i16) bool {
    var p1_16: [*]const u16 = @ptrCast(p1.ptr);
    var p2_16: [*]const u16 = @ptrCast(p2.ptr);

    inline for (0..@sizeOf(usize)) |i| {
        const width: comptime_int = 1 << i;
        if (width & p1.len != 0) {
            const TYPE: type = @Type(.{ .int = .{
                .signedness = .unsigned,
                .bits = width * 16,
            } });

            const v1 = std.mem.bytesToValue(TYPE, p1_16[0..width]);
            const v2 = std.mem.bytesToValue(TYPE, p2_16[0..width]);

            if (v1 != v2) {
                return true;
            }

            // should check for i >= @sizeOf(usize) - @clz(p1.len) - 1
            if (i >= 7) {
                return false;
            }

            p1_16 += width;
            p2_16 += width;
        }
    }

    return false; // this will never be hit
}

fn diff_exp3(p1: []const i16, p2: []const i16) bool {
    const count64 = p1.len / 4;
    const count16 = p1.len % 4;

    for (0..count64) |i| {
        if (std.mem.bytesToValue(u64, p1[i * 4 .. i * 4 + 4]) != std.mem.bytesToValue(u64, p2[i * 4 .. i * 4 + 4])) {
            return true;
        }
    }

    for (0..count16) |i| {
        if (p1[4 * count64 + i] != p2[4 * count64 + i]) {
            return true;
        }
    }
    return false;
}

fn diff_fast(p1: []const i16, p2: []const i16, comptime len: usize) bool {
    const TYPE = @Type(.{ .int = .{
        .signedness = .unsigned,
        .bits = len * 16,
    } });

    const v1 = std.mem.bytesToValue(TYPE, p1);
    const v2 = std.mem.bytesToValue(TYPE, p2);

    return v1 != v2;
}

fn diff_fast2(p1: []const i16, p2: []const i16, comptime len: usize) bool {
    const TYPE = @Type(.{ .int = .{
        .signedness = .unsigned,
        .bits = len,
    } });

    const p1_16 = p1.ptr;
    const p2_16 = p2.ptr;

    const p1_many: [*]const TYPE = @alignCast(@ptrCast(p1_16));
    const p2_many: [*]const TYPE = @alignCast(@ptrCast(p2_16));

    return p1_many[0] != p2_many[0];
}

fn diff_c_wrapper(p1: []const i16, p2: []const i16) bool {
    return c.memcmp(p1.ptr, p2.ptr, @as(c_ulonglong, @intCast(p1.len)) * 2) != 0;
}

fn diff_c_trans_wrapper(p1: []const i16, p2: []const i16) bool {
    return c_trans.diff(p1.ptr, p2.ptr, p1.len);
}

fn benchmark(comptime iterations: usize, comptime size: usize) void {
    var total_time_test: i128 = 0;
    var total_time_std: i128 = 0;

    var good_a = true;

    for (0..iterations / 50_000) |_| {
        var ptr1 = @as([*]i16, @ptrCast(@alignCast(c.malloc(size + 1).?)));
        var ptr2 = @as([*]i16, @ptrCast(@alignCast(c.malloc(size + 1).?)));

        const buffer1: []i16 = ptr1[0..size];
        const buffer2: []i16 = ptr2[0..size];

        for (0..50_000) |_| {
            const start_diff = std.time.nanoTimestamp();
            const a = testing_fn(buffer1, buffer2);
            const end_diff = std.time.nanoTimestamp();
            total_time_test += end_diff - start_diff;

            const start_eql = std.time.nanoTimestamp();
            const e = diff_std(buffer1, buffer2);
            const end_eql = std.time.nanoTimestamp();
            total_time_std += end_eql - start_eql;

            good_a = good_a and a == e;
        }
    }

    if (!good_a) {
        std.debug.print("!!!a\t", .{});
    }

    std.debug.print("Size: {} i16 =>\n", .{size});
    std.debug.print("\t\t01: {} ns per call\n", .{@divTrunc(total_time_test, iterations)});
    std.debug.print("\t\tstd:  {} ns per call\n\n", .{@divTrunc(total_time_std, iterations)});
}

test "100 tests in 1...100" {
    inline for (1..41) |i| {
        benchmark(5_000_000, i);
    }
    inline for (41..101) |i| {
        benchmark(2_000_000, i);
    }
}

test "133 tests in 0..6300" {
    benchmark(10_000_000, 1);
    inline for (1..25) |size| {
        benchmark(4_000_000, size * 4);
    }
    inline for (0..25) |size| {
        benchmark(3_000_000, 100 + size * 8);
    }
    inline for (0..25) |size| {
        benchmark(2_000_000, 300 + size * 16);
    }
    inline for (0..25) |size| {
        benchmark(1_000_000, 700 + size * 32);
    }
    inline for (0..25) |size| {
        benchmark(1_000_000, 1500 + size * 64);
    }
    inline for (0..26) |size| {
        benchmark(500_000, 3100 + size * 128);
    }
}

test "11 tests in 3..3072" {
    inline for (0..11) |size| {
        benchmark(1_000_000, 3 << (size)); // 00000011 << x
    }
}

test "check working 1" {
    const res = testing_fn(&[_]i16{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 0 }, &[_]i16{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 0 });
    const expected = diff_std(&[_]i16{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 0 }, &[_]i16{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 0 });

    try std.testing.expectEqual(expected, res);
}

test "check working 2" {
    const res = testing_fn(&[_]i16{1}, &[_]i16{0});
    const expected = diff_std(&[_]i16{1}, &[_]i16{0});

    try std.testing.expectEqual(expected, res);
}

test "check working 3" {
    const res = testing_fn(&[_]i16{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }, &[_]i16{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 1, 2, 3, 4 });
    const expected = diff_std(&[_]i16{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }, &[_]i16{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 1, 2, 3, 4 });

    try std.testing.expectEqual(expected, res);
}

test "check working 4" {
    const res = testing_fn(&[_]i16{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }, &[_]i16{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 });
    const expected = diff_std(&[_]i16{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }, &[_]i16{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 });

    try std.testing.expectEqual(expected, res);
}

test "check working 5" {
    const res = testing_fn(&[_]i16{ 1, 2 }, &[_]i16{ 1, 2 });
    const expected = diff_std(&[_]i16{ 1, 2 }, &[_]i16{ 1, 2 });

    try std.testing.expectEqual(expected, res);
}

test "check working 6" {
    const res = testing_fn(&[_]i16{ -5, -10, 15, 20 }, &[_]i16{ 5, 10, -15, -20 });
    const expected = diff_std(&[_]i16{ -5, -10, 15, 20 }, &[_]i16{ 5, 10, -15, -20 });

    try std.testing.expectEqual(expected, res);
}

test "check working 7" {
    const res = testing_fn(&[_]i16{ 100, 200, 300 }, &[_]i16{ 50, 150, 250 });
    const expected = diff_std(&[_]i16{ 100, 200, 300 }, &[_]i16{ 50, 150, 250 });

    try std.testing.expectEqual(expected, res);
}

test "check working 8" {
    const res = testing_fn(&[_]i16{ 7, 14, 21, 28, 35, 42 }, &[_]i16{ 1, 2, 3, 4, 5, 6 });
    const expected = diff_std(&[_]i16{ 7, 14, 21, 28, 35, 42 }, &[_]i16{ 1, 2, 3, 4, 5, 6 });

    try std.testing.expectEqual(expected, res);
}

test "check working 9" {
    const res = testing_fn(&[_]i16{ -1, -2, -3, -4, -5 }, &[_]i16{ -1, -2, -3, -4, -5 });
    const expected = diff_std(&[_]i16{ -1, -2, -3, -4, -5 }, &[_]i16{ -1, -2, -3, -4, -5 });

    try std.testing.expectEqual(expected, res);
}

test "check working 10" {
    const res = testing_fn(&[_]i16{ 0, 0, 0, 0, 0, 0 }, &[_]i16{ 1, 1, 1, 1, 1, 1 });
    const expected = diff_std(&[_]i16{ 0, 0, 0, 0, 0, 0 }, &[_]i16{ 1, 1, 1, 1, 1, 1 });

    try std.testing.expectEqual(expected, res);
}

test "check working 11" {
    const res = testing_fn(&[_]i16{ 32767, -32768, 1234, -5678 }, &[_]i16{ -32768, 32767, -1234, 5678 });
    const expected = diff_std(&[_]i16{ 32767, -32768, 1234, -5678 }, &[_]i16{ -32768, 32767, -1234, 5678 });

    try std.testing.expectEqual(expected, res);
}

test "check working 12" {
    const res = testing_fn(&[_]i16{42}, &[_]i16{24});
    const expected = diff_std(&[_]i16{42}, &[_]i16{24});

    try std.testing.expectEqual(expected, res);
}

test "check working 13" {
    const res = testing_fn(&[_]i16{ 11, 22, 33, 44, 55, 66, 77, 88, 99 }, &[_]i16{ 9, 8, 7, 6, 5, 4, 3, 2, 1 });
    const expected = diff_std(&[_]i16{ 11, 22, 33, 44, 55, 66, 77, 88, 99 }, &[_]i16{ 9, 8, 7, 6, 5, 4, 3, 2, 1 });

    try std.testing.expectEqual(expected, res);
}

test "check working 14" {
    const res = testing_fn(&[_]i16{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, &[_]i16{ 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 });
    const expected = diff_std(&[_]i16{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, &[_]i16{ 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 });

    try std.testing.expectEqual(expected, res);
}

test "check working 15" {
    const res = testing_fn(&[_]i16{ 500, 400, 300, 200, 100 }, &[_]i16{ 100, 200, 300, 400, 500 });
    const expected = diff_std(&[_]i16{ 500, 400, 300, 200, 100 }, &[_]i16{ 100, 200, 300, 400, 500 });

    try std.testing.expectEqual(expected, res);
}
