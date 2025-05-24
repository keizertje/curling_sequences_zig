const std = @import("std");
const v16 = std.ArrayList(i16);
const Map = std.AutoHashMap;

var outmutex = std.Thread.Mutex{};
const output_writer = std.io.getStdOut().writer();
fn output(comptime pattern: []const u8, args: anytype) !void {
    outmutex.lock();
    defer outmutex.unlock();

    // std.log.debug(pattern, args); // seems not to output anything

    // comment things out based on your needs
    // std.debug.print(pattern, args);
    try output_writer.print(pattern, args);
}

var queue: std.fifo.LinearFifo(v16, .Dynamic) = undefined;
var g_best_tails: std.ArrayList(usize) = undefined;
var g_best_grts: std.ArrayList(v16) = undefined;
var m_queue = std.Thread.Mutex{};
var m_tails = std.Thread.Mutex{};

const context = struct {
    length: usize,
    c_cand: i16,
    p_cand: i16,
    depth: usize,
    seq: v16,
    seq_new: v16,
    periods: v16,
    pairs: v16,
    temp: v16,
    seq_map: std.ArrayList(v16),
    // change_indices: Map(i16, void),
    change_indices: std.DynamicBitSet,
    grts_mem: Map(i16, v16),
    best_tails: std.ArrayList(usize),
    best_grts: std.ArrayList(v16),

    fn init(allocator: std.mem.Allocator) @This() {
        return context{
            .length = 0,
            .c_cand = 0,
            .p_cand = 0,
            .depth = 0,
            .seq = v16.init(allocator),
            .seq_new = v16.init(allocator),
            .periods = v16.init(allocator),
            .pairs = v16.init(allocator),
            .temp = v16.init(allocator),
            .seq_map = std.ArrayList(v16).init(allocator),
            // .change_indices = Map(i16, void).init(allocator),
            .change_indices = std.DynamicBitSet.initEmpty(allocator, 0) catch unreachable,
            .grts_mem = Map(i16, v16).init(allocator),
            .best_tails = std.ArrayList(usize).init(allocator),
            .best_grts = std.ArrayList(v16).init(allocator),
        };
    }
};

var known_tails: [390]usize = undefined;

const diff = @import("benches/diff.zig").diff_best;

pub fn init(len: usize, allocator: std.mem.Allocator) !void {
    g_best_tails = try std.ArrayList(usize).initCapacity(allocator, len + 1);
    g_best_grts = try std.ArrayList(v16).initCapacity(allocator, len + 1);

    queue = std.fifo.LinearFifo(v16, .Dynamic).init(allocator);

    g_best_tails.appendNTimesAssumeCapacity(0, len + 1);
    for (0..len + 1) |_| {
        g_best_grts.appendAssumeCapacity(try v16.initCapacity(allocator, len));
    }

    known_tails[2] = 2;
    known_tails[4] = 4;
    known_tails[6] = 8;
    known_tails[8] = 58;
    known_tails[9] = 59;
    known_tails[10] = 60;
    known_tails[11] = 112;
    known_tails[14] = 118;
    known_tails[19] = 119;
    known_tails[22] = 120;
    known_tails[48] = 131;
    known_tails[68] = 132;
    known_tails[73] = 133;
    known_tails[77] = 173;
    known_tails[85] = 179;
    known_tails[115] = 215;
    known_tails[116] = 228;
    known_tails[118] = 229;
    known_tails[128] = 332;
    known_tails[132] = 340;
    known_tails[133] = 342;
    known_tails[143] = 343;
    known_tails[154] = 356;
    known_tails[176] = 406;
    known_tails[197] = 1668;
    known_tails[199] = 1669;
    known_tails[200] = 1670;
    known_tails[208] = 1708;
    known_tails[217] = 1836;
    known_tails[290] = 3382;
    known_tails[385] = 3557;
}

