const std = @import("std");
const jdz_allocator = @import("jdz_allocator");
const JdzGlobalAllocator = jdz_allocator.JdzGlobalAllocator(.{});
const ArrayList = std.ArrayList; // c++ equivalent: std::vector<>
const Mutex = std.Thread.Mutex;
const Map = std.AutoHashMap; // c++ equivalent: std::map<>
inline fn Set(comptime T: type) type { // c++ equivalent: std::set<>
    return Map(T, void);
}

// var arena: std.heap.ArenaAllocator = undefined;
pub var allocator: std.mem.Allocator = undefined;

const Value = i16;
const Sequence = ArrayList(Value);

// see init() for comments on this variables
pub const length: Value = 60; // max length of generators to consider

threadlocal var c_cand: Value = undefined;
threadlocal var p_cand: Value = undefined;
threadlocal var tail: Sequence = undefined;
threadlocal var periods: Sequence = undefined;
threadlocal var generator: Sequence = undefined;
threadlocal var generators_mem: Map(usize, Sequence) = undefined;
threadlocal var change_indices: Set(usize) = undefined;
threadlocal var seq_new: Sequence = undefined;
threadlocal var best_gens: ArrayList(Sequence) = undefined;
threadlocal var max_lengths: ArrayList(usize) = undefined;

pub var global_max_lengths: ArrayList(usize) = undefined;
pub var global_best_gens: ArrayList(Sequence) = undefined;

pub var mutex: Mutex = undefined;

// following function is for copying a Map(Value, Set(Value)), that is, not only the map itself (map.clone()), but also its values (the sets)
fn cloneDict(src: Map(Value, Set(Value))) !Map(Value, Set(Value)) {
    var dest = Map(Value, Set(Value)).init(src.allocator);
    var it = src.iterator();
    while (it.next()) |entry| {
        var set = Set(Value).init(dest.allocator);
        var value_it = entry.value_ptr.keyIterator();
        while (value_it.next()) |key_ptr| {
            try set.put(key_ptr.*, {});
        }
        try dest.put(entry.key_ptr.*, set);
    }
    return dest;
}

// clearDict frees a Map(K, V) and calls for every value V.deinit() (usefull for freeing a Map(Value, Set(Value)), or a Map(usize, Sequence))
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
    tail = Sequence.init(alloc); // tail has zero or more elements, and all its elements are integers larger than 1
    periods = Sequence.init(alloc); // The size of periods always equals the size of tail, and in contains the periods corresponding to the elements of tail.
    generator = Sequence.init(alloc); // generator always has length elements which are integers
    max_lengths = ArrayList(usize).init(alloc); // at i, the value of max_lengths is the largest (official) tail length of a string with length i+1.
    generators_mem = Map(usize, Sequence).init(alloc); // a map in which the keys are all the places in tail which are not in exactly and in which the values are the corresponding generators.
    best_gens = ArrayList(Sequence).init(alloc); // for each i, the value of best_gens is the set of all generators with length i+1 which yield the record value.
    change_indices = Set(usize).init(alloc); // places in the tail where the generator was changed
    // dict = Map(Value, Set(Value)).init(alloc); // At key k, dict has as value the list of numbers i such that exp_seq[i]=k, where exp_seq = generator + tail.
    // dicts_mem = Map(usize, Map(Value, Set(Value))).init(alloc); //  a map of maps corresponding to the generators in generators_mem

    seq_new = Sequence.init(alloc);
    // dict_new = Map(Value, Set(Value)).init(alloc);

    // creating default values
    try change_indices.put(0, {});

    var empty_gen: Sequence = Sequence.init(alloc);
    defer empty_gen.deinit();

    for (0..length) |i| {
        var set: Set(Value) = Set(Value).init(alloc);
        defer set.deinit();
        try set.put(@as(Value, @intCast(i)), {});

        try generator.append(-length + @as(Value, @intCast(i))); // type?
        // try dict.put(-@as(Value, @intCast(i)), try set.clone());
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

    // clearDict(Map(Value, Set(Value)), &dict);
    // clearDict(Map(Value, Set(Value)), &dict_new);
    clearDict(Map(usize, Sequence), &generators_mem);

    // dicts_mem: Map(usize, Map(Value, Set(Value)))
    // var it = dicts_mem.valueIterator();
    // while (it.next()) |item| {
    //     clearDict(Map(Value, Set(Value)), item); // first every inner Map is deallocated...
    // }
    // dicts_mem.deinit(); // then also the outer one

    for (best_gens.items) |sequence| {
        sequence.deinit();
    }
    best_gens.deinit();

    // arena.deinit();
}

