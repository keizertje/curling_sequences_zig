const std = @import("std");

const N = 100_000_000; // Aantal getallen om te testen

pub fn main() !void {
    const gpa = std.heap.c_allocator;
    var rnd = std.Random.DefaultPrng.init(42); // Gebruik vaste seed voor consistente resultaten
    const random = rnd.random();

    // Genereer N willekeurige getallen
    var numbers = try std.ArrayList(u32).initCapacity(gpa, N);
    defer numbers.deinit();
    for (0..N) |_| {
        try numbers.append(random.int(u32) % (N * 10)); // Willekeurige getallen
    }

    // **HashMap Benchmark**
    var hashmap = std.AutoHashMap(u32, void).init(gpa);
    defer hashmap.deinit();

    const start_hash_insert = std.time.nanoTimestamp();
    for (numbers.items) |num| {
        try hashmap.put(num, {});
    }
    const end_hash_insert = std.time.nanoTimestamp();

    const start_hash_lookup = std.time.nanoTimestamp();
    for (numbers.items) |num| {
        _ = hashmap.contains(num);
    }
    const end_hash_lookup = std.time.nanoTimestamp();

    const start_hash_remove = std.time.nanoTimestamp();
    for (numbers.items) |num| {
        _ = hashmap.remove(num);
    }
    const end_hash_remove = std.time.nanoTimestamp();

    // **BitSet Benchmark**
    var bitset = try std.DynamicBitSet.initEmpty(gpa, N * 10); // Startgrootte
    defer bitset.deinit();

    const start_bitset_insert = std.time.nanoTimestamp();
    for (numbers.items) |num| {
        bitset.set(num);
    }
    const end_bitset_insert = std.time.nanoTimestamp();

    const start_bitset_lookup = std.time.nanoTimestamp();
    for (numbers.items) |num| {
        _ = bitset.isSet(num);
    }
    const end_bitset_lookup = std.time.nanoTimestamp();

    const start_bitset_remove = std.time.nanoTimestamp();
    for (numbers.items) |num| {
        bitset.unset(num);
    }
    const end_bitset_remove = std.time.nanoTimestamp();

    // **Resultaten printen**
    std.debug.print("HashMap Insert: {} ms\n", .{@divTrunc(end_hash_insert - start_hash_insert, std.time.ns_per_ms)});
    std.debug.print("HashMap Lookup: {} ms\n", .{@divTrunc(end_hash_lookup - start_hash_lookup, std.time.ns_per_ms)});
    std.debug.print("HashMap Remove: {} ms\n", .{@divTrunc(end_hash_remove - start_hash_remove, std.time.ns_per_ms)});

    std.debug.print("BitSet Insert: {} ms\n", .{@divTrunc(end_bitset_insert - start_bitset_insert, std.time.ns_per_ms)});
    std.debug.print("BitSet Lookup: {} ms\n", .{@divTrunc(end_bitset_lookup - start_bitset_lookup, std.time.ns_per_ms)});
    std.debug.print("BitSet Remove: {} ms\n", .{@divTrunc(end_bitset_remove - start_bitset_remove, std.time.ns_per_ms)});
}