// fn diff(p1: []const i16, p2: []const i16) bool {
//     return !std.mem.eql(i16, p1, p2); // maybe there are faster ways
// }

// fn diff_fast(p1: []const i16, p2: []const i16, comptime len: usize) bool {
//     const TYPE = @Type(.{ .int = .{
//         .signedness = .unsigned,
//         .bits = len,
//     } });

//     const v1 = std.mem.bytesAsValue(TYPE, p1);
//     const v2 = std.mem.bytesAsValue(TYPE, p2);

//     return v1 != v2;
// }

pub fn krul(seq: []const i16, period: *usize, len: usize, minimum: i16) i16 {
    var curl: i16 = minimum - 1;
    var limit = @divTrunc(len, @as(usize, @intCast(minimum)));
    var i: usize = 1;
    while (i <= limit) : (i += 1) {
        const p1: []const i16 = seq[len - i .. len];
        var freq: usize = 2;
        while (freq * i <= len) : (freq += 1) {
            if (diff(p1, seq[len - freq * i .. len - freq * i + i])) {
                break;
            }
        }
        if (curl < freq - 1) {
            curl = @intCast(freq - 1);
            limit = @divTrunc(len, @as(usize, @intCast(curl + 1)));
            period.* = i;
        }
    }
    return curl;
}

fn erase(vec: *v16, x: i16) void {
    // var i: usize = 0;
    // while (vec.items[i] != x) : (i += 1) {}
    const i = std.mem.indexOfScalar(i16, vec.items, x).?;
    _ = vec.swapRemove(i);
}

fn backtracking_step(ctx: *context) !void {
    ctx.p_cand += 1;
    while ((ctx.c_cand * ctx.p_cand) > ctx.seq.items.len) {
        if (ctx.periods.items.len < ctx.depth) {
            break;
        }

        if (ctx.c_cand <= ctx.seq.getLast()) {
            ctx.c_cand += 1;
            ctx.p_cand = 1 + @divTrunc(@as(i16, @intCast(ctx.periods.items.len)), ctx.c_cand);
        } else {
            const k: i16 = @intCast(ctx.periods.items.len - 1);
            // if (!ctx.change_indices.contains(k)) {
            if (!(ctx.change_indices.capacity() > k and ctx.change_indices.isSet(@intCast(k)))) {
                // try ctx.change_indices.put(k, undefined);
                ctx.change_indices.set(@intCast(k));
                ctx.c_cand = ctx.seq.getLast() + 1;
                ctx.p_cand = 1 + @divTrunc(k, ctx.c_cand);
            } else {
                ctx.c_cand = ctx.seq.getLast();
                ctx.p_cand = ctx.periods.getLast() + 1;

                var temp: v16 = ctx.grts_mem.fetchRemove(k).?.value;
                defer temp.deinit();
                for (ctx.seq.items[0..ctx.length], 0..) |item, i| {
                    if (item != temp.items[i]) {
                        erase(&ctx.seq_map.items[@as(usize, @intCast(item + @as(i16, @intCast(ctx.length))))], @intCast(i));
                        try ctx.seq_map.items[@as(usize, @intCast(temp.items[i] + @as(i16, @intCast(ctx.length))))].append(@intCast(i));
                        ctx.seq.items[i] = temp.items[i];
                    }
                }
            }

            // implementation of std::find
            // var i: usize = 0;
            // while (ctx.seq_map.items[@as(usize, @intCast(ctx.seq.getLast())) + ctx.length].items[i] != ctx.seq.items.len - 1) : (i += 1) {}
            const i = std.mem.indexOfScalar(i16, ctx.seq_map.items[@as(usize, @intCast(ctx.seq.getLast())) + ctx.length].items, @intCast(ctx.seq.items.len - 1)).?;
            _ = ctx.seq_map.items[@as(usize, @intCast(ctx.seq.getLast())) + ctx.length].swapRemove(i);
            _ = ctx.seq.pop();
            _ = ctx.periods.pop();
            // if (ctx.change_indices.contains(k + 1)) {
            if (ctx.change_indices.capacity() > k + 1 and ctx.change_indices.isSet(@intCast(k + 1))) {
                // _ = ctx.change_indices.remove(k + 1);
                ctx.change_indices.unset(@intCast(k + 1));
            }
        }
    }
}

