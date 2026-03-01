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
  xrgb32,   // no alpha, R in high bits memory order: [B,G,R,X]
  xbgr32,   // no alpha, B in high bits memory order: [R,G,B,X]
  rgbx32,   // no alpha, memory order: [X,B,G,R]
  argb32,   // with alpha, memory order: [B,G,R,A]
  abgr32,   // with alpha, memory order: [R,G,B,A]
  rgba32,   // with alpha, memory order: [A,B,G,R]

  pub fn fromDrm(fmt: Drm.Format) ?Format {
    return switch (fmt) {
      .xrgb8888 => .xrgb32,
      .xbgr8888 => .xbgr32,
      .rgbx8888 => .rgbx32,
      .argb8888 => .argb32,
      .abgr8888 => .abgr32,
      .rgba8888 => .rgba32,
      else      => null,
    };
  }

  pub fn fromVk(fmt: vk.Format) ?Format {
    return switch (fmt) {
      .b8g8r8a8_unorm  => .argb32,
      .r8g8b8a8_unorm  => .abgr32,
      .a8b8g8r8_unorm_pack32 => .rgba32,
      else             => null,
    };
  }

  pub fn toDrm(fmt: Format) Drm.Format {
    return switch (fmt) {
      .invalid => .invalid,
      .xrgb32  => .xrgb8888,
      .xbgr32  => .xbgr8888,
      .rgbx32  => .rgbx8888,
      .argb32  => .argb8888,
      .abgr32  => .abgr8888,
      .rgba32  => .rgba8888,
    };
  }

  pub fn toVk(fmt: Format) vk.Format {
    return switch (fmt) {
      .invalid => .undefined,
      .xrgb32  => .b8g8r8a8_unorm,  // X treated as ignored alpha
      .xbgr32  => .r8g8b8a8_unorm,
      .rgbx32  => .a8b8g8r8_unorm_pack32,
      .argb32  => .b8g8r8a8_unorm,
      .abgr32  => .r8g8b8a8_unorm,
      .rgba32  => .a8b8g8r8_unorm_pack32,
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

