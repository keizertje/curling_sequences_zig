const std = @import("std");
const jdz_allocator = @import("jdz_allocator");

const v16 = std.ArrayList(i16);
const Map = std.AutoHashMap;

const context = struct { length: i16, c_cand: i16, p_cand: i16, depth: i16, seq: v16, seq_new: v16, periods: v16, pairs: v16, temp: v16, seq_map: std.ArrayList(v16), change_indices: Map(i16, void), grts_mem: Map(i16, v16), best_tails: v16, best_grts: std.ArrayList(v16) };

var queue = std.SinglyLinkedList(v16){}; // doesn't need an alocator (so why not initialize it here)
var g_best_tails: v16 = undefined;
var g_best_grts: std.ArrayList(v16) = undefined;
var mutex: std.Thread.Mutex = undefined;

fn diff(p1: []const i16, p2: []const i16) bool {
    return !std.mem.eql(i16, p1, p2); // maybe there are faster ways
}

pub fn krul(seq: *v16, period: *usize, len: usize, minimum: usize) i16 {
    var curl: i16 = @intCast(minimum - 1);
    var limit = len / minimum;
    var i: usize = 1;
    while (i <= limit) : (i += 1) {
        const p1: []i16 = seq.items[len - i .. len];
        var freq: usize = 2;
        while (true) : (freq += 1) {
            if (len < freq * i) {
                break;
            }
            const p2: []i16 = seq.items[len - freq * i .. len - freq * i + i];
            if (diff(p1, p2)) {
                break;
            }
            if (curl < freq) {
                curl = @intCast(freq);
                limit = len / @as(usize, @intCast(curl + 1));
                period.* = i;
            }
        }
    }
    return curl;
}

fn erase(vec: *v16, x: i16) void {
    var i: usize = 0;
    while (vec.items[i] != x) : (i += 1) {}
    vec.swapRemove(i);
}

pub fn backtracking_step(ctx: *context) !void {
    ctx.p_cand += 1;
    while ((ctx.c_cand * ctx.p_cand) > ctx.seq.items.len) {
        if (ctx.periods.items.len < ctx.depth) {
            break;
        }

        if (ctx.c_cand <= ctx.seq.getLast()) {
            ctx.c_cand += 1;
            ctx.p_cand = 1 + @as(i16, @intCast(ctx.periods.items.len)) / ctx.c_cand;
        } else {
            const k = @as(i16, @intCast(ctx.periods.items.len)) - 1;
            if (!ctx.change_indices.contains(k)) {
                try ctx.change_indices.put(k, undefined);
                ctx.c_cand = ctx.seq.getLast() + 1;
                ctx.p_cand = 1 + k / ctx.c_cand;
            } else {
                ctx.c_cand = ctx.seq.getLast();
                ctx.p_cand = ctx.periods.getLast() + 1;

                var temp: *v16 = ctx.grts_mem.fetchRemove(k).?;
                for (ctx.seq.items[0..ctx.length], 0..) |item, i| {
                    if (item != temp.items[i]) {
                        erase(ctx.seq_map.items[item + ctx.length], @intCast(i));
                        try ctx.seq_map.items[temp.items[i] + ctx.length].append(@intCast(i));
                        ctx.seq.items[i] = temp.items[i];
                    }
                }
                temp.deinit();
            }

            // implementation of std::find
            var i: usize = 0;
            while (ctx.seq_map.items[ctx.seq.getLast() + ctx.length].items[i] != ctx.seq.items.len - 1) : (i += 1) {}
            ctx.seq_map.items[ctx.seq.getLast() + ctx.length].swapRemove(i); // swap?
            _ = ctx.seq.pop();
            _ = ctx.periods.pop();
            if (ctx.change_indices.contains(k + 1)) {
                ctx.change_indices.remove(k + 1);
            }
        }
    }
}

fn real_grtr_len(ctx: *context) usize {
    var i: usize = 0;
    while ((ctx.seq[i] == (-ctx.length + i)) and (i + 1 != ctx.length)) : (i += 1) {}
    return (ctx.length - i);
}

pub fn append(ctx: *context) !void {
    var i = 0;
    while (i < ctx.pairs.items.len) : (i += 2) {
        for (ctx.seq_map.items[ctx.pairs.items[i + 1] + ctx.length]) |x| {
            try ctx.seq_map.items[ctx.pairs.items[i] + ctx.length].append(x);
        }
        ctx.seq_map.items[ctx.pairs.items[i + 1] + ctx.length].deinit(); // or only clear?
    }
    ctx.seq.shrinkRetainingCapacity(ctx.length);
    std.mem.swap(v16, &(ctx.grts_mem.get(@intCast(ctx.periods.items.len)).?), &ctx.seq);
    std.mem.swap(v16, &ctx.seq, &ctx.seq_new);
    try ctx.seq.append(ctx.c_cand);
    try ctx.periods.append(ctx.p_cand);
    var seq_len = ctx.seq.items.len;
    try ctx.seq_map.items[ctx.c_cand + ctx.length].append(@intCast(seq_len - 1));
    var period = 0;
    while (true) {
        const curl = krul(ctx.seq, &period, seq_len, 2);
        if (curl == 1) break;
        try ctx.seq.append(@intCast(curl));
        try ctx.seq_map.items[@intCast(curl + ctx.length)].append(@intCast(seq_len));
        seq_len += 1;
        ctx.periods.append(period);
    }

    const tail = ctx.periods.items.len;
    ctx.c_cand = 2;
    ctx.p_cand = 1 + tail / 2;
    try ctx.change_indices.put(@intCast(tail), undefined);
    // TODO
    const len = real_grtr_len(&ctx);
    if (ctx.best_tails.items[len] < @as(i16, @intCast(tail))) {
        ctx.best_tails.items[len] = tail;
        std.mem.copyForwards(i16, &ctx.best_grts.items[len].items[0], &ctx.seq.items[0..len]);
    }
}

fn test_cands(ctx: *context) bool {
    var l = ctx.seq.items.len;
    var lcp = l - ctx.p_cand;
    const limit = (ctx.c_cand - 1) * ctx.p_cand;
    for (0..limit) |_| {
        l -= 1; lcp -= 1;
        if (ctx.seq.items[l] != ctx.seq.items[lcp] and ) { // TODO
            return false;
        }
    }

    ctx.seq_new.clearAndFree();
    ctx.seq_new = try ctx.seq.clone();

    ctx.pairs.clearRetainingCapacity();
    
}
