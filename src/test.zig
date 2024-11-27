const std = @import("std");
const Main = @import("./main.zig");
const expect = std.testing.expect;
const allocator = std.testing.allocator;

test "krul" {
    var list = std.ArrayList(i16).init(allocator);
    defer list.deinit();

    var period: usize = 0;
    list.clearAndFree();
    try list.appendSlice(&[_]i16{ 2, 2, 2, 2, 2 });

    var curl = Main.krul(&list, &period, list.items.len, 1);
    try expect(curl == 5 and period == 1);

    period = 0;
    list.clearAndFree();
    try list.appendSlice(&[_]i16{ 2, 3, 2, 3, 2 });

    curl = Main.krul(&list, &period, list.items.len, 1);
    try expect(curl == 2 and period == 2);

    period = 0;
    list.clearAndFree();
    try list.appendSlice(&[_]i16{ 4, 2, 2, 3, 3, 3, 2, 2, 3, 3, 3, 2, 2, 3, 3, 3, 2, 2, 3, 3, 3 });

    curl = Main.krul(&list, &period, list.items.len, 1);
    try expect(curl == 4 and period == 5);
}

const T = struct {
    x: i16,
};

fn Test(t: *T) void {
    t.x = 0;
}

test {
    var i: T = T{ .x = 1 };
    Test(&i);
    try expect(i.x == 0);
}