fn real_grtr_len(ctx: *context) usize {
    var i: usize = 0;
    while ((ctx.seq.items[i] == (-@as(i16, @intCast(ctx.length)) + @as(i16, @intCast(i)))) and (i + 1 != ctx.length)) : (i += 1) {}
    return (ctx.length - i);
}

fn append(ctx: *context) !void {
    var i: usize = 0;
    while (i < ctx.pairs.items.len) : (i += 2) {
        for (ctx.seq_map.items[@as(usize, @intCast(ctx.pairs.items[i + 1] + @as(i16, @intCast(ctx.length))))].items) |x| {
            try ctx.seq_map.items[@as(usize, @intCast(ctx.pairs.items[i] + @as(i16, @intCast(ctx.length))))].append(x);
        }
        ctx.seq_map.items[@as(usize, @intCast(ctx.pairs.items[i + 1] + @as(i16, @intCast(ctx.length))))].clearRetainingCapacity();
    }
    ctx.seq.shrinkRetainingCapacity(ctx.length);
    if (ctx.grts_mem.contains(@intCast(ctx.periods.items.len))) {
        std.mem.swap(v16, ctx.grts_mem.getPtr(@intCast(ctx.periods.items.len)).?, &ctx.seq);
    } else {
        try ctx.grts_mem.put(@intCast(ctx.periods.items.len), try ctx.seq.clone());
    }
    std.mem.swap(v16, &ctx.seq, &ctx.seq_new);
    try ctx.seq.append(ctx.c_cand);
    try ctx.periods.append(ctx.p_cand);
    var seq_len = ctx.seq.items.len;
    try ctx.seq_map.items[@as(usize, @intCast(ctx.c_cand)) + ctx.length].append(@intCast(seq_len - 1));
    var period: usize = 0;
    while (true) {
        const curl = krul(ctx.seq.items, &period, seq_len, 2);
        if (curl == 1) break;
        try ctx.seq.append(curl);
        try ctx.seq_map.items[@as(usize, @intCast(curl)) + ctx.length].append(@intCast(seq_len));
        seq_len += 1;
        try ctx.periods.append(@intCast(period));
    }

    const tail = ctx.periods.items.len;
    ctx.c_cand = 2;
    ctx.p_cand = 1 + @divTrunc(@as(i16, @intCast(tail)), 2);
    // try ctx.change_indices.put(@intCast(tail), undefined);
    try ctx.change_indices.resize(tail + 1, false);
    ctx.change_indices.set(tail);
    const len = real_grtr_len(ctx);
    if (ctx.best_tails.items[len] < tail) {
        ctx.best_tails.items[len] = tail;
        std.mem.copyForwards(i16, ctx.best_grts.items[len].items[0..len], ctx.seq.items[ctx.length - len .. ctx.length]); // TODO?
    }
}

