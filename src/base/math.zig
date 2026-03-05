pub const Units = struct {
  pub inline fn KB(val: anytype) @TypeOf(val) {
    comptime {
      const t_info = @typeInfo(@TypeOf(val));
      if (!(t_info == .int or t_info == .comptime_int)) {
        @compileError("Unit conversion values must be of unsigned integer type");
      }
      if (!(t_info == .comptime_int and val >= 0) and t_info.int.signedness == .signed) {
        @compileError("Unit conversion values must be unsigned integers");
      }

      if ((t_info == .int and t_info.int.bits < 16)) {
        @compileError("Integer too small. Must have at minimum 16 bits");
      }
    }

    return val << 10;
  }

  pub inline fn MB(val: anytype) @TypeOf(val) {
    comptime {
      const t_info = @typeInfo(@TypeOf(val));
      if (!(t_info == .int or t_info == .comptime_int)) {
        @compileError("Unit conversion values must be of unsigned integer type");
      }
      if (!(t_info == .comptime_int and val >= 0) and t_info.int.signedness == .signed) {
        @compileError("Unit conversion values must be unsigned integers");
      }

      if ((t_info == .int and t_info.int.bits < 32)) {
        @compileError("Integer too small. Must have at minimum 32 bits");
      }
    }

    return val << 20;
  }

  pub inline fn GB(val: anytype) @TypeOf(val) {
    comptime {
      const t_info = @typeInfo(@TypeOf(val));
      if (!(t_info == .int or t_info == .comptime_int)) {
        @compileError("Unit conversion values must be of unsigned integer type");
      }
      if (!(t_info == .comptime_int and val >= 0) and t_info.int.signedness == .signed) {
        @compileError("Unit conversion values must be unsigned integers");
      }

      if ((t_info == .int and t_info.int.bits < 64)) {
        @compileError("Integer too small. Must have at minimum 64 bits");
      }
    }

    return val << 30;
  }

  pub inline fn TB(val: anytype) @TypeOf(val) {
    comptime {
      const t_info = @typeInfo(@TypeOf(val));
      if (!(t_info == .int or t_info == .comptime_int)) {
        @compileError("Unit conversion values must be of unsigned integer type");
      }
      if (!(t_info == .comptime_int and val >= 0) and t_info.int.signedness == .signed) {
        @compileError("Unit conversion values must be unsigned integers");
      }

      if ((t_info == .int and t_info.int.bits < 64)) {
        @compileError("Integer too small. Must have at minimum 64 bits");
      }
    }

    return val << 40;
  }
};

//-----------------------------------------------------------------------------
// Vector Types
//-----------------------------------------------------------------------------

pub const Vec2f32 = packed struct {
  x: f32,
  y: f32,

  /// Returns a pointer to the vector as an indexable array
  ///
  /// Works for const and non-const values
  pub fn arr(vec: anytype) asArrT(f32, @TypeOf(vec), 2) {
    return @ptrCast(vec);
  }
};

pub const Vec2i32 = packed struct {
  x: i32,
  y: i32,

  /// Returns a pointer to the vector as an indexable array
  ///
  /// Works for const and non-const values
  pub fn arr(vec: anytype) asArrT(i32, @TypeOf(vec), 2) {
    return @ptrCast(vec);
  }
};

pub const Vec2u32 = packed struct {
  x: u32,
  y: u32,

  /// Returns a pointer to the vector as an indexable array
  ///
  /// Works for const and non-const values
  pub fn arr(vec: anytype) asArrT(u32, @TypeOf(vec), 2) {
    return @ptrCast(vec);
  }
};

pub const Vec3f32 = packed struct {
  x: f32,
  y: f32,
  z: f32,

  /// Returns a pointer to the vector as an indexable array
  ///
  /// Works for const and non-const values
  pub fn arr(vec: anytype) asArrT(f32, @TypeOf(vec), 3) {
    return @ptrCast(vec);
  }
};

pub const Vec3i32 = packed struct {
  x: i32,
  y: i32,
  z: i32,

  /// Returns a pointer to the vector as an indexable array
  ///
  /// Works for const and non-const values
  pub fn arr(vec: anytype) asArrT(i32, @TypeOf(vec), 3) {
    return @ptrCast(vec);
  }
};

