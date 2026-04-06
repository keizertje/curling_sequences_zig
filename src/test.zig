const std = @import("std");

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var dll: std.DoublyLinkedList(usize) = .{};
    for (0..10) |i| {
        var node: *std.DoublyLinkedList(usize).Node = try allocator.create(std.DoublyLinkedList(usize).Node);
        node.data = i;
        dll.append(node);
    }

    var it = dll.first;
    while (it) |node| {
        std.debug.print("{}\t{*}\t{*}\n", .{ node.data, it, node.next });
        it = node.*.next;
    }

    it = dll.last;
    while (it) |node| {
        std.debug.print("{}\t{*}\t{*}\n", .{ node.data, it, node.next });
        it = node.*.prev;
    }

    while (dll.popFirst()) |node| {
        allocator.destroy(node);
    }

    const a: i16 = 0;
    const b: usize = 0;
    std.debug.print("{}", .{a == b});
}
