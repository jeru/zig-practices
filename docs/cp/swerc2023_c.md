# An annoying problem
[SWERC 2023](https://swerc.eu/2023/results/) Problem C: Metro quiz.

It is very easy to notice the very small data size: `N <= 18`.
So the problem is probably aiming at something proportional to `2**N`.
This class of problem has some famous pattern of either being totally trivial
  or intentionally added a bunch of annoying complications to make a problem solver's
  life miserable.
And this is the latter.

It's not hard to solve, but a little hard to implement:
  some creativity is needed to sort all the messes out.
It ends up needing some slightly more involving language-level stuff.

## Problem statement issue
There's some inconsistency of `N` vs `M` in the problem statement.
Seems the input description section is current and the text description section is wrong.
So be sure: `N` is the number of stations and `M` is the number of metro lines.

## Solution Overview
Not very interesting, let's skip...

## Language-specific experiences

### Debug logging
Zig's `std.log` package does hvae all the standard logging mechansims we need in developing
  some large-scale softwares (the error/warning/info/debug leveled logging).
But all the cumbersome line headers are very unnecessary for solving a competition programming problem: too overkill and added too much information to read.
So a hacky stripped down version:
```zig
const dbg = std.log.defaultLogEnabled(.debug);
```
Now here and there, just add
```zig
  if (dbg) std.debug.print(...);
```

If the binary is compiled with default mode, this will output every debug message.
But when it is built with `-O ReleaseFast`, all the debug messages will be gone.

Should we add command-line argument support to more flexible toggle this?
There might be one such problem in a hundred problems...

### Sorting indices by values
There's an array `A` of N values, and an index array `I = [0, 1, 2, ..., N-1]`.
Sort `I` so `A[I[k]] <= A[I[k + 1]]` for all valid `k`.

For C++ (or any language with closure), it is simply
```c++
  sort(I.begin(), I.end(), [&A](size_t u, size_t v) { return A[u] < A[v]; });
```

For Zig, it is
```zig
fn compareIdsByItems(A: []i32, u: usize, v: usize) bool {
    return A[u] < A[v];
}
std.sort.heap(usize, I, A, compareIdsByItems);
```
More generally, the third param of `std.sort.heap()` can be any context object,
  passed to the comparing function as the first argument.

This is basically hand-crafting a closure.
This is probably the best one can get when the language doesn't (and probably won't) have closures.

### Integer casting
Zig supports a lot of integers, from `u1` up to `u128` for unsigned, and `i1` up to `u128`, CONTINUOUSLY (actually, even `u0` is allowed).
Just for fun, the solution of this problem uses `u18` as a bitmap for stations, and `u6` for a station id.
Then it has a ton of problems converting between these types.

Casting an integer type to a larger integer type is implicit ("type coercion"), but the reverse direction needs some explicit cast for potentially losing info.

There are a few options to cast ints to smaller ints:
* `@intCast`, eg., `@as(u18, @intCast(a_usize))`: Runtime error if `a_usize` is too big.
* `@truncate`, eg., `@as(u18, @truncate(a_usize))`: Ignore higher bits if `a_usize` is too big.

The combined use of `@as()` and `@intCast()` is not needed if the return type of `@intCast()` can be inferred. Eg., `const a: u18 = @intCast(a_usize);`
