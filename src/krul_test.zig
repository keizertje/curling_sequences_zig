const std = @import("std");
const diff = @import("diff_test.zig").diff_best;
const v16 = std.ArrayList(i16);

fn krul_std(seq: *v16, period: *usize, len: usize, minimum: i16) i16 {
    var curl: i16 = minimum - 1;
    var limit = @divTrunc(len, @as(usize, @intCast(minimum)));
    var i: usize = 1;
    while (i <= limit) : (i += 1) {
        const p1: []i16 = seq.items[len - i .. len];
        var freq: usize = 2;
        while (true) : (freq += 1) {
            if (freq * i > len) {
                break;
            }
            const p2: []i16 = seq.items[len - freq * i .. len - freq * i + i];
            if (diff(p1, p2)) {
                break;
            }
            if (curl < freq) {
                curl = @intCast(freq);
                limit = @divTrunc(len, @as(usize, @intCast(curl + 1)));
                period.* = i;
            }
        }
    }
    return curl;
}