// seq is an arraylist with arbitrary Value integers, returns the curling number of that list
pub fn krul(seq: *Sequence, curl: *Value, period: *Value) !void {
    curl.* = 1;
    period.* = 0;

    const l = seq.items.len;
    for (1..l / 2 + 1) |i| {
        var j = i;
        while (seq.items[l - j - 1] == seq.items[l - j - 1 + i]) {
            j += 1;
            if (j >= l) {
                const candidate: Value = @intCast(j / i);
                if (candidate > curl.*) {
                    curl.* = candidate;
                    period.* = @intCast(i);
                }
                break;
            }
            const cand: Value = @intCast(j / i); // usize -> Value
            if (cand > curl.*) {
                curl.* = cand;
                period.* = @intCast(i); // usize -> Value
            }
        }
    }
}

// seq is a list with arbitrary integers as entries. Returns the official tail of seq together with the list of corresponding minimal periods.
pub fn tail_with_periods(seq: *Sequence, seq_tail: *Sequence, seq_periods: *Sequence) !void {
    var curl: Value = 1;
    var period: Value = 0;
    var temp: Sequence = try seq.clone();
    defer temp.deinit();

    const l: usize = seq.items.len;
    try krul(seq, &curl, &period);
    while (curl > 1) {
        try temp.append(curl);
        try seq_periods.append(period);
        try krul(&temp, &curl, &period);
    }
    seq_tail.clearRetainingCapacity();
    try seq_tail.appendSlice(temp.items[l..]);
}

// seq is a list with arbitrary integers as entries. Returns first i entries of the official tail of seq
// together with the list of corresponding minimal periods.
// If the official tail is smaller than i, return the entire tail and periods.
pub fn tail_with_periods_part(seq: *Sequence, seq_tail: *Sequence, seq_periods: *Sequence, i: Value) !void {
    var curl: Value = 1;
    var period: Value = 0;
    var temp: Sequence = try seq.clone();
    defer temp.deinit();

    const l: usize = seq.items.len;
    try krul(seq, &curl, &period);
    while (curl > 1 and seq_tail.items.len < i) {
        try temp.append(curl);
        try seq_periods.append(period);
        try krul(&temp, &curl, &period);
    }
    seq_tail.clearRetainingCapacity();
    seq_tail.appendSlice(temp.items[l..]);
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
            if (tail.items.len == 0) {
                c_cand = 0; // terminate program
                break :loop;
            }
            if (change_indices.get(periods.items.len) != null) {
                _ = change_indices.remove(periods.items.len);
            }
            if (change_indices.get(periods.items.len - 1) == null) {
                try change_indices.put(periods.items.len - 1, {});
                // _ = dict.getPtr(tail.getLast()).?.remove(@as(Value, @intCast(length + tail.items.len - 1)));
                c_cand = tail.getLast() + 1;
                p_cand = 1;
            } else {
                c_cand = tail.getLast();
                p_cand = periods.getLast() + 1;

                generator.clearRetainingCapacity(); // future optimalization (done)
                generator.appendSliceAssumeCapacity(generators_mem.get(periods.items.len - 1).?.items);
                // generator = try generators_mem.get(periods.items.len - 1).?.clone();

                // clearDict(Map(Value, Set(Value)), &dict);
                // dict = try cloneDict(dicts_mem.get(periods.items.len).?);
                var del = generators_mem.fetchRemove(periods.items.len - 1); // remove the generator at index periods.items.len and return it
                clearOptional(Map(usize, Sequence).KV, &del);
                // var deleted = dicts_mem.fetchRemove(periods.items.len); // remove the dict at index periods.items.len and return it
                // if (deleted != null) {
                //     clearDict(Map(Value, Set(Value)), &(deleted.?.value));
                // }
            }
            _ = tail.pop();
            _ = periods.pop();
        }
    }
}

