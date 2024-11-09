const std = @import("std");
const jdz_allocator = @import("jdz_allocator");
const ArrayList = std.ArrayList; // c++ equivalent: std::vector<>
const Map = std.AutoHashMap; // c++ equivalent: std::map<>
inline fn Set(comptime T: type) type { // c++ equivalent: std::set<>
    return Map(T, void);
}

// var arena: std.heap.ArenaAllocator = undefined;
pub var allocator: std.mem.Allocator = undefined;

// see init() for comments on this variables
pub const length: i32 = 40; // max length of generators to consider
pub var c_cand: i32 = undefined;
pub var p_cand: i32 = undefined;
pub var tail: ArrayList(i32) = undefined;
pub var periods: ArrayList(i32) = undefined;
pub var generator: ArrayList(i32) = undefined;
pub var max_lengths: ArrayList(usize) = undefined;
pub var generators_mem: Map(usize, ArrayList(i32)) = undefined;
pub var best_gens: ArrayList(ArrayList(i32)) = undefined;
pub var change_indices: Set(usize) = undefined;
// pub var dict: Map(i32, Set(i32)) = undefined;
// pub var dicts_mem: Map(usize, Map(i32, Set(i32))) = undefined;

pub var seq_new: ArrayList(i32) = undefined;
// pub var dict_new: Map(i32, Set(i32)) = undefined;

// following function is for copying a Map(i32, Set(i32)), that is, not only the map itself (map.clone()), but also its values (the sets)
fn cloneDict(src: Map(i32, Set(i32))) !Map(i32, Set(i32)) {
    var dest = Map(i32, Set(i32)).init(src.allocator);
    var it = src.iterator();
    while (it.next()) |entry| {
        var set = Set(i32).init(dest.allocator);
        var value_it = entry.value_ptr.keyIterator();
        while (value_it.next()) |key_ptr| {
            try set.put(key_ptr.*, {});
        }
        try dest.put(entry.key_ptr.*, set);
    }
    return dest;
}

// clearDict frees a Map(K, V) and calls for every value V.deinit() (usefull for freeing a Map(i32, Set(i32)), or a Map(usize, ArrayList(i32)))
fn clearDict(comptime T: type, src: *T) void {
    var it = src.valueIterator();
    while (it.next()) |seq| {
        seq.deinit();
    }
    src.deinit();
}

// if the optional KV pair is available, it is deallocated
fn clearOptional(comptime T: type, value: *?T) void {
    if (value.* != null) {
        value.*.?.value.deinit();
    }
}

// fn initAllocator() void {
//     arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     allocator = arena.allocator();
// }

pub fn init(alloc: std.mem.Allocator) !void {

    // init data structures
    c_cand = 2; // the curling number which we will test next; if it works, we will append it to tail.
    p_cand = 1; // the period which we will test next; if it works, we will append it to periods.
    tail = ArrayList(i32).init(alloc); // tail has zero or more elements, and all its elements are integers larger than 1
    periods = ArrayList(i32).init(alloc); // The size of periods always equals the size of tail, and in contains the periods corresponding to the elements of tail.
    generator = ArrayList(i32).init(alloc); // generator always has length elements which are integers
    max_lengths = ArrayList(usize).init(alloc); // at i, the value of max_lengths is the largest (official) tail length of a string with length i+1.
    generators_mem = Map(usize, ArrayList(i32)).init(alloc); // a map in which the keys are all the places in tail which are not in exactly and in which the values are the corresponding generators.
    best_gens = ArrayList(ArrayList(i32)).init(alloc); // for each i, the value of best_gens is the set of all generators with length i+1 which yield the record value.
    change_indices = Set(usize).init(alloc); // places in the tail where the generator was changed
    // dict = Map(i32, Set(i32)).init(alloc); // At key k, dict has as value the list of numbers i such that exp_seq[i]=k, where exp_seq = generator + tail.
    // dicts_mem = Map(usize, Map(i32, Set(i32))).init(alloc); //  a map of maps corresponding to the generators in generators_mem

    seq_new = ArrayList(i32).init(alloc);
    // dict_new = Map(i32, Set(i32)).init(alloc);

    // creating default values
    try change_indices.put(0, {});

    var empty_gen: ArrayList(i32) = ArrayList(i32).init(alloc);
    defer empty_gen.deinit();

    for (0..length) |i| {
        var set: Set(i32) = Set(i32).init(alloc);
        defer set.deinit();
        try set.put(@as(i32, @intCast(i)), {});

        try generator.append(-length + @as(i32, @intCast(i))); // type?
        // try dict.put(-@as(i32, @intCast(i)), try set.clone());
        try max_lengths.append(0);
        try best_gens.append(try empty_gen.clone());
    }
}

