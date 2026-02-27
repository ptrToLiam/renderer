/// Reinterpret the bytes of `src` as type `T`.
/// This WILL cast const -> non-const if `T` is non_const.
pub fn transmute(comptime T: type, src: anytype) T {
  const SourceType = @TypeOf(src);

  const TargetTypeInfo = @typeInfo(T);
  const TargetTypeName = @typeName(T);
  const SourceTypeInfo = @typeInfo(SourceType);
  const SourceTypeName = @typeName(SourceType);

  const result: T = if (T == SourceType)
    src
  else res: {
    switch (TargetTypeInfo) {
      .array => {
        if (SourceTypeInfo != .array)
          @compileError("Cannot transmute non-array type to array type");

        break :res @bitCast(src);
      },
      .pointer => {
        if (SourceTypeInfo == .pointer) {
          break :res if (TargetTypeInfo.pointer.is_const)
            @ptrCast(@alignCast(src))
          else
            @constCast(@ptrCast(@alignCast(src)));
        } else if (SourceTypeInfo == .array) {
          break :res if (TargetTypeInfo.pointer.is_const)
            @ptrCast(@alignCast(&src))
          else
            @constCast(@ptrCast(@alignCast(&src)));

        } else if (SourceTypeInfo == .int) {
          if (@sizeOf(SourceType) != @sizeOf(T)) {
            @compileError(
              "Cannot transmute type " ++
              SourceTypeName ++
              "to type " ++
              TargetTypeName ++
              ". Type sizes do not match!"
            );
          }
          break :res @ptrFromInt(src);
        } else {
          @compileError(
            "Cannot transmute non-pointer, non-int type to pointer type."
          );
        }
      },
      .optional => {
        @compileError("Transmute to optional types not yet implemented");
      },
      .@"struct" => |struct_t| {
        if (struct_t.backing_integer) |_| {
          if (SourceTypeInfo == .@"struct" and
              SourceTypeInfo.@"struct".backing_integer == null)
          {
            @compileError(
              "Cannot transmute from non-packed struct type " ++
              SourceTypeName ++
              "."
            );
          } else if (@sizeOf(SourceType) != @sizeOf(T)) {
            @compileError(
              "Cannot transmute type " ++
              SourceTypeName ++
              "to type " ++
              TargetTypeName ++
              ". Type sizes do not match!"
            );
          }
          break :res @bitCast(src);
        }
        @compileError(
          "Cannot transmute to non-packed struct type " ++
          TargetTypeName ++
          "."
        );
      },
      .int, .float, .bool => {
        if (@sizeOf(SourceType) != @sizeOf(T))
          @compileError(
            "Cannot transmute type " ++
            SourceTypeName ++
            "to type " ++
            TargetTypeName ++
            ". Type sizes do not match!"
          );
        break :res @bitCast(src);
      },
      else => @compileError(
        "Unsupported transmute target type: " ++
        TargetTypeName
      ),
    }
  };
  return result;
}

test "transmute: u32 <-> f32" {
  const uint: u32 = 20;
  const float: f32 = 40;

  const expected_uint_as_float: f32 = @bitCast(uint);
  const expected_float_as_uint: u32 = @bitCast(float);

  try testing.expect(transmute(f32, uint) == expected_uint_as_float);
  try testing.expect(transmute(u32, float) == expected_float_as_uint);
}

test "transmute: ptr_t <-> ptr_t" {
  // const values and pointers
  const uint_const: u32 = 20;
  const float_const: f32 = 20;
  const byte_const: u8 align(4) = 2;
  const uintptr_const = &uint_const;
  const floatptr_const = &float_const;
  const byteptr_const: *align(4) const u8 = &byte_const;

  const expected_uintptr_const: *const u32 = @ptrCast(@alignCast(floatptr_const));
  const expected_floatptr_const: *const f32 = @ptrCast(@alignCast(byteptr_const));
  const expected_byteptr_const: *align(4) const u8 = @ptrCast(@alignCast(uintptr_const));

  try testing.expect(transmute(*const u32, floatptr_const) == expected_uintptr_const);
  try testing.expect(transmute(*const f32, byteptr_const) == expected_floatptr_const);
  try testing.expect(transmute(*align(4) u8, uintptr_const) == expected_byteptr_const);

  // non-const values and pointers
  var uint: u32 = 10;
  var float: f32 = 10;
  var byte: u8 align(4) = 1;
  const uintptr: *u32 = &uint;
  const floatptr: *f32 = &float;
  const byteptr: *align(4) u8 = &byte;

  const expected_uintptr: *const u32 = @ptrCast(floatptr);
  const expected_floatptr: *const f32 = @ptrCast(byteptr);
  const expected_byteptr: *align(4) u8 = @ptrCast(@alignCast(uintptr));

  try testing.expect(transmute(*u32, floatptr) == expected_uintptr);
  try testing.expect(transmute(*f32, byteptr) == expected_floatptr);
  try testing.expect(transmute(*align(4) u8, uintptr) == expected_byteptr);
}

