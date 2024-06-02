const std = @import("std");

fn intToSomeTypes(a: u32) type {
    if (a < 32) {
        return u64;
    } else if (a % 2 == 0) {
        return i64;
    } else {
        return f64;
    }
}

fn doSomething(comptime a: u32, b: intToSomeTypes(a)) void {
    std.debug.print("{}: {s}\n", .{ b, @typeName(@TypeOf(b)) });
}

pub fn main() void {
    doSomething(10, 123); // Output: 123: u64
    doSomething(68, -456); // Output: -456: i64
    doSomething(69, 78.9); // Output: 7.89e1: f64
}
