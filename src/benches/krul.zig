const std = @import("std");
const diff = @import("diff.zig").diff_best;
const diff_fast = @import("diff.zig").diff_comptime_len_best;
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

// still draft
pub fn krul_exp3(seq: []const i16, period: *usize, len: usize, minimum: i16) i16 {
    var curl: i16 = minimum - 1;
    var limit = @divTrunc(len, @as(usize, @intCast(minimum)));
    var i: usize = 1;
    switch (limit) {
        0...15 => {
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
        },
        16...63 => {},
        64...255 => {},
        else => {},
    }

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

fn krul_exp4(seq: []const i16, period: *usize, len: usize, minimum: i16) i16 {
    var curl: i16 = minimum - 1;
    var limit = @divTrunc(len, @as(usize, @intCast(minimum)));
    inline for (1..100) |i| {
        if (i > limit) break;
        const p1: []const i16 = seq[len - i .. len];
        var p2 = p1;
        p2.ptr -= i;
        var freq: usize = 2;
        while (freq * i <= len) : ({
            freq += 1;
            p2.ptr -= i;
        }) {
            if (diff_fast(p1, p2, i)) {
                break;
            }
        }
        if (curl < freq - 1) {
            curl = @intCast(freq - 1);
            limit = @divTrunc(len, @as(usize, @intCast(curl + 1)));
            period.* = i;
        }
    }
    var i: usize = 100;
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

    const dataset_sizes = [_]usize{ 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 200, 300, 400, 500, 1000, 5000 };
    const pattern_lengths = [_]usize{ 1, 2, 1, 2, 3, 2, 2, 3, 2, 4, 3, 7, 50, 100, 150, 250 }; // Verschillende patronen

    const different_sequences = 70; // Aantal verschillende sequenties per dataset
    const iterations = 1500; // Aantal herhalingen per dataset

    for (dataset_sizes, pattern_lengths) |size, pattern| {
        var total_time_stable: u64 = 0;
        var total_time_exp: u64 = 0;
        var total_time_exp2: u64 = 0;
        var total_time_exp3: u64 = 0;
        var total_time_exp4: u64 = 0;
        var period: usize = 0;

        var timer = try std.time.Timer.start();

        for (0..different_sequences) |_| {
            const seq = try generateSemiRandomSequence(allocator, size, pattern);
            defer allocator.free(seq);

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
                timer.reset();
                const d = krul_exp3(seq, &period, size, 3);
                total_time_exp3 += timer.read();
                timer.reset();
                const e = krul_exp4(seq, &period, size, 3);
                total_time_exp4 += timer.read();

                if (a != b or a != c or a != d or a != e) {
                    std.debug.print("not ok!\n", .{});
                }
            }
        }

        const avg_time_stable_ns = total_time_stable / iterations / different_sequences;
        const avg_time_exp_ns = total_time_exp / iterations / different_sequences;
        const avg_time_exp2_ns = total_time_exp2 / iterations / different_sequences;
        const avg_time_exp3_ns = total_time_exp3 / iterations / different_sequences;
        const avg_time_exp4_ns = total_time_exp4 / iterations / different_sequences;
        try stdout.print("Dataset grootte: {} | Patroongrootte: {} | Gem. tijd: {} ns, {} ns, {} ns, {} ns, {} ns\n", .{ size, pattern, avg_time_stable_ns, avg_time_exp_ns, avg_time_exp2_ns, avg_time_exp3_ns, avg_time_exp4_ns });
    }
}