fn test_cands(ctx: *context) !bool {
    var l = ctx.seq.items.len - 1;
    var lcp: usize = l - @as(usize, @intCast(ctx.p_cand));
    const limit: usize = @intCast((ctx.c_cand - 1) * ctx.p_cand);
    for (0..limit) |_| {
        if (ctx.seq.items[l] != ctx.seq.items[lcp] and (ctx.seq.items[l] | ctx.seq.items[lcp]) > 0) {
            return false;
        }
        if (lcp > 0) { // last iteration, lcp can't be negative, there may be a faster way
            l -= 1;
            lcp -= 1;
        } else if (lcp == 0) {
            break;
        }
    }

    ctx.seq_new.clearRetainingCapacity();
    try ctx.seq_new.ensureTotalCapacity(ctx.seq.items.len);
    ctx.seq_new.appendSliceAssumeCapacity(ctx.seq.items);

    ctx.pairs.clearRetainingCapacity();
    try ctx.pairs.ensureTotalCapacity(2 * limit);

    var pairs_len: usize = 0;
    l = ctx.seq.items.len - 1; // reset l and lcp
    lcp = l - @as(usize, @intCast(ctx.p_cand));
    for (0..limit) |_| {
        var a = ctx.seq_new.items[l];
        var b = ctx.seq_new.items[lcp];
        if (a != b) {
            if ((a | b) > 0)
                return false;

            if (a > b)
                std.mem.swap(i16, &a, &b);

            try ctx.pairs.append(b);
            try ctx.pairs.append(a);
            pairs_len += 2;

            const p_begin: usize = 0;
            const p_end: usize = pairs_len;

            ctx.temp.clearRetainingCapacity();
            try ctx.temp.append(a);
            var temp_len: usize = 1;
            var i: usize = 0;
            while (i < temp_len) : (i += 1) {
                const tmp = ctx.temp.items[i];
                var pi: usize = p_begin;
                while (pi < p_end) : (pi += 2) {
                    if (ctx.pairs.items[pi] == tmp) { // *(pi++) in c++ equals ctx.pairs.items[pi] in zig followed by pi+=1
                        try ctx.temp.append(ctx.pairs.items[pi + 1]); // (that pi+=1 is absorbed into the increment statement (pi+=2 instead of pi+=1))
                        temp_len += 1;
                    }
                }
            }
            for (ctx.temp.items) |x| {
                for (ctx.seq_map.items[@intCast(x + @as(i16, @intCast(ctx.length)))].items) |ind| {
                    ctx.seq_new.items[@intCast(ind)] = b;
                }
            }
        }
        if (lcp > 0) {
            l -= 1;
            lcp -= 1;
        } else if (lcp == 0) {
            break;
        }
    }
    return true;
}

fn test_seq_new(ctx: *context) !bool {
    const l = ctx.seq_new.items.len;
    var period: usize = 0;
    var i: usize = 0;
    while (i < l - ctx.length) : (i += 1) {
        const curl = krul(ctx.seq_new.items, &period, ctx.length + i, ctx.seq_new.items[ctx.length + i]);

        // if (!ctx.change_indices.contains(@intCast(i))) {
        if (!(ctx.change_indices.capacity() > i and ctx.change_indices.isSet(i))) {
            if (curl != ctx.seq_new.items[ctx.length + i]) {
                return false;
            }
        } else {
            if (curl != ctx.seq_new.items[ctx.length + i] or period != ctx.periods.items[i]) {
                return false;
            }
        }
    }
    const curl = krul(ctx.seq_new.items, &period, l, ctx.c_cand);
    return (curl == ctx.c_cand and period == ctx.p_cand);
}

pub fn backtracking(ctx: *context) !void {
    if (try test_cands(ctx) and try test_seq_new(ctx)) {
        try append(ctx);
    } else {
        try backtracking_step(ctx);
    }
}

