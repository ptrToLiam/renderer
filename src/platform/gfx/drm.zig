pub const Format = enum (u32) {
  invalid = 0,
  // color index
  c8 = fourcc_code('C', '8', ' ', ' '),   // [7:0] C

  // 8 bpp Red
  r8 = fourcc_code('R', '8', ' ', ' '),   // [7:0] R

  // 16 bpp Red
  r16 = fourcc_code('R', '1', '6', ' '),   // [15:0] R little endian

  // 16 bpp RG
  rg88 = fourcc_code('R', 'G', '8', '8'),   // [15:0] R:G 8:8 little endian
  gr88 = fourcc_code('G', 'R', '8', '8'),   // [15:0] G:R 8:8 little endian

  // 32 bpp RG
  rg1616 = fourcc_code('R', 'G', '3', '2'),   // [31:0] R:G 16:16 little endian
  gr1616 = fourcc_code('G', 'R', '3', '2'),   // [31:0] G:R 16:16 little endian

  // 8 bpp RGB
  rgb332 = fourcc_code('R', 'G', 'B', '8'),   // [7:0] R:G:B 3:3:2
  bgr233 = fourcc_code('B', 'G', 'R', '8'),   // [7:0] B:G:R 2:3:3

  // 16 bpp RGB
  xrgb4444 = fourcc_code('X', 'R', '1', '2'),   // [15:0] x:R:G:B 4:4:4:4 little endian
  xbgr4444 = fourcc_code('X', 'B', '1', '2'),   // [15:0] x:B:G:R 4:4:4:4 little endian
  rgbx4444 = fourcc_code('R', 'X', '1', '2'),   // [15:0] R:G:B:x 4:4:4:4 little endian
  bgrx4444 = fourcc_code('B', 'X', '1', '2'),   // [15:0] B:G:R:x 4:4:4:4 little endian

  argb4444 = fourcc_code('A', 'R', '1', '2'),   // [15:0] A:R:G:B 4:4:4:4 little endian
  abgr4444 = fourcc_code('A', 'B', '1', '2'),   // [15:0] A:B:G:R 4:4:4:4 little endian
  rgba4444 = fourcc_code('R', 'A', '1', '2'),   // [15:0] R:G:B:A 4:4:4:4 little endian
  bgra4444 = fourcc_code('B', 'A', '1', '2'),   // [15:0] B:G:R:A 4:4:4:4 little endian

  xrgb1555 = fourcc_code('X', 'R', '1', '5'),   // [15:0] x:R:G:B 1:5:5:5 little endian
  xbgr1555 = fourcc_code('X', 'B', '1', '5'),   // [15:0] x:B:G:R 1:5:5:5 little endian
  rgbx5551 = fourcc_code('R', 'X', '1', '5'),   // [15:0] R:G:B:x 5:5:5:1 little endian
  bgrx5551 = fourcc_code('B', 'X', '1', '5'),   // [15:0] B:G:R:x 5:5:5:1 little endian

  argb1555 = fourcc_code('A', 'R', '1', '5'),   // [15:0] A:R:G:B 1:5:5:5 little endian
  abgr1555 = fourcc_code('A', 'B', '1', '5'),   // [15:0] A:B:G:R 1:5:5:5 little endian
  rgba5551 = fourcc_code('R', 'A', '1', '5'),   // [15:0] R:G:B:A 5:5:5:1 little endian
  bgra5551 = fourcc_code('B', 'A', '1', '5'),   // [15:0] B:G:R:A 5:5:5:1 little endian

  rgb565 = fourcc_code('R', 'G', '1', '6'),   // [15:0] R:G:B 5:6:5 little endian
  bgr565 = fourcc_code('B', 'G', '1', '6'),   // [15:0] B:G:R 5:6:5 little endian

  // 24 bpp RGB
  rgb888 = fourcc_code('R', 'G', '2', '4'),   // [23:0] R:G:B little endian
  bgr888 = fourcc_code('B', 'G', '2', '4'),   // [23:0] B:G:R little endian

  // 32 bpp RGB
  xrgb8888 = fourcc_code('X', 'R', '2', '4'),   // [31:0] x:R:G:B 8:8:8:8 little endian
  xbgr8888 = fourcc_code('X', 'B', '2', '4'),   // [31:0] x:B:G:R 8:8:8:8 little endian
  rgbx8888 = fourcc_code('R', 'X', '2', '4'),   // [31:0] R:G:B:x 8:8:8:8 little endian
  bgrx8888 = fourcc_code('B', 'X', '2', '4'),   // [31:0] B:G:R:x 8:8:8:8 little endian

  argb8888 = fourcc_code('A', 'R', '2', '4'),   // [31:0] A:R:G:B 8:8:8:8 little endian
  abgr8888 = fourcc_code('A', 'B', '2', '4'),   // [31:0] A:B:G:R 8:8:8:8 little endian
  rgba8888 = fourcc_code('R', 'A', '2', '4'),   // [31:0] R:G:B:A 8:8:8:8 little endian
  bgra8888 = fourcc_code('B', 'A', '2', '4'),   // [31:0] B:G:R:A 8:8:8:8 little endian

  xrgb2101010 = fourcc_code('X', 'R', '3', '0'),   // [31:0] x:R:G:B 2:10:10:10 little endian
  xbgr2101010 = fourcc_code('X', 'B', '3', '0'),   // [31:0] x:B:G:R 2:10:10:10 little endian
  rgbx1010102 = fourcc_code('R', 'X', '3', '0'),   // [31:0] R:G:B:x 10:10:10:2 little endian
  bgrx1010102 = fourcc_code('B', 'X', '3', '0'),   // [31:0] B:G:R:x 10:10:10:2 little endian

  argb2101010 = fourcc_code('A', 'R', '3', '0'),   // [31:0] A:R:G:B 2:10:10:10 little endian
  abgr2101010 = fourcc_code('A', 'B', '3', '0'),   // [31:0] A:B:G:R 2:10:10:10 little endian
  rgba1010102 = fourcc_code('R', 'A', '3', '0'),   // [31:0] R:G:B:A 10:10:10:2 little endian
  bgra1010102 = fourcc_code('B', 'A', '3', '0'),   // [31:0] B:G:R:A 10:10:10:2 little endian

  // 64 bpp RGBA (16 bits per channel)
  abgr16161616f = fourcc_code('A', 'B', '4', 'H'),  // 0x48344241 - float
  abgr16161616  = fourcc_code('A', 'B', '4', '8'),  // 0x38344241 - uint
  argb16161616f = fourcc_code('A', 'R', '4', 'H'),  // 0x48345241
  argb16161616  = fourcc_code('A', 'R', '4', '8'),  // 0x38345241

  // 64 bpp RGBX (16 bits per channel)
  xbgr16161616f = fourcc_code('X', 'B', '4', 'H'),  // 0x48344258
  xbgr16161616  = fourcc_code('X', 'B', '4', '8'),  // 0x38344258
  xrgb16161616f = fourcc_code('X', 'R', '4', 'H'),  // 0x48345258
  xrgb16161616  = fourcc_code('X', 'R', '4', '8'),  // 0x38345258

  // packed YCbCr
  yuyv = fourcc_code('Y', 'U', 'Y', 'V'),   // [31:0] Cr0:Y1:Cb0:Y0 8:8:8:8 little endian
  yvyu = fourcc_code('Y', 'V', 'Y', 'U'),   // [31:0] Cb0:Y1:Cr0:Y0 8:8:8:8 little endian
  uyvy = fourcc_code('U', 'Y', 'V', 'Y'),   // [31:0] Y1:Cr0:Y0:Cb0 8:8:8:8 little endian
  vyuy = fourcc_code('V', 'Y', 'U', 'Y'),   // [31:0] Y1:Cb0:Y0:Cr0 8:8:8:8 little endian

  ayuv = fourcc_code('A', 'Y', 'U', 'V'),   // [31:0] A:Y:Cb:Cr 8:8:8:8 little endian

  // 2 plane RGB + A
  // index 0 = RGB plane, same format as the corresponding non _A8 format has
  // index 1 = A plane, [7:0] A

  xrgb8888_a8 = fourcc_code('X', 'R', 'A', '8'),
  xbgr8888_a8 = fourcc_code('X', 'B', 'A', '8'),
  rgbx8888_a8 = fourcc_code('R', 'X', 'A', '8'),
  bgrx8888_a8 = fourcc_code('B', 'X', 'A', '8'),
  rgb888_a8 = fourcc_code('R', '8', 'A', '8'),
  bgr888_a8 = fourcc_code('B', '8', 'A', '8'),
  rgb565_a8 = fourcc_code('R', '5', 'A', '8'),
  bgr565_a8 = fourcc_code('B', '5', 'A', '8'),

  // 2 plane YCbCr
  // index 0 = Y plane, [7:0] Y
  // index 1 = Cr:Cb plane, [15:0] Cr:Cb little endian
  // or
  // index 1 = Cb:Cr plane, [15:0] Cb:Cr little endian

  nv12 = fourcc_code('N', 'V', '1', '2'),   // 2x2 subsampled Cr:Cb plane
  nv21 = fourcc_code('N', 'V', '2', '1'),   // 2x2 subsampled Cb:Cr plane
  nv16 = fourcc_code('N', 'V', '1', '6'),   // 2x1 subsampled Cr:Cb plane
  nv61 = fourcc_code('N', 'V', '6', '1'),   // 2x1 subsampled Cb:Cr plane
  nv24 = fourcc_code('N', 'V', '2', '4'),   // non-subsampled Cr:Cb plane
  nv42 = fourcc_code('N', 'V', '4', '2'),   // non-subsampled Cb:Cr plane

  // 3 plane YCbCr
  // index 0: Y plane, [7:0] Y
  // index 1: Cb plane, [7:0] Cb
  // index 2: Cr plane, [7:0] Cr
  // or
  // index 1: Cr plane, [7:0] Cr
  // index 2: Cb plane, [7:0] Cb

  yuv410 = fourcc_code('Y', 'U', 'V', '9'),   // 4x4 subsampled Cb (1) and Cr (2) planes
  yvu410 = fourcc_code('Y', 'V', 'U', '9'),   // 4x4 subsampled Cr (1) and Cb (2) planes
  yuv411 = fourcc_code('Y', 'U', '1', '1'),   // 4x1 subsampled Cb (1) and Cr (2) planes
  yvu411 = fourcc_code('Y', 'V', '1', '1'),   // 4x1 subsampled Cr (1) and Cb (2) planes
  yuv420 = fourcc_code('Y', 'U', '1', '2'),   // 2x2 subsampled Cb (1) and Cr (2) planes
  yvu420 = fourcc_code('Y', 'V', '1', '2'),   // 2x2 subsampled Cr (1) and Cb (2) planes
  yuv422 = fourcc_code('Y', 'U', '1', '6'),   // 2x1 subsampled Cb (1) and Cr (2) planes
  yvu422 = fourcc_code('Y', 'V', '1', '6'),   // 2x1 subsampled Cr (1) and Cb (2) planes
  yuv444 = fourcc_code('Y', 'U', '2', '4'),   // non-subsampled Cb (1) and Cr (2) planes
  yvu444 = fourcc_code('Y', 'V', '2', '4'),   // non-subsampled Cr (1) and Cb (2) planes

  // 10-bit single channel (from newer kernel drm_fourcc.h)
  r10    = fourcc_code('R', '1', '0', '1'),
  r100   = fourcc_code('R', '1', '0', '0'),
  b101   = fourcc_code('B', '1', '0', '1'),
  b100   = fourcc_code('B', '1', '0', '0'),

  // [15:0] R 10 MSB in 16-bit word, little endian
  r10_unorm       = fourcc_code('R', '1', '0', ' '),
  b10_unorm       = fourcc_code('B', '1', '0', ' '),

  // 10/12-bit YUV semi-planar
  // Y plane + interleaved UV, 10 bits stored in 16-bit words
  p010          = fourcc_code('P', '0', '1', '0'),
  p012          = fourcc_code('P', '0', '1', '2'),
  p210          = fourcc_code('P', '2', '1', '0'),

  // HDR metadata (not for rendering)
  hdr_static  = fourcc_code('H', 'D', '0', '1'),
  uhd_dynamic = fourcc_code('U', 'H', 'D', '0'),

  _,

  pub fn fromInt(n: u32) Format {
    return @enumFromInt(n);
  }
  pub fn toInt(fmt: Format) u32 {
    return @intFromEnum(fmt);
  }
};

