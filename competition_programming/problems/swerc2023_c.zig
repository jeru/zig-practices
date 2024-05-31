// Copyright 2024 Cheng Sheng
// SPDX-License-Identifier: Apache-2.0
//
// SWERC 2023 C: Metro quiz
// https://swerc.eu/2023/results/
// https://swerc.eu/2023/problemset/problems.pdf
//
// Zig version: local 0.13 + PR#20002.

const std = @import("std");
const dbg = std.log.defaultLogEnabled(.debug);

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

fn compareIdsByItems(items: []u18, a: u6, b: u6) bool {
    return items[a] < items[b];
}

const State = struct {
    id: usize,
    bits: u18,
    lines: []u6,
};

const States = struct {
    alloc: std.mem.Allocator,
    states: std.ArrayList(State),
    state_lines_pool: []u6 = undefined,
    state_to_id: []usize = undefined,

    num_stations: u6,
    lines: []u18,

    pub fn deinit(self: *@This()) void {
        self.alloc.free(self.state_to_id);
        self.states.deinit();
        self.alloc.free(self.state_lines_pool);
    }

    pub fn init(alloc: std.mem.Allocator, num_stations: usize, lines: []u18) !States {
        var s = States{
            .alloc = alloc,
            .num_stations = @truncate(num_stations),
            .lines = lines,
            .states = std.ArrayList(State).init(alloc),
        };

        const pow2 = @as(usize, 1) << s.num_stations;
        s.state_lines_pool = try alloc.alloc(u6, pow2 * lines.len);
        var state_lines_pool = s.state_lines_pool;

        const masked_lines = try alloc.alloc(u18, lines.len);
        defer alloc.free(masked_lines);
        const ids = try alloc.alloc(u6, lines.len);
        defer alloc.free(ids);
        const bit_mask = pow2 - 1;
        for (0..pow2) |reverse_bits| {
            const bits: u18 = @truncate(~reverse_bits & bit_mask);
            for (lines, 0..) |line, i| {
                masked_lines[i] = line & bits;
                ids[i] = @truncate(i);
            }
            std.sort.heap(u6, ids, masked_lines, compareIdsByItems);
            var i: usize = 0;
            while (i < lines.len) {
                var j = i + 1;
                while (j < lines.len and masked_lines[ids[i]] == masked_lines[ids[j]]) j += 1;

                std.debug.assert(j - i <= state_lines_pool.len);
                var state_lines = state_lines_pool[0 .. j - i];
                state_lines_pool = state_lines_pool[j - i ..];
                for (0..j - i) |k| state_lines[k] = ids[i + k];

                const new_state_id = s.states.items.len;
                try s.states.append(.{ .id = new_state_id, .bits = bits, .lines = state_lines });
                i = j;
            }
        }

        s.state_to_id = try alloc.alloc(usize, pow2 * lines.len);
        for (s.states.items) |*state| {
            for (state.lines) |line| {
                const pos = @as(usize, state.bits) * lines.len + line;
                s.state_to_id[pos] = state.id;
            }
        }

        return s;
    }

    pub fn stateId(self: *const @This(), bits: u18, line: u6) usize {
        return self.state_to_id[@as(usize, bits) * self.lines.len + line];
    }

    pub fn len(self: *const @This()) usize {
        return self.states.items.len;
    }
    pub fn items(self: *const @This()) []const State {
        return self.states.items;
    }

    pub fn printDebug(self: *const @This()) void {
        std.debug.print("#states = {}\n", .{self.states.items.len});
        for (self.states.items) |state| {
            std.debug.print("state {}\t bits {b} lines", .{ state.id, state.bits });
            for (state.lines) |line| std.debug.print(" {}", .{line});
            std.debug.print("\n", .{});
        }
    }
};

fn computeTransitionCost(state: *const State, new_bits: u18, dp: []const f64, states: *const States) ?f64 {
    var sum: f64 = 0;
    for (state.lines) |line| {
        const i = states.stateId(new_bits, line);
        if (dp[i] >= 1e199) return null;
        sum += dp[i] + 1;
    }
    return sum / @as(f64, @floatFromInt(state.lines.len));
}

pub fn main() !void {
    const alloc = gpa.allocator();
    var in = tokenStream(std.io.getStdIn().reader());
    const out = std.io.getStdOut().writer();

    const num_stations = try nextInt(&in, usize);
    const num_lines = try nextInt(&in, usize);
    const lines = try alloc.alloc(u18, num_lines);
    for (lines) |*line| {
        const k = try nextInt(&in, usize);
        line.* = 0;
        for (0..k) |_| {
            const s = try nextInt(&in, usize);
            std.debug.assert(s < num_stations);
            line.* |= @as(u18, 1) << @as(u5, @truncate(s));
        }
    }

    var states = try States.init(alloc, num_stations, lines);
    defer states.deinit();

    if (dbg) states.printDebug();
    const dp = try alloc.alloc(f64, states.len());
    for (states.items(), 0..) |*s, i| {
        if (s.lines.len == 1) {
            dp[i] = 0;
            continue;
        }
        dp[i] = 1e200;
        for (0..num_stations) |k| {
            if ((s.bits >> @truncate(k) & 1) != 0) continue;
            const new_bits = s.bits | @as(u18, 1) << @truncate(k);
            const maybe_cost = computeTransitionCost(s, new_bits, dp, &states);
            if (maybe_cost) |cost| dp[i] = @min(dp[i], cost);
        }
        if (dbg) std.debug.print("dp[{}] = {}\n", .{ i, dp[i] });
    }
    const ans = dp[dp.len - 1];
    if (ans >= 1e199) {
        try out.print("not possible\n", .{});
    } else {
        try out.print("{d:.20}\n", .{ans});
    }
}

fn nextInt(in: anytype, comptime int_type: type) !int_type {
    return std.fmt.parseInt(int_type, (try in.next()).?, 10); // Sloppy unwrap.
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
