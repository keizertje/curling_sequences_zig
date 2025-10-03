const std = @import("std");
const builtin = @import("builtin");

const left = switch (builtin.target.cpu.arch.endian()) {
    .little => true,
    .big => false,
};

pub fn diff_exp2(p1: []const i16, p2: []const i16) bool {
    const p1_many: [*]const i16 = @ptrCast(p1.ptr);
    const p2_many: [*]const i16 = @ptrCast(p2.ptr);

    switch (p1.len) {
        1...4 => {
            var v1 = std.mem.bytesToValue(u48, p1_many[0..4]);
            var v2 = std.mem.bytesToValue(u48, p2_many[0..4]);

            if (left) {
                v1 <<= 4 - @as(u6, @intCast(p1.len));
                v2 <<= 4 - @as(u6, @intCast(p1.len));
            } else {
                v1 >>= 4 - @as(u6, @intCast(p1.len));
                v2 >>= 4 - @as(u6, @intCast(p1.len));
            }

            return v1 != v2;
        },
        5...8 => {
            var v1 = std.mem.bytesToValue(u96, p1_many[0..8]);
            var v2 = std.mem.bytesToValue(u96, p2_many[0..8]);

            if (left) {
                v1 <<= 8 - @as(u7, @intCast(p1.len));
                v2 <<= 8 - @as(u7, @intCast(p1.len));
            } else {
                v1 >>= 8 - @as(u7, @intCast(p1.len));
                v2 >>= 8 - @as(u7, @intCast(p1.len));
            }

            return v1 != v2;
        },
        9...12 => {
            var v1 = std.mem.bytesToValue(u144, p1_many[0..12]);
            var v2 = std.mem.bytesToValue(u144, p2_many[0..12]);

            if (left) {
                v1 <<= 12 - @as(u8, @intCast(p1.len));
                v2 <<= 12 - @as(u8, @intCast(p1.len));
            } else {
                v1 >>= 12 - @as(u8, @intCast(p1.len));
                v2 >>= 12 - @as(u8, @intCast(p1.len));
            }

            return v1 != v2;
        },
        13...16 => {
            var v1 = std.mem.bytesToValue(u192, p1_many[0..16]);
            var v2 = std.mem.bytesToValue(u192, p2_many[0..16]);

            if (left) {
                v1 <<= 16 - @as(u9, @intCast(p1.len));
                v2 <<= 16 - @as(u9, @intCast(p1.len));
            } else {
                v1 >>= 16 - @as(u9, @intCast(p1.len));
                v2 >>= 16 - @as(u9, @intCast(p1.len));
            }

            return v1 != v2;
        },
        17...20 => {
            var v1 = std.mem.bytesToValue(u240, p1_many[0..20]);
            var v2 = std.mem.bytesToValue(u240, p2_many[0..20]);

            if (left) {
                v1 <<= 20 - @as(u10, @intCast(p1.len));
                v2 <<= 20 - @as(u10, @intCast(p1.len));
            } else {
                v1 >>= 20 - @as(u10, @intCast(p1.len));
                v2 >>= 20 - @as(u10, @intCast(p1.len));
            }

            return v1 != v2;
        },
        21...24 => {
            var v1 = std.mem.bytesToValue(u288, p1_many[0..24]);
            var v2 = std.mem.bytesToValue(u288, p2_many[0..24]);

            if (left) {
                v1 <<= 24 - @as(u11, @intCast(p1.len));
                v2 <<= 24 - @as(u11, @intCast(p1.len));
            } else {
                v1 >>= 24 - @as(u11, @intCast(p1.len));
                v2 >>= 24 - @as(u11, @intCast(p1.len));
            }

            return v1 != v2;
        },
        25...28 => {
            var v1 = std.mem.bytesToValue(u336, p1_many[0..28]);
            var v2 = std.mem.bytesToValue(u336, p2_many[0..28]);

            if (left) {
                v1 <<= 28 - @as(u12, @intCast(p1.len));
                v2 <<= 28 - @as(u12, @intCast(p1.len));
            } else {
                v1 >>= 28 - @as(u12, @intCast(p1.len));
                v2 >>= 28 - @as(u12, @intCast(p1.len));
            }

            return v1 != v2;
        },
        29...32 => {
            var v1 = std.mem.bytesToValue(u384, p1_many[0..32]);
            var v2 = std.mem.bytesToValue(u384, p2_many[0..32]);

            if (left) {
                v1 <<= 32 - @as(u13, @intCast(p1.len));
                v2 <<= 32 - @as(u13, @intCast(p1.len));
            } else {
                v1 >>= 32 - @as(u13, @intCast(p1.len));
                v2 >>= 32 - @as(u13, @intCast(p1.len));
            }

            return v1 != v2;
        },
        33...36 => {
            var v1 = std.mem.bytesToValue(u432, p1_many[0..36]);
            var v2 = std.mem.bytesToValue(u432, p2_many[0..36]);

            if (left) {
                v1 <<= 36 - @as(u14, @intCast(p1.len));
                v2 <<= 36 - @as(u14, @intCast(p1.len));
            } else {
                v1 >>= 36 - @as(u14, @intCast(p1.len));
                v2 >>= 36 - @as(u14, @intCast(p1.len));
            }

            return v1 != v2;
        },
        37...40 => {
            var v1 = std.mem.bytesToValue(u480, p1_many[0..40]);
            var v2 = std.mem.bytesToValue(u480, p2_many[0..40]);

            if (left) {
                v1 <<= 40 - @as(u15, @intCast(p1.len));
                v2 <<= 40 - @as(u15, @intCast(p1.len));
            } else {
                v1 >>= 40 - @as(u15, @intCast(p1.len));
                v2 >>= 40 - @as(u15, @intCast(p1.len));
            }

            return v1 != v2;
        },
        else => return !std.mem.eql(i16, p1, p2),
    }
}

