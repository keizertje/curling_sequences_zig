const std = @import("std");
const mem = std.mem;
const expect = std.testing.expect;
const Main = @import("./main.zig");
const allocator = std.testing.allocator;

// pub fn main() !void {
//     Main.init();
//     defer Main.deinit();
//
//     try Test();
// }
//
// pub fn Test() !void {
//     const stdout = std.io.getStdOut().writer();
//
//     var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     defer arena.deinit();
//
//     const allocator = arena.allocator();
//
//     var list = std.ArrayList(i32).init(allocator);
//     defer list.deinit();
//
//
//     // try list.append(1);
//     // try list.append(1);
//     // try list.append(1);
//     try list.append(2);
//     try list.append(2);
//     try list.append(3);
//     try list.append(2);
//     try list.append(2);
//     try list.append(2);
//     try list.append(3);
//     try list.append(2);
//     try list.append(3);
//
//     const length = 9;
//
//     const index: usize = Main.find(i32, list.items, 2);
//     try stdout.print("{d}", .{index});
//     if (index != list.items.len) {
//         try stdout.print(" -> {d}\n", .{list.items[index]});
//     }
//
//     try stdout.print("\n", .{});
//
//     var temp = try list.clone();
//     defer temp.deinit();
//
//     var curl: i32 = 1;
//     var period: i32 = 0;
//
//     for (0..length, temp.items[0..length]) |i, item| {
//         try stdout.print("{}\t{}\n", .{i, item});
//     }
//
//     for (0..30) |i| {
//         try Main.krul(&list, &curl, &period);
//         try stdout.print("{}\t{}\t{}\n", .{i+length, curl, period});
//         try temp.append(curl);
//         curl = 1;
//         period = 0;
//     }
//
//     try stdout.print("\n", .{});
//
//     var tail = std.ArrayList(i32).init(allocator);
//     defer tail.deinit();
//
//     var periods = std.ArrayList(i32).init(allocator);
//     defer periods.deinit();
//
//     try Main.tail_with_periods(list, &tail, &periods);
//     try list.appendSlice(tail.items);
//
//     try stdout.print("{}\n", .{list.items.len});
//     try stdout.print("{}\n", .{tail.items.len});
//     try stdout.print("{}\n", .{periods.items.len});
//     try stdout.print("{}\n", .{list.items[0..8].len});
//
//     try stdout.print("\n", .{});
//
//     for (0..length, list.items[0..length]) |i, item| {
//         try stdout.print("{}\t{}\n", .{i, item});
//     }
//
//     try stdout.print("\n", .{});
//
//     for (length..list.items.len, list.items[length..], tail.items, periods.items) |i, seq, seq_tail, seq_period| {
//         try stdout.print("{}\t{}\t{}\t{}\n", .{i, seq, seq_tail, seq_period});
//     }
// }

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();
    var c: u8 = 0;
    while (c != 32) {
        c = stdin.readByte() catch blk: {
            break :blk 0;
        };
        try stdout.print("{c}", .{c});
    }
}

test "krul" {
    var curl: i32 = 1;
    var period: i32 = 0;
    var list = std.ArrayList(i32).init(allocator);
    defer list.deinit();

    var slice: []const i32 = &[5]i32{ 2, 2, 2, 2, 2 };
    list.items = @constCast(slice);

    try Main.krul(&list, &curl, &period);
    try expect(curl == 5 and period == 1);

    slice = &[5]i32{ 2, 3, 2, 3, 2 };
    list.items = @constCast(slice);

    curl = 1;
    period = 0;

    try Main.krul(&list, &curl, &period);
    try expect(curl == 2 and period == 2);

    slice = &[21]i32{ 4, 2, 2, 3, 3, 3, 2, 2, 3, 3, 3, 2, 2, 3, 3, 3, 2, 2, 3, 3, 3 };
    list.items = @constCast(slice);

    curl = 1;
    period = 0;

    try Main.krul(&list, &curl, &period);
    try expect(curl == 4 and period == 5);
}

