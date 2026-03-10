//-----------------------------------------------------------------------------
// Type & Cast Macros
//-----------------------------------------------------------------------------

#define S static

#define F1 float
#define F2 float2
#define F3 float3
#define F4 float4

#define L1 uint64_t

#define I1 uint
#define I2 uint2
#define I3 uint3
#define I4 uint4

#define S1 int

#define F1_(x) (F1)(x)
#define F2_(x) (F2)(x)
#define F3_(x) (F3)(x)
#define F4_(x) (F4)(x)

#define L1_(x) (L1)(x)
#define I1_(x) (I1)(x)
#define I2_(x) (I2)(x)
#define I3_(x) (I3)(x)
#define I4_(x) (I4)(x)

//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Key Inputs
//-----------------------------------------------------------------------------

#define KEY_0         (L1_(1) <<  0)
#define KEY_1         (L1_(1) <<  2)
#define KEY_2         (L1_(1) <<  2)
#define KEY_3         (L1_(1) <<  3)
#define KEY_4         (L1_(1) <<  4)
#define KEY_5         (L1_(1) <<  5)
#define KEY_6         (L1_(1) <<  6)
#define KEY_7         (L1_(1) <<  7)
#define KEY_8         (L1_(1) <<  8)
#define KEY_9         (L1_(1) <<  9)
#define KEY_A         (L1_(1) << 10)
#define KEY_B         (L1_(1) << 11)
#define KEY_C         (L1_(1) << 12)
#define KEY_D         (L1_(1) << 13)
#define KEY_E         (L1_(1) << 14)
#define KEY_F         (L1_(1) << 15)
#define KEY_G         (L1_(1) << 16)
#define KEY_H         (L1_(1) << 17)
#define KEY_I         (L1_(1) << 18)
#define KEY_J         (L1_(1) << 19)
#define KEY_K         (L1_(1) << 20)
#define KEY_L         (L1_(1) << 21)
#define KEY_M         (L1_(1) << 22)
#define KEY_N         (L1_(1) << 23)
#define KEY_O         (L1_(1) << 24)
#define KEY_P         (L1_(1) << 25)
#define KEY_Q         (L1_(1) << 26)
#define KEY_R         (L1_(1) << 27)
#define KEY_S         (L1_(1) << 28)
#define KEY_T         (L1_(1) << 29)
#define KEY_U         (L1_(1) << 30)
#define KEY_V         (L1_(1) << 31)
#define KEY_W         (L1_(1) << 32)
#define KEY_X         (L1_(1) << 33)
#define KEY_Y         (L1_(1) << 34)
#define KEY_Z         (L1_(1) << 35)
#define KEY_SPACE     (L1_(1) << 36)
#define KEY_ESC       (L1_(1) << 37)
#define KEY_ENTER     (L1_(1) << 38)
#define KEY_TAB       (L1_(1) << 39)
#define KEY_BACKSPACE (L1_(1) << 40)
#define KEY_RIGHT     (L1_(1) << 41)
#define KEY_LEFT      (L1_(1) << 42)
#define KEY_UP        (L1_(1) << 43)
#define KEY_DOWN      (L1_(1) << 44)
#define KEY_SHIFT     (L1_(1) << 45)
#define KEY_ALT       (L1_(1) << 46)
#define KEY_CTRL      (L1_(1) << 47)
#define KEY_SUPER     (L1_(1) << 48)
#define KEY_F1        (L1_(1) << 49)
#define KEY_F2        (L1_(1) << 50)
#define KEY_F3        (L1_(1) << 51)
#define KEY_F4        (L1_(1) << 52)
#define KEY_F5        (L1_(1) << 53)
#define KEY_F6        (L1_(1) << 54)
#define KEY_F7        (L1_(1) << 55)
#define KEY_F8        (L1_(1) << 56)
#define KEY_F9        (L1_(1) << 57)
#define KEY_F10       (L1_(1) << 58)
#define KEY_F11       (L1_(1) << 59)
#define KEY_F12       (L1_(1) << 60)

//-----------------------------------------------------------------------------

struct Globals {
  F3 color;
  F1 time;
  F2 resolution;
};

struct Camera {
  F3 position;
  F3 target;
};

struct Box {
  F4 color;
  F3 center, size;
};

struct Sphere {
  F4 color;
  F3 center;
  F1 radius;
};

struct SdfResult {
  F1 dist;
  F3 color;
};

struct GpuScene {
  Sphere sphere;
  Box box;
  Camera camera;
};

struct InputPacket {
  I1 packet_hash;
  F1 mouse_x;
  F1 mouse_y;
  I1 cpu_time_lo;
  I1 cpu_time_hi;
  I1 key_arr_lo;
  I1 key_arr_hi;
  I1 resolution_xy;
};

