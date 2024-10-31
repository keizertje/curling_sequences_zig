const std = @import("std");
const Allocator = std.mem.Allocator;
inline fn Iterator(comptime T: type) type {
    return Set(T).keyIterator;
}
const ArrayList = std.ArrayList;
const Map = std.AutoHashMap;
inline fn Set(comptime T: type) type {
    return Map(T, void);
}

var arena: std.heap.ArenaAllocator = undefined;
var allocator: Allocator = undefined;

pub const length: i32 = 25;
pub var c_cand: i32 = undefined;
pub var p_cand: i32 = undefined;
pub var tail: ArrayList(i32) = undefined;
pub var periods: ArrayList(i32) = undefined;
pub var generator: ArrayList(i32) = undefined;
pub var max_lengths: ArrayList(usize) = undefined;
pub var generators_mem: Map(usize, ArrayList(i32)) = undefined;
pub var best_gens: ArrayList(ArrayList(i32)) = undefined;
pub var change_indices: Set(usize) = undefined;
pub var dict: Map(i32, Set(i32)) = undefined;
pub var dicts_mem: Map(usize, Map(i32, Set(i32))) = undefined;

pub var seq_new: ArrayList(i32) = undefined;
pub var dict_new: Map(i32, Set(i32)) = undefined;

fn copyDictInto(dest: *Map(i32, Set(i32)), src: Map(i32, Set(i32))) !void {
    dest.clearRetainingCapacity();
    var it = src.iterator();
    while (it.next()) |entry| {
        var set = Set(i32).init(dest.allocator);
        var value_it = entry.value_ptr.keyIterator();
        while (value_it.next()) |key_ptr| {
            try set.put(key_ptr.*, {});
        }
        try dest.put(entry.key_ptr.*, set);
    }
}

fn cloneDict(src: Map(i32, Set(i32))) !Map(i32, Set(i32)) {
    var dest = Map(i32, Set(i32)).init(src.allocator);
    try copyDictInto(&dest, src);
    return dest;
}

pub fn init() !void {
    arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    allocator = arena.allocator();

    c_cand = 2;
    p_cand = 1;
    tail = ArrayList(i32).init(allocator);
    periods = ArrayList(i32).init(allocator);
    generator = ArrayList(i32).init(allocator);
    max_lengths = ArrayList(usize).init(allocator);
    generators_mem = Map(usize, ArrayList(i32)).init(allocator);
    best_gens = ArrayList(ArrayList(i32)).init(allocator);
    change_indices = Set(usize).init(allocator);
    dict = Map(i32, Set(i32)).init(allocator);
    dicts_mem = Map(usize, Map(i32, Set(i32))).init(allocator);

    seq_new = ArrayList(i32).init(allocator);
    dict_new = Map(i32, Set(i32)).init(allocator);

    // creating default values
    try change_indices.put(0, {});

    var empty_gen: ArrayList(i32) = ArrayList(i32).init(allocator);
    defer empty_gen.deinit();

    for (0..length) |i| {
        var set: Set(i32) = Set(i32).init(allocator);
        defer set.deinit();
        try set.put(@as(i32, @intCast(i)), {});

        try generator.append(-@as(i32, @intCast(i)));
        try dict.put(-@as(i32, @intCast(i)), try set.clone());
        try max_lengths.append(0);
        try best_gens.append(try empty_gen.clone());
    }
}

pub fn deinit() void {
    tail.deinit();
    periods.deinit();
    generator.deinit();
    max_lengths.deinit();
    change_indices.deinit();

    var it = generators_mem.valueIterator();
    var it2 = dict.valueIterator();
    var it3 = dicts_mem.valueIterator();

    while (it.next()) |seq| seq.deinit();
    while (it2.next()) |seq2| seq2.deinit();
    while (it3.next()) |seq3| seq3.deinit();
    generators_mem.deinit();
    dict.deinit();
    dicts_mem.deinit();

    for (best_gens.items) |sequence| {
        sequence.deinit();
    }
    best_gens.deinit();

    seq_new.deinit();
    dict_new.deinit();

    arena.deinit();
}

pub fn krul(seq: *ArrayList(i32), curl: *i32, period: *i32) !void {
    const l: usize = @intCast(seq.items.len);
    for (1..l / 2 + 1) |i| {
        var j: usize = i;
        while (seq.items[l - j - 1] == seq.items[l - j - 1 + i]) {
            j += 1;
            if (j >= l) {
                break;
            }
        }
        const cand: i32 = @intCast(j / i);
        if (cand > curl.*) {
            curl.* = cand;
            period.* = @intCast(i);
        }
    }
}