pub fn worker(thread_number: usize, len: usize, allocator: std.mem.Allocator) !void {
    const t1 = std.time.milliTimestamp();
    try output("[{}] Thread {} started!\n", .{ t1, thread_number });

    var ctx = context.init(allocator);
    ctx.length = len;
    try ctx.seq.appendNTimes(0, len);
    try ctx.best_tails.appendNTimes(0, len + 1);
    try ctx.best_grts.ensureTotalCapacity(len + 1);
    for (0..len + 1) |i| {
        try ctx.best_grts.append(v16.init(allocator));
        try ctx.best_grts.items[i].appendNTimes(0, len);
    }
    try ctx.seq_map.ensureTotalCapacity(2 * len + 2);
    for (0..2 * len + 2) |_| {
        try ctx.seq_map.append(try v16.initCapacity(allocator, 10));
    }

    var cmb: v16 = undefined;
    while (true) {
        {
            m_queue.lock();
            defer m_queue.unlock();

            if (queue.readableLength() == 0)
                continue;

            cmb = queue.readItem().?;
            if (cmb.items[0] == 0) {
                try queue.unget(&[_]v16{cmb});
                break;
            }
        }

        ctx.depth = @intCast(cmb.items[0]);

        try ctx.seq.resize(ctx.length);
        for (0..ctx.length) |i| {
            ctx.seq.items[i] = -@as(i16, @intCast(ctx.length)) + @as(i16, @intCast(i));
        }

        for (0..ctx.seq_map.items.len) |i| {
            ctx.seq_map.items[i].clearRetainingCapacity();
        }

        for (0..ctx.length) |j| {
            try ctx.seq_map.items[j].append(@intCast(j));
        }

        ctx.periods.clearRetainingCapacity();
        // ctx.change_indices.clearRetainingCapacity();
        ctx.change_indices.unmanaged.unsetAll(); // ???

        for (1..ctx.depth + 1) |i| {
            ctx.c_cand = cmb.items[i * 2 - 1];
            ctx.p_cand = cmb.items[i * 2];

            var period: usize = 0;
            const curl = krul(ctx.seq.items, &period, ctx.length + i - 1, ctx.c_cand);
            if (curl < ctx.c_cand) {
                // try ctx.change_indices.put(@intCast(i - 1), undefined);
                if (ctx.change_indices.capacity() < i) {
                    try ctx.change_indices.resize(i, false);
                }
                ctx.change_indices.set(i - 1);
            }
            if (i == ctx.depth) {
                break;
            }

            _ = try test_cands(&ctx) and try test_seq_new(&ctx);
            var j: usize = 0;
            while (j < ctx.pairs.items.len) : (j += 2) {
                for (ctx.seq_map.items[@as(usize, @intCast(ctx.pairs.items[j + 1] + @as(i16, @intCast(ctx.length))))].items) |x| {
                    try ctx.seq_map.items[@as(usize, @intCast(ctx.pairs.items[j] + @as(i16, @intCast(ctx.length))))].append(x);
                }
                ctx.seq_map.items[@as(usize, @intCast(ctx.pairs.items[j + 1] + @as(i16, @intCast(ctx.length))))].clearRetainingCapacity();
            }
            std.mem.swap(v16, &ctx.seq, &ctx.seq_new);
            try ctx.seq.append(ctx.c_cand);
            try ctx.periods.append(ctx.p_cand);
            try ctx.seq_map.items[@as(usize, @intCast(ctx.c_cand)) + ctx.length].append(@intCast(ctx.length + 1));
        }

        try backtracking(&ctx);
        while (ctx.periods.items.len >= ctx.depth) {
            try backtracking(&ctx);
        }
    }

    {
        m_tails.lock();
        defer m_tails.unlock();

        for (0..ctx.length + 1) |i| {
            if (ctx.best_tails.items[i] > g_best_tails.items[i]) {
                g_best_tails.items[i] = ctx.best_tails.items[i];
                g_best_grts.items[i].clearRetainingCapacity();
                g_best_grts.items[i] = try ctx.best_grts.items[i].clone();
            }
        }
    }

    const t2 = std.time.milliTimestamp();
    try output("[{}] Thread {} finished, duration: {} ms\n", .{ t2, thread_number, t2 - t1 });
}

