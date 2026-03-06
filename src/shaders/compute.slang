#define S static

#define I1 uint
#define S1 int

#define F1 float
#define F2 float2
#define F3 float3
#define F4 float4

#define F1_(x) (F1)(x)
#define F2_(x) (F2)(x)
#define F3_(x) (F3)(x)
#define F4_(x) (F4)(x)

struct Globals {
  F3 color;
  F1 time;
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

S Box b = {
  { 0.8, 0.2, 0.3, 1.0 },
  { 0.5, 0.0, 0.0 },
  { 0.2, 0.4, 0.1 },
};

S Sphere s = {
  { 0.3, 0.2, 0.8, 1.0 },
  {0, 0, 0},
  0.3,
};


F1 Box_signed_distance(F3 p, F3 center, F3 size) {
  F3 q = abs(p - center) - size;
  return length(max(q, 0.0)) + min(max(q.x, max(q.y,q.z)), 0.0);
}

F1 Sphere_signed_distance(F3 p, F3 center, F1 r) {
  return length(p - center) - r;
}

F2 coord_to_uv(F2 coord, I1 width, I1 height) {
  F1 aspect_ratio = F1_(width) / F1_(height);
  F2 normalized_coords = ((coord / float2(F1_(width), F1_(height))) * 2 )- 1;

  return normalized_coords * float2(aspect_ratio, 1);
}

S const I1 kMaxIter = 1024;
I1 mandelbrot(inout F2 z, F1 time) {
  const F2 c = z;
  for (I1 i = 0; i < kMaxIter; i++) {
    if (dot(z,z) > 256) return i;
    z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y)
        + sin(time+c);
  }
  return kMaxIter;
}

[shader("compute")]
[numthreads(16, 16, 1)]
void compMain(
  uint3 threadId: SV_DispatchThreadID,
  uniform RWTexture2D<float4> outputImage,
  uniform Globals globals,
) {
  I1 width, height;
  outputImage.GetDimensions(width, height);

  if (threadId.x >= width || threadId.y >= height)
    return;

  F4 bg_color = float4(globals.color.r, globals.color.g, globals.color.b, 1);

  // UV Resolution
  F2 uv = coord_to_uv(float2(threadId.x, threadId.y), width, height);

  // SDF Calculations
  F1 sphere_sdf = Sphere_signed_distance(float3(uv.xy, 0), s.center, s.radius);
  F1 box_sdf = Box_signed_distance(float3(uv.xy, 0), b.center, b.size);

  // Signed Distance Union (Box U Sphere)
  F1 signed_dist = min(sphere_sdf, box_sdf);
  F4 shape_color = (sphere_sdf < box_sdf) ? s.color : b.color;
  F1 mask = smoothstep(-0.003, 0.003, signed_dist);
  F4 color = lerp(shape_color, bg_color, mask);

  // Unrelated to SDF -- Just overwrites the output with Mandelbrot set image
  {
    I1 i = mandelbrot(uv, globals.time);
    F3 m_color = float3(0.0);
    if (i != kMaxIter) {
      m_color = 0.5 + 0.5 * sin(i + globals.time + float3(0, 0.5, 1)
                                -log2(log2(dot(uv, uv))));
    }
    color = float4(m_color, 1.0);
  }

  outputImage[threadId.xy] = color;
  // example_effect(outputImage[threadId.xy], globals, uv);
}


F1 example_effect_rand(F1 n) {
  return fract(sin(n) * 43758.5453123);
}

void example_effect(inout F4 color, Globals globals, F2 uv) {
  F1 freq = 0.5;
  F2 pos = (uv + globals.time*float2(0.25f, 0.0f)) * freq;

  F2 center = floor(pos + float2(0.5));

  F1 r0 = example_effect_rand(center.x*3.0  + center.y*7.0 );
  F1 r1 = example_effect_rand(center.x*7.0  + center.y*13.0);
  F1 r2 = example_effect_rand(center.x*13.0 + center.y*3.0 );

  F1 p = smoothstep(0.0, 4.0, r0);
  F1 f = smoothstep(0.2, 0.9, r1);

  F1 a = 0.5f * (1.0f + cos(globals.time*f + p));

  F1 rad0 = smoothstep(0.1, 0.4, r2);
  F1 rad1 = smoothstep(0.2, 0.9, r0);

  F1 radius = 0.5f*smoothstep(rad0, rad1, a);

  F2 delta = pos - center;
  F1 distance = length(delta);

  color.xyz = float3(r0, r1, r2);
  color.w = 1.0f;

  if(distance > radius) color.xyz = float3(0.25f);
}