pub const Vec3u32 = packed struct {
  x: u32,
  y: u32,
  z: u32,

  /// Returns a pointer to the vector as an indexable array
  ///
  /// Works for const and non-const values
  pub fn arr(vec: anytype) asArrT(u32, @TypeOf(vec), 3) {
    return @ptrCast(vec);
  }
};

pub const Vec4f32 = packed struct {
  x: f32,
  y: f32,
  z: f32,
  w: f32,

  /// Returns a pointer to the vector as an indexable array
  ///
  /// Works for const and non-const values
  pub fn arr(vec: anytype) asArrT(f32, @TypeOf(vec), 4) {
    return @ptrCast(vec);
  }
};

pub const Vec4i32 = packed struct {
  x: i32,
  y: i32,
  z: i32,
  w: i32,

  /// Returns a pointer to the vector as an indexable array
  ///
  /// Works for const and non-const values
  pub fn arr(vec: anytype) asArrT(i32, @TypeOf(vec), 4) {
    return @ptrCast(vec);
  }
};

pub const Vec4u32 = packed struct {
  x: u32,
  y: u32,
  z: u32,
  w: u32,

  /// Returns a pointer to the vector as an indexable array
  ///
  /// Works for const and non-const values
  pub fn arr(vec: anytype) asArrT(u32, @TypeOf(vec), 4) {
    return @ptrCast(vec);
  }
};

/// Recasts a pointer to some data of type T as a pointer
/// to an array of N elements of type E
fn asArrT(comptime E: type, comptime T: type, N: usize) type {
  return switch (@typeInfo(T)) {
    .pointer => |p| switch (p.is_const) {
      true => *const [N]E,
      false => *[N]E,
    },
    else => @compileError(""),
  };
}

//-----------------------------------------------------------------------------

pub const Rng2u64 = packed struct {
  min: u64,
  max: u64,

  /// Returns a pointer to the vector as an indexable array
  ///
  /// Works for const and non-const values
  pub fn arr(rng: anytype) asArrT(u64, @TypeOf(rng), 2) {
    return @ptrCast(rng);
  }
};

//-----------------------------------------------------------------------------

pub inline fn div_roundup(n: anytype, size: usize) u32 {
  // TODO: See if there's a better way to do this... am tired
  return base.u32_(size * ((base.u64_(n) + (size-1)) / size));
}

pub fn align_pow2(x: usize, b: usize) usize {
  return @as(usize, (@as(usize, (x + b - 1)) & (~@as(usize, (b - 1)))));
}

pub fn is_pow2(x: anytype) bool {
  base.Assert(x > 0);
  return (x & (x - 1)) == 0;
}