test "transmute: array -> int / packed struct / slice" {
  const eql = @import("std").mem.eql;
  const pstruct = packed struct (u64) { x: u32, y: u32 };
  const uint_arr = [2]u32{ 0, 10 };

  const expected_u64: u64 = @bitCast(uint_arr);
  const expected_pstruct: pstruct = .{ .x = 0, .y = 10 };
  const expected_uint_slice: []u32 = @ptrCast(@constCast(&uint_arr));
  const expected_byte_slice: []u8 = @ptrCast(@constCast(&uint_arr));

  try testing.expect(transmute(u64, uint_arr) == expected_u64);
  try testing.expect(transmute(pstruct, uint_arr) == expected_pstruct);
  try testing.expect(eql(u32, transmute([]u32, uint_arr), expected_uint_slice));
  try testing.expect(eql(u8, transmute([]u8, uint_arr), expected_byte_slice));
}

/// Cast the value of `src` to the same value of type `T`
/// Will invoke `transmute` if
/// - `T` is a pointer type.
/// - `T` is an integer type and `src` is a packed struct or vice versa.
/// - `T` is a packed struct and `src` is an enum type or vice versa.
pub fn cast(comptime T: type, src: anytype) T {
  const SourceType = @TypeOf(src);

  const TargetTypeInfo = @typeInfo(T);
  const TargetTypeName = @typeName(T);
  const SourceTypeInfo = @typeInfo(SourceType);
  const SourceTypeName = @typeName(SourceType);

  const result: T = if (T == SourceType)
    src
  else res: {
    switch (TargetTypeInfo) {
      .int => {
        if (SourceTypeInfo == .int or SourceTypeInfo == .comptime_int)
          break :res @intCast(src);
        if (SourceTypeInfo == .float or SourceTypeInfo == .comptime_float)
          break :res @intFromFloat(src);
        if (SourceTypeInfo == .@"struct") break :res transmute(T, src);
        if (SourceTypeInfo == .@"enum") break :res @intFromEnum(src);
        if (SourceTypeInfo == .pointer) break :res @intFromPtr(src);
      },
      .float => {
        if (SourceTypeInfo == .int or SourceTypeInfo == .comptime_int)
          break :res @floatFromInt(src);
        if (SourceTypeInfo == .float or SourceTypeInfo == .comptime_float)
          break :res @floatCast(src);
      },
      .@"enum" => {
        if (SourceTypeInfo == .int) break :res @enumFromInt(src);
        if (SourceTypeInfo == .@"enum") break :res @enumFromInt(@intFromEnum(src));
        if (SourceTypeInfo == .@"struct")  break :res transmute(T, src);
      },
      .pointer => {
        break :res transmute(T, src);
      },
      .@"struct" => |struct_t| {
        if (struct_t.backing_integer != null) {
          if (SourceTypeInfo == .int) break :res transmute(T, src);
          if (SourceTypeInfo == .@"enum") break :res transmute(T, @intFromEnum(src));
          if (SourceTypeInfo == .@"struct") break :res transmute(T, src);
        }
      },
      else => @compileError(
        "Unsupported cast target type: " ++
        TargetTypeName ++ "."
      ),
    }
    @compileError(
      "No conversion path from source type " ++
      SourceTypeName ++ " to target type " ++
      TargetTypeName
    );
  };

  return result;
}

test "cast: enum_t -> enum_t" {
  const enum_a_t = enum { one, two, three };
  const enum_b_t = enum { a, b, c };

  const one: enum_a_t = .one;
  const b: enum_b_t = .b;

  const expected_enum_b: enum_b_t = @enumFromInt(@intFromEnum(one));
  const expected_enum_a: enum_a_t = @enumFromInt(@intFromEnum(b));

  try testing.expect(cast(enum_b_t, one) == expected_enum_b);
  try testing.expect(cast(enum_a_t, b) == expected_enum_a);
}

test "cast: ints and floats" {
  const uint: u32 = 10;
  const sint: i32 = 20;
  const float: f32 = 30;

  const expected_uint: u32 = @intCast(sint);
  const expected_sint: i32 = @intFromFloat(float);
  const expected_float: f32 = @floatFromInt(uint);

  try testing.expect(cast(u32, sint) == expected_uint);
  try testing.expect(cast(i32, float) == expected_sint);
  try testing.expect(cast(f32, uint) == expected_float);
}

test "cast: ints and enums" {
  const enum_t = enum { one, two, three, four };
  const four: enum_t = .four;
  const uint: u32 = 2;

  const expected_uint: u32 = @intFromEnum(four);
  const expected_enum_t: enum_t = @enumFromInt(uint);

  try testing.expect(cast(u32, four) == expected_uint);
  try testing.expect(cast(enum_t, uint) == expected_enum_t);
}

const testing = @import("std").testing;