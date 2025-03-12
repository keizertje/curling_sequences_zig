const std = @import("std");

const c = @cImport({
    @cInclude("c_func.h");
});

const expect = std.testing.expect;
const alloc = std.testing.allocator;

fn diff_std(p1: []const i16, p2: []const i16) bool {
    return !std.mem.eql(i16, p1, p2); // maybe there are faster ways
}

test {
    const res = c.diff(&[_]i16{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 0 }, &[_]i16{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 0 }, 10);
    const expected = diff_std(&[_]i16{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 0 }, &[_]i16{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 0 });

    try std.testing.expectEqual(expected, res);
}

test {
    const res = c.diff(&[_]i16{}, &[_]i16{}, 0);
    const expected = diff_std(&[_]i16{}, &[_]i16{});

    try std.testing.expectEqual(expected, res);
}

// test {
//     const res = c.diff(&[_]i16{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }, &[_]i16{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 1, 2, 3, 4 }, 24);
//     const expected = diff_std(&[_]i16{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }, &[_]i16{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 1, 2, 3, 4 });

//     try std.testing.expectEqual(expected, res);
// }

test {
    const res = c.diff(&[_]i16{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }, &[_]i16{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }, 24);
    const expected = diff_std(&[_]i16{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 }, &[_]i16{ 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 });

    try std.testing.expectEqual(expected, res);
}

test {
    const res = c.diff(&[_]i16{ 1, 2 }, &[_]i16{ 1, 2 }, 2);
    const expected = diff_std(&[_]i16{ 1, 2 }, &[_]i16{ 1, 2 });

    try std.testing.expectEqual(expected, res);
}
