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
// General Constant Defines
//-----------------------------------------------------------------------------
#define US_PER_S 1000000
//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// Key Inputs
//-----------------------------------------------------------------------------

#define KEY_0         L1_( 0)
#define KEY_1         L1_( 1)
#define KEY_2         L1_( 2)
#define KEY_3         L1_( 3)
#define KEY_4         L1_( 4)
#define KEY_5         L1_( 5)
#define KEY_6         L1_( 6)
#define KEY_7         L1_( 7)
#define KEY_8         L1_( 8)
#define KEY_9         L1_( 9)
#define KEY_A         L1_(10)
#define KEY_B         L1_(11)
#define KEY_C         L1_(12)
#define KEY_D         L1_(13)
#define KEY_E         L1_(14)
#define KEY_F         L1_(15)
#define KEY_G         L1_(16)
#define KEY_H         L1_(17)
#define KEY_I         L1_(18)
#define KEY_J         L1_(19)
#define KEY_K         L1_(20)
#define KEY_L         L1_(21)
#define KEY_M         L1_(22)
#define KEY_N         L1_(23)
#define KEY_O         L1_(24)
#define KEY_P         L1_(25)
#define KEY_Q         L1_(26)
#define KEY_R         L1_(27)
#define KEY_S         L1_(28)
#define KEY_T         L1_(29)
#define KEY_U         L1_(30)
#define KEY_V         L1_(31)
#define KEY_W         L1_(32)
#define KEY_X         L1_(33)
#define KEY_Y         L1_(34)
#define KEY_Z         L1_(35)
#define KEY_SPACE     L1_(36)
#define KEY_ESC       L1_(37)
#define KEY_ENTER     L1_(38)
#define KEY_TAB       L1_(39)
#define KEY_BACKSPACE L1_(40)
#define KEY_RIGHT     L1_(41)
#define KEY_LEFT      L1_(42)
#define KEY_UP        L1_(43)
#define KEY_DOWN      L1_(44)
#define KEY_SHIFT     L1_(45)
#define KEY_ALT       L1_(46)
#define KEY_CTRL      L1_(47)
#define KEY_SUPER     L1_(48)
#define KEY_F1        L1_(49)
#define KEY_F2        L1_(50)
#define KEY_F3        L1_(51)
#define KEY_F4        L1_(52)
#define KEY_F5        L1_(53)
#define KEY_F6        L1_(54)
#define KEY_F7        L1_(55)
#define KEY_F8        L1_(56)
#define KEY_F9        L1_(57)
#define KEY_F10       L1_(58)
#define KEY_F11       L1_(59)
#define KEY_F12       L1_(60)

//-----------------------------------------------------------------------------

struct Globals {
  F3 color;
  F1 time;
  F2 resolution;
};

struct Camera {
  F3 position;
  F1 yaw;
  F1 pitch;
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
  I1 frame_idx;
  I1 __reserved_0;
  I1 __reserved_1;
  I1 __reserved_2;
  I1 __reserved_3;
  I1 __reserved_4;
  I1 __reserved_5;
  I1 __reserved_6;
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

SdfResult sdf_scene(F3 point, I1 fidx, F3 ground_color) {
  F1 ground_dist = max(point.y + 0.5, length(point.xz) - 8.0);

  F1 sphere_dist =
    sdf_Sphere( point, scene[fidx].sphere.center, scene[fidx].sphere.radius);
  F1 box_dist = sdf_Box(point, scene[fidx].box.center, scene[fidx].box.size);
  F2 sm = smin_col(sphere_dist, box_dist, 0.4); // smin = blended edge
  F3 shape_color =
    lerp(scene[fidx].sphere.color.rgb, scene[fidx].box.color.rgb, sm.y);

  F1 final_dist = smin(sm.x, ground_dist, 8); // min = hard edge
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

  hash ^= asuint(input_packet[idx].mouse_x);
  hash ^= asuint(input_packet[idx].mouse_y);
  hash ^= I1_(input_packet[idx].cpu_time_lo);
  hash ^= I1_(input_packet[idx].cpu_time_hi);
  hash ^= I1_(input_packet[idx].key_arr_lo);
  hash ^= I1_(input_packet[idx].key_arr_hi);
  hash ^= I1_(input_packet[idx].resolution_xy);
  hash ^= I1_(input_packet[idx].frame_idx);

  return (hash == input_packet[idx].packet_hash);
}

bool keyPressed(I1 packet_idx, L1 key) {
  I1 keys = (L1_(input_packet[packet_idx].key_arr_hi) << 32)
               | input_packet[packet_idx].key_arr_lo;
  return (keys & key) != 0;
  // return (key >= (L1_(1) << 31)) ?
  //     ((input_packet[packet_idx].key_arr_hi & I1_(key >> 32)) != 0)
  //   : ((input_packet[packet_idx].key_arr_lo & I1_(key)) != 0);
}
//-----------------------------------------------------------------------------

S const I1 marchMaxSteps = 128;

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

