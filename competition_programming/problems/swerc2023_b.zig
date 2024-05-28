// Copyright 2024 Cheng Sheng
// SPDX-License-Identifier: Apache-2.0
//
// SWERC 2023 B: Supporting everyone.
// https://swerc.eu/2023/results/
// https://swerc.eu/2023/problemset/problems.pdf
//
// Zig version: local 0.13 + PR#20002.

const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const Graph = struct {
    alloc: std.mem.Allocator,
    arc_pool: std.heap.MemoryPool(ArcList.Node),
    n: usize,
    // Adjacency list.
    arcs_by_node: []ArcList,

    pub fn init(alloc: std.mem.Allocator, n: usize) !Graph {
        const arcs_by_node = try alloc.alloc(std.SinglyLinkedList(Arc), n);
        for (arcs_by_node) |*list| list.* = .{};
        return .{
            .alloc = alloc,
            .arc_pool = std.heap.MemoryPool(ArcList.Node).init(alloc),
            .n = n,
            .arcs_by_node = arcs_by_node,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.alloc.free(self.arcs_by_node);
        self.arc_pool.deinit();
    }

    pub const Arc = struct {
        a: usize,
        b: usize,
        capacity: i64,
        flow: i64,
        reverse: *Arc,

        pub fn residual(self: *const Arc) i64 {
            return self.capacity - self.flow;
        }

        pub fn updateFlow(self: *Arc, delta: i64) void {
            self.flow += delta;
            self.reverse.flow -= delta;
        }
    };
    const ArcList = std.SinglyLinkedList(Arc);

    pub fn addArc(self: *@This(), a: usize, b: usize, capacity: i64) !void {
        const arc_node_ab = try self.arc_pool.create();
        const arc_node_ba = try self.arc_pool.create();
        arc_node_ab.* = .{ .data = .{ .a = a, .b = b, .capacity = capacity, .flow = 0, .reverse = &arc_node_ba.data } };
        arc_node_ba.* = .{ .data = .{ .a = b, .b = a, .capacity = 0, .flow = 0, .reverse = &arc_node_ab.data } };

        self.arcs_by_node[a].prepend(arc_node_ab);
        self.arcs_by_node[b].prepend(arc_node_ba);
    }

    pub fn flowUp(self: *@This(), s: usize, t: usize) !i64 {
        const NodeStatus = struct {
            id: usize,  // id = n for unused
            arriving_arc: ?*Arc = null,
        };
        const Queue = std.DoublyLinkedList(NodeStatus);
        const items = try self.alloc.alloc(Queue.Node, self.n);
        defer self.alloc.free(items);
        for (items) |*item| item.data.id = self.n;

        var q = Queue{};
        items[s] = .{ .data = .{ .id = s } };
        q.append(&items[s]);
        while (q.popFirst()) |cur| {
            const u = cur.data.id;
            var arc_it = self.arcs_by_node[u].first;
            while (arc_it) |arc| : (arc_it = arc.next) {
                const v = arc.data.b;
                if (arc.data.residual() > 0 and items[v].data.id == self.n) {
                    items[v].data = .{ .id = v, .arriving_arc = &arc.data };
                    q.append(&items[v]);
                }
            }
            // An augment path from `s` to `t` is found.
            if (items[t].data.id != self.n) break;
        }
        if (items[t].data.id == self.n) return 0;

        var flow_size: i64 = std.math.maxInt(i64);
        var arc_it = items[t].data.arriving_arc;
        while (arc_it) |arc| : (arc_it = items[arc.a].data.arriving_arc) {
            flow_size = @min(flow_size, arc.residual());
        }
        arc_it = items[t].data.arriving_arc;
        while (arc_it) |arc| : (arc_it = items[arc.a].data.arriving_arc) {
            arc.updateFlow(flow_size);
        }
        return flow_size;
    }
};

pub fn main() !void {
    const alloc = gpa.allocator();
    var in = tokenStream(std.io.getStdIn().reader());
    const out = std.io.getStdOut().writer();

    const n = try nextInt(&in, usize);
    const m = try nextInt(&in, usize);
    const flags = try alloc.alloc([]usize, n);
    defer alloc.free(flags);
    for (flags) |*flag| {
        const k = try nextInt(&in, usize);
        flag.* = try alloc.alloc(usize, k);
        for (flag.*) |*color| {
            color.* = try nextInt(&in, usize) - 1;
            std.debug.assert(color.* < m);
        }
    }

    const s = n + m + 0;
    const t = n + m + 1;
    var g = try Graph.init(alloc, n + m + 2);
    defer g.deinit();
    for (0..n) |i| try g.addArc(s, i, 1);
    for (0..m) |i| try g.addArc(n + i, t, 1);
    for (flags, 0..) |flag, i| {
        for (flag) |color| try g.addArc(i, n + color, 100000);
    }
    var ans: i64 = 0;
    while (true) {
        const f = try g.flowUp(s, t);
        if (f == 0) break;
        ans += f;
    }
    try out.print("{}\n", .{ans});
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