// /// Row-major 4x4 f32 Matrix
// ///
// /// Use matrix.col_maj() to export column-major matrix for GLSL compat
// pub const Matrix = struct {
//   data: [4]@Vector(4, f32),
//
//   pub fn identity() Matrix {
//     return .{
//       .data = .{
//         .{ 1.0, 0.0, 0.0, 0.0 },
//         .{ 0.0, 1.0, 0.0, 0.0 },
//         .{ 0.0, 0.0, 1.0, 0.0 },
//         .{ 0.0, 0.0, 0.0, 1.0 },
//       },
//     };
//   }
//
//   pub fn look_at(eye: Vec3f32, target: Vec3f32, up: Vec3f32, flip_axis: bool) Matrix {
//     const forward = normalize(target - eye);
//     const right = normalize(cross3(forward, up));
//     const up_true = cross3(right, forward);
//
//     return .{
//       .data = .{
//         .{ right[0], right[1], right[2], -dot(right, eye) },
//         .{ up_true[0], up_true[1], up_true[2], -dot(up_true, eye) },
//         .{ -forward[0], -forward[1], -forward[2], if (flip_axis) dot(forward, eye) else -dot(forward, eye) },
//         .{ 0, 0, 0, 1 },
//       },
//     };
//   }
//
//   pub fn col_maj(noalias mat: *const Matrix) Matrix {
//     return .{
//       .data = .{
//         .{ mat.data[0][0], mat.data[1][0], mat.data[2][0], mat.data[3][0] },
//         .{ mat.data[0][1], mat.data[1][1], mat.data[2][1], mat.data[3][1] },
//         .{ mat.data[0][2], mat.data[1][2], mat.data[2][2], mat.data[3][2] },
//         .{ mat.data[0][3], mat.data[1][3], mat.data[2][3], mat.data[3][3] },
//       },
//     };
//   }
//
//   pub fn perspective(fov: f32, aspect: f32, near: f32, far: f32) Matrix {
//     const tan_half_fov = std.math.tan(fov / 2.0);
//     const z_range = near - far;
//     return .{
//       .data = .{
//         .{ 1.0 / (aspect * tan_half_fov), 0.0, 0.0, 0.0 },
//         .{ 0.0, 1.0 / tan_half_fov, 0.0, 0.0 },
//         .{ 0.0, 0.0, (near + far) / z_range, (2.0 * near * far) / z_range },
//         .{ 0.0, 0.0, -1.0, 0.0 },
//       },
//     };
//   }
//
//   pub fn rotateX(angle_radians: f32) Matrix {
//     const c = math.cos(angle_radians);
//     const s = math.sin(angle_radians);
//     return .{
//       .data = .{
//         .{ 1.0, 0.0, 0.0, 0.0 }, // Row 0
//         .{ 0.0, c, s, 0.0 }, // Row 1
//         .{ 0.0, -s, c, 0.0 }, // Row 2
//         .{ 0.0, 0.0, 0.0, 1.0 }, // Row 3
//       },
//     };
//   }
//
//   pub fn rotateY(angle_radians: f32) Matrix {
//     const c = math.cos(angle_radians);
//     const s = math.sin(angle_radians);
//     return .{
//       .data = .{
//         .{ c, 0.0, -s, 0.0 }, // Row 0
//         .{ 0.0, 1.0, 0.0, 0.0 }, // Row 1
//         .{ s, 0.0, c, 0.0 }, // Row 2
//         .{ 0.0, 0.0, 0.0, 1.0 }, // Row 3
//       },
//     };
//   }
//
//   pub fn rotateZ(angle_radians: f32) Matrix {
//     const c = cos(angle_radians);
//     const s = sin(angle_radians);
//     return .{
//       .data = .{
//         .{ c, s, 0.0, 0.0 }, // Row 0
//         .{ -s, c, 0.0, 0.0 }, // Row 1
//         .{ 0.0, 0.0, 1.0, 0.0 }, // Row 2
//         .{ 0.0, 0.0, 0.0, 1.0 }, // Row 3
//       },
//     };
//   }
//   // Translation along X-axis (right/left)
//   pub fn translateX(tx: f32) Matrix {
//     return .{
//       .data = .{
//         .{ 1.0, 0.0, 0.0, tx }, // Positive tx = right
//         .{ 0.0, 1.0, 0.0, 0.0 },
//         .{ 0.0, 0.0, 1.0, 0.0 },
//         .{ 0.0, 0.0, 0.0, 1.0 },
//       },
//     };
//   }
//
//   // Translation along Y-axis (up/down)
//   pub fn translateY(ty: f32) Matrix {
//     return .{
//       .data = .{
//         .{ 1.0, 0.0, 0.0, 0.0 },
//         .{ 0.0, 1.0, 0.0, ty }, // Positive ty = up
//         .{ 0.0, 0.0, 1.0, 0.0 },
//         .{ 0.0, 0.0, 0.0, 1.0 },
//       },
//     };
//   }
//
//   // Translation along Z-axis (forward/back)
//   pub fn translateZ(tz: f32) Matrix {
//     return .{
//       .data = .{
//         .{ 1.0, 0.0, 0.0, 0.0 },
//         .{ 0.0, 1.0, 0.0, 0.0 },
//         .{ 0.0, 0.0, 1.0, tz }, // Positive tz = forward (out of screen)
//         .{ 0.0, 0.0, 0.0, 1.0 },
//       },
//     };
//   }
//
//   pub fn mul(noalias mat: *const Matrix, b: anytype) if (@TypeOf(b) == Vec4f32) Vec4f32 else Matrix {
//     const return_t = if (@TypeOf(b) == Vec4f32) Vec4f32 else Matrix ;
//     const result: return_t = switch (@TypeOf(b)) {
//       Matrix => matmul: {
//         var tmp: Matrix = .{ .data = @splat(@as(@Vector(4, f32), @splat(0))) };
//         comptime var row: u32 = 0;
//         inline while (row < 4) : (row += 1) {
//           const vx = swizzle4(mat.data[row], .x, .x, .x, .x);
//           const vy = swizzle4(mat.data[row], .y, .y, .y, .y);
//           const vz = swizzle4(mat.data[row], .z, .z, .z, .z);
//           const vw = swizzle4(mat.data[row], .w, .w, .w, .w);
//           tmp.data[row] = mulAdd(vx, b.data[0], vz * b.data[2]) + mulAdd(vy, b.data[1], vw * b.data[3]);
//         }
//         break :matmul tmp;
//       },
//       f32 => scalarmul: {
//         var tmp: Matrix = mat.*;
//         const scalar_vec: @Vector(4, f32) = @splat(b);
//
//         comptime var row: u32 = 0;
//         inline while (row < 4) : (row += 1) {
//           tmp[row] *= scalar_vec;
//         }
//
//         break :scalarmul tmp;
//       },
//       Vec4f32 => vecmul: {
//         break :vecmul @as(Vec4f32, .{
//           dot4(b, mat.data[0])[0],
//           dot4(b, mat.data[1])[0],
//           dot4(b, mat.data[2])[0],
//           dot4(b, mat.data[3])[0],
//         });
//       },
//       else => {
//         @compileError("Type " ++ @typeName(@TypeOf(b)) ++ " is not a valid multiplier type for type Matrix");
//       },
//     };
//
//     return result;
//   }
//
//   pub fn eql(noalias mat: *const Matrix, cmp: Matrix) bool {
//     const result = cmp: {
//       inline for (0..4) |idx| {
//         const res: bool = @reduce(.And, (mat.data[idx] == cmp.data[idx]));
//         if (!res) break :cmp false;
//       }
//       break :cmp true;
//     };
//
//     return result;
//   }
//
//   pub fn format(mat: *const Matrix, fmt: [:0]const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
//     _ = fmt;
//     _ = options;
//     comptime var idx: u8 = 0;
//     try writer.print("\n(", .{});
//     inline while (idx < 4) : (idx += 1) {
//       if (idx != 0) {
//         try writer.print(" ", .{});
//       }
//       const x, const y, const z, const w = mat.data[idx];
//       try writer.print("{c}: [ {d:.2}, {d:.2}, {d:.2}, {d:.2} ]", .{
//         'a' + idx,
//         x,
//         y,
//         z,
//         w,
//       });
//       if (idx != 3) {
//         try writer.print("\n", .{});
//       }
//     }
//     try writer.print(")", .{});
//   }
// };
//
// pub const Rng2f32 = rng_2_t(f32);
// pub const Rng2i32 = rng_2_t(i32);
//
// pub const Rng3f32 = rng_3_t(f32);
// pub const Rng3i32 = rng_3_t(i32);
//
// pub const Rectf32 = rect_t(f32);
// pub const Recti32 = rect_t(i32);
//
// // pub const Vec2f32 = @Vector(2, f32);
// pub const Vec2i32 = @Vector(2, i32);
// pub const Vec2f32 = packed union {
//   vec: @Vector(2, f32),
// };
//
// pub const Vec3f32 = @Vector(3, f32);
// pub const Vec3i32 = @Vector(3, i32);
// pub const Vec4f32 = @Vector(4, f32);
// pub const Vec4i32 = @Vector(4, i32);