test "tail_with_periods" {
    var list = std.ArrayList(i32).init(allocator);
    defer list.deinit();
    var tail = std.ArrayList(i32).init(allocator);
    defer tail.deinit();
    var periods = std.ArrayList(i32).init(allocator);
    defer periods.deinit();

    // test 1
    var slice: []const i32 = &[_]i32{ 2, 3, 2, 2, 2, 3, 2, 3 };
    var result: []const i32 = &[_]i32{ 2, 2, 2, 3, 2, 2, 2, 3, 2, 2, 3, 2, 2, 2, 3, 2, 2, 2, 3, 2, 3, 2, 2, 2, 3, 2, 2, 2, 3, 2, 2, 3, 2, 2, 2, 3, 2, 2, 2, 3, 2, 3, 2, 2, 2, 3, 2, 2, 2, 3, 2, 2, 3, 2, 2, 3, 3, 2 };

    try list.appendSlice(slice);

    try Main.tail_with_periods(&list, &tail, &periods);
    try expect(mem.eql(i32, tail.items, result));

    list.clearAndFree();
    tail.clearAndFree();
    periods.clearAndFree();

    //test 2
    slice = &[_]i32{ 2, 2, 2, 2, 2 };
    result = &[_]i32{5};

    try list.appendSlice(slice);

    try Main.tail_with_periods(&list, &tail, &periods);
    try expect(mem.eql(i32, tail.items, result));

    list.clearAndFree();
    tail.clearAndFree();
    periods.clearAndFree();

    //test 3
    slice = &[_]i32{ 2, 233, 2, 233 };
    result = &[_]i32{ 2, 2, 2, 3 };

    try list.appendSlice(slice);

    try Main.tail_with_periods(&list, &tail, &periods);
    try expect(mem.eql(i32, tail.items, result));

    list.clearAndFree();
    tail.clearAndFree();
    periods.clearAndFree();

    //test 4
    slice = &[_]i32{ 2, 2, 2, 3, 2, 2 };
    result = &[_]i32{ 2, 3, 2, 2, 2, 3, 3, 2 };

    try list.appendSlice(slice);

    try Main.tail_with_periods(&list, &tail, &periods);
    try expect(mem.eql(i32, tail.items, result));

    list.clearAndFree();
    tail.clearAndFree();
    periods.clearAndFree();
}

test "tail_with_periods_part" {
    var list = std.ArrayList(i32).init(allocator);
    defer list.deinit();
    var tail = std.ArrayList(i32).init(allocator);
    defer tail.deinit();
    var periods = std.ArrayList(i32).init(allocator);
    defer periods.deinit();

    // test 1
    var slice: []const i32 = &[_]i32{ 2, 3, 2, 2, 2, 3, 2, 3 };
    var result: []const i32 = &[_]i32{ 2, 2, 2, 3, 2, 2, 2, 3, 2, 2, 3, 2, 2, 2, 3, 2, 2, 2 };

    try list.appendSlice(slice);

    try Main.tail_with_periods_part(&list, &tail, &periods, 18);
    try expect(mem.eql(i32, tail.items, result));

    list.clearAndFree();
    tail.clearAndFree();
    periods.clearAndFree();

    //test 2
    slice = &[_]i32{ 2, 2, 2, 2, 2 };
    result = &[_]i32{5};

    try list.appendSlice(slice);

    try Main.tail_with_periods_part(&list, &tail, &periods, 255);
    try expect(mem.eql(i32, tail.items, result));

    list.clearAndFree();
    tail.clearAndFree();
    periods.clearAndFree();

    //test 3
    slice = &[_]i32{ 2, 233, 2, 233 };
    result = &[_]i32{};

    try list.appendSlice(slice);

    try Main.tail_with_periods_part(&list, &tail, &periods, 0);
    try expect(mem.eql(i32, tail.items, result));

    list.clearAndFree();
    tail.clearAndFree();
    periods.clearAndFree();

    //test 4
    slice = &[_]i32{ 2, 2, 2, 3, 2, 2 };
    result = &[_]i32{ 2, 3, 2, 2 };

    try list.appendSlice(slice);

    try Main.tail_with_periods_part(&list, &tail, &periods, 4);
    try expect(mem.eql(i32, tail.items, result));

    list.clearAndFree();
    tail.clearAndFree();
    periods.clearAndFree();
}

test "complete story" {
    try Main.init();
    defer Main.deinit();

    Main.allocator = std.testing.allocator;

    const start = std.time.nanoTimestamp();
    try Main.backtracking(10, 10);
    const end = std.time.nanoTimestamp();
    std.debug.print("time elapsed: {d} ns", .{end - start});
}