// deallocates all data at the end of the program
// use in combination with init eg:
// try init();
// defer deinit();
pub fn deinit() void {
    tail.deinit();
    periods.deinit();
    generator.deinit();
    max_lengths.deinit();
    change_indices.deinit();
    seq_new.deinit();

    // clearDict(Map(i32, Set(i32)), &dict);
    // clearDict(Map(i32, Set(i32)), &dict_new);
    clearDict(Map(usize, ArrayList(i32)), &generators_mem);

    // dicts_mem: Map(usize, Map(i32, Set(i32)))
    // var it = dicts_mem.valueIterator();
    // while (it.next()) |item| {
    //     clearDict(Map(i32, Set(i32)), item); // first every inner Map is deallocated...
    // }
    // dicts_mem.deinit(); // then also the outer one

    for (best_gens.items) |sequence| {
        sequence.deinit();
    }
    best_gens.deinit();

    // arena.deinit();
}

// seq is an arraylist with arbitrary i32 integers, returns the curling number of that list
pub fn krul(seq: *ArrayList(i32), curl: *i32, period: *i32) !void {
    const l = seq.items.len;
    for (1..l / 2 + 1) |i| {
        var j = i;
        while (seq.items[l - j - 1] == seq.items[l - j - 1 + i]) {
            j += 1;
            if (j >= l) {
                break;
            }
        }
        const cand: i32 = @intCast(j / i); // usize -> i32
        if (cand > curl.*) {
            curl.* = cand;
            period.* = @intCast(i); // usize -> i32
        }
    }
}

// seq is a list with arbitrary integers as entries. Returns the official tail of seq together with the list of corresponding minimal periods.
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

// seq is a list with arbitrary integers as entries. Returns first i entries of the official tail of seq
// together with the list of corresponding minimal periods.
// If the official tail is smaller than i, return the entire tail and periods.
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

// checks whether the size of p_cand is not too big.
pub fn check_periods_size() bool {
    return (c_cand * p_cand) > (length + periods.items.len);
}

// checks whether the size of c_cand is not too big.
pub fn check_c_cand_size() bool {
    if (tail.items.len != 0) {
        return c_cand > tail.getLast() + 1;
    } else {
        return c_cand > length;
    }
}

// If a period does not work(i.e. if (!check_if_period_works())), we up().
pub fn up() !void {
    p_cand += 1;
    loop: while (check_periods_size()) {
        c_cand += 1;
        p_cand = 1;
        if (check_c_cand_size()) {
            if (change_indices.get(periods.items.len) != null) {
                _ = change_indices.remove(periods.items.len);
            }
            if (tail.items.len == 0) {
                c_cand = 0; // terminate program
                break :loop;
            }
            if (change_indices.get(periods.items.len - 1) == null) {
                try change_indices.put(periods.items.len - 1, {});
                // _ = dict.getPtr(tail.getLast()).?.remove(@as(i32, @intCast(length + tail.items.len - 1)));
                c_cand = tail.pop() + 1;
                p_cand = 1;
                _ = periods.pop();
            } else {
                c_cand = tail.pop();
                p_cand = periods.pop() + 1;

                generator.clearAndFree(); // future optimalization
                generator = try generators_mem.get(periods.items.len).?.clone();

                // clearDict(Map(i32, Set(i32)), &dict);
                // dict = try cloneDict(dicts_mem.get(periods.items.len).?);
                var del = generators_mem.fetchRemove(periods.items.len); // remove the generator at index periods.items.len and return it
                clearOptional(Map(usize, ArrayList(i32)).KV, &del);
                // var deleted = dicts_mem.fetchRemove(periods.items.len); // remove the dict at index periods.items.len and return it
                // if (deleted != null) {
                //     clearDict(Map(i32, Set(i32)), &(deleted.?.value));
                // }
            }
        }
    }
}

