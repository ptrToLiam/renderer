struct PushConstants {
  float r, g, b, a;
};

[[vk::push_constant]]
PushConstants push;

[shader("compute")]
[numthreads(8, 8, 1)]
void compMain(
  uint3 threadId: SV_DispatchThreadID,
  uniform RWTexture2D<float4> outputImage
) {
  uint width, height;
  outputImage.GetDimensions(width, height);

  if (threadId.x >= width || threadId.y >= height)
    return;

  outputImage[threadId.xy] = float4(push.r, push.g, push.b, 1.0);
}
