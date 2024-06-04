const std = @import("std");

const FooField = struct{
    type_: type,
    name: [:0]const u8,
};

const FooInternal: type = constructFooInternal(&[_]FooField{
    .{.type_ = u8, .name = "foo_byte"},
    .{.type_ = i32, .name = "bar_int"},
});

pub const Foo = struct {
    internal: FooInternal,

    pub fn has(self: *const Foo, comptime field_name: [:0]const u8) bool {
        return @field(self.internal, field_name) != null;
    }
    pub fn get(self: *const Foo, comptime field_name: [:0]const u8)
            @TypeOf(@field(self.internal, field_name)) {
        return @field(self.internal, field_name);
    }
    pub fn mutable(self: *Foo, comptime field_name: [:0]const u8)
            *@typeInfo(@TypeOf(@field(self.internal, field_name))).Optional.child {
        const type_ = @typeInfo(@TypeOf(@field(self.internal, field_name))).Optional.child;
        if (@field(self.internal, field_name) == null) {
            @field(self.internal, field_name) = @as(type_, 0);
        }
        return &@field(self.internal, field_name).?;
    }
};

pub fn constructFooInternal(comptime field_descs: []const FooField) type {
    const Type = std.builtin.Type;
    const fields = block_fields: {
        var fields1: [field_descs.len]Type.StructField = undefined;
        for (field_descs, &fields1) |*desc, *field| {
            field.* = Type.StructField{
                .name = desc.name,
                .type = ?desc.type_,
                .default_value = null,
                .is_comptime = false,
                .alignment = 0,
            };
        }
        break :block_fields fields1;
    };
    const decls: [0]Type.Declaration = undefined;
    const T = @Type(Type{.Struct = Type.Struct{
        .layout = .auto,
        .fields = &fields,
        .decls = &decls,
        .is_tuple = false,
    }});
    return T;
}

test "smoke test" {
    var foo: Foo = std.mem.zeroes(Foo);
    try std.testing.expect(!foo.has("foo_byte"));
    try std.testing.expect(!foo.has("bar_int"));
    try std.testing.expectEqual(null, foo.get("foo_byte"));
    try std.testing.expectEqual(null, foo.get("bar_int"));

    foo.mutable("foo_byte").* = 3;
    try std.testing.expect(foo.has("foo_byte"));
    try std.testing.expectEqual(@as(?u8, 3), foo.get("foo_byte"));

    foo.mutable("bar_int").* = -5;
    try std.testing.expect(foo.has("bar_int"));
    try std.testing.expectEqual(@as(?i32, -5), foo.get("bar_int"));
}