pub const FourccCode = packed struct (u32) {
  a: u8,
  b: u8,
  c: u8,
  d: u8,
};

inline fn fourcc_code(a: u8, b: u8, c: u8, d: u8) u32 {
  return @bitCast(FourccCode{ .a = a, .b = b, .c = c, .d = d });
}

pub const ModifierValue = packed struct (u64) {
  code: u56,
  vendor: Vendor,

  pub fn create(vendor: Vendor, num: u64) ModifierValue {
    return .{
      .vendor = vendor,
      .code = @truncate(num & 0x00ffffffffffffff),
    };
  }
  pub fn fromInt(num: u64) ModifierValue {
    return @bitCast(num);
  }

  pub const Vendor = enum (u8) {
    none = 0,
    intel = 0x01,
    amd = 0x02,
    nvidia = 0x03,
    samsung = 0x04,
    qcom = 0x05,
    vivante = 0x06,
    broadcom = 0x07,
    arm = 0x08,
    allwinner = 0x09,
    amlogic = 0x0a,
  };
};

pub const Modifier = enum (u64) {
  ///  Invalid Modifier
  ///
  ///  This modifier can be used as a sentinel to terminate the format modifiers
  ///  list, or to initialize a variable with an invalid modifier. It might also be
  ///  used to report an error back to userspace for certain APIs.
  invalid = u64_(ModifierValue.create(.none, ((1<<56) - 1))),

  /// Linear Layout
  ///
  /// Just plain linear layout. Note that this is different from no specifying any
  /// modifier (e.g. not setting DRM_MODE_FB_MODIFIERS in the DRM_ADDFB2 ioctl),
  /// which tells the driver to also take driver-internal information into account
  /// and so might actually result in a tiled framebuffer.
  linear = u64_(ModifierValue.create(.none, 0)),

  //------------------------------------------------------------------------------
  // Intel framebuffer modifiers
  //------------------------------------------------------------------------------

  /// Intel X-tiling layout
  ///
  /// This is a tiled layout using 4Kb tiles (except on gen2 where the tiles 2Kb)
  /// in row-major layout. Within the tile bytes are laid out row-major, with
  /// a platform-dependent stride. On top of that the memory can apply
  /// platform-depending swizzling of some higher address bits into bit6.
  ///
  /// This format is highly platforms specific and not useful for cross-driver
  /// sharing. It exists since on a given platform it does uniquely identify the
  /// layout in a simple way for i915-specific userspace.
  i915_x_tile = fourcc_mod_code(.intel, 1),

  /// Intel Y-tiling layout
  ///
  /// This is a tiled layout using 4Kb tiles (except on gen2 where the tiles 2Kb)
  /// in row-major layout. Within the tile bytes are laid out in OWORD (16 bytes)
  /// chunks column-major, with a platform-dependent height. On top of that the
  /// memory can apply platform-depending swizzling of some higher address bits
  /// into bit6.
  ///
  /// This format is highly platforms specific and not useful for cross-driver
  /// sharing. It exists since on a given platform it does uniquely identify the
  /// layout in a simple way for i915-specific userspace.
  i915_y_tiled = fourcc_mod_code(.intel, 2),

  /// Intel Yf-tiling layout
  ///
  /// This is a tiled layout using 4Kb tiles in row-major layout.
  /// Within the tile pixels are laid out in 16 256 byte units / sub-tiles which
  /// are arranged in four groups (two wide, two high) with column-major layout.
  /// Each group therefore consits out of four 256 byte units, which are also laid
  /// out as 2x2 column-major.
  /// 256 byte units are made out of four 64 byte blocks of pixels, producing
  /// either a square block or a 2:1 unit.
  /// 64 byte blocks of pixels contain four pixel rows of 16 bytes, where the width
  /// in pixel depends on the pixel depth.
  i915_yf_tiled = fourcc_mod_code(.intel, 3),

  /// Intel color control surface (CCS) for render compression
  ///
  /// The framebuffer format must be one of the 8:8:8:8 RGB formats.
  /// The main surface will be plane index 0 and must be Y/Yf-tiled,
  /// the CCS will be plane index 1.
  ///
  /// Each CCS tile matches a 1024x512 pixel area of the main surface.
  /// To match certain aspects of the 3D hardware the CCS is
  /// considered to be made up of normal 128Bx32 Y tiles, Thus
  /// the CCS pitch must be specified in multiples of 128 bytes.
  ///
  /// In reality the CCS tile appears to be a 64Bx64 Y tile, composed
  /// of QWORD (8 bytes) chunks instead of OWORD (16 bytes) chunks.
  /// But that fact is not relevant unless the memory is accessed
  /// directly.
  i915_y_tiled_ccs = fourcc_mod_code(.intel, 4),
  i915_yf_tiled_ccs = fourcc_mod_code(.intel, 5),

  /// Tiled, NV12MT, grouped in 64 (pixels) x 32 (lines) -sized macroblocks
  ///
  /// Macroblocks are laid in a Z-shape, and each pixel data is following the
  /// standard NV12 style.
  /// As for NV12, an image is the result of two frame buffers: one for Y,
  /// one for the interleaved Cb/Cr components (1/2 the height of the Y buffer).
  /// Alignment requirements are (for each buffer):
  /// - multiple of 128 pixels for the width
  /// - multiple of  32 pixels for the height
  ///
  /// For more information: see https://linuxtv.org/downloads/v4l-dvb-apis/re32.html
  drm_samsung_64_32_tile = fourcc_mod_code(.samsung, 1),

  /// Qualcomm Compressed Format
  ///
  /// Refers to a compressed variant of the base format that is compressed.
  /// Implementation may be platform and base-format specific.
  ///
  /// Each macrotile consists of m x n (mostly 4 x 4) tiles.
  /// Pixel data pitch/stride is aligned with macrotile width.
  /// Pixel data height is aligned with macrotile height.
  /// Entire pixel data buffer is aligned with 4k(bytes).
  drm_qcom_compressed = fourcc_mod_code(.qcom, 1),

  //------------------------------------------------------------------------------
  // Vivante framebuffer modifiers
  //------------------------------------------------------------------------------

  /// Vivante 4x4 tiling layout
  ///
  /// This is a simple tiled layout using tiles of 4x4 pixels in a row-major
  /// layout.
  drm_vivante_tiled  = fourcc_mod_code(.vivante, 1),

  /// Vivante 64x64 super-tiling layout
  ///
  /// This is a tiled layout using 64x64 pixel super-tiles, where each super-tile
  /// contains 8x4 groups of 2x4 tiles of 4x4 pixels (like above) each, all in row-
  /// major layout.
  ///
  /// For more information: see
  /// https://github.com/etnaviv/etna_viv/blob/master/doc/hardware.md#texture-tiling
  drm_vivante_super_tiled = fourcc_mod_code(.vivante, 2),

  /// Vivante 4x4 tiling layout for dual-pipe
  ///
  /// Same as the 4x4 tiling layout, except every second 4x4 pixel tile starts at a
  /// different base address. Offsets from the base addresses are therefore halved
  /// compared to the non-split tiled layout.
 drm_vivante_split_tiled = fourcc_mod_code(.vivante, 3),

  /// Vivante 64x64 super-tiling layout for dual-pipe
  ///
  /// Same as the 64x64 super-tiling layout, except every second 4x4 pixel tile
  /// starts at a different base address. Offsets from the base addresses are
  /// therefore halved compared to the non-split super-tiled layout.
  drm_vivante_split_super_tiled = fourcc_mod_code(.vivante, 4),

  //------------------------------------------------------------------------------
  // NVIDIA framebuffer modifiers
  //------------------------------------------------------------------------------

  /// Tegra Tiled Layout, used by Tegra 2, 3 and 4.
  ///
  /// Pixels are arranged in simple tiles of 16 x 16 bytes.
  drm_nvidia_tegra_tiled = fourcc_mod_code(.nvidia, 1),

  /// 16Bx2 Block Linear layout, used by desktop GPUs, and Tegra K1 and later
  ///
  /// Pixels are arranged in 64x8 Groups Of Bytes (GOBs). GOBs are then stacked
  /// vertically by a power of 2 (1 to 32 GOBs) to form a block.
  ///
  /// Within a GOB, data is ordered as 16B x 2 lines sectors laid in Z-shape.
  ///
  /// Parameter 'v' is the log2 encoding of the number of GOBs stacked vertically.
  /// Valid values are:
  ///
  /// 0 == ONE_GOB
  /// 1 == TWO_GOBS
  /// 2 == FOUR_GOBS
  /// 3 == EIGHT_GOBS
  /// 4 == SIXTEEN_GOBS
  /// 5 == THIRTYTWO_GOBS
  ///
  /// Chapter 20 "Pixel Memory Formats" of the Tegra X1 TRM describes this format
  /// in full detail.
  // #define DRM_NVIDIA_16BX2_BLOCK(v) fourcc_mod_code(NVIDIA, 0x10 | ((v) & 0xf))

  nvidia_16bx2_block_one_gob = fourcc_mod_code(.nvidia, 0x10),
  nvidia_16bx2_block_two_gob = fourcc_mod_code(.nvidia, 0x11),
  nvidia_16bx2_block_four_gob = fourcc_mod_code(.nvidia, 0x12),
  nvidia_16bx2_block_eight_gob = fourcc_mod_code(.nvidia, 0x13),
  nvidia_16bx2_block_sixteen_gob = fourcc_mod_code(.nvidia, 0x14),
  nvidia_16bx2_block_thirtytwo_gob = fourcc_mod_code(.nvidia, 0x15),


  /// Broadcom VC4 "T" format
  ///
  /// This is the primary layout that the V3D GPU can texture from (it
  /// can't do linear).  The T format has:
  ///
  /// - 64b utiles of pixels in a raster-order grid according to cpp.  It's 4x4
  ///   pixels at 32 bit depth.
  ///
  /// - 1k subtiles made of a 4x4 raster-order grid of 64b utiles (so usually
  ///   16x16 pixels).
  ///
  /// - 4k tiles made of a 2x2 grid of 1k subtiles (so usually 32x32 pixels).  On
  ///   even 4k tile rows, they're arranged as (BL, TL, TR, BR), and on odd rows
  ///   they're (TR, BR, BL, TL), where bottom left is start of memory.
  ///
  /// - an image made of 4k tiles in rows either left-to-right (even rows of 4k
  ///   tiles) or right-to-left (odd rows of 4k tiles).
  drm_broadcom_vc4_t_tiled = fourcc_mod_code(.broadcom, 1),

  // Broadcom SAND format
  //
  // This is the native format that the H.264 codec block uses.  For VC4
  // HVS, it is only valid for H.264 (NV12/21) and RGBA modes.
  //
  // The image can be considered to be split into columns, and the
  // columns are placed consecutively into memory.  The width of those
  // columns can be either 32, 64, 128, or 256 pixels, but in practice
  // only 128 pixel columns are used.
  //
  // The pitch between the start of each column is set to optimally
  // switch between SDRAM banks. This is passed as the number of lines
  // of column width in the modifier (we can't use the stride value due
  // to various core checks that look at it , so you should set the
  // stride to width*cpp).
  //
  // Note that the column height for this format modifier is the same
  // for all of the planes, assuming that each column contains both Y
  // and UV.  Some SAND-using hardware stores UV in a separate tiled
  // image from Y to reduce the column height, which is not supported
  // with these modifiers.

// #define DRM_BROADCOM_SAND32_COL_HEIGHT(v)  fourcc_mod_broadcom_code(2, v)
// #define DRM_BROADCOM_SAND64_COL_HEIGHT(v)  fourcc_mod_broadcom_code(3, v)
// #define DRM_BROADCOM_SAND128_COL_HEIGHT(v)  fourcc_mod_broadcom_code(4, v)
// #define DRM_BROADCOM_SAND256_COL_HEIGHT(v)  fourcc_mod_broadcom_code(5, v)
//
// #define DRM_BROADCOM_SAND32  DRM_BROADCOM_SAND32_COL_HEIGHT(0)
// #define DRM_BROADCOM_SAND64  DRM_BROADCOM_SAND64_COL_HEIGHT(0)
// #define DRM_BROADCOM_SAND128  DRM_BROADCOM_SAND128_COL_HEIGHT(0)
// #define DRM_BROADCOM_SAND256 DRM_BROADCOM_SAND256_COL_HEIGHT(0)

  /// Broadcom UIF format
  ///
  /// This is the common format for the current Broadcom multimedia
  /// blocks, including V3D 3.x and newer, newer video codecs, and
  /// displays.
  ///
  /// The image consists of utiles (64b blocks), UIF blocks (2x2 utiles),
  /// and macroblocks (4x4 UIF blocks).  Those 4x4 UIF block groups are
  /// stored in columns, with padding between the columns to ensure that
  /// moving from one column to the next doesn't hit the same SDRAM page
  /// bank.
  ///
  /// To calculate the padding, it is assumed that each hardware block
  /// and the software driving it knows the platform's SDRAM page size,
  /// number of banks, and XOR address, and that it's identical between
  /// all blocks using the format.  This tiling modifier will use XOR as
  /// necessary to reduce the padding.  If a hardware block can't do XOR,
  /// the assumption is that a no-XOR tiling modifier will be created.
  drm_broadcom_uif = fourcc_mod_code(.broadcom, 6),

  //------------------------------------------------------------------------------
  // Arm Framebuffer Compression (AFBC) modifiers
  //------------------------------------------------------------------------------

  /// AFBC is a proprietary lossless image compression protocol and format.
  /// It provides fine-grained random access and minimizes the amount of data
  /// transferred between IP blocks.
  ///
  /// AFBC has several features which may be supported and/or used, which are
  /// represented using bits in the modifier. Not all combinations are valid,
  /// and different devices or use-cases may support different combinations.

  /// AFBC lossless colorspace transform
  ///
  /// Indicates that the buffer makes use of the AFBC lossless colorspace
  /// transform.
  afbc_ytr = (1 <<  4),

  /// AFBC block-split
  ///
  /// Indicates that the payload of each superblock is split. The second
  /// half of the payload is positioned at a predefined offset from the start
  /// of the superblock payload.
  afbc_split = (1 <<  5),

  /// AFBC sparse layout
  ///
  /// This flag indicates that the payload of each superblock must be stored at a
  /// predefined position relative to the other superblocks in the same AFBC
  /// buffer. This order is the same order used by the header buffer. In this mode
  /// each superblock is given the same amount of space as an uncompressed
  /// superblock of the particular format would require, rounding up to the next
  /// multiple of 128 bytes in size.
  afbc_sparse = (1 <<  6),

  /// AFBC copy-block restrict
  ///
  /// Buffers with this flag must obey the copy-block restriction. The restriction
  /// is such that there are no copy-blocks referring across the border of 8x8
  /// blocks. For the subsampled data the 8x8 limitation is also subsampled.
  afbc_cbr = (1 <<  7),

  /// AFBC tiled layout
  ///
  /// The tiled layout groups superblocks in 8x8 or 4x4 tiles, where all
  /// superblocks inside a tile are stored together in memory. 8x8 tiles are used
  /// for pixel formats up to and including 32 bpp while 4x4 tiles are used for
  /// larger bpp formats. The order between the tiles is scan line.
  /// When the tiled layout is used, the buffer size (in pixels) must be aligned
  /// to the tile size.

  afbc_tile = @as(u64, 1) <<  8,

  /// AFBC solid color blocks
  ///
  /// Indicates that the buffer makes use of solid-color blocks, whereby bandwidth
  /// can be reduced if a whole superblock is a single color.
  afbc_sc = (1 <<  9),

  _,

  pub fn fromInt(n: u64) Modifier {
    return @enumFromInt(n);
  }
  pub fn toInt(mod: Modifier) u64 {
    return u64_(mod);
  }
  pub fn hi(mod: Modifier) u32 {
    return @as(HiLo64, @bitCast(mod.toInt())).hi;
  }
  pub fn lo(mod: Modifier) u32 {
    return @as(HiLo64, @bitCast(mod.toInt())).lo;
  }

  pub fn toModVal(mod: Modifier) ModifierValue {
    return .fromInt(mod.toInt());
  }

  // pub fn drm_arm_afbc(mode: u64) ModifierValue {
  // }

  // #define DRM_ARM_AFBC(__afbc_mode) fourcc_mod_code(ARM, __afbc_mode)
  inline fn fourcc_mod_code(vendor: ModifierValue.Vendor, code: u54) u64 {
    return u64_(ModifierValue.create(vendor, code));
  }

  // Some Broadcom modifiers take parameters, for example the number of
  // vertical lines in the image. Reserve the lower 32 bits for modifier
  // type, and the next 24 bits for parameters. Top 8 bits are the
  // vendor code.

// #define __fourcc_mod_broadcom_param_shift 8
// #define __fourcc_mod_broadcom_param_bits 48
// #define fourcc_mod_broadcom_code(val, params) fourcc_mod_code(BROADCOM, ((((__u64)params) << __fourcc_mod_broadcom_param_shift) | val))

// #define fourcc_mod_broadcom_param(m) ((int)(((m) >> __fourcc_mod_broadcom_param_shift) &        ((1ULL << __fourcc_mod_broadcom_param_bits) - 1)))
// #define fourcc_mod_broadcom_mod(m) ((m) & ~(((1ULL << __fourcc_mod_broadcom_param_bits) - 1) <<   __fourcc_mod_broadcom_param_shift))

  const __fourcc_mod_broadcom_param_shift = 8;
  const __fourcc_mod_broadcom_param_bits = 48;

  inline fn fourcc_mod_broadcom_code(val: u64, params: u64) u64 {
    const code = (params << __fourcc_mod_broadcom_param_shift) | val;
    return fourcc_mod_code(.broadcom, @intCast(code));
  }

  /// AFBC superblock size
  ///
  /// Indicates the superblock size(s) used for the AFBC buffer. The buffer
  /// size (in pixels) must be aligned to a multiple of the superblock size.
  /// Four lowest significant bits(LSBs) are reserved for block size.
  const afbc_block_size_mask: u64 = 0xf;
  const afbc_block_size_16x16: u64 = 1;
  const afbc_block_size_32x8: u64 = 2;
};

const HiLo64 = packed struct (u64) {
  lo: u32,
  hi: u32,
};

const u64_ = base.u64_;
const base = @import("base");
