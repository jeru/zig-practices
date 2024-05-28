# Problem with network flow
[SWERC 2023](https://swerc.eu/2023/results/) Problem B: Supporting everyone.

Given a bunch of national flags to draw, each requires some colors, one can choose to either draw a flag (requiring buying all those colors) or directly buy a flag.

Minimize: #colors-bought + #flags-bought.

Up to 1000 flags, up to 100 colors.

## Solution overview
Quite standard min-cut:
* Each color a graph node, each flag also a graph node, and add a source node and a target node.
* Source node has a unit-capacity edge to each color. Saturated edge means buying that color.
* Each flag has a unit-capacity edge to the target node. Saturated edge means buying that flag.
* Color to flag node has a inifinity-capacity edge if the flag needs the color. It means that either the source-color edge is saturated or the flag-target edge is saturated, for otherwise, that's not a max-flow (i.e., min-cut).

So this problem needs a little more graph/struct involvement.

## Language-specific experiences
To implement network flow, we need a `Graph` of nodes and arcs, each arc has a capacity and flow, and needs to also track its "reverse arc".
The arcs should be organized in an adjacency list so all arcs going out from a node can be accessed easily.

### Definition of the Arc
```zig
const Graph = struct {
    ...
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
```
Allowing member functions did provide some ergonomic value comparing to C.

The adjacency list will be implemented as a (node-indexed-)array of singly linked list.
Zig's linked list is a little special:
* Contrasting to C's linked list, it employs allowed generic types to allow the user type
  inside the linked list node (roughly: `Node = struct { next: *?Node, data: T}`).
  This avoids the need of C's methodology of defining the node as a member field of a user
  struct, then letting the linked list manage only the node fields, then "cast-node-field-ptr-to-containing-struct-ptr" to obtain the genericality.
* Contrasting to C++ STL's linked list, the user does need to manage the nodes themselves,
  instead of encapsulating the nodes totally as internal details of the linked list.
  This is totally understandable: if the user has no access to some node pointer, who cares
  about linked list? Totally useless as in C++'s.

### Managing the linked list nodes into an adjacency list
```zig
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
    ...

    pub fn addArc(self: *@This(), a: usize, b: usize, capacity: i64) !void {
        const arc_node_ab = try self.arc_pool.create();
        const arc_node_ba = try self.arc_pool.create();
        arc_node_ab.* = .{ .data = .{ .a = a, .b = b, .capacity = capacity, .flow = 0, .reverse = &arc_node_ba.data } };
        arc_node_ba.* = .{ .data = .{ .a = b, .b = a, .capacity = 0, .flow = 0, .reverse = &arc_node_ab.data } };

        self.arcs_by_node[a].prepend(arc_node_ab);
        self.arcs_by_node[b].prepend(arc_node_ba);
    }
    ...
```
A few places to notice:
* MemoryPool for arcs. No idea how many arcs there are at the beginning, so some dynamic-sized but stable storage is needed.
* Dynamically allocated slices (here, the array of singly-linked-list) by the allocator are
  by default not initialized. Remember to do some default initialization.
  - Or, zero-init? The allocator libraray doesn't seem to have such a function yet.
* A copy of the allocator is kept in `Graph`, so it can be `deinit()`ed.
  - Can I avoid storing the alloc but provide it to both `init()` and `deinit()`?
  - If there's only one allocator, and we do this for all nested `struct`s recursively, it
    actually sounds also okay?
  - Reason for doing this is to save a variable in each `struct`. Might be useful in some extreme cases, eg., a lot of potentially small but variable-sized objects.

What would I do this in C++?
```c++
struct Graph {
    size_t n;
    vector<deque<Arc>> arcs_by_node;

    Graph(_n: size_t) : n(_n), arcs_by_node(n) {}

    void AddArc(size_t a, size_t b, int64_t capacity) {
        arcs_by_node[a].emplace_back();
        Arc& arc_ab = arcs_by_node[a].back();
        arcs_by_node[b].emplace_back();
        Arc& arc_ba = arcs_by_node[b].back();

        arc_ab = Arc{a, b, capacity, /*flow=*/0, &arc_ba};
        arc_ab = Arc{a, b, /*capacity=*/0, /*flow=*/0, &arc_ab};
    }
};
```
It's neater, but saving comes from majorly no need to manage the memory allocation and initialization.

### Breath-first search for a network flow augment path
There's no direct "queue" data structure in Zig.
One replacement if a doubly-linked list.
Just like the singly-linked list, the user needs to manage the generic node themselves.
```zig
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
```

Now, find the maximum amount of the flow that can be augmented:
```zig
        var flow_size: i64 = std.math.maxInt(i64);
        var arc_it = items[t].data.arriving_arc;
        while (arc_it) |arc| : (arc_it = items[arc.a].data.arriving_arc) {
            flow_size = @min(flow_size, arc.residual());
        }
```
and apply the augmentation:
```zig
        arc_it = items[t].data.arriving_arc;
        while (arc_it) |arc| : (arc_it = items[arc.a].data.arriving_arc) {
            arc.updateFlow(flow_size);
        }
        return flow_size;
    }
```

Also, have a comparison C++ version:
```c++
    int64_t FlowUp(size_t s, size_t t) {
        vector<bool> visited(n, false);
        vector<Arc*> arriving_arc(n, nullptr);
        queue<size_t> q;
        visited[s] = true;
        q.push(s);
        while (!q.empty() && !visited[t]) {
            const size_t u = q.front();
            q.pop();
            for (Arc& arc : arcs_by_node[u]) {
                const size_t v = arc.b;
                if (arc.residual() > 0 && !visited[v]) {
                    visited[v] = true;
                    arriving_arc[v] = &arc;
                    q.push(v);
                }
            }
        }
        if (!visited[t]) return 0;

        auto flow_size = limits<int64_t>::max();
        for (Arc* arc = arriving_arc[t]; arc != nullptr; arc = arriving_arc[arc->a]) {
            flow_size = max(flow_size, arc->residual());
        }
        for (Arc* arc = arriving_arc[t]; arc != nullptr; arc = arriving_arc[arc->a]) {
            arc->UpdateFlow(flow_size);
        }
        return flow_size;
    }
```

The need to declare a loop variable outside the loop in Zig is mildly annoying, but pure ergonomic.
