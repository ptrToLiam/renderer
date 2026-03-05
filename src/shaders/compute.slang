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
  F1 iTime;
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

S const I1 kMaxIter = 64;
I1 mandelbrot(inout F2 z) {
  const F2 c = z;
  for (I1 i = 0; i < kMaxIter; i++) {
    if (dot(z,z) > 256) return i;
    z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y)
        + c;
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
  // F2 uv = threadId.xy  / float2(width, height);
  F2 uv = coord_to_uv(float2(threadId.x, threadId.y), width, height);

  // SDF Calculations
  F1 sphere_sdf = Sphere_signed_distance(float3(uv.xy, 0), s.center, s.radius);
  F1 box_sdf = Box_signed_distance(float3(uv.xy, 0), b.center, b.size);

  // Signed Distance Union (Box U Sphere)
  F1 signed_dist = min(sphere_sdf, box_sdf);
  F4 shape_color = (sphere_sdf < box_sdf) ? s.color : b.color;
  F1 mask = smoothstep(-0.003, 0.003, signed_dist);
  F4 color = lerp(shape_color, bg_color, mask);

  I1 i = mandelbrot(uv);
  F3 m_color = float3(0.0);
  if (i != kMaxIter) {
    m_color = 0.5 + 0.5 * sin(i + globals.iTime + float3(0, 0.5, 1)
                              -log2(log2(dot(uv, uv))));
  }
  color = float4(m_color, 1.0);

  outputImage[threadId.xy] = color;
  // outputImage[threadId.xy] = float4(i, i, i, 1.0);
}
