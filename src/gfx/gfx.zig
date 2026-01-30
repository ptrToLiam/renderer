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

// Imported Types
const Arena = base.Arena;

// Imported Namespaces
const math = base.math;

// Module Imports
const base = @import("base");
const os = @import("os");

// 3rd-Party Module Imports
const builtin = @import("builtin");