// returns the smallest length of a suffix of generator which gives the same tail
pub fn real_gen_len() usize {
    var i: usize = 0;
    loop: while (generator.items[i] == (-length + @as(i32, @intCast(i)))) { // typeError expected
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

//  When we append, we may immediately append the next curls until 1 occurs.
//  When we, by up(), come back at those places at a later time, we
//  can immediately skip all other periods and raise the c_cand with 1.
//  This is because our end goal is not to find all possible combinations of
//  tail and periods, but only tail matters. So when there may be more than 1 period at the same time corresponding to a curl,
//  then we only have to take the one that always occurs.
//  This does not work after we have raised with 1, from then it may be that one generatorchange gives one period,
//  and another generatorchange gives another period, but not at the same time, and all for the same curl.
//  If a period does work(i.e. if (check_if_period_works())), we append().
pub fn append() !void {
    var del = try generators_mem.fetchPut(periods.items.len, try generator.clone()); // set index periods.items.len to (the current) generator
    clearOptional(Map(usize, ArrayList(i32)).KV, &del); // and return previous value, if there was something at that index

    // var deleted = try dicts_mem.fetchPut(@intCast(periods.items.len), try cloneDict(dict));
    // if (deleted != null) {
    //     clearDict(Map(i32, Set(i32)), &(deleted.?.value));
    // }

    generator.clearAndFree(); // future optimalization
    try generator.appendSlice(seq_new.items[0..length]);
    // clearDict(Map(i32, Set(i32)), &dict);
    // dict = try cloneDict(dict_new);

    // if (dict.getPtr(c_cand) != null) {
    //     try dict.getPtr(c_cand).?.put(@intCast(length + periods.items.len), {});
    //     try dict_new.getPtr(c_cand).?.put(@intCast(length + periods.items.len), {});
    // } else {
    //     var set: Set(i32) = Set(i32).init(allocator);
    //     defer set.deinit();

    //     try set.put(@intCast(length + periods.items.len), {});

    //     var removed = try dict.fetchPut(c_cand, try set.clone()); // set index c_cand to set.clone and return previous value if there was something at that index
    //     clearOptional(Map(i32, Set(i32)).KV, &removed);
    //     removed = try dict_new.fetchPut(c_cand, try set.clone()); // set index c_cand to set.clone and return previous value if there was something at that index
    //     clearOptional(Map(i32, Set(i32)).KV, &removed);
    // }

    try tail.append(c_cand);
    try periods.append(p_cand);

    var curl: i32 = 1;
    var period: i32 = 0;
    var temp = try generator.clone();
    defer temp.deinit();

    try temp.appendSlice(tail.items);

    // add the complete tail
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

        // if (dict.getPtr(curl) != null) {
        //     try dict.getPtr(curl).?.put(@intCast(length + periods.items.len - 1), {});
        //     try dict_new.getPtr(curl).?.put(@intCast(length + periods.items.len - 1), {});
        // } else {
        //     var set: Set(i32) = Set(i32).init(allocator);
        //     defer set.deinit();

        //     try set.put(@intCast(length + periods.items.len - 1), {});

        //     var removed = try dict.fetchPut(curl, try set.clone()); // set index curl to set.clone and return previous value if there was something at that index
        //     clearOptional(Map(i32, Set(i32)).KV, &removed);
        //     removed = try dict_new.fetchPut(curl, try set.clone()); // set index curl to set.clone and return previous value if there was something at that index
        //     clearOptional(Map(i32, Set(i32)).KV, &removed);
        // }
    }

    c_cand = 2;
    p_cand = 1;
    try change_indices.put(periods.items.len, {});

    // update max_lengths
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

        var tmp = ArrayList(i32).init(allocator);
        defer tmp.deinit();
        try tmp.appendSlice(generator.items[generator.items.len - len ..]);

        var removed = best_gens.items[len - 1];
        best_gens.items[len - 1] = try tmp.clone();
        removed.deinit();
    }
}