pub fn eql(a: anytype, b: anytype) bool {
  const Type = @TypeOf(a);
  const result: bool = if (@TypeOf(a) == @TypeOf(b)) cmp: {
    switch (@typeInfo(Type)) {
      .vector => {
        break :cmp @reduce(.And, (a == b));
      },
      .@"struct" => {
        if (!@hasDecl(Type, "eql")) {
          @compileError("No eql function provided in type: " ++ @typeName(Type));
        } else {
          break :cmp a.eql(b);
        }
      },
      else => {
        @compileError("Invalid math comparison type: " ++ @typeName(Type));
      },
    }
  } else false;

  return result;
}

// pub inline fn mulAdd(v0: anytype, v1: anytype, v2: anytype) @TypeOf(v0, v1, v2) {
//   const T = @TypeOf(v0, v1, v2);
//   if (cpu_arch == .x86_64 and has_avx and has_fma) {
//     return @mulAdd(T, v0, v1, v2);
//   } else {
//     return v0 * v1 + v2;
//   }
// }
//
// pub inline fn dot4(v0: Vec4f32, v1: Vec4f32) Vec4f32 {
//   var xmm0 = v0 * v1; // | x0*x1 | y0*y1 | z0*z1 | w0*w1 |
//   var xmm1 = swizzle4(xmm0, .y, .x, .w, .x); // | y0*y1 | -- | w0*w1 | -- |
//   xmm1 = xmm0 + xmm1; // | x0*x1 + y0*y1 | -- | z0*z1 + w0*w1 | -- |
//   xmm0 = swizzle4(xmm1, .z, .x, .x, .x); // | z0*z1 + w0*w1 | -- | -- | -- |
//   xmm0 = .{
//     xmm0[0] + xmm1[0],
//     xmm0[1],
//     xmm0[2],
//     xmm0[2],
//   }; // addss
//   return swizzle4(xmm0, .x, .x, .x, .x);
// }
//
// pub inline fn swizzle4(
//   v: Vec4f32,
//   comptime x: Vec4Component,
//   comptime y: Vec4Component,
//   comptime z: Vec4Component,
//   comptime w: Vec4Component,
// ) Vec4f32 {
//   return @shuffle(f32, v, undefined, [4]i32{ x.toInt(), y.toInt(), z.toInt(), w.toInt() });
// }
//
// pub inline fn swizzle3(
//   v: Vec3f32,
//   comptime x: Vec3Component,
//   comptime y: Vec3Component,
//   comptime z: Vec3Component,
// ) Vec3f32 {
//   return @shuffle(f32, v, undefined, [3]i32{ x.toInt(), y.toInt(), z.toInt() });
// }
//
// pub inline fn cross3(v0: Vec3f32, v1: Vec3f32) Vec3f32 {
//   const a_yzx = swizzle3(v0, .y, .z, .x);
//   const b_zxy = swizzle3(v1, .z, .x, .y);
//   const a_zxy = swizzle3(v0, .z, .x, .y);
//   const b_yzx = swizzle3(v1, .y, .z, .x);
//
//   return ((a_yzx * b_zxy) - (a_zxy * b_yzx));
// }
//
// pub inline fn dot(v0: anytype, v1: @TypeOf(v0)) f32 {
//   if (@typeInfo(@TypeOf(v0)) != .vector) @compileError("Cannot perform dot operation on non-vector type");
//
//   return @reduce(.Add, v0 * v1);
// }
//
// pub inline fn mag(vec: anytype) f32 {
//   return @sqrt(@reduce(.Add, (vec * vec)));
// }
//
// pub inline fn normalize(vec: anytype) @TypeOf(vec) {
//   if (@typeInfo(@TypeOf(vec)) != .vector) @compileError("Cannot normalize non-vector type");
//
//   const magnitude = mag(vec);
//   if (builtin.mode != .ReleaseFast) if (magnitude == 0) @panic("Cannot normalize Zero vector");
//
//   const mag_vec: @TypeOf(vec) = @splat((1 / magnitude));
//   return vec * mag_vec;
// }
//
// pub const Vec4Component = enum(u8) {
//   x = 0,
//   y = 1,
//   z = 2,
//   w = 3,
//
//   pub fn toInt(component: Vec4Component) i32 {
//     return @intCast(@intFromEnum(component));
//   }
// };
//
// pub const Vec3Component = enum(u8) {
//   x = 0,
//   y = 1,
//   z = 2,
//
//   pub fn toInt(component: Vec3Component) i32 {
//     return @intCast(@intFromEnum(component));
//   }
// };
//
// pub const Vec2Component = enum(u8) {
//   x = 0,
//   y = 1,
//
//   pub fn toInt(component: Vec2Component) i32 {
//     return @intCast(@intFromEnum(component));
//   }
// };
//
// fn rect_t(comptime T: type) type {
//   const Vec2_T = switch (@typeInfo(T)) {
//     .int => Vec2i32,
//     .float => Vec2f32,
//     else => @compileError(@typeName(T) ++ " is not a valid Rect child type"),
//   };
//
//   return struct {
//     x: T,
//     y: T,
//     w: T,
//     h: T,
//
//     const Rect_T = @This();
//
//     pub const zero: Rect_T = .{ .x = 0, .y = 0, .w = 0, .h = 0 };
//
//     pub fn init(x: T, y: T, w: T, h: T) Rect_T {
//       return .{ .x = x, .y = y, .w = w, .h = h };
//     }
//
//     pub fn contains_point(rect: *const Rect_T, point: Vec2_T) bool {
//       return ((rect.x <= point[0] and rect.x + rect.w >= point[0]) and
//         (rect.y <= point[1] and rect.y + rect.h >= point[1]));
//     }
//
//     pub fn toRectf32(rect: *const Rect_T) rect_t(f32) {
//       if (@typeInfo(T) == .float) {
//         return .{
//           .x = @floatCast(rect.x),
//           .y = @floatCast(rect.y),
//           .w = @floatCast(rect.w),
//           .h = @floatCast(rect.h),
//         };
//       } else {
//         return .{
//           .x = @floatFromInt(rect.x),
//           .y = @floatFromInt(rect.y),
//           .w = @floatFromInt(rect.w),
//           .h = @floatFromInt(rect.h),
//         };
//       }
//     }
//
//     pub fn toRecti32(rect: *const Rect_T) rect_t(f32) {
//       if (@typeInfo(T) == .int) {
//         return .{
//           .x = @intCast(rect.x),
//           .y = @intCast(rect.y),
//           .w = @intCast(rect.w),
//           .h = @intCast(rect.h),
//         };
//       } else {
//         return .{
//           .x = @intFromFloat(rect.x),
//           .y = @intFromFloat(rect.y),
//           .w = @intFromFloat(rect.w),
//           .h = @intFromFloat(rect.h),
//         };
//       }
//     }
//   };
// }
//
//
//
// fn rng_2_t(comptime T: type) type {
//   const Vec2_T = switch (@typeInfo(T)) {
//     .int => Vec2i32,
//     .float => Vec2f32,
//     else => @compileError(@typeName(T) ++ " is not a valid Rng2 child type"),
//   };
//   return struct {
//     data: @Vector(4, T),
//
//     const Rng2_T = @This();
//     const Rect_T = rect_t(T);
//
//     pub const zero: Rng2_T = .{ .data = .{ 0, 0, 0, 0 } };
//
//     pub fn init(@"0": T, @"1": T, @"2": T, @"3": T) Rng2_T {
//       return .{ .data = .{ @"0", @"1", @"2", @"3" } };
//     }
//
//     pub fn v(rng: *const Rng2_T) @Vector(4, T) {
//       return rng.data;
//     }
//
//     pub fn v_ptr(rng: *Rng2_T) *@Vector(4, T) {
//       return &rng.data;
//     }
//
//     pub fn p0(rng: *const Rng2_T) Vec2_T {
//       return .{
//         .x = rng.data[0],
//         .y = rng.data[1],
//       };
//     }
//
//     pub fn p1(rng: *const Rng2_T) Vec2_T {
//       return .{
//         .x = rng.data[2],
//         .y = rng.data[3],
//       };
//     }
//
//     pub fn rect(rng: *const Rng2_T) Rect_T {
//       return .{
//         .x = rng.data[0],
//         .y = rng.data[1],
//         .w = rng.data[2],
//         .h = rng.data[3],
//       };
//     }
//
//     pub fn to_rect(rng: *const Rng2_T) Rect_T {
//       return .{
//         .x = rng.data[0],
//         .y = rng.data[1],
//         .w = rng.data[2] - rng.data[0],
//         .h = rng.data[3] - rng.data[1],
//       };
//     }
//
//     pub fn area(rng: *const Rng2_T) T {
//       return ((rng.data[2] - rng.data[0]) * (rng.data[3] - rng.data[1]));
//     }
//
//     pub fn overlaps(rng: *const Rng2_T, cmp: *const Rng2_T) bool {
//       return ((true) and
//         (rng.data[0] <= cmp.data[2]) and // rng.x_min <= cmp.x_max
//         (rng.data[2] >= cmp.data[0]) and // rng.x_max >= cmp.x_min
//         (rng.data[1] <= cmp.data[3]) and // rng.y_min <= cmp.y_max
//         (rng.data[3] >= cmp.data[1])); //   rng.y_max <= cmp.y_min
//     }
//
//     pub fn contains(rng: *const Rng2_T, point: Vec2_T) bool {
//       return ((point[0] >= rng.data[0] and
//         point[0] <= rng.data[2]) and
//         (point[1] >= rng.data[1] and
//           point[1] <= rng.data[3]));
//     }
//
//     pub fn eql(rng: *const Rng2_T, cmp: Rng2_T) bool {
//       return @reduce(.And, (rng.data == cmp.data));
//     }
//   };
// }
//
// fn rng_3_t(comptime T: type) type {
//   const Vec3_T = switch (@typeInfo(T)) {
//     .int => Vec3i32,
//     .float => Vec3f32,
//     else => @compileError(@typeName(T) ++ " is not a valid Rng2 child type"),
//   };
//
//   return struct {
//     data: Vec_T,
//
//     const Vec_T = @Vector(6, T);
//
//     const Rng3_T = @This();
//
//     pub const zero: Rng3_T = .{ .data = @splat(0) };
//
//     pub fn init(@"0": T, @"1": T, @"2": T, @"3": T, @"4": T, @"5": T) Rng3_T {
//       return .{ .data = .{ @"0", @"1", @"2", @"3", @"4", @"5" } };
//     }
//
//     pub fn v(rng: *const Rng3_T) Vec_T {
//       return rng.data;
//     }
//
//     pub fn v_ptr(rng: *Rng3_T) *Vec_T {
//       return &rng.data;
//     }
//
//     pub fn p0(rng: *const Rng3_T) Vec3_T {
//       return .{
//         .x = rng.data[0],
//         .y = rng.data[1],
//         .z = rng.data[2],
//       };
//     }
//
//     pub fn p1(rng: *const Rng3_T) Vec3_T {
//       return .{
//         .x = rng.data[3],
//         .y = rng.data[4],
//         .z = rng.data[5],
//       };
//     }
//   };
// }

// --- STD CONST ALIASES ---
const math = std.math;
pub const tau = math.tau;
pub const pi = math.pi;

// --- STD FN ALIASES ---
pub const cos = math.cos;
pub const sin = math.sin;
pub const tan = math.tan;
pub const inf = math.inf;
pub const pow = math.pow;
pub const sqrt = math.sqrt;
pub const maxInt = math.maxInt;
pub const maxFloat = math.floatMax;
pub const degToRad = math.degreesToRadians;
pub const radToDeg = math.radiansToDegrees;

const log = std.log.scoped(.Math);

const cpu_arch = builtin.cpu.arch;
const has_avx = if (cpu_arch == .x86_64) std.Target.x86.featureSetHas(builtin.cpu.features, .avx) else false;
const has_avx512f = if (cpu_arch == .x86_64) std.Target.x86.featureSetHas(builtin.cpu.features, .avx512f) else false;
const has_fma = if (cpu_arch == .x86_64) std.Target.x86.featureSetHas(builtin.cpu.features, .fma) else false;

const base = @import("base.zig");

// 3rd-Party Imports
const std = @import("std");
const builtin = @import("builtin");
