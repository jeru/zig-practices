// Copyright 2024 Cheng Sheng
// SPDX-License-Identifier: Apache-2.0
//
// SWERC 2023 Practice Problem A: Ascending hike
// https://swerc.eu/2023/results/
// https://swerc.eu/2023/problemset/practice-problems.pdf

const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

fn nextInt(in: anytype, comptime int_type: type) !int_type {
    return std.fmt.parseInt(int_type, (try in.next()).?, 10);  // Sloppy unwrap.
}

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

pub fn main() !void {
    var in = tokenStream(std.io.getStdIn().reader());
    const out = std.io.getStdOut().writer();

    const n = try nextInt(&in, usize);
    const A = try alloc.alloc(i32, n);
    for (A) |*h| {
        h.* = try nextInt(&in, i32);
    }

    //const ans = try solve1(A);
    const ans = solve2(A);

    try out.print("{}\n", .{ans});
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