// returns the smallest length of a suffix of generator which gives the same tail
pub fn real_gen_len() usize {
    var i: usize = 0;
    loop: while (generator.items[i] == (-length + @as(Value, @intCast(i)))) { // typeError expected
        i += 1;
        if (i == length) {
            break :loop;
        }
    }
    return length - i;
}

pub fn check_positive(len: Value) bool {
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
    clearOptional(Map(usize, Sequence).KV, &del); // and return previous value, if there was something at that index

    // var deleted = try dicts_mem.fetchPut(@intCast(periods.items.len), try cloneDict(dict));
    // if (deleted != null) {
    //     clearDict(Map(Value, Set(Value)), &(deleted.?.value));
    // }

    generator.clearRetainingCapacity(); // future optimalization (done)
    generator.appendSliceAssumeCapacity(seq_new.items[0..length]);
    // clearDict(Map(Value, Set(Value)), &dict);
    // dict = try cloneDict(dict_new);

    // if (dict.getPtr(c_cand) != null) {
    //     try dict.getPtr(c_cand).?.put(@intCast(length + periods.items.len), {});
    //     try dict_new.getPtr(c_cand).?.put(@intCast(length + periods.items.len), {});
    // } else {
    //     var set: Set(Value) = Set(Value).init(allocator);
    //     defer set.deinit();

    //     try set.put(@intCast(length + periods.items.len), {});

    //     var removed = try dict.fetchPut(c_cand, try set.clone()); // set index c_cand to set.clone and return previous value if there was something at that index
    //     clearOptional(Map(Value, Set(Value)).KV, &removed);
    //     removed = try dict_new.fetchPut(c_cand, try set.clone()); // set index c_cand to set.clone and return previous value if there was something at that index
    //     clearOptional(Map(Value, Set(Value)).KV, &removed);
    // }

    try tail.append(c_cand);
    try periods.append(p_cand);

    var curl: Value = 1;
    var period: Value = 0;
    var temp = try generator.clone();
    defer temp.deinit();

    try temp.appendSlice(tail.items);

    // add the complete tail
    loop: while (true) {
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
        //     var set: Set(Value) = Set(Value).init(allocator);
        //     defer set.deinit();

        //     try set.put(@intCast(length + periods.items.len - 1), {});

        //     var removed = try dict.fetchPut(curl, try set.clone()); // set index curl to set.clone and return previous value if there was something at that index
        //     clearOptional(Map(Value, Set(Value)).KV, &removed);
        //     removed = try dict_new.fetchPut(curl, try set.clone()); // set index curl to set.clone and return previous value if there was something at that index
        //     clearOptional(Map(Value, Set(Value)).KV, &removed);
        // }
    }

    c_cand = 2;
    p_cand = 1;
    try change_indices.put(periods.items.len, {});

    // update max_lengths
    const len: usize = real_gen_len();
    if (max_lengths.getLast() == periods.items.len) {
        var tmp: Sequence = try best_gens.getLast().clone();
        defer tmp.deinit();

        try tmp.appendSlice(generator.items[0 .. generator.items.len - len]);
        var last = best_gens.pop();
        last.deinit();
        try best_gens.append(try tmp.clone());
    }
    if (max_lengths.items[len - 1] < periods.items.len) {
        max_lengths.items[len - 1] = periods.items.len;

        var tmp = Sequence.init(allocator);
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
    seq_new.clearRetainingCapacity(); // future optimalization (done)
    try seq_new.appendSlice(generator.items);
    try seq_new.appendSlice(tail.items);
    // clearDict(Map(Value, Set(Value)), &dict_new);
    // dict_new = try cloneDict(dict);

    const k: usize = generator.items.len;
    const l: usize = seq_new.items.len;
    for (0..@intCast((c_cand - 1) * p_cand)) |i| {
        const a: Value = seq_new.items[l - 1 - i];
        const b: Value = seq_new.items[l - 1 - i - @as(usize, @intCast(p_cand))];
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
            // clearOptional(Map(Value, Set(Value)).KV, &deleted);
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
            // clearOptional(Map(Value, Set(Value)).KV, &deleted);
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

    var curl: Value = 1;
    var period: Value = 0;
    for (0..l - length + 1) |i| {
        var temp = Sequence.init(allocator);
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
pub fn backtracking(k1: Value, p1: Value, k2: Value, p2: Value) void {
    defer JdzGlobalAllocator.deinitThread(); // call this from every thread that makes an allocation

    // generator, tail are the lists we are currently studying. They are not in the memory.
    // If we append and move on to new generator/longer tail, then we put the old generator in the memory.
    // If we up() and the tail length remains the same, then Generator is changed and the memory remains the same.
    // If we up() and the tail length becomes smaller, but we do not pass by an entry of the memory, then generator is changed and the memory remains the same.
    // If we up() and the tail length becomes smaller, and we do pass by an entry of the memory, then generator is deleted and replaced by
    // the last entry of generators_mem, which is also deleted from the memory.
    // Since we have one universal tail and also one universal periods, these never need to be in the memory.

    c_cand = k1;
    p_cand = p1;

    init(allocator) catch @panic("error");
    defer deinit();

    const t1 = std.time.milliTimestamp();
    loop: while (c_cand != 0) {
        if (tail.items.len == 0 and c_cand == k2 and p_cand == p2) {
            break :loop;
        }
        backtracking_step() catch @panic("error");
    }
    const t2 = std.time.milliTimestamp();

    mutex.lock();
    for (0..length) |i| {
        if (max_lengths.items[i] > global_max_lengths.items[i]) {
            global_max_lengths.items[i] = max_lengths.items[i];
            global_best_gens.items[i] = best_gens.items[i].clone() catch @panic("error");
        }
    }
    mutex.unlock();

    // var record: usize = 0;
    // for (0..length) |i| {
    //     if (max_lengths.items[i] > record) {
    //         record = max_lengths.items[i];
    //         std.debug.print("{d}: {d}, [", .{ i + 1, record });
    //         for (best_gens.items[i].items) |item| {
    //             std.debug.print("{d}, ", .{item});
    //         }
    //         std.debug.print("]\n", .{});
    //     }
    // }

    std.debug.print("finished {d}, {d}, {d}, {d}, duration: {d}\n", .{ k1, p1, k2, p2, t2 - t1 });
}

pub fn multi_threader() !void {
    var wait_group: std.Thread.WaitGroup = undefined;
    wait_group.reset();

    var pool: std.Thread.Pool = undefined;
    try pool.init(.{ .allocator = allocator });
    defer pool.deinit();

    try pool.spawn(backtracking, .{ 2, 1, 2, 3 });
    try pool.spawn(backtracking, .{ 2, 3, 2, 7 });
    try pool.spawn(backtracking, .{ 2, 7, 2, 24 });
    try pool.spawn(backtracking, .{ 2, 24, 2, 40 });
    try pool.spawn(backtracking, .{ 2, 40, 3, 3 });
    try pool.spawn(backtracking, .{ 3, 3, 3, 24 });
    try pool.spawn(backtracking, .{ 3, 24, 5, 1 });
    try pool.spawn(backtracking, .{ 5, 1, 1000, 1000 });

    pool.waitAndWork(&wait_group);
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

    defer JdzGlobalAllocator.deinit();
    defer JdzGlobalAllocator.deinitThread(); // call this from every thread that makes an allocation

    allocator = JdzGlobalAllocator.allocator();

    global_best_gens = ArrayList(Sequence).init(allocator);
    global_max_lengths = ArrayList(usize).init(allocator);

    var empty_seq = Sequence.init(allocator);
    defer empty_seq.deinit();
    for (0..length) |_| {
        try global_max_lengths.append(0);
        try global_best_gens.append(try empty_seq.clone());
    }

    const start = std.time.milliTimestamp();
    try multi_threader();
    const end = std.time.milliTimestamp();

    var record: usize = 0;
    for (0..length) |i| {
        if (global_max_lengths.items[i] > record) {
            record = global_max_lengths.items[i];
            std.debug.print("{d}: {d}, [", .{ i + 1, record });
            for (global_best_gens.items[i].items) |item| {
                std.debug.print("{d}, ", .{item});
            }
            std.debug.print("]\n", .{});
        }
    }

    std.debug.print("time elapsed: {d} ms\n", .{end - start});
}