pub fn diff_exp4(p1: []const i16, p2: []const i16) bool {
    const p1_many: [*]const i16 = @ptrCast(p1.ptr);
    const p2_many: [*]const i16 = @ptrCast(p2.ptr);

    switch (p1.len) {
        0...4 => {
            var v1 = std.mem.bytesToValue(u48, p1_many[0..4]);
            var v2 = std.mem.bytesToValue(u48, p2_many[0..4]);

            if (left) {
                v1 <<= 4 - @as(u6, @intCast(p1.len));
                v2 <<= 4 - @as(u6, @intCast(p1.len));
            } else {
                v1 >>= 4 - @as(u6, @intCast(p1.len));
                v2 >>= 4 - @as(u6, @intCast(p1.len));
            }

            return v1 != v2;
        },
        5...16 => {
            var v1 = std.mem.bytesToValue(u192, p1_many[0..16]);
            var v2 = std.mem.bytesToValue(u192, p2_many[0..16]);

            if (left) {
                v1 <<= 16 - @as(u8, @intCast(p1.len));
                v2 <<= 16 - @as(u8, @intCast(p1.len));
            } else {
                v1 >>= 16 - @as(u8, @intCast(p1.len));
                v2 >>= 16 - @as(u8, @intCast(p1.len));
            }

            return v1 != v2;
        },
        17...64 => {
            var v1 = std.mem.bytesToValue(u768, p1_many[0..64]);
            var v2 = std.mem.bytesToValue(u768, p2_many[0..64]);

            if (left) {
                v1 <<= 64 - @as(u10, @intCast(p1.len));
                v2 <<= 64 - @as(u10, @intCast(p1.len));
            } else {
                v1 >>= 64 - @as(u10, @intCast(p1.len));
                v2 >>= 64 - @as(u10, @intCast(p1.len));
            }

            return v1 != v2;
        },
        65...128 => {
            var v1 = std.mem.bytesToValue(u1536, p1_many[0..128]);
            var v2 = std.mem.bytesToValue(u1536, p2_many[0..128]);

            if (left) {
                v1 <<= 128 - @as(u11, @intCast(p1.len));
                v2 <<= 128 - @as(u11, @intCast(p1.len));
            } else {
                v1 >>= 128 - @as(u11, @intCast(p1.len));
                v2 >>= 128 - @as(u11, @intCast(p1.len));
            }

            return v1 != v2;
        },
        129...256 => {
            var v1 = std.mem.bytesToValue(u3072, p1_many[0..256]);
            var v2 = std.mem.bytesToValue(u3072, p2_many[0..256]);

            if (left) {
                v1 <<= 256 - @as(u12, @intCast(p1.len));
                v2 <<= 256 - @as(u12, @intCast(p1.len));
            } else {
                v1 >>= 256 - @as(u12, @intCast(p1.len));
                v2 >>= 256 - @as(u12, @intCast(p1.len));
            }

            return v1 != v2;
        },
        257...512 => {
            var v1 = std.mem.bytesToValue(u6144, p1_many[0..512]);
            var v2 = std.mem.bytesToValue(u6144, p2_many[0..512]);

            if (left) {
                v1 <<= 512 - @as(u13, @intCast(p1.len));
                v2 <<= 512 - @as(u13, @intCast(p1.len));
            } else {
                v1 >>= 512 - @as(u13, @intCast(p1.len));
                v2 >>= 512 - @as(u13, @intCast(p1.len));
            }

            return v1 != v2;
        },
        513...1024 => {
            var v1 = std.mem.bytesToValue(u12288, p1_many[0..1024]);
            var v2 = std.mem.bytesToValue(u12288, p2_many[0..1024]);

            if (left) {
                v1 <<= 1024 - @as(u14, @intCast(p1.len));
                v2 <<= 1024 - @as(u14, @intCast(p1.len));
            } else {
                v1 >>= 1024 - @as(u14, @intCast(p1.len));
                v2 >>= 1024 - @as(u14, @intCast(p1.len));
            }

            return v1 != v2;
        },
        else => return !std.mem.eql(i16, p1, p2),
    }
}