pub fn generate_combinations(len: usize, max_depth: usize, allocator: std.mem.Allocator) !void {
    var ctx = context.init(allocator);
    ctx.length = len;
    try ctx.seq.appendNTimes(0, len);
    try ctx.seq_map.ensureTotalCapacity(2 * len + 2);
    for (0..2 * len + 2) |_| {
        try ctx.seq_map.append(try v16.initCapacity(allocator, 10));
    }
    try ctx.best_tails.appendNTimes(0, len + 1);
    try ctx.best_grts.ensureTotalCapacity(len + 1);
    for (0..len + 1) |i| {
        try ctx.best_grts.append(try v16.initCapacity(allocator, len));
        try ctx.best_grts.items[i].appendNTimes(0, len);
    }

    var depth = max_depth;
    var cmb = try v16.initCapacity(allocator, 1 + 2 * max_depth);
    try cmb.appendNTimes(0, 1 + 2 * max_depth);
    cmb.items[0] = @as(i16, @intCast(max_depth));
    for (1..max_depth + 1) |i| {
        cmb.items[2 * i - 1] = 2;
        cmb.items[2 * i] = 1;
    }

    while (cmb.items[1] <= ctx.length) {
        while (queue.readableLength() < ctx.length * ctx.length and cmb.items[1] <= ctx.length) {
            ctx.depth = depth;
            try ctx.seq.resize(ctx.length);
            for (0..ctx.length) |i| {
                ctx.seq.items[i] = -@as(i16, @intCast(ctx.length)) + @as(i16, @intCast(i));
            }
            for (0..ctx.seq_map.items.len) |i| {
                ctx.seq_map.items[i].clearRetainingCapacity();
            }
            for (0..ctx.length) |j| {
                try ctx.seq_map.items[j].append(@as(i16, @intCast(j)));
            }
            ctx.periods.clearRetainingCapacity();
            // ctx.change_indices.clearRetainingCapacity();
            ctx.change_indices.unmanaged.unsetAll(); // ???

            var invalid: bool = false;
            for (1..ctx.depth) |i| {
                ctx.c_cand = cmb.items[2 * i - 1];
                ctx.p_cand = cmb.items[2 * i];
                if (try test_cands(&ctx) and try test_seq_new(&ctx)) {
                    var j: usize = 0;
                    while (j < ctx.pairs.items.len) : (j += 2) {
                        for (ctx.seq_map.items[@as(usize, @intCast(ctx.pairs.items[j + 1] + @as(i16, @intCast(ctx.length))))].items) |x| {
                            try ctx.seq_map.items[@as(usize, @intCast(ctx.pairs.items[j] + @as(i16, @intCast(ctx.length))))].append(x);
                        }
                        ctx.seq_map.items[@as(usize, @intCast(ctx.pairs.items[j + 1] + @as(i16, @intCast(ctx.length))))].clearRetainingCapacity();
                    }
                    std.mem.swap(v16, &ctx.seq, &ctx.seq_new);
                    try ctx.seq.append(ctx.c_cand);
                    try ctx.periods.append(ctx.p_cand);
                    try ctx.seq_map.items[@as(usize, @intCast(ctx.c_cand + @as(i16, @intCast(ctx.length))))].append(@as(i16, @intCast(ctx.length + 1)));
                    // try ctx.change_indices.put(@as(i16, @intCast(i - 1)), undefined);
                    if (ctx.change_indices.capacity() < i) {
                        try ctx.change_indices.resize(i, false);
                    }
                    ctx.change_indices.set(i - 1);
                } else {
                    invalid = true;
                    break;
                }
            }

            ctx.c_cand = cmb.items[ctx.depth * 2 - 1];
            ctx.p_cand = cmb.items[ctx.depth * 2];
            if (!invalid and try test_cands(&ctx) and try test_seq_new(&ctx)) {
                cmb.items[0] = @as(i16, @intCast(depth));
                {
                    m_queue.lock();
                    defer m_queue.unlock();

                    try queue.writeItem(try cmb.clone());
                }
            }

            cmb.items[depth * 2] += 1;
            var recalc: bool = false;
            while (cmb.items[depth * 2 - 1] * cmb.items[depth * 2] >= ctx.length + depth) {
                cmb.items[depth * 2] = 1;
                cmb.items[depth * 2 - 1] += 1;
                recalc = true;
                if (depth > 1 and (cmb.items[depth * 2 - 1]) > (cmb.items[depth * 2 - 3] + 1)) {
                    cmb.items[depth * 2 - 1] = 2;
                    depth -= 1;
                    cmb.items[depth * 2] += 1;
                } else if (depth == 1) {
                    break;
                }
            }

            if (recalc) {
                var sum: i16 = cmb.items[1] * cmb.items[1] * cmb.items[2];
                depth = 1;
                while (depth < max_depth) : (depth += 1) {
                    if (sum > max_depth * max_depth) {
                        break;
                    }
                    sum += @as(i16, @intCast(depth)) * cmb.items[depth * 2 + 1] * cmb.items[depth * 2 + 2];
                }
                if (depth == 1 and sum <= ctx.length) {
                    depth = 2;
                }
            }
        }

        std.time.sleep(5 * std.time.ns_per_ms); // docu says: "Spurious wakeups are possible and no precision of timing is guaranteed.", so watch out!
    }

    cmb.items[0] = 0;
    {
        m_queue.lock();
        defer m_queue.unlock();

        try queue.writeItem(try cmb.clone());
    }

    try output("[{}] Finished generating combinations\n", .{std.time.milliTimestamp()});
}

