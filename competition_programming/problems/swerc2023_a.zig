// Copyright 2024 Cheng Sheng
// SPDX-License-Identifier: Apache-2.0
//
// SWERC 2023 A: Card game
// https://swerc.eu/2023/results/
// https://swerc.eu/2023/problemset/problems.pdf
//
// Zig version: local 0.13 + PR#20002.

const std = @import("std");

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

const old_perms = old_perms_block: {
    var perms_buf: [1 << 10]u8 = undefined;
    var perms_fba = std.heap.FixedBufferAllocator.init(&perms_buf);
    var perms_helper = PermutationsHelper(4).init(perms_fba.allocator());
    perms_helper.recursive(0) catch @panic("buffer too small");
    var array: [perms_helper.ans.items.len][4]u8 = undefined;
    @memcpy(&array, perms_helper.ans.items);
    break :old_perms_block array;
};

fn getSuitePermutations() [old_perms.len][5]u8 {
    comptime {
        var new_perms: [old_perms.len][5]u8 = undefined;
        for (&old_perms, &new_perms) |*old_perm, *new_perm| {
            @memcpy(new_perm[0..4], old_perm);
            new_perm[4] = 4;
        }
        return new_perms;
    }
}

// It's absolutely unnecessary to compute this in compile time. Just give a try
// of the language feature...
const perms = getSuitePermutations();

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

const InvalidCardError = error{
    Empty,
    UnknownSuite,
};

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
        return .{ .suite = suite, .num = num };
    }
};

const MyTreap = std.Treap(u64, std.math.order);
const MyValue = struct {
    node: MyTreap.Node,
    value: usize,
};

pub fn main() !void {
    var in = tokenStream(std.io.getStdIn().reader());
    const out = std.io.getStdOut().writer();

    const n = try std.fmt.parseInt(usize, (try in.next()).?, 10);
    const cards = try alloc.alloc(Card, n);
    defer alloc.free(cards);
    for (cards) |*card| {
        card.* = try Card.init((try in.next()).?);
    }

    const flat_cards = try alloc.alloc(u64, n);
    defer alloc.free(flat_cards);
    const values = try alloc.alloc(MyValue, n);
    defer alloc.free(values);

    var ans: usize = std.math.maxInt(usize);
    for (&perms) |*perm| {
        for (cards, flat_cards) |*card, *flat_card| {
            flat_card.* = @as(u64, perm[card.suite]) << 32 | @as(u64, card.num);
        }
        ans = @min(ans, minOperations(flat_cards, values));
    }
    try out.print("{}\n", .{ans});
}

fn minOperations(cards: []u64, values: []MyValue) usize {
    var treap = MyTreap{};
    var max_len: usize = 0;
    for (cards, values) |card, *value| {
        {
            var entry = treap.getEntryFor(card);
            // Might overwrite previous cards with same value.
            entry.set(&value.node);
        }
        const new_value = valueFromNode(value.node.prev()) + 1;
        value.value = new_value;
        max_len = @max(max_len, new_value);

        var node_to_remove = value.node.next();
        while (node_to_remove) |node| {
            if (valueFromNode(node) > new_value) break;
            node_to_remove = node.next();
            var entry = treap.getEntryForExisting(node);
            entry.set(null);
        }
    }
    return cards.len - max_len;
}

fn valueFromNode(maybe_node: ?*MyTreap.Node) usize {
    if (maybe_node) |node| {
        const my_value: *MyValue = @fieldParentPtr("node", node);
        return my_value.value;
    } else {
        return 0;
    }
}

// **********************************************************
// **********************************************************
// **********************************************************
// IMPORTED LIBS BELOW
// **********************************************************
// **********************************************************
// **********************************************************

// Copyright 2024 Cheng Sheng
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// A whitespace-separated stream of tokens from a Reader.
pub fn TokenStream(comptime ReaderType: type) type {
    return struct {
        r: ReaderType,
        gpa: DefaultGpa,
        byte_buf: []u8 = undefined,
        byte_cur: []u8 = undefined,
        item_buf: []u8 = undefined,

        pub const Error = ReaderType.Error;

        const Self = @This();
        const DefaultGpa = std.heap.GeneralPurposeAllocator(.{});

        pub fn init(r: ReaderType) Self {
            var s = Self{
                .r = r,
                .gpa = DefaultGpa{},
            };
            s.byte_buf = s.alloc(4096);
            s.byte_cur = s.byte_buf[0..0];
            s.item_buf = s.alloc(4);
            return s;
        }

        pub fn deinit(self: *Self) void {
            self.free(self.item_buf);
            self.free(self.byte_buf);
            self.gpa.deinit() catch @panic("leak");
        }

        /// Returns the next token; null if the nothing left (EOF reached). The
        /// returned slice's content is only valid before the next call to this
        /// function.
        pub fn next(self: *Self) Error!?[]u8 {
            while (true) {
                if (self.byte_cur.len == 0) {
                    const len = try self.r.read(self.byte_buf);
                    if (len == 0) return null; // EOF
                    self.byte_cur = self.byte_buf[0..len];
                } else if (std.ascii.isWhitespace(self.byte_cur[0])) {
                    self.byte_cur = self.byte_cur[1..];
                } else {
                    return try self.getCompleteItem();
                }
            }
        }

        fn getCompleteItem(self: *Self) Error![]u8 {
            var len: usize = 0;
            while (try self.nextByte()) |byte| {
                if (std.ascii.isWhitespace(byte)) return self.item_buf[0..len];
                if (len == self.item_buf.len) self.doubleItemBuf();
                self.item_buf[len] = byte;
                len += 1;
            }
            return self.item_buf[0..len];
        }

        fn nextByte(self: *Self) Error!?u8 {
            if (self.byte_cur.len == 0) {
                const len = try self.r.read(self.byte_buf);
                if (len == 0) return null; // EOF
                self.byte_cur = self.byte_buf[0..len];
            }
            const byte = self.byte_cur[0];
            self.byte_cur = self.byte_cur[1..];
            return byte;
        }

        fn alloc(self: *Self, len: usize) []u8 {
            return self.gpa.allocator().alloc(u8, len) catch @panic("alloc");
        }
        fn free(self: *Self, array: []u8) void {
            self.gpa.allocator().free(array);
        }
        fn doubleItemBuf(self: *Self) void {
            const len = self.item_buf.len;
            var new_buf = self.alloc(len * 2);
            @memcpy(new_buf[0..len], self.item_buf);
            self.item_buf = new_buf;
        }
    };
}

pub fn tokenStream(reader: anytype) TokenStream(@TypeOf(reader)) {
    return TokenStream(@TypeOf(reader)).init(reader);
}