  //---------------------------------------------------------------------------
  // Input Packet Selection
  //---------------------------------------------------------------------------

  bool p0_valid = input_packet_valid(0);
  bool p1_valid = input_packet_valid(1);

  I1 pidx = 0;
  if (p0_valid && p1_valid) {
    L1 t0 = (L1_(input_packet[0].cpu_time_hi) << 32) |
             L1_(input_packet[0].cpu_time_lo);
    L1 t1 = (L1_(input_packet[1].cpu_time_hi) << 32) |
             L1_(input_packet[1].cpu_time_lo);
    pidx = (t0 >= t1) ? 0 : 1;
  } else {
    if (p0_valid) pidx = 0;
    if (p1_valid) pidx = 1;
  }

  L1 cpu_t = (L1_(input_packet[pidx].cpu_time_hi) << 32) |
              L1_(input_packet[pidx].cpu_time_lo);

  I1 fidx = (input_packet[pidx].frame_idx) & 1;
  I1 nfidx = (fidx + 1) & 1;
  F1 time = F1_(cpu_t) / F1_(US_PER_S);

  //---------------------------------------------------------------------------

  // UV Resolution
  F2 uv = coord_to_uv(F2(threadId.x, threadId.y), width, height);

  F3 camera = scene[fidx].camera.position;
  F1 yaw = scene[fidx].camera.yaw;
  F1 pitch = scene[fidx].camera.pitch;
  F3 forward = normalize(F3(
    cos(pitch) * sin(yaw),
    sin(pitch),
    cos(pitch) * cos(yaw),
  ));

  F3 right = normalize(cross(forward, F3(0, 1, 0)));
  F3 up = cross(right, forward);
  F3 rd = normalize(uv.x * right + uv.y * up + 1.5 * forward);
  F3 ro = scene[fidx].camera.position;
  scene[fidx].sphere.center.zx = 1.3*sin(time);

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
  // SDF Scene Ray March
  //---------------------------------------------------------------------------

  F4 color = bg_color;
  F3 sdf_color = F3(0);
  F1 t = 0.0;
  for (I1 i=0;i<marchMaxSteps;++i) {
    SdfResult res = sdf_scene(ro + rd * t, fidx, ground_color);
    if (res.dist < 0.001) { sdf_color = res.color; break; }
    t += res.dist;
    if (t > 128) { t = -1.0; break; }
  }

