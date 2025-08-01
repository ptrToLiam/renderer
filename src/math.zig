// Copyright (c) Liam Malone. All rights reserved.

const std = @import("std");

pub const Rng2f32 = rng_2_t(f32);
pub const Rng2i32 = rng_2_t(i32);
pub const Rng3f32 = rng_3_t(f32);
pub const Rng3i32 = rng_3_t(i32);

pub const Rectf32 = rect_t(f32);
pub const Recti32 = rect_t(i32);

pub const Vec2f32 = vec2_t(f32);
pub const Vec2i32 = vec2_t(i32);
pub const Vec3f32 = vec3_t(f32);
pub const Vec3i32 = vec3_t(i32);
pub const Vec4f32 = vec4_t(f32);
pub const Vec4i32 = vec4_t(i32);

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

fn rect_t(comptime T: type) type {
    switch (@typeInfo(T)) {
        .int, .float => {},
        else => @compileError(@typeName(T) ++ " is not a valid Rect child type"),
    }

    return struct {
        x: T,
        y: T,
        w: T,
        h: T,

        const Rect_T = @This();

        pub const zero: Rect_T = .{ .x = 0, .y = 0, .w = 0, .h = 0 };

        pub fn init(x: T, y: T, w: T, h: T) Rect_T {
            return .{ .x = x, .y = y, .w = w, .h = h };
        }

        pub fn contains_point(rect: *const Rect_T, point: vec2_t(T)) bool {
            return ((rect.x <= point.x and rect.x + rect.w >= point.x) and
                (rect.y <= point.y and rect.y + rect.h >= point.y));
        }

        pub fn toRectf32(rect: *const Rect_T) rect_t(f32) {
            if (@typeInfo(T) == .float) {
                return .{
                    .x = @floatCast(rect.x),
                    .y = @floatCast(rect.y),
                    .w = @floatCast(rect.w),
                    .h = @floatCast(rect.h),
                };
            } else {
                return .{
                    .x = @floatFromInt(rect.x),
                    .y = @floatFromInt(rect.y),
                    .w = @floatFromInt(rect.w),
                    .h = @floatFromInt(rect.h),
                };
            }
        }

        pub fn toRecti32(rect: *const Rect_T) rect_t(f32) {
            if (@typeInfo(T) == .int) {
                return .{
                    .x = @intCast(rect.x),
                    .y = @intCast(rect.y),
                    .w = @intCast(rect.w),
                    .h = @intCast(rect.h),
                };
            } else {
                return .{
                    .x = @intFromFloat(rect.x),
                    .y = @intFromFloat(rect.y),
                    .w = @intFromFloat(rect.w),
                    .h = @intFromFloat(rect.h),
                };
            }
        }
    };
}

fn vec2_t(comptime T: type) type {
    switch (@typeInfo(T)) {
        .int, .float => {},
        else => @compileError(@typeName(T) ++ " is not a valid Vector2 child type"),
    }
    return struct {
        x: T,
        y: T,

        const Vec2_T = @This();
        pub const zero: Vec2_T = .{ .x = 0, .y = 0 };

        pub fn eql(a: *const Vec2_T, b: Vec2_T) bool {
            return (a.x == b.x and a.y == b.y);
        }
    };
}

fn vec3_t(comptime T: type) type {
    switch (@typeInfo(T)) {
        .int, .float => {},
        else => @compileError(@typeName(T) ++ " is not a valid Vector2 child type"),
    }
    return struct {
        x: T,
        y: T,
        z: T,

        const Vec3_T = @This();
        pub const zero: Vec3_T = .{ .x = 0, .y = 0, .z = 0 };

        pub fn eql(a: *const Vec3_T, b: Vec3_T) bool {
            return (a.x == b.x and a.y == b.y and a.z == b.z);
        }
    };
}

fn vec4_t(comptime T: type) type {
    switch (@typeInfo(T)) {
        .int, .float => {},
        else => @compileError(@typeName(T) ++ " is not a valid Vector2 child type"),
    }
    return struct {
        x: T,
        y: T,
        z: T,
        w: T,

        const Vec4_T = @This();
        pub const zero: Vec4_T = .{ .x = 0, .y = 0, .z = 0, .w = 0 };

        pub fn eql(a: *const Vec4_T, b: Vec4_T) bool {
            return (a.x == b.x and a.y == b.y and a.z == b.z and a.w == b.w);
        }
    };
}

