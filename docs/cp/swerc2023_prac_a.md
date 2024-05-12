# A very simple array problem
[SWERC 2023](https://swerc.eu/2023/results/) Practice Problem A: Ascending hike.

Short description: Given an array of integers `A[]`, find its maximum monotonely increasing continuous subarray.
Maximum defined as `A[last] - A[first]`, and `monotonely increaseing` means `A[i] < A[i + 1]` for all `i` between `first` and `last`.

A straightforward (though too slow) solution would be

```zig
    var ans: i32 = 0;
    for (range(0, A.len)) |i| {
      for (range(i + 1, A.len)) |j| {
        if (isMonotonelyIncreasing(A[i..j])) {
          ans = @max(ans, A[j - 1] - A[i]);
        }
      }
    }
```
But since the input `A[]` can be as long as 1 million elements, we need a linear-time method, or at least sub-quadratic time.

## Identifying boundaries
Smarter idea is to observe that if `A[i..j]` is monotonely increasing, there's no need to check any proper subarray of `A`.
With this, we can simply partition the array into maximal monotonely increasing subarrays by cutting every boundary `A[i], A[i+1]` such that `A[i] >= A[i + 1]`.

Since Zig 0.13 has no coroutine (well, it has, but unlaunched as of 0.11), and we don't really care that much about the space consumption in competition programming (as far as it is within a predefined, normally quite generous, memory limit), just use a slice for that.

```zig
fn computeBoundaries(A: []i32) !std.ArrayList(usize) {
    var b = std.ArrayList(usize).init(alloc);
    try b.append(0);
    var i: usize = 1;
    while (i < A.len) : (i += 1) {
        if (A[i - 1] >= A[i]) {
          try b.append(i);
        }
    }
    try b.append(A.len);
    return b;
}

fn solve1(A: []i32) !i32 {
    const boundaries = try computeBoundaries(A);
    defer boundaries.deinit();
    const B = boundaries.items;

    var ans: i32 = 0;
    var i: usize = 1;
    while (i < B.len) : (i += 1) {
      ans = @max(ans, A[B[i] - 1] - A[B[i - 1]]);
    }

    return ans;
}

```
This is already linear-time.

How does it look like in C++? I'd write it as:

```C++
vector<size_t> ComputeBoundaries(const vector<int>& A) {
    vector<size_t> b;
    b.push_back(0);
    for (int i = 1; i < A.size(); ++i) {
        if (A[i - 1] >= A[i]) {
            b.push_back(i);
        }
    }
    b.push_back(A.size());
    return b;
}

int solve1(const vector<int>& A) {
    const boundaries = ComputeBoundaries(A);
    int ans = 0;
    for (int i = 1; i < boundaries.size(); ++i) {
      ans = max(ans, A[boundaries[i] - 1] - A[boundaries[i - 1]]);
    }
    return ans;
}
```

## More free-style looping.
Alternatively, we can have the loop variable `i` pointing to a boundary point, then compute `j` to be the next boundary point, then process `A[i..j]` and then make `i` immediately jumping to `j`, then no need to explicitly compute the boundary array.

```zig
fn solve2(A: []i32) i32 {
    var i: usize = 0;
    var ans: i32 = 0;
    while (i < A.len) {
        var j = i + 1;
        while (j < A.len and A[j - 1] < A[j]) : (j += 1) {}
        ans = @max(ans, A[j - 1] - A[i]);
        i = j;
    }
    return ans;
}
```

How does it look like in C++? I'd write it as:

```C++
int solve2(const vector<int>& A) {
    int ans = 0;
    for (size_t i = 0, j; i < A.size(); i = j) {
        for (j = i + 1; j < A.size() && A[j - 1] < A[j]; ++j);
        // A[i..j] is monotonely increasing and maximal.
        ans = max(ans, A[j - 1] - A[i]);
    }
    return ans;
}
```

## Summary
The solution is simple enough to stay very closely with the very common functionalities of different languages.
Feeling so far:
* Comparing to C++, Zig has more exposure to memory allocation (forced to use it explicitly) and its potential errors.
* The "destructors" (`deinit()`) of Zig containers don't really run the "destructors" of the underlying objects.
  This might shift more things towards structs.
  Eg., instead of saying `vector<Animal>` as in C++, Zig might prefer dealing with
  `struct Animals`, which wraps `ArrayList(Animal)`, just to ensure having the knowledge to properly destruct an individual `Animal`.
  But if lifetimes are already held by other means and a function is just reading or updating the objects, containers might still be used.
* The need to declare a loop variable outside the loop, and the consequent leaking of its scope, is mildly annoying.