//-----------------------------------------------------------------------------
// Vulkan Bindings
//-----------------------------------------------------------------------------

[[vk::binding(1,0)]]
ConstantBuffer<Globals> globals;

[[vk::binding(2,0)]]
RWStructuredBuffer<GpuScene> scene;

[[vk::binding(3,0)]]
ConstantBuffer<InputPacket[2]> input_packet;

//-----------------------------------------------------------------------------

F1 sdf_Box(F3 p, F3 center, F3 size) {
  F3 q = abs(p - center) - size;
  return length(max(q, 0.0)) + min(max(q.x, max(q.y,q.z)), 0.0);
}

F1 sdf_Sphere(F3 p, F3 center, F1 r) {
  return length(p - center) - r;
}

F2 coord_to_uv(F2 coord, I1 width, I1 height) {
  F1 aspect_ratio = F1_(width) / F1_(height);
  F2 normalized_coords = ((coord / F2(F1_(width), F1_(height))) * 2 ) - 1;
  normalized_coords.y *= -1;

  return normalized_coords * F2(aspect_ratio, 1);
}

SdfResult sdf_scene(F3 point, F3 ground_color) {
  F1 ground_dist = max(point.y + 0.5, length(point.xz) - 8.0);

  F1 sphere_dist =
    sdf_Sphere( point, scene[0].sphere.center, scene[0].sphere.radius);
  F1 box_dist = sdf_Box(point, scene[0].box.center, scene[0].box.size);
  F2 sm = smin_col(sphere_dist, box_dist, 0.4); // smin = blended edge
  F3 shape_color =
    lerp(scene[0].sphere.color.rgb, scene[0].box.color.rgb, sm.y);

  F1 final_dist = min(sm.x, ground_dist); // min = hard edge
  F3 final_color = sm.x < ground_dist ? shape_color : ground_color;

  return {
    final_dist,
    final_color,
  };
}

// polynomial smin
F2 smin_col(F1 a, F1 b, F1 k) {
  F1 h = max(k - abs(a - b), 0.0) / k;
  F1 m = h * h * 0.5;
  F1 s = m * k * 0.5;
  return ( a < b) ? F2(a - s, m) : F2(b - s, 1.0 - m);
}

// exponential smin
F1 smin(F1 a, F1 b, F1 k) {
  return -log(exp(-k * a) + exp(-k * b)) / k;
}

//-----------------------------------------------------------------------------
// Input Packet Processing
//-----------------------------------------------------------------------------
bool input_packet_valid(I1 idx) {
  I1 hash = 0x55555555;

  hash ^= I1_(input_packet[idx].mouse_x);
  hash ^= I1_(input_packet[idx].mouse_y);
  hash ^= I1_(input_packet[idx].cpu_time_lo);
  hash ^= I1_(input_packet[idx].cpu_time_hi);
  hash ^= I1_(input_packet[idx].key_arr_lo);
  hash ^= I1_(input_packet[idx].key_arr_hi);
  hash ^= I1_(input_packet[idx].resolution_xy);

  return (hash == input_packet[idx].packet_hash);
}

bool keyPressed(I1 packet_idx, L1 key) {
  return (key >= (L1_(1) << 31)) ?
      ((input_packet[packet_idx].key_arr_hi & I1_(key >> 32)) != 0)
    : ((input_packet[packet_idx].key_arr_lo & I1_(key)) != 0);
}
//-----------------------------------------------------------------------------

S const I1 marchMaxSteps = 64;

