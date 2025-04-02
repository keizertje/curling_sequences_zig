const std = @import("std");
const diff = @import("diff.zig").diff_best;
pub const krul_stable = krul_exp2;

pub fn krul(seq: []const i16, period: *usize, len: usize, minimum: i16) i16 {
    var curl: i16 = minimum - 1;
    var limit = @divTrunc(len, @as(usize, @intCast(minimum)));
    var i: usize = 1;
    while (i <= limit) : (i += 1) {
        const p1: []const i16 = seq[len - i .. len];
        var freq: usize = 2;
        while (freq * i <= len) : (freq += 1) {
            if (diff(p1, seq[len - freq * i .. len - freq * i + i])) {
                break;
            }
        }
        if (curl < freq - 1) {
            curl = @intCast(freq - 1);
            limit = @divTrunc(len, @as(usize, @intCast(curl + 1)));
            period.* = i;
        }
    }
    return curl;
}

pub fn krul_exp2(seq: []const i16, period: *usize, len: usize, minimum: i16) i16 {
    var curl: i16 = minimum - 1;
    var limit = @divTrunc(len, @as(usize, @intCast(minimum)));
    var i: usize = 1;
    while (i <= limit) : (i += 1) {
        const p1: []const i16 = seq[len - i .. len];
        var p2 = p1;
        p2.ptr -= i;
        var freq: usize = 2;
        while (freq * i <= len) : ({
            freq += 1;
            p2.ptr -= i;
        }) {
            if (diff(p1, p2)) {
                break;
            }
        }
        if (curl < freq - 1) {
            curl = @intCast(freq - 1);
            limit = @divTrunc(len, @as(usize, @intCast(curl + 1)));
            period.* = i;
        }
    }
    return curl;
}

pub fn krul_exp(seq: []const i16, period: *usize, len: usize, minimum: i16) i16 {
    var curl: i16 = minimum - 1;
    var limit = @divTrunc(len, @as(usize, @intCast(minimum)));
    var i: usize = 1;
    while (i <= limit) : (i += 1) {
        const p1: []const i16 = seq[len - i .. len];
        var start: usize = 2 * i;
        while (start <= len) : ({
            start += i;
        }) {
            if (diff(p1, seq[len - start .. len - start + i])) {
                break;
            }
        }
        if (curl < start / i - 1) {
            curl = @intCast(start / i - 1);
            limit = @divTrunc(len, @as(usize, @intCast(curl + 1)));
            period.* = i;
        }
    }
    return curl;
}

fn generateSemiRandomSequence(allocator: std.mem.Allocator, len: usize, pattern_len: usize) ![]i16 {
    var seq = try allocator.alloc(i16, len);
    var rng = std.Random.DefaultPrng.init(@as(u32, @truncate(@as(u128, @bitCast(std.time.nanoTimestamp())))));
    var random = rng.random();

    // Genereer een herhalend patroon met wat ruis
    for (0..len) |i| {
        seq[i] = @intCast((i % pattern_len) + 1); // Basispatroon
        if (random.boolean()) {
            seq[i] += @intCast(random.intRangeAtMost(i16, -1, 1)); // Kleine verstoringen
        }
    }
    return seq;
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const dataset_sizes = [_]usize{ 100, 500, 1000, 5000 };
    const pattern_lengths = [_]usize{ 10, 50, 100, 250 }; // Verschillende patronen

    const iterations = 5000; // Aantal herhalingen per dataset

    for (dataset_sizes, pattern_lengths) |size, pattern| {
        var total_time_stable: u64 = 0;
        var total_time_exp: u64 = 0;
        var total_time_exp2: u64 = 0;
        var period: usize = 0;

        const seq = try generateSemiRandomSequence(allocator, size, pattern);
        defer allocator.free(seq);

        var timer = try std.time.Timer.start();

        for (0..iterations) |_| {
            timer.reset();
            const a = krul(seq, &period, size, 3);
            total_time_stable += timer.read();
            timer.reset();
            const b = krul_exp(seq, &period, size, 3);
            total_time_exp += timer.read();
            timer.reset();
            const c = krul_exp2(seq, &period, size, 3);
            total_time_exp2 += timer.read();

            if (a != b or a != c) {
                std.debug.print("not ok!\n", .{});
            }
        }

        const avg_time_stable_ns = total_time_stable / iterations;
        const avg_time_exp_ns = total_time_exp / iterations;
        const avg_time_exp2_ns = total_time_exp2 / iterations;
        try stdout.print("Dataset grootte: {} | Patroongrootte: {} | Gem. tijd: {} ns, {} ns, {} ns\n", .{ size, pattern, avg_time_stable_ns, avg_time_exp_ns, avg_time_exp2_ns });
    }
}
