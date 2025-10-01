const std = @import("std");
const math = @import("math");
pub const Image = []Pixel;

pub const Pixel = u32;
pub const Color = packed struct (u32) {
    b: u8 = 0,
    g: u8 = 0,
    r: u8 = 0,
    a: u8 = 0,

    pub const red: Color = .{
         .r = 255,
         .a = 255,
    };
    pub const blue: Color = .{
         .b = 255,
         .a = 255,
    };
    pub const green: Color = .{
         .g = 255,
         .a = 255,
    };
    pub const yellow: Color = .{
        .r = 255,
        .g = 255,
        .a = 255,
    };
};

pub const Viewport = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
};

pub const Canvas = struct {
    width: i32,
    height: i32,
};

pub const Position = Vec3f32;
pub const Sphere = struct {
    center: Position,
    radius: f32,
    color: Color,
};

pub const Vertex = packed struct {
    pos: Position,
    col: Color,
};

pub fn canvas_to_viewport(noalias vp: *const Viewport, noalias canvas: *const Canvas, x: i32, y: i32, proj_z: f32) Position {
    const fx: f32 = @floatFromInt(x);
    const fy: f32 = @floatFromInt(y);
    const vw: f32 = @floatFromInt(vp.width);
    const vh: f32 = @floatFromInt(vp.height);
    const cw: f32 = @floatFromInt(canvas.width);
    const ch: f32 = @floatFromInt(canvas.height);

    const vx: f32 = fx * (vw / cw);
    const vy: f32 = fy * (vh / ch);

    return .{
        vx,
        vy,
        proj_z,
    };
}

pub fn intersect_ray_sphere(origin: Position, direction: Vec3f32, sphere: Sphere) Vec2f32 {
    const oc = origin - sphere.center;

    const k1: f32 = math.dot(direction, direction);
    const k2: f32 = 2 * math.dot(oc, direction);
    const k3: f32 = math.dot(oc, oc) - (sphere.radius * sphere.radius);

    const discriminant = (k2 * k2) - (4 * k1 * k3);
    if (discriminant < 0) {
        return @splat(1000);
    }

    const t1 = (-k2 + math.sqrt(discriminant)) / (2 * k1);
    const t2 = (-k2 - math.sqrt(discriminant)) / (2 * k1);

    return .{ t1, t2 };
}

pub fn trace_ray(origin: Vec3f32, direction: Vec3f32, spheres: []const Sphere, min_t: f32, max_t: f32) ?Color {
    var closest_t: f32 = max_t;
    var closest_sphere: ?Sphere = null;

    for (spheres) |sphere| {
        const ts = intersect_ray_sphere(origin, direction, sphere);
        if (ts[0] < closest_t and min_t < ts[0] and ts[0] < max_t) {
            closest_t = ts[0];
            closest_sphere = sphere;
        }
        if (ts[1] < closest_t and min_t < ts[1] and ts[1] < max_t) {
            closest_t = ts[1];
            closest_sphere = sphere;
        }
    }

    const sphere = closest_sphere orelse return null;
    return sphere.color;
}
pub const Vec2f32 = math.Vec2f32;
pub const Vec3f32 = math.Vec3f32;