pub fn tail_with_periods(seq: *ArrayList(i32), seq_tail: *ArrayList(i32), seq_periods: *ArrayList(i32)) !void {
    var curl: i32 = 1;
    var period: i32 = 0;
    var temp: ArrayList(i32) = try seq.clone();
    defer temp.deinit();

    try krul(seq, &curl, &period);
    while (curl > 1) {
        try seq_tail.append(curl);
        try temp.append(curl);
        try seq_periods.append(period);
        curl = 1;
        period = 0;
        try krul(&temp, &curl, &period);
    }
}

pub fn tail_with_periods_part(seq: *ArrayList(i32), seq_tail: *ArrayList(i32), seq_periods: *ArrayList(i32), i: i32) !void {
    var curl: i32 = 1;
    var period: i32 = 0;
    var temp: ArrayList(i32) = try seq.clone();
    defer temp.deinit();

    try krul(seq, &curl, &period);

    while (curl > 1 and seq_tail.items.len < i) {
        try seq_tail.append(curl);
        try temp.append(curl);
        try seq_periods.append(period);
        curl = 1;
        period = 0;
        try krul(&temp, &curl, &period);
    }
}

pub fn check_periods_size() bool {
    return (c_cand * p_cand) > (length + periods.items.len);
}

pub fn check_c_cand_size() bool {
    if (tail.items.len != 0) {
        return c_cand > tail.getLast() + 1;
    } else {
        return c_cand > length;
    }
}

pub fn up() !void {
    p_cand += 1;
    loop: while (check_periods_size()) {
        c_cand += 1;
        p_cand = 1;
        if (check_c_cand_size()) {
            if (change_indices.get(periods.items.len) != null) { // usize or i32?
                _ = change_indices.remove(periods.items.len); // usize or i32?
            }
            if (tail.items.len == 0) {
                c_cand = 0; // terminate program
                break :loop;
            }
            if (change_indices.get(periods.items.len - 1) == null) { // usize or i32?
                try change_indices.put(periods.items.len - 1, {});
                _ = dict.getPtr(tail.getLast()).?.remove(@as(i32, @intCast(length + tail.items.len - 1)));
                c_cand = tail.pop() + 1;
                p_cand = 1;
                _ = periods.pop();
            } else {
                c_cand = tail.pop();
                p_cand = periods.pop() + 1;

                generator = try generators_mem.get(periods.items.len).?.clone();
                dict = try cloneDict(dicts_mem.get(periods.items.len).?);
                _ = generators_mem.remove(periods.items.len);
                _ = dicts_mem.remove(periods.items.len);
            }
        }
    }
}

pub fn real_gen_len() usize {
    var i: usize = 0;
    loop: while (dict.getPtr(generator.items[i]).?.count() == 1) {
        i += 1;
        if (i == length) {
            break :loop;
        }
    }
    return length - i;
}

pub fn check_positive(len: i32) bool {
    for (generator.items[length - len ..]) |i| {
        if (i < 1) {
            return false;
        }
    }
    return true;
}

pub fn append() !void {
    try generators_mem.put(periods.items.len, try generator.clone());
    try dicts_mem.put(@intCast(periods.items.len), try cloneDict(dict));
    generator.clearAndFree();
    try generator.appendSlice(seq_new.items[0..length]);
    dict = try cloneDict(dict_new);

    if (dict.getPtr(c_cand) != null) {
        try dict.getPtr(c_cand).?.put(@intCast(length + periods.items.len), {});
        try dict_new.getPtr(c_cand).?.put(@intCast(length + periods.items.len), {});
    } else {
        var set: Set(i32) = Set(i32).init(allocator);
        defer set.deinit();

        try set.put(@intCast(length + periods.items.len), {});

        try dict.put(c_cand, try set.clone());
        try dict_new.put(c_cand, try set.clone());
    }

    try tail.append(c_cand);
    try periods.append(p_cand);

    var curl: i32 = 1;
    var period: i32 = 0;
    var temp: ArrayList(i32) = try generator.clone();
    defer temp.deinit();

    // try temp.append(c_cand);
    try temp.appendSlice(tail.items);

    loop: while (true) {
        curl = 1;
        period = 0;
        try krul(&temp, &curl, &period);
        if (curl == 1) {
            break :loop;
        }
        try tail.append(curl);
        try temp.append(curl);
        try periods.append(period);

        if (dict.getPtr(curl) != null) {
            try dict.getPtr(curl).?.put(@intCast(length + periods.items.len - 1), {});
            try dict_new.getPtr(curl).?.put(@intCast(length + periods.items.len - 1), {});
        } else {
            var set: Set(i32) = Set(i32).init(allocator);
            defer set.deinit();

            try set.put(@intCast(length + periods.items.len - 1), {});

            try dict.put(curl, try set.clone());
            try dict_new.put(curl, try set.clone());
        }
    }
    c_cand = 2;
    p_cand = 1;
    try change_indices.put(periods.items.len, {});
    const len: usize = real_gen_len();
    if (max_lengths.getLast() == periods.items.len) {
        var tmp: std.ArrayList(i32) = try best_gens.getLast().clone();
        defer tmp.deinit();

        try tmp.appendSlice(generator.items[0 .. generator.items.len - len]);
        var last = best_gens.pop();
        last.deinit();
        try best_gens.append(try tmp.clone());
    }
    if (max_lengths.items[len - 1] < periods.items.len) {
        max_lengths.items[len - 1] = periods.items.len;

        var tmp: ArrayList(i32) = ArrayList(i32).init(allocator);
        defer tmp.deinit();
        try tmp.appendSlice(generator.items[generator.items.len - len ..]);

        var deleted = best_gens.items[len - 1];
        best_gens.items[len - 1] = try tmp.clone();
        deleted.deinit();
    }
}

