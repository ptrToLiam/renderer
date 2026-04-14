/// Microsecond timestamp
pub fn microTimestamp() u64 {
  return timestamp_ns() / time.ns_per_us;
}

/// Microseconds since program start
pub fn us() u64 {
  const cur_us = microTimestamp();
  const elapsed_us = cur_us - program_start;
  return elapsed_us;
}

pub fn us_to_ms(micros: u64) u64 {
  return micros / time.us_per_ms;
}

fn timestamp_ns() u64 {
  const ns: u64 = ts: {switch (builtin.os.tag) {
    .linux => {
      var ts: os.linux.timespec = undefined;
      _ = os.linux.clock_gettime(.MONOTONIC, &ts);
      break :ts cast(u64, (ts.sec * time.ns_per_s) + ts.nsec);
    },
    else => {
      @compileError("TODO: Implement timestamp_ns for target");
    },
  }};
  return ns;
}

// Divisions of a nanosecond.
pub const ns_per_us = 1000;
pub const ns_per_ms = 1000 * ns_per_us;
pub const ns_per_s = 1000 * ns_per_ms;
pub const ns_per_min = 60 * ns_per_s;
pub const ns_per_hour = 60 * ns_per_min;
pub const ns_per_day = 24 * ns_per_hour;
pub const ns_per_week = 7 * ns_per_day;

// Divisions of a microsecond.
pub const us_per_ms = 1000;
pub const us_per_s = 1000 * us_per_ms;
pub const us_per_min = 60 * us_per_s;
pub const us_per_hour = 60 * us_per_min;
pub const us_per_day = 24 * us_per_hour;
pub const us_per_week = 7 * us_per_day;

// Divisions of a millisecond.
pub const ms_per_s = 1000;
pub const ms_per_min = 60 * ms_per_s;
pub const ms_per_hour = 60 * ms_per_min;
pub const ms_per_day = 24 * ms_per_hour;
pub const ms_per_week = 7 * ms_per_day;

// Divisions of a second.
pub const s_per_min = 60;
pub const s_per_hour = s_per_min * 60;
pub const s_per_day = s_per_hour * 24;
pub const s_per_week = s_per_day * 7;

/// Time of program start -- assumed initialized in entry.primary
pub var program_start: u64 = undefined;

const cast = casts.cast;
const transmute = casts.transmute;

const base = @import("base.zig");
const casts = @import("casts.zig");

const os = @import("os");
const time = @import("std").time;
const builtin = @import("builtin");
