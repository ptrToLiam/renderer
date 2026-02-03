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
  argb8888,
  abgr8888,
  rgba8888,

  pub fn fromDrmFormat(fmt: Drm.Format) Format {
    return switch (fmt) {
      .abgr8888 => .rgba8888,
      .rgba8888 => .abgr8888,
      else => @panic("Unhandled Drm -> Gfx Format Conversion"),
    };
  }

  pub fn fromVkFormat(fmt: vk.Format) Format {
    return switch (fmt) {
      .r8g8b8a8_unorm => .rgba8888,
      .b8g8r8a8_unorm => .argb8888,
      else => @panic("Unhandled Vk -> Gfx Format Conversion"),
    };
  }

  pub fn toDrmFormat(fmt: Format) Drm.Format {
    return switch (fmt) {
      .rgba8888 => .abgr8888,
      .abgr8888 => .rgba8888,
      else => @panic("Unhandled Gfx -> Drm Format Conversion"),
    };
  }

  pub fn toVkFormat(fmt: Format) vk.Format {
    return switch (fmt) {
      .rgba8888 => .r8g8b8a8_unorm,
      .argb8888 => .b8g8r8a8_unorm,
      else => @panic("Unhandled Gfx -> Vk Format Conversion"),
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

