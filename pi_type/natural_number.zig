const std = @import("std");

pub const NaturalNumberNodeType = enum {
    zero,
    succ,
};

pub const NaturalNumberZero = struct {};

pub const NaturalNumber = union(NaturalNumberNodeType) {
    zero: NaturalNumberZero,
    succ: *const NaturalNumber,
};

const zero: *const NaturalNumber = &NaturalNumber{.zero = NaturalNumberZero{}};
const one: *const NaturalNumber = &NaturalNumber{.succ = zero};
const two: *const NaturalNumber = &NaturalNumber{.succ = one};
const three: *const NaturalNumber = &NaturalNumber{.succ = two};
const four: *const NaturalNumber = &NaturalNumber{.succ = three};
const five: *const NaturalNumber = &NaturalNumber{.succ = four};
const five_value = smallNaturalNumberToU32(five);

pub fn smallNaturalNumberToU32(comptime a: *const NaturalNumber) u32 {
    var a1 = a;
    var ans: u32 = 0;
    while (true) {
        switch (a1.*) {
            .zero => return ans,
            .succ => |b1| {
                ans += 1;
                a1 = b1;
            },
        }
    }
}

test "some constants" {
    try std.testing.expectEqual(0, smallNaturalNumberToU32(zero));
    try std.testing.expectEqual(1, smallNaturalNumberToU32(one));
    try std.testing.expectEqual(2, smallNaturalNumberToU32(two));
    try std.testing.expectEqual(3, smallNaturalNumberToU32(three));
    try std.testing.expectEqual(4, smallNaturalNumberToU32(four));
    try std.testing.expectEqual(5, smallNaturalNumberToU32(five));
    try std.testing.expectEqual(5, five_value);
}

// For some testing. Cannot make this function a proposition because a proof must be able
// to look into the internal definition of a real "equal" definition.
fn equal(comptime a: *const NaturalNumber, comptime b: *const NaturalNumber) bool {
    return switch (a.*) {
        .zero => @as(NaturalNumberNodeType, b.*) == .zero,
        .succ => |a1| switch (b.*) {
            .zero => false,
            .succ => |b1| equal(a1, b1),
        },
    };
}

test "equal" {
    try std.testing.expect(equal(zero, zero));
    try std.testing.expect(!equal(zero, one));
    try std.testing.expect(!equal(one, zero));
    try std.testing.expect(equal(one, one));
    try std.testing.expect(equal(five, five));
    try std.testing.expect(!equal(five, one));
    try std.testing.expect(!equal(one, five));
}

pub fn plus(comptime a: *const NaturalNumber, comptime b: *const NaturalNumber) *const NaturalNumber {
    return switch (b.*) {
        .zero => a,
        .succ => |b1| &NaturalNumber{.succ = plus(a, b1)},
    };
}

test "small plus" {
    try std.testing.expect(equal(three, plus(one, two)));
    try std.testing.expect(equal(three, plus(two, one)));
    try std.testing.expect(equal(three, plus(zero, three)));
    try std.testing.expect(equal(three, plus(three, zero)));
}
