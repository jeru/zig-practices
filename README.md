Learn Zig
=========
Competition programming can be a good source of practices:
well-defined problems;
small, isolated solutoins;
potentially complex logic.

Start with a [`TokenStream`](competition_programming/lib/token_stream.zig) to ease I/O interfacing.
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
