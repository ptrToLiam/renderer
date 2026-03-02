// Module Re-Exports
pub const Drm = @import("drm.zig");

// General Types
pub const ColorRgba = packed union {
  rgba32: Rgba32,
  uint: u32,

  pub fn rgba32_(r: u8, g: u8, b: u8, a: u8) ColorRgba {
    return .{ .rba32 = .{ .r = r, .g = g, .b = b, .a = a } };
  }

  pub const Rgba32 = packed struct (u32) {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 0,
  };

  pub const black: ColorRgba = rgba32_(0, 0, 0, 0);
  pub const white: ColorRgba = rgba32_(255, 255, 255, 255);
  pub const red: ColorRgba = rgba32_(255, 0, 0, 255);
  pub const blue: ColorRgba = rgba32_(0, 0, 255, 255);
  pub const green: ColorRgba = rgba32_(0, 255, 0, 255);
};

pub const Float4 = packed union {
  xyzw: packed struct (u128) { x: f32, y: f32, z: f32, w: f32 },
  rgba: packed struct (u128) { r: f32, g: f32, b: f32, a: f32 },
  vec: @Vector(4, f32),
};
pub const Format = enum(u32) {
  invalid = 0,
  rgba32,   // vk: r8g8b8a8_unorm,         drm: abgr8888  [A,B,G,R] in memory
  bgra32,   // vk: b8g8r8a8_unorm,         drm: argb8888  [B,G,R,A] in memory
  abgr32,   // vk: a8b8g8r8_unorm_pack32,  drm: rgba8888  [R,G,B,A] in memory
  rgbx32,   // vk: r8g8b8a8_unorm,         drm: xbgr8888  [X,B,G,R] in memory
  bgrx32,   // vk: b8g8r8a8_unorm,         drm: xrgb8888  [B,G,R,X] in memory

  pub fn fromDrm(fmt: Drm.Format) ?Format {
    return switch (fmt) {
      .abgr8888 => .rgba32,
      .argb8888 => .bgra32,
      .rgba8888 => .abgr32,
      .xbgr8888 => .rgbx32,
      .xrgb8888 => .bgrx32,
      else      => null,
    };
  }

  pub fn fromVk(fmt: vk.Format) ?Format {
    return switch (fmt) {
      .r8g8b8a8_unorm        => .rgba32,
      .b8g8r8a8_unorm        => .bgra32,
      .a8b8g8r8_unorm_pack32 => .abgr32,
      else                   => null,
    };
  }

  pub fn toDrm(fmt: Format) Drm.Format {
    return switch (fmt) {
      .invalid => .invalid,
      .rgba32  => .abgr8888,
      .bgra32  => .argb8888,
      .abgr32  => .rgba8888,
      .rgbx32  => .xbgr8888,
      .bgrx32  => .xrgb8888,
    };
  }

  pub fn toVk(fmt: Format) vk.Format {
    return switch (fmt) {
      .invalid => .undefined,
      .rgba32  => .r8g8b8a8_unorm,
      .bgra32  => .b8g8r8a8_unorm,
      .abgr32  => .a8b8g8r8_unorm_pack32,
      .rgbx32  => .r8g8b8a8_unorm,  // x = ignored alpha
      .bgrx32  => .b8g8r8a8_unorm,
    };
  }
};

// Imported Types
const Arena = base.Arena;

// Imported Namespaces
const math = base.math;

// Module Imports
const base = @import("base");
const os = @import("os");
const vk = @import("vulkan");

// 3rd-Party Module Imports
const builtin = @import("builtin");

