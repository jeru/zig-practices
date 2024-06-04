# Learn Zig

## Competition programming
Competition programming can be a good source of practices:
well-defined problems;
small, isolated solutoins;
potentially complex logic.

1. Start implementing something: a [`TokenStream'](docs/token_stream.md).
1. Solve [a very simple array problem](docs/cp/swerc2023_prac_a.md).
1. Solve [a slightly more involving problem](docs/cp/swerc2023_a.md).
1. Solve [a problem with network flow](docs/cp/swerc2023_b.md).
1. Solve [an annoying problem](docs/cp/swerc2023_c.md).

## How powerful is the type system?

Zig supports at least some level of [dependent types](https://en.wikipedia.org/wiki/Dependent_type).
A small [example](pi_type/dummy_example.zig).
What can we do with Zig's type system?

1. Can we prove math theorems with it (like in Coq)? Attempt to define a [compile-time recursive data structure](pi_type/natural_number.zig). Then no idea how to express a "white-box" function (eg., for `plus()`), whose internal definition can be used for reasoning in a proof.
1. Can we run a very complicated code-gen (like Protobuf's code-gen) directly with Zig's compile-time computation? Most of code can be covered, but not fully. Like [this](pi_type/reflection.zig).