// this function tries to construct new_seq and new_dict, but we don't know if that's possible.
// if there's an error somewhere in the process, it returns false
// if everything went correctly, this function returns true
pub fn test_1() !bool {
    seq_new.clearAndFree(); // future optimalization
    seq_new = try generator.clone(); // deinited in deinit()
    try seq_new.appendSlice(tail.items);
    // clearDict(Map(i32, Set(i32)), &dict_new);
    // dict_new = try cloneDict(dict);

    const k: usize = generator.items.len;
    const l: usize = seq_new.items.len;
    for (0..@intCast((c_cand - 1) * p_cand)) |i| {
        const a: i32 = seq_new.items[l - 1 - i];
        const b: i32 = seq_new.items[l - 1 - i - @as(usize, @intCast(p_cand))];
        if (a != b and a > 0 and b > 0) {
            return false; // fail
        }
        if (a > b) {
            for (0..k) |j| {
                if (seq_new.items[j] == b) {
                    seq_new.items[j] = a;
                }
            }

            // var deleted = dict_new.fetchRemove(b); // remove the set at index b and return it
            // var iterator = deleted.?.value.keyIterator();
            // while (iterator.next()) |item| {
            //     try dict_new.getPtr(a).?.put(item.*, {});
            // }
            // clearOptional(Map(i32, Set(i32)).KV, &deleted);
        } else if (b > a) {
            for (0..k) |j| {
                if (seq_new.items[j] == a) {
                    seq_new.items[j] = b;
                }
            }

            // var deleted = dict_new.fetchRemove(a); // remove the set at index a and return it
            // var iterator = deleted.?.value.keyIterator();
            // while (iterator.next()) |item| {
            //     try dict_new.getPtr(b).?.put(item.*, {});
            // }
            // clearOptional(Map(i32, Set(i32)).KV, &deleted);
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

var last_capacity: usize = 0;

// one step in the backtracking algorithm
pub fn backtracking_step() !void {
    // var best_gens_sum: usize = 0;
    // for (best_gens.items) |seq| {
    //     best_gens_sum += seq.items.len;
    // }
    // var generators_mem_sum: usize = 0;
    // var it = generators_mem.iterator();
    // while (it.next()) |entry| {
    //     generators_mem_sum += entry.value_ptr.items.len;
    // }
    // std.debug.print("{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\n", .{ tail.items.len, periods.items.len, generator.items.len, max_lengths.items.len, generators_mem_sum, change_indices.count(), best_gens_sum, seq_new.items.len });
    // const capacity = arena.queryCapacity();
    // if (capacity != last_capacity) {
    //     last_capacity = capacity;
    //     std.debug.print("{d}\n", .{capacity});
    // }
    if (try check_if_period_works()) {
        try append();
    } else {
        try up();
    }
}

// for default behavior enter k2=1000,p2=1000
pub fn backtracking(k2: i32, p2: i32) !void {
    // generator, tail are the lists we are currently studying. They are not in the memory.
    // If we append and move on to new generator/longer tail, then we put the old generator in the memory.
    // If we up() and the tail length remains the same, then Generator is changed and the memory remains the same.
    // If we up() and the tail length becomes smaller, but we do not pass by an entry of the memory, then generator is changed and the memory remains the same.
    // If we up() and the tail length becomes smaller, and we do pass by an entry of the memory, then generator is deleted and replaced by
    // the last entry of generators_mem, which is also deleted from the memory.
    // Since we have one universal tail and also one universal periods, these never need to be in the memory.

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

    //    initAllocator();
    //
    //    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    //    // allocator = gpa.allocator();
    //    // defer {
    //    //     const deinit_status = gpa.deinit();
    //    //     //fail test; can't try in defer as defer is executed after we return
    //    //     if (deinit_status == .leak) std.testing.expect(false) catch @panic("TEST FAIL");
    //    // }
    //    // try init(allocator);
    //    // defer deinit();
    //
    //    allocator = std.heap.c_allocator;
    //
    //    try init(std.heap.c_allocator);
    //    defer deinit();

    // var jdz = jdz_allocator.JdzAllocator(.{}).init();
    // defer jdz.deinit();

    // allocator = jdz.allocator();

    const JdzGlobalAllocator = jdz_allocator.JdzGlobalAllocator(.{});
    defer JdzGlobalAllocator.deinit();
    defer JdzGlobalAllocator.deinitThread(); // call this from every thread that makes an allocation

    allocator = JdzGlobalAllocator.allocator();

    try init(allocator);
    defer deinit();

    const start = std.time.milliTimestamp();
    try backtracking(1000, 1000);
    const end = std.time.milliTimestamp();
    std.debug.print("time elapsed: {d} ms\n", .{end - start});
}