[shader("compute")]
[numthreads(16, 16, 1)]
void compMain(
  I3 threadId: SV_DispatchThreadID,
  uniform RWTexture2D<F4> outputImage,
) {
  //---------------------------------------------------------------------------
  // General Init Section
  //---------------------------------------------------------------------------

  I1 width, height;
  outputImage.GetDimensions(width, height);
  if (threadId.x >= width || threadId.y >= height)
    return;

  // F4 bg_color = F4(F3(1), 1);
  // F4 bg_color = float4(globals.color.r, globals.color.g, globals.color.b, 1);

  // UV Resolution
  F2 uv = coord_to_uv(F2(threadId.x, threadId.y), width, height);
  // F3 camera = F3(sin(globals.time), 1.2, -3 + cos(globals.time));
  F3 camera = scene[0].camera.position;
  F3 target = scene[0].camera.target;
  F3 forward = normalize(target - camera);
  F3 right = normalize(cross(forward, F3(0, 1, 0)));
  F3 up = cross(right, forward);
  F3 rd = normalize(uv.x * right + uv.y * up + 1.5 * forward);
  F3 ro = scene[0].camera.position;

  F4 bg_color = F4(
    lerp(F3(0.6, 0.7, 0.9),
    F3(1.0, 1.0, 1.0),
    clamp(rd.y * 2.0, 0.0, 1.0)),
    1.0,
  );
  F3 ground_color = F3(0.8, 0.8, 0.8);

  F4 col_mod = F4(1, 1, 1, 1);
  if ((threadId.y % 4) == 0) {
    col_mod = F4(F3(0.8), 1);
  }

  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // Input Processing
  //---------------------------------------------------------------------------

  if (input_packet_valid(0)) {
    if (keyPressed(0, KEY_R)) {
      ground_color = F3(1, 0, 0);
    }

    F1 mov = 0.01 / (16 * 16 * 1);
    if (keyPressed(0, KEY_W) || keyPressed(0, KEY_UP)) {
      scene[0].camera.position.z += mov;
    }
    if (keyPressed(0, KEY_S) || keyPressed(0, KEY_DOWN)) {
      scene[0].camera.position.z -= mov;
    }
    if (keyPressed(0, KEY_LEFT)) {
      scene[0].camera.position.x -= mov;
    }
    if (keyPressed(0, KEY_RIGHT)) {
      scene[0].camera.position.x += mov;
    }
  }

  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // SDF Scene Ray March
  //---------------------------------------------------------------------------

  F4 color = bg_color;
  F3 sdf_color = F3(0);
  F1 t = 0.0;
  for (I1 i=0;i<marchMaxSteps;++i) {
    SdfResult res = sdf_scene(ro + rd * t, ground_color);
    if (res.dist < 0.001) { sdf_color = res.color; break; }
    t += res.dist;
    if (t > 100) { t = -1.0; break; }
  }

  if (t>0) {
    F3 hit = ro + rd * t;

    // Normal Calculation
    F1 e = 0.001; // error step?
    F3 normal = normalize(F3(
      sdf_scene(hit + F3(e,0,0), ground_color).dist - sdf_scene(hit - F3(e,0,0), ground_color).dist,
      sdf_scene(hit + F3(0,e,0), ground_color).dist - sdf_scene(hit - F3(0,e,0), ground_color).dist,
      sdf_scene(hit + F3(0,0,e), ground_color).dist - sdf_scene(hit - F3(0,0,e), ground_color).dist,
    ));

    F3 light = normalize(F3(0.5, 1, -1));
    F1 diffuse = max(dot(normal, light), 0.0);
    F1 ambient = 0.5;

    // Shadow Calculation
    F1 shadow = 1.0;
    F3 shadow_ro = hit + normal * 0.01;
    F3 shadow_rd = light;
    F1 st = 0.0;
    for (I1 i=0;i<marchMaxSteps/2;++i) {
      F1 d = sdf_scene(shadow_ro + shadow_rd * st, ground_color).dist;
      if (d < 0.001) { shadow = 0.0; break; }
      st += d;
      if (st > 10.0) { break; }
    }

    // Ambient Occlusion
    F1 ao = 0.0;
    F1 ao_step = 0.1;
    for (I1 i=1;i<3;++i) {
      F1 d = sdf_scene(hit + normal * ao_step * F1_(i), ground_color).dist;
      ao += max(0.0, ao_step * F1_(i) - d);
    }
    ao = 1.0 - clamp(ao * 2, 0, 1);

    F1 spec = pow(max(dot(reflect(-light, normal), -rd), 0.0), 20.0);
    color = F4( spec + ((diffuse * shadow + ambient * ao) * sdf_color), 1);
  }

  //---------------------------------------------------------------------------
  // Final Output
  //---------------------------------------------------------------------------

  outputImage[threadId.xy] = color * col_mod;

  //---------------------------------------------------------------------------
}

S const I1 kMaxIter = 1024;
I1 mandelbrot(inout F2 z, F1 time) {
  const F2 c = z;
  for (I1 i = 0; i < kMaxIter; i++) {
    if (dot(z,z) > 256) return i;
    z = F2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y)
        // + c;
        + sin(time+c);
  }
  return kMaxIter;
}

F3 mandelbrot_color(F2 uv){
  I1 i = mandelbrot(uv, globals.time);
  F3 color = F3(0.0);
  if (i != kMaxIter) {
    color = 0.5 + 0.5 * sin(i + globals.time + F3(0, 0.5, 1)
                              -log2(log2(dot(uv, uv))));
  }
  return color;
}

F3 rot3D(F3 point, F3 axis, F1 angle) {
  return lerp(dot(axis, point) * axis, point, cos(angle))
         + cross(axis, point) * sin(angle);
}