  if (t>0) {
    F3 hit = ro + rd * t;

    // Normal Calculation
    F1 e = 0.001; // error step?
    F3 normal = normalize(F3(
      sdf_scene(hit + F3(e,0,0), fidx, ground_color).dist - sdf_scene(hit - F3(e,0,0), fidx, ground_color).dist,
      sdf_scene(hit + F3(0,e,0), fidx, ground_color).dist - sdf_scene(hit - F3(0,e,0), fidx, ground_color).dist,
      sdf_scene(hit + F3(0,0,e), fidx, ground_color).dist - sdf_scene(hit - F3(0,0,e), fidx, ground_color).dist,
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
      F1 d = sdf_scene(shadow_ro + shadow_rd * st, fidx, ground_color).dist;
      if (d < 0.001) { shadow = 0.0; break; }
      st += d;
      if (st > 10.0) { break; }
    }

    // Ambient Occlusion
    F1 ao = 0.0;
    F1 ao_step = 0.1;
    for (I1 i=1;i<4;++i) {
      F1 d = sdf_scene(hit + normal * ao_step * F1_(i), fidx, ground_color).dist;
      ao += max(0.0, ao_step * F1_(i) - d);
    }
    ao = 1.0 - clamp(ao * 2, 0, 1);

    F1 spec = pow(max(dot(reflect(-light, normal), -rd), 0.0), 20.0);
    color = F4( spec + ((diffuse * shadow + ambient * ao) * sdf_color), 1);
  }

  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // Apply User Input
  //---------------------------------------------------------------------------

  if (threadId.x == 0 && threadId.y == 0) {
    scene[nfidx].box = scene[fidx].box;
    scene[nfidx].sphere = scene[fidx].sphere;
    scene[nfidx].camera = scene[fidx].camera;

    F3 campos = scene[fidx].camera.position;
    F1 pitch = scene[fidx].camera.pitch;
    F1 yaw = scene[fidx].camera.yaw;
    F1 mov = 0.02;

    L1 keyboard = L1_((L1_(input_packet[fidx].key_arr_hi)<<32)
                      | L1_(input_packet[fidx].key_arr_lo));

    F3 cam_displace = F3(0);
    F1 pitch_displace = 0;
    F1 yaw_displace = 0;

    cam_displace += (mov *  forward) * ((keyboard >> KEY_W)&1);
    cam_displace += (mov * -forward) * ((keyboard >> KEY_S)&1);
    cam_displace += (mov *    right) * ((keyboard >> KEY_D)&1);
    cam_displace += (mov *   -right) * ((keyboard >> KEY_A)&1);
    cam_displace += (mov *       up) * ((keyboard >> KEY_SPACE)&1);
    cam_displace += (mov *      -up) * ((keyboard >> KEY_SHIFT)&1);

    pitch_displace +=  mov * ((keyboard >> KEY_UP)&1);
    pitch_displace += -mov * ((keyboard >> KEY_DOWN)&1);

    yaw_displace +=  mov * ((keyboard >> KEY_LEFT)&1);
    yaw_displace += -mov * ((keyboard >> KEY_RIGHT)&1);

    scene[nfidx].camera.position = campos + cam_displace;
    scene[nfidx].camera.pitch = clamp(pitch + pitch_displace, -1.5, 1.5);
    scene[nfidx].camera.yaw = yaw + yaw_displace;

    // if (keyPressed(pidx, KEY_S)) {
    //   scene[nfidx].camera.position = campos + (mov * -forward);
    // }
    // if (keyPressed(pidx, KEY_A)) {
    //   scene[nfidx].camera.position = campos + (mov * -right);
    // }
    // if (keyPressed(pidx, KEY_D)) {
    //   scene[nfidx].camera.position = campos + (mov * right);
    // }
    // if (keyPressed(pidx, KEY_SPACE)) {
    //   scene[nfidx].camera.position = campos + (mov * up);
    // }
    // if (keyPressed(pidx, KEY_SHIFT)) {
    //   scene[nfidx].camera.position = campos + (mov * -up);
    // }


    // if (keyPressed(pidx, KEY_UP)) {
    //   scene[nfidx].camera.pitch = (pitch+mov);
    // }
    // if (keyPressed(pidx, KEY_DOWN)) {
    //   scene[nfidx].camera.pitch = (pitch-mov);
    // }
    // if (keyPressed(pidx, KEY_LEFT)) {
    //   scene[nfidx].camera.yaw = (yaw+mov);
    // }
    // if (keyPressed(pidx, KEY_RIGHT)) {
    //   scene[nfidx].camera.yaw = (yaw-mov);
    // }
    // scene[nfidx].camera.pitch = clamp(scene[nfidx].camera.pitch, -1.5, 1.5);
  }

  //---------------------------------------------------------------------------

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