pub fn test_1() !bool {
    seq_new = try generator.clone(); // deinited in deinit()
    try seq_new.appendSlice(tail.items);
    dict_new = try cloneDict(dict);

    const l: usize = seq_new.items.len;
    for (0..@intCast((c_cand - 1) * p_cand)) |i| {
        const a: i32 = seq_new.items[l - 1 - i];
        const b: i32 = seq_new.items[l - 1 - i - @as(usize, @intCast(p_cand))];
        if (a != b and a > 0 and b > 0) {
            return false;
        }
        if (a > b) {
            for (0..l) |j| {
                if (seq_new.items[j] == b) {
                    seq_new.items[j] = a;
                }
            }

            var deleted = dict_new.fetchRemove(b).?;
            var iterator = deleted.value.keyIterator();
            while (iterator.next()) |item| {
                try dict_new.getPtr(a).?.put(item.*, {});
            }
            deleted.value.deinit();
        } else if (b > a) {
            for (0..l) |j| {
                if (seq_new.items[j] == a) {
                    seq_new.items[j] = b;
                }
            }

            var deleted = dict_new.fetchRemove(a).?;
            var iterator = deleted.value.keyIterator();
            while (iterator.next()) |item| {
                try dict_new.getPtr(b).?.put(item.*, {});
            }
            deleted.value.deinit();
        }
    }
    return true;
}

pub fn test_2() !bool {
    const l: usize = seq_new.items.len;

    var tmp_seq = try seq_new.clone();
    defer tmp_seq.deinit();
    try tmp_seq.append(c_cand);

    var tmp_periods = try periods.clone();
    defer tmp_periods.deinit();
    try tmp_periods.append(p_cand);

    var curl: i32 = 1;
    var period: i32 = 0;
    for (0..l - length + 1) |i| {
        var temp = ArrayList(i32).init(allocator);
        defer temp.deinit();

        try temp.appendSlice(seq_new.items[0 .. length + i]);

        curl = 1;
        period = 0;
        try krul(&temp, &curl, &period);
        if (curl != tmp_seq.items[length + i] or period != tmp_periods.items[i]) {
            return false;
        }
    }
    return true;
}

pub fn check_if_period_works() !bool {
    if (try test_1()) {
        if (try test_2()) {
            return true;
        }
    }
    return false;
}

pub fn backtracking_step() !void {
    if (try check_if_period_works()) {
        try append();
    } else {
        try up();
    }
}

pub fn backtracking(k2: i32, p2: i32) !void {
    loop: while (c_cand != 0) {
        if (tail.items.len == 0 and c_cand == k2 and p_cand == p2) {
            break :loop;
        }
        try backtracking_step();
    }

    var record: usize = 0;
    for (0..length) |i| {
        if (max_lengths.items[i] > record) {
            record = max_lengths.items[i];
            std.debug.print("{d}: {d}, [", .{ i + 1, record });
            for (best_gens.items[i].items) |item| {
                std.debug.print("{d}, ", .{item});
            }
            std.debug.print("]\n", .{});
        }
    }
}

pub fn main() !void {
    // const stdout = std.io.getStdOut().writer();

    // const stdin = std.io.getStdIn().reader();
    // try stdout.print("Hello, {s}!\n", .{"world"});

    try init();
    defer deinit();

    const start = std.time.nanoTimestamp();
    try backtracking(25, 25);
    const end = std.time.nanoTimestamp();
    std.debug.print("time elapsed: {d} ns", .{end - start});
}
