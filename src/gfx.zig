const std = @import("std");
const math = @import("math");
pub const Image = []Pixel;

pub const Pixel = u32;
pub const Color = packed struct(u32) {
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

pub fn trace_ray_vectorized(origin: Vec3f32, direction: Vec3f32, spheres: []const Sphere, min_t: f32, max_t: f32) ?Color {
    const min_ts: @Vector(4, f32) = @splat(min_t);
    const max_ts: @Vector(4, f32) = @splat(max_t);

    const colors: @Vector(4, u32) = .{
        @bitCast(spheres[0].color),
        @bitCast(spheres[1].color),
        @bitCast(spheres[2].color),
        @bitCast(spheres[3].color),
    };

    const ox_vec: @Vector(4, f32) = @splat(origin[0]);
    const oy_vec: @Vector(4, f32) = @splat(origin[1]);
    const oz_vec: @Vector(4, f32) = @splat(origin[2]);
    const dx_vec: @Vector(4, f32) = @splat(direction[0]);
    const dy_vec: @Vector(4, f32) = @splat(direction[1]);
    const dz_vec: @Vector(4, f32) = @splat(direction[2]);

    const sx_vec: @Vector(4, f32) = .{
        spheres[0].center[0],
        spheres[1].center[0],
        spheres[2].center[0],
        spheres[3].center[0],
    };
    const sy_vec: @Vector(4, f32) = .{
        spheres[0].center[1],
        spheres[1].center[1],
        spheres[2].center[1],
        spheres[3].center[1],
    };
    const sz_vec: @Vector(4, f32) = .{
        spheres[0].center[2],
        spheres[1].center[2],
        spheres[2].center[2],
        spheres[3].center[2],
    };
    const radii_vec: @Vector(4, f32) = .{
        spheres[0].radius,
        spheres[1].radius,
        spheres[2].radius,
        spheres[3].radius,
    };

    const ocx = ox_vec - sx_vec;
    const ocy = oy_vec - sy_vec;
    const ocz = oz_vec - sz_vec;

    const k1s: @Vector(4, f32) = @splat(math.dot(direction, direction));
    const k2s = (@as(@Vector(4, f32), @splat(2)) *
        ((ocx * dx_vec) + (ocy * dy_vec) + (ocz * dz_vec)));
    const k3s = (((ocx * ocx) + (ocy * ocy) + (ocz * ocz)) - (radii_vec * radii_vec));

    const discriminants = ((k2s * k2s) -
        (@as(@Vector(4, f32), @splat(4))) * k1s * k3s);
    const disc_mask = discriminants >= @as(@Vector(4, f32), (@splat(0)));

    const disc_sqrts = @sqrt(
        @select(
            f32,
            disc_mask,
            discriminants,
            @as(@Vector(4, f32), @splat(0)),
        ),
    );

    const denoms = @as(@Vector(4, f32), @splat(2)) * k1s;

    var t1s: @Vector(4, f32) = (-k2s + disc_sqrts) / denoms;
    var t2s: @Vector(4, f32) = (-k2s - disc_sqrts) / denoms;

    const t1s_mask = disc_mask & (t1s >= min_ts) & (t1s <= max_ts);
    const t2s_mask = disc_mask & (t2s >= min_ts) & (t2s <= max_ts);

    t1s = @select(f32, t1s_mask, t1s, max_ts);
    t2s = @select(f32, t2s_mask, t2s, max_ts);

    const t_mins = @min(t1s, t2s);
    const t_min = @reduce(.Min, t_mins);

    if (t_min >= max_t or t_min <= min_t) return null;

    for (0..4) |idx| {
        if (t_mins[idx] == t_min) {
            return @bitCast(colors[idx]);
        }
    }
    unreachable;
}

pub fn trace_rays(
    len: comptime_int,
    origin: Vec3f32,
    bg_color: Color,
    dirx: @Vector(len, f32),
    diry: @Vector(len, f32),
    dirz: @Vector(len, f32),
    spheres: []const Sphere,
    min_t: f32,
    max_t: f32,
) @Vector(len, u32) {
    const VecF32 = @Vector(len, f32);
    const VecU32 = @Vector(len, u32);

    const max_ts: VecF32 = @splat(max_t);
    const min_ts: VecF32 = @splat(min_t);
    var min_t_vec: VecF32 = @splat(max_t);

    var colors: VecU32 = @splat(@bitCast(bg_color));
    for (spheres) |sphere| {
        const ocx: VecF32 = @splat(origin[0] - sphere.center[0]);
        const ocy: VecF32 = @splat(origin[1] - sphere.center[1]);
        const ocz: VecF32 = @splat(origin[2] - sphere.center[2]);

        const zeroes: VecF32 = @splat(0);
        const twos: VecF32 = @splat(2);
        const fours: VecF32 = @splat(4);
        const rads: VecF32 = @splat(sphere.radius);
        const cols: VecU32 = @splat(@bitCast(sphere.color));

        const k1s = (dirx * dirx) + (diry * diry) + (dirz * dirz);
        const k2s = twos * ((ocx * dirx) + (ocy * diry) + (ocz * dirz));
        const k3s = ((ocx * ocx) + (ocy * ocy) + (ocz * ocz)) - (rads * rads);

        const discriminants = (k2s * k2s) - (fours * k1s * k3s);
        const disc_mask = discriminants >= zeroes;

        const disc_sqrts = @sqrt(@select(
            f32,
            disc_mask,
            discriminants,
            zeroes,
        ));
        const denoms = twos * k1s;

        var t1s = (-k2s + disc_sqrts) / denoms;
        var t2s = (-k2s - disc_sqrts) / denoms;

        const t1s_mask = disc_mask & (t1s >= min_ts) & (t1s <= max_ts);
        const t2s_mask = disc_mask & (t2s >= min_ts) & (t2s <= max_ts);

        t1s = @select(f32, t1s_mask, t1s, max_ts);
        t2s = @select(f32, t2s_mask, t2s, max_ts);
        const t_mins = @min(t1s, t2s);

        const update_mask = (t_mins < min_t_vec) & ((t_mins > min_ts) & (t_mins < max_ts));
        min_t_vec = @select(f32, update_mask, t_mins, min_t_vec);

        colors = @select(u32, update_mask, cols, colors);
    }

    return colors;
}

pub const Vec2f32 = math.Vec2f32;
pub const Vec3f32 = math.Vec3f32;
