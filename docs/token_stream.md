Token Stream
=============

Start implementing something to get a taste of Zig.

In competition programming, I/O with stdin + stdout is probably the most popular manner due to its generality, simplicity (for the platform not for the contestants) and history (whole ICPC, older days IOI, etc.).

In such settings, inputs are normally described line-based, eg., "first line an integer `n`; the next `n` lines each describe an item, each item a list; each list starts with an integer `k` followed by `k` integers, all separated by a single space".
_The format is normally designed in a way that a contestant can also simply treat all newline symbols as spaces as well._
As a result, a contestant has two ways to deal with the inputs:
* Either follow the line-based description rigorously,
* or simply treat the input as a stream of tokens separated by whitespaces.
The latter one is typically easily handled by `scanf()` for C, `istream` for C++, 'Scanner+BufferedReader` for Java.
Reason of almost always allowing this "sloppy" convenience:
inputs are nearly always NOT the interesting part of a problem, let's pass this stage as fast as possible.

So here's a rough implementation of [`TokenStream`](competition_programming/lib/token_stream.zig) in Zig.

First impression:
* Quite a neat language overall.
* Has a strong flavor of C, maybe due to the lack of auto-destructor (instead, don't forget to `defer`!), or maybe I'm still only working with slices.
* Feels safer than C:
  - the way `struct` has "member" functions and visibility control, means I don't need to hold a ton of requirements in a comment (eg., to NOT explicitly manipulate some intermediate state fields) and worry it can be violated accidentally,
  - largely replaced raw pointer manipulations with slices.
* Inlined tests feel handy, though introduces a concern of accidentally ship testing libraries to prod code.
* Very interesting on `generic` handling: treating types as objects (but in compile time) and allowing compile-time computation in the same syntax as the normal code.
  Yet to see how this will unfold when more complicated type manipulating is needed.
  Kind-of feel that the pure "duck typing" approach will hit some problems, which C++ would address with "concepts" and Rust with `T: Trait`.
* Error handling and `optional` feels quite similar to Rust.