fn rng_2_t(comptime T: type) type {
    switch (@typeInfo(T)) {
        .int, .float => {},
        else => @compileError(@typeName(T) ++ " is not a valid Rng2 child type"),
    }
    return struct {
        data: @Vector(4, T),

        const Rng2_T = @This();
        const Vec2_T = vec2_t(T);
        const Rect_T = rect_t(T);

        pub const zero: Rng2_T = .{ .data = .{ 0, 0, 0, 0 } };

        pub fn init(@"0": T, @"1": T, @"2": T, @"3": T) Rng2_T {
            return .{ .data = .{ @"0", @"1", @"2", @"3" } };
        }

        pub fn v(rng: *const Rng2_T) @Vector(4, T) {
            return rng.data;
        }

        pub fn v_ptr(rng: *Rng2_T) *@Vector(4, T) {
            return &rng.data;
        }

        pub fn p0(rng: *const Rng2_T) Vec2_T {
            return .{
                .x = rng.data[0],
                .y = rng.data[1],
            };
        }

        pub fn p1(rng: *const Rng2_T) Vec2_T {
            return .{
                .x = rng.data[2],
                .y = rng.data[3],
            };
        }

        pub fn rect(rng: *const Rng2_T) Rect_T {
            return .{
                .x = rng.data[0],
                .y = rng.data[1],
                .w = rng.data[2],
                .h = rng.data[3],
            };
        }

        pub fn to_rect(rng: *const Rng2_T) Rect_T {
            return .{
                .x = rng.data[0],
                .y = rng.data[1],
                .w = rng.data[2] - rng.data[0],
                .h = rng.data[3] - rng.data[1],
            };
        }

        pub fn area(rng: *const Rng2_T) T {
            return ((rng.data[2] - rng.data[0]) * (rng.data[3] - rng.data[1]));
        }

        pub fn overlaps(rng: *const Rng2_T, cmp: *const Rng2_T) bool {
            return ((true) and
                (rng.data[0] <= cmp.data[2]) and // rng.x_min <= cmp.x_max
                (rng.data[2] >= cmp.data[0]) and // rng.x_max >= cmp.x_min
                (rng.data[1] <= cmp.data[3]) and // rng.y_min <= cmp.y_max
                (rng.data[3] >= cmp.data[1])); //   rng.y_max <= cmp.y_min
        }

        pub fn contains(rng: *const Rng2_T, point: Vec2_T) bool {
            return ((point.x >= rng.data[0] and
                point.x <= rng.data[2]) and
                (point.y >= rng.data[1] and
                    point.y <= rng.data[3]));
        }

        pub fn eql(rng: *const Rng2_T, cmp: *const Rng2_T) bool {
            return @reduce(.And, (rng.data == cmp.data));
        }
    };
}

fn rng_3_t(comptime T: type) type {
    switch (@typeInfo(T)) {
        .int, .float => {},
        else => @compileError(@typeName(T) ++ " is not a valid Rng2 child type"),
    }
    return struct {
        data: Vec_T,

        const Vec_T = @Vector(6, T);

        const Rng3_T = @This();
        const Vec3_T = vec3_t(T);

        pub const zero: Rng3_T = .{ .data = @splat(0) };

        pub fn init(@"0": T, @"1": T, @"2": T, @"3": T, @"4": T, @"5": T) Rng3_T {
            return .{ .data = .{ @"0", @"1", @"2", @"3", @"4", @"5" } };
        }

        pub fn v(rng: *const Rng3_T) Vec_T {
            return rng.data;
        }

        pub fn v_ptr(rng: *Rng3_T) *Vec_T {
            return &rng.data;
        }

        pub fn p0(rng: *const Rng3_T) Vec3_T {
            return .{
                .x = rng.data[0],
                .y = rng.data[1],
                .z = rng.data[2],
            };
        }

        pub fn p1(rng: *const Rng3_T) Vec3_T {
            return .{
                .x = rng.data[3],
                .y = rng.data[4],
                .z = rng.data[5],
            };
        }
    };
}

// --- STD CONST ALIASES ---
const math = std.math;
pub const tau = math.tau;
pub const pi = math.pi;

// --- STD FN ALIASES ---
pub const cos = math.cos;
pub const sin = math.sin;
pub const maxInt = math.maxInt;
pub const maxFloat = math.floatMax;

const log = std.log.scoped(.MATH);