pub fn log_results(max_dephts: usize) !void {
    try output("[{}] Logging results:\n", .{std.time.milliTimestamp()});

    var record: usize = 0;
    for (0..g_best_tails.items.len) |i| {
        if (g_best_tails.items[i] > record) {
            record = g_best_tails.items[i];
            if (i <= max_dephts) {
                continue;
            }
            if (i > known_tails.len) {
                try output("NEW: ", .{});
            }
            if (known_tails[i] != record) {
                try output("!!!: ", .{});
            } else {
                try output("OLD: ", .{});
            }
            try output("{}: {}, {any}\n", .{ i, record, g_best_grts.items[i].items[0..i] });
        }
    }
}

inline fn largest_power(n: usize) usize {
    var n_copy = n;
    var power: usize = 0;
    while (n_copy != 0) {
        n_copy >>= 1;
        power += 1;
    }
    return power;
}

fn noerror_generate_cmbs(len: usize, max_depth: usize, allocator: std.mem.Allocator, thread_number: usize) void {
    generate_combinations(len, max_depth, allocator) catch |e| std.debug.panic("error: {any}\n", .{e});
    worker(thread_number, len, allocator) catch |e| std.debug.panic("error: {any}\n", .{e});
}

fn noerror_worker(thread_number: usize, len: usize, allocator: std.mem.Allocator) void {
    worker(thread_number, len, allocator) catch |e| std.debug.panic("error: {any}\n", .{e});
}

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    var args = try std.process.argsWithAllocator(allocator);
    _ = args.next();

    const length = try std.fmt.parseInt(usize, args.next().?, 0);
    var thread_count = try std.fmt.parseInt(usize, args.next().?, 0);
    const max_depth: usize = largest_power(length);

    if (thread_count == 0) {
        thread_count = try std.Thread.getCpuCount();
    }

    try output("[{}] Started. Length: {}, maximum depth: {}, thread count: {}\n", .{ std.time.milliTimestamp(), length, max_depth, thread_count });

    try init(length, allocator);

    var wait_group: std.Thread.WaitGroup = undefined;
    wait_group.reset();

    var pool: std.Thread.Pool = undefined;
    try pool.init(.{ .allocator = allocator });
    defer pool.deinit();

    pool.spawnWg(&wait_group, noerror_generate_cmbs, .{ length, max_depth, allocator, 0 });
    for (1..thread_count) |i| {
        pool.spawnWg(&wait_group, noerror_worker, .{ i, length, allocator });
    }

    wait_group.wait();

    try output("{}\n", .{queue.readableLength()});

    try log_results(0);
}
