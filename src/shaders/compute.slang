struct UniformBuffer {
  float delta_time;
};
ConstantBuffer<UniformBuffer> ubo;

// This is prolly not correct syntax
RWTexture2<float> bufferIn;
RWTexture2<float> imageOut;

[shader("compute")]
[numthreads(256,1,1)]
void main(uint3 threadId : SV_DispatchThreadID) {
  // TODO
  // write image
}
