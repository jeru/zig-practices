# A slightly more involving problem
[SWERC 2023](https://swerc.eu/2023/results/) Problem A: Card game.

Sorting a poker with 5 suites on hand with minimum amount of operations, each operation is removing one card and reinserting it back.
Order requirements:
* Each suite's card must be toghether and ordered by number.
* The fifth suite must be at last; the other four suites' order doesn't matter.
* Number can be as big as 100K, so must have a very fast algorithm.

## Solution overview

If we have only one allowd suite order, then the problem becomes:
 given an array, find the minimum amount of operations to sort that array.
When there are multiple possible orders, can try all of them and pick the minimum among them.
And there are only `4! = 24` possible suite orders.

To find the minimum amount of operations to sort one array, it is basically finding the largest increasing
(non-continuous) sub-sequence; all the remaining elements outside this sub-sequence should be operated.

So it boils down to an algorithm with complexity `24 * T`, where `T` is the time complexity of finding the largest increasing sub-sequence.
`T = O(N log N)` sounds acceptable.

## Largest increasing sub-sequence
One dynamic-programming method is to scan through the array from left to right, and maintain a data structure to support querying:
length of the largest increasing sub-sequence so far with ending value at most `x`.
Then the code looks roughly like:

```zig
    var my_ds = ...;
    var answer: usize = 0;
    for (my_array) |x| {
      const answer_for_x = my_ds.query(x - 1) + 1;
      answer = @max(answer, answer_for_x);
      my_ds.insert(x, answer_for_x);
    }
```

This data structure can be a [range tree](https://en.wikipedia.org/wiki/Range_tree) (though in the competition programming context, probably called [segment tree](https://www.geeksforgeeks.org/segment-tree-data-structure/), not to be confused with another [segument tree](https://en.wikipedia.org/wiki/Segment_tree) that actually indexes segments/intervals).

But to keep oneself as lazy as possible, using a balanced search tree provided by a language's standard library is also possible and actually preferred, with the following observation:
* If `my_array[i] <= my_array[j]` but the computed answer for `my_array[i]` is larger than the answer for `my_array[j]`, then `my_array[j]` has no value for the future computation (the new `x` can always pick `my_array[i]` as the previous element in the sub-sequence and get better results).

Therefore, by removing all the no-value items from the tree, the remaining `(my_array[i], answer_for_my_array[i])` candidate list, when ordered by the first element, has increasing second element.
So just store them in an ordered map keyed by the first element and valued by the second element, `my_ds.query(x - 1)` just becomes returning the value of the last entry in the ordered map whose key is at most `x - 1`.

### Zig's balanced search tree
[Treap](https://ziglang.org/documentation/0.11.0/std/#A;std:Treap) is implemented.
But there's no good way to traverse around a node.
It means the std library if Zig (as of 0.11) is not very comprehensive.
A brief chat with a maintainer reveals that the current goal is still trying to prioritize the code that are needed by the compiler itself or other std libraries.

So, need to [increment the data structure a little](https://github.com/ziglang/zig/pull/20002).
(It feels quite priviliged to modify a language's standard library :-P).

## Language-specific experiences

Playing around with the language. Not necessarily relevant to the problem above anymore.

### Inferred type of `switch`

Eg., `E39` means suite E number 39.
```zig
const Card = struct {
    suite: u8,
    num: u32,

    pub fn init(str: []u8) !Card {
        if (str.len == 0) return InvalidCardError.Empty;
        const suite: u8 = switch (str[0]) {
            'S' => 0,
            'W' => 1,
            'E' => 2,
            'R' => 3,
            'C' => 4,
            else => return InvalidCardError.UnknownSuite,
        };
        const num = try std.fmt.parseInt(u32, str[1..], 10);
        return .{.suite = suite, .num = num};
    }
};
```

Note that if the type of `const suite` is omitted, i.e., `const suite = switch ...`, there'll be a compilation error
```
swerc2023_a.zig:25:23: error: value with comptime-only type 'comptime_int' depends on runtime control flow
        const suite = switch (str[0]) {
                      ^~~~~~
swerc2023_a.zig:25:34: note: runtime control flow here
        const suite = switch (str[0]) {
```
So there seems to be a type inferring system over the switch-clause' values.
Since all the values here are compile-time ints, it infers suite so as well.
Then `str[0]` being non-compile time caused a problem.

To verify this hypothesis, try the following instead:
```zig
        const suite = switch (str[0]) {  // No explicit type for `suite`.
            'S' => @as(u8, 0),
            'W' => 1,
            ...
        };
```

And.... It compiles!

Now try something more sophisticated with another program:
```zig
const std = @import("std");

pub fn main() void {
    const a = switch (@as(u8, 0)) {
      0 => @as(u8, 0),
      1 => @as(u16, 1),
      else => @as(u1, 0),
    };
    std.debug.print("{s}\n", .{@typeName(@TypeOf(a))});
}
```

Compiling and running shows: `u8`... Okay, switch:
```zig
    const a = switch (@as(u8, 0)) {
      0 => @as(u16, 0),
      1 => @as(u8, 1),
      else => @as(u1, 0),
    };
```

And it shows `u16`. So the type inferring is just based on the first branch?
What about this:
```zig
    const a = switch (@as(u8, 0)) {
      else => @as(u1, 0),
      0 => @as(u16, 0),
      1 => @as(u8, 1),
    };
```

Still output `u16`. So `else` doesn't count?

What about this:
```zig
    const a = switch (@as(u8, 0)) {
      else => @as(u1, 0),
      1 => @as(u8, 1),
      0 => @as(u16, 0),
    };
```

Still output `u16`.

So the hypothesis is not correct here... Since the switch is a compile-type constant, it unfolds before getting the type?
To verify:
```zig
    const a = switch (@as(u8, 1)) {
      else => @as(u1, 0),
      1 => @as(u8, 1),
      0 => @as(u16, 0),
    };
```

And now it is `u8`.
So compile-time unfold first, then evaluate the type. Real Duck typing!

What if the switch param is run-time only?

```zig
    var condition: u8 = 0;
    condition += 1;
    const a = switch (condition) {
      else => @as(u1, 0),
      1 => @as(u8, 1),
      0 => @as(u16, 0),
    };
    std.debug.print("{s}\n", .{@typeName(@TypeOf(a))});
```

Now it is `u16`.

And switch the order?
```zig
    const a = switch (condition) {
      else => @as(u1, 0),
      0 => @as(u8, 1),
      1 => @as(u16, 0),
    };
```
Still `u16`. Now it is the "biggest" type?

What about mixed but probably incomptible types?
```zig
    const a = switch (condition) {
      else => @as(u1, 0),
      0 => @as(u64, 1),
      1 => @as(f32, 0),
    };
```

Now `f32`. So floats are "more general" than ints.
And really incompatible?
```zig
    const a = switch (condition) {
      else => @as(u1, 0),
      0 => @as(u64, 1),
      1 => false,
    };
```
Now has an error `error: incompatible types: 'u64' and 'bool'`.

In summary:
* Compile-time `switch`: evaluate as is and derive the type later.
* Run-time `switch`: pick the "biggest" type. 

### Compile-time complex computation
For this problem, it is absolutely UNNECESSARY to compute the permutations at compile time.
But just for fun learning the language, do it at compile time anyway.

So we first come up with a helper class that recursively computes the permutations:
```zig
fn PermutationsHelper(comptime n: u8) type {
    return struct {
        current: [n]u8 = undefined,
        used: [n]bool = [_]bool{false} ** n,
        ans: std.ArrayList([n]u8) = undefined,

        pub fn init(alloc1: std.mem.Allocator) @This() {
            return .{ .ans = std.ArrayList([n]u8).init(alloc1) };
        }

        pub fn recursive(self: *@This(), i: usize) !void {
            if (i == n) {
                try self.ans.append(self.current);
                return;
            }
            var num: u8 = 0;
            while (num < n) : (num += 1) {
                if (self.used[num]) continue;
                self.used[num] = true;
                self.current[i] = num;
                try self.recursive(i + 1);
                self.used[num] = false;
            }
        }
    };
}
```
The end result, after calling `.recursive(0)`, is stored in `.ans` an ArrayList.

Taking them out as an array (so it no longer needs an allocator) is a little annoying with my current knowledge of using this language:
```zig
fn numPermutations(comptime n: u8) usize {
    comptime {
        var buf: [1 << 10]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var ph = PermutationsHelper(n).init(fba.allocator());
        ph.recursive(0) catch @panic("buffuer too small");

        return ph.ans.items.len;
    }
}

fn getPermutations(comptime n: u8) [numPermutations(n)][n]u8 {
    comptime {
        var buf: [1 << 10]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var ph = PermutationsHelper(n).init(fba.allocator());
        ph.recursive(0) catch @panic("buffuer too small");
        var p: [numPermutations(n)][n]u8 = undefined;

        @memcpy(&p, ph.ans.items);
        return p;
    }
}

const perms = getPermutations(4);
```
Annoying because the computation is run twice.

I tried the following instead, but it does NOT work:
```zig
fn getPermutations(comptime n: u8) [_][n]u8 {
    comptime {
        var buf: [1 << 10]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var ph = PermutationsHelper(n).init(fba.allocator());
        ph.recursive(0) catch @panic("buffuer too small");
        var p: [ph.ans.items.len][n]u8 = undefined;
        @memcpy(&p, ph.ans.items);
        return p;
    }
}
```
The return type `[_][n]u8` cannot be inferred just like this.

Is there any return-type inferrence/derivation in Zig?

Anyway, the compile-time computation in Zig is NOT obstacle-free comparing to its run-time computatoin (also need a special allocator).
But it still feels easier than C++'s template-based programming.