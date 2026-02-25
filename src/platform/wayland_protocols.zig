//  This file is generated from provided Wayland XML specifications by
//  wayland-code-generator and should NOT be edited manually.

pub const MessageArg = union(enum) {
  string: [:0]const u8,
  array: []const u8,
  @"enum": Enum,
  new_id: u32,
  object: u32,
  fixed: f32,
  uint: u32,
  int: i32,
  fd: i32,
};

pub const Proxy = struct {
  ctx: *anyopaque,
  vtable: VTable,

  pub fn message_decode(
    noalias proxy: *Proxy,
    noalias args_out: []MessageArg,
    noalias message: []const u8,
  ) void {
    @call(
      .auto,
      proxy.vtable.message_decode,
      .{ proxy.ctx, args_out, message },
    );
  }

  pub fn message_encode(
    noalias proxy: *Proxy,
    id: u32,
    opcode: u16,
    noalias args: []const ?MessageArg,
  ) void {
    @call(
      .auto,
      proxy.vtable.message_encode,
      .{ proxy.ctx, id, opcode, args },
    );
  }

  pub fn get_id(
    proxy: *Proxy,
  ) u32 {
    return @call(
      .auto,
      proxy.vtable.get_id,
      .{ proxy.ctx },
    );
  }

  pub fn put_object(
    proxy: *Proxy,
    object: Object,
  ) void {
    @call(
      .auto,
      proxy.vtable.put_object,
      .{ proxy.ctx, object },
    );
  }

  pub fn destroy_object(
    proxy: *Proxy,
    object_id: u32,
  ) void {
    @call(
      .auto,
      proxy.vtable.destroy_object,
      .{ proxy.ctx, object_id },
    );
  }

  const VTable = struct {
    message_decode: MessageDecodeFn,
    message_encode: MessageEncodeFn,
    get_id: GetIdFn,
    put_object: PutObjectFn,
    destroy_object: DestroyObjectFn,
  };
};

pub const MessageDecodeFn = *const fn (
  noalias ctx: *anyopaque,
  args_out: []MessageArg,
  noalias message: []const u8
) void;

pub const MessageEncodeFn = *const fn (
  noalias ctx: *anyopaque,
  id: u32,
  opcode: u16,
  noalias args: []const ?MessageArg,
) void;

pub const GetIdFn = *const fn (
  noalias ctx: *anyopaque,
) u32;

pub const PutObjectFn = *const fn (
  noalias ctx: *anyopaque,
  object: Object,
) void;

pub const DestroyObjectFn = *const fn (
  noalias ctx: *anyopaque,
  object_id: u32,
) void;

pub fn BitfieldMixin(comptime T: type) type {
  const int_type = @typeInfo(T).@"struct".backing_integer.?;

  return struct {
    pub fn toInt(self: T) Int {
      return @bitCast(self);
    }
    pub fn fromInt(int: Int) T {
      return @bitCast(int);
    }
    pub fn not(self: T) T {
      return fromInt(~toInt(self));
    }

    pub fn either(a: T, b: T) T {
      return fromInt(toInt(a) | toInt(b));
    }
    pub fn both(a: T, b: T) T {
      return fromInt(toInt(a) & toInt(b));
    }
    pub fn eql(a: T, b: T) bool {
      return fromInt(a) == fromInt(b);
    }
    pub fn contains(a: T, b: T) bool {
      return toInt(both(a, b)) == toInt(b);
    }
    pub const Int = int_type;
  };
}

//-----------------------------------------------------------------------------
// BEGIN Protocol linux_dmabuf_v1
//-----------------------------------------------------------------------------

pub const zwp_linux_dmabuf_v1 = enum (u32) {
  _,

  pub fn object(self: zwp_linux_dmabuf_v1) Object {
    return .{ .zwp_linux_dmabuf_v1 = self };
  }

  pub fn toInt(self: zwp_linux_dmabuf_v1) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) zwp_linux_dmabuf_v1 {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN zwp_linux_dmabuf_v1 MESSAGES
  //---------------------------------------------------------------------------

  pub fn destroy(
    noalias self: *const zwp_linux_dmabuf_v1,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn create_params(
    noalias self: *const zwp_linux_dmabuf_v1,
    noalias proxy: *Proxy,
  ) zwp_linux_buffer_params_v1 {
    const Opcode = 1;
    const result: zwp_linux_buffer_params_v1 = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .new_id = result.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }

  pub fn get_default_feedback(
    noalias self: *const zwp_linux_dmabuf_v1,
    noalias proxy: *Proxy,
  ) zwp_linux_dmabuf_feedback_v1 {
    const Opcode = 2;
    const result: zwp_linux_dmabuf_feedback_v1 = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .new_id = result.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }

  pub fn get_surface_feedback(
    noalias self: *const zwp_linux_dmabuf_v1,
    noalias proxy: *Proxy,
    surface: wl_surface,
  ) zwp_linux_dmabuf_feedback_v1 {
    const Opcode = 3;
    const result: zwp_linux_dmabuf_feedback_v1 = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .new_id = result.toInt() },
        .{ .object = surface.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }

  pub const format = struct {
    format: u32,
  };

  pub const modifier = struct {
    format: u32,
    modifier_hi: u32,
    modifier_lo: u32,
  };

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .zwp_linux_dmabuf_v1_format = .{
              .format = args_in[0].uint,
            }
          };
        },
        1 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .uint = undefined },
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .zwp_linux_dmabuf_v1_modifier = .{
              .format = args_in[0].uint,
              .modifier_hi = args_in[1].uint,
              .modifier_lo = args_in[2].uint,
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  pub const Name = "zwp_linux_dmabuf_v1";
  pub const Version = 5;
};

pub const zwp_linux_buffer_params_v1 = enum (u32) {
  _,

  pub fn object(self: zwp_linux_buffer_params_v1) Object {
    return .{ .zwp_linux_buffer_params_v1 = self };
  }

  pub fn toInt(self: zwp_linux_buffer_params_v1) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) zwp_linux_buffer_params_v1 {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN zwp_linux_buffer_params_v1 MESSAGES
  //---------------------------------------------------------------------------

  pub fn destroy(
    noalias self: *const zwp_linux_buffer_params_v1,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn add(
    noalias self: *const zwp_linux_buffer_params_v1,
    noalias proxy: *Proxy,
    fd: c_int,
    plane_idx: u32,
    offset: u32,
    stride: u32,
    modifier_hi: u32,
    modifier_lo: u32,
  ) void {
    const Opcode = 1;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .fd = fd },
        .{ .uint = plane_idx },
        .{ .uint = offset },
        .{ .uint = stride },
        .{ .uint = modifier_hi },
        .{ .uint = modifier_lo },
      },
    );
  }

  pub fn create(
    noalias self: *const zwp_linux_buffer_params_v1,
    noalias proxy: *Proxy,
    width: i32,
    height: i32,
    format: u32,
    flags: Flags,
  ) void {
    const Opcode = 2;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .int = width },
        .{ .int = height },
        .{ .uint = format },
        .{ .uint = flags.toInt() },
      },
    );
  }

  pub fn create_immed(
    noalias self: *const zwp_linux_buffer_params_v1,
    noalias proxy: *Proxy,
    width: i32,
    height: i32,
    format: u32,
    flags: Flags,
  ) wl_buffer {
    const Opcode = 3;
    const result: wl_buffer = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .new_id = result.toInt() },
        .{ .int = width },
        .{ .int = height },
        .{ .uint = format },
        .{ .uint = flags.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }

  pub const created = struct {
    buffer: u32,
  };

  pub const failed = void;

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
            .{ .new_id = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .zwp_linux_buffer_params_v1_created = .{
              .buffer = args_in[0].new_id,
            }
          };
        },
        1 => {
          var args_in = [_]MessageArg{
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .zwp_linux_buffer_params_v1_failed = {
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN zwp_linux_buffer_params_v1 ENUMS
  //---------------------------------------------------------------------------

  pub const Error = enum (u32) {
    already_used = 0,
    plane_idx = 1,
    plane_set = 2,
    incomplete = 3,
    invalid_format = 4,
    invalid_dimensions = 5,
    out_of_bounds = 6,
    invalid_wl_buffer = 7,

    pub fn toInt(self: Error) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Error {
      return @enumFromInt(int);
    }
  };

  pub const Flags = packed struct (u32) {
    y_invert: bool = false,
    interlaced: bool = false,
    bottom_first: bool = false,

    __reserved_bits: u29 = 0,

    pub const toInt = Mixin.toInt;
    pub const fromInt = Mixin.fromInt;
    pub const not = Mixin.not;
    pub const either = Mixin.either;
    pub const both = Mixin.both;
    pub const eql = Mixin.eql;
    pub const contains = Mixin.contains;

    const Mixin = BitfieldMixin(@This());
  };
  //---------------------------------------------------------------------------

  pub const Name = "zwp_linux_buffer_params_v1";
  pub const Version = 5;
};

pub const zwp_linux_dmabuf_feedback_v1 = enum (u32) {
  _,

  pub fn object(self: zwp_linux_dmabuf_feedback_v1) Object {
    return .{ .zwp_linux_dmabuf_feedback_v1 = self };
  }

  pub fn toInt(self: zwp_linux_dmabuf_feedback_v1) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) zwp_linux_dmabuf_feedback_v1 {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN zwp_linux_dmabuf_feedback_v1 MESSAGES
  //---------------------------------------------------------------------------

  pub fn destroy(
    noalias self: *const zwp_linux_dmabuf_feedback_v1,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub const done = void;

  pub const format_table = struct {
    fd: c_int,
    size: u32,
  };

  pub const main_device = struct {
    device: []const u8,
  };

  pub const tranche_done = void;

  pub const tranche_target_device = struct {
    device: []const u8,
  };

  pub const tranche_formats = struct {
    indices: []const u8,
  };

  pub const tranche_flags = struct {
    flags: TrancheFlags,
  };

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .zwp_linux_dmabuf_feedback_v1_done = {
            }
          };
        },
        1 => {
          var args_in = [_]MessageArg{
            .{ .fd = undefined },
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .zwp_linux_dmabuf_feedback_v1_format_table = .{
              .fd = args_in[0].fd,
              .size = args_in[1].uint,
            }
          };
        },
        2 => {
          var args_in = [_]MessageArg{
            .{ .array = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .zwp_linux_dmabuf_feedback_v1_main_device = .{
              .device = args_in[0].array,
            }
          };
        },
        3 => {
          var args_in = [_]MessageArg{
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .zwp_linux_dmabuf_feedback_v1_tranche_done = {
            }
          };
        },
        4 => {
          var args_in = [_]MessageArg{
            .{ .array = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .zwp_linux_dmabuf_feedback_v1_tranche_target_device = .{
              .device = args_in[0].array,
            }
          };
        },
        5 => {
          var args_in = [_]MessageArg{
            .{ .array = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .zwp_linux_dmabuf_feedback_v1_tranche_formats = .{
              .indices = args_in[0].array,
            }
          };
        },
        6 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .zwp_linux_dmabuf_feedback_v1_tranche_flags = .{
              .flags = .fromInt(args_in[0].uint),
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN zwp_linux_dmabuf_feedback_v1 ENUMS
  //---------------------------------------------------------------------------

  pub const TrancheFlags = packed struct (u32) {
    scanout: bool = false,

    __reserved_bits: u31 = 0,

    pub const toInt = Mixin.toInt;
    pub const fromInt = Mixin.fromInt;
    pub const not = Mixin.not;
    pub const either = Mixin.either;
    pub const both = Mixin.both;
    pub const eql = Mixin.eql;
    pub const contains = Mixin.contains;

    const Mixin = BitfieldMixin(@This());
  };
  //---------------------------------------------------------------------------

  pub const Name = "zwp_linux_dmabuf_feedback_v1";
  pub const Version = 5;
};

//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// BEGIN Protocol presentation_time
//-----------------------------------------------------------------------------

pub const wp_presentation = enum (u32) {
  _,

  pub fn object(self: wp_presentation) Object {
    return .{ .wp_presentation = self };
  }

  pub fn toInt(self: wp_presentation) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wp_presentation {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wp_presentation MESSAGES
  //---------------------------------------------------------------------------

  pub fn destroy(
    noalias self: *const wp_presentation,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn feedback(
    noalias self: *const wp_presentation,
    noalias proxy: *Proxy,
    surface: wl_surface,
  ) wp_presentation_feedback {
    const Opcode = 1;
    const result: wp_presentation_feedback = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .object = surface.toInt() },
        .{ .new_id = result.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }

  pub const clock_id = struct {
    clk_id: u32,
  };

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wp_presentation_clock_id = .{
              .clk_id = args_in[0].uint,
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN wp_presentation ENUMS
  //---------------------------------------------------------------------------

  pub const Error = enum (u32) {
    invalid_timestamp = 0,
    invalid_flag = 1,

    pub fn toInt(self: Error) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Error {
      return @enumFromInt(int);
    }
  };
  //---------------------------------------------------------------------------

  pub const Name = "wp_presentation";
  pub const Version = 2;
};

pub const wp_presentation_feedback = enum (u32) {
  _,

  pub fn object(self: wp_presentation_feedback) Object {
    return .{ .wp_presentation_feedback = self };
  }

  pub fn toInt(self: wp_presentation_feedback) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wp_presentation_feedback {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wp_presentation_feedback MESSAGES
  //---------------------------------------------------------------------------

  pub const sync_output = struct {
    output: wl_output,
  };

  pub const presented = struct {
    tv_sec_hi: u32,
    tv_sec_lo: u32,
    tv_nsec: u32,
    refresh: u32,
    seq_hi: u32,
    seq_lo: u32,
    flags: Kind,
  };

  pub const discarded = void;

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
            .{ .object = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wp_presentation_feedback_sync_output = .{
              .output = .fromInt(args_in[0].object),
            }
          };
        },
        1 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .uint = undefined },
            .{ .uint = undefined },
            .{ .uint = undefined },
            .{ .uint = undefined },
            .{ .uint = undefined },
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wp_presentation_feedback_presented = .{
              .tv_sec_hi = args_in[0].uint,
              .tv_sec_lo = args_in[1].uint,
              .tv_nsec = args_in[2].uint,
              .refresh = args_in[3].uint,
              .seq_hi = args_in[4].uint,
              .seq_lo = args_in[5].uint,
              .flags = .fromInt(args_in[6].uint),
            }
          };
        },
        2 => {
          var args_in = [_]MessageArg{
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wp_presentation_feedback_discarded = {
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN wp_presentation_feedback ENUMS
  //---------------------------------------------------------------------------

  pub const Kind = packed struct (u32) {
    vsync: bool = false,
    hw_clock: bool = false,
    hw_completion: bool = false,
    zero_copy: bool = false,

    __reserved_bits: u28 = 0,

    pub const toInt = Mixin.toInt;
    pub const fromInt = Mixin.fromInt;
    pub const not = Mixin.not;
    pub const either = Mixin.either;
    pub const both = Mixin.both;
    pub const eql = Mixin.eql;
    pub const contains = Mixin.contains;

    const Mixin = BitfieldMixin(@This());
  };
  //---------------------------------------------------------------------------

  pub const Name = "wp_presentation_feedback";
  pub const Version = 2;
};

//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// BEGIN Protocol wayland
//-----------------------------------------------------------------------------

pub const wl_display = enum (u32) {
  _,

  pub fn object(self: wl_display) Object {
    return .{ .wl_display = self };
  }

  pub fn toInt(self: wl_display) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wl_display {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wl_display MESSAGES
  //---------------------------------------------------------------------------

  pub fn sync(
    noalias self: *const wl_display,
    noalias proxy: *Proxy,
  ) wl_callback {
    const Opcode = 0;
    const result: wl_callback = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .new_id = result.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }

  pub fn get_registry(
    noalias self: *const wl_display,
    noalias proxy: *Proxy,
  ) wl_registry {
    const Opcode = 1;
    const result: wl_registry = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .new_id = result.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }

  pub const @"error" = struct {
    object_id: u32,
    code: u32,
    message: [:0]const u8,
  };

  pub const delete_id = struct {
    id: u32,
  };

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
            .{ .object = undefined },
            .{ .uint = undefined },
            .{ .string = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_display_error = .{
              .object_id = args_in[0].object,
              .code = args_in[1].uint,
              .message = args_in[2].string,
            }
          };
        },
        1 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_display_delete_id = .{
              .id = args_in[0].uint,
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN wl_display ENUMS
  //---------------------------------------------------------------------------

  pub const Error = enum (u32) {
    invalid_object = 0,
    invalid_method = 1,
    no_memory = 2,
    implementation = 3,

    pub fn toInt(self: Error) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Error {
      return @enumFromInt(int);
    }
  };
  //---------------------------------------------------------------------------

  pub const Name = "wl_display";
  pub const Version = 1;
};

pub const wl_registry = enum (u32) {
  _,

  pub fn object(self: wl_registry) Object {
    return .{ .wl_registry = self };
  }

  pub fn toInt(self: wl_registry) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wl_registry {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wl_registry MESSAGES
  //---------------------------------------------------------------------------

  pub fn bind(
    noalias self: *const wl_registry,
    noalias proxy: *Proxy,
    name: u32,
    InterfaceT: type,
    version: u32,
  ) InterfaceT {
    const Opcode = 0;
    const result: InterfaceT = .fromInt(proxy.get_id());

    if (InterfaceT.Version != version) {
      log.warn(
        "Interface {s} version mismatch :: Client expects v{} — Compositor has v{}",
        .{
          InterfaceT.Name,
          InterfaceT.Version,
          version,
        },
      );
    }
    const selected_version = @min(InterfaceT.Version, version);
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .uint = name },
        .{ .string = InterfaceT.Name },
        .{ .uint = selected_version },
        .{ .new_id = result.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }

  pub const global = struct {
    name: u32,
    interface: [:0]const u8,
    version: u32,
  };

  pub const global_remove = struct {
    name: u32,
  };

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .string = undefined },
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_registry_global = .{
              .name = args_in[0].uint,
              .interface = args_in[1].string,
              .version = args_in[2].uint,
            }
          };
        },
        1 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_registry_global_remove = .{
              .name = args_in[0].uint,
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  pub const Name = "wl_registry";
  pub const Version = 1;
};

pub const wl_callback = enum (u32) {
  _,

  pub fn object(self: wl_callback) Object {
    return .{ .wl_callback = self };
  }

  pub fn toInt(self: wl_callback) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wl_callback {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wl_callback MESSAGES
  //---------------------------------------------------------------------------

  pub const done = struct {
    callback_data: u32,
  };

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_callback_done = .{
              .callback_data = args_in[0].uint,
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  pub const Name = "wl_callback";
  pub const Version = 1;
};

pub const wl_compositor = enum (u32) {
  _,

  pub fn object(self: wl_compositor) Object {
    return .{ .wl_compositor = self };
  }

  pub fn toInt(self: wl_compositor) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wl_compositor {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wl_compositor MESSAGES
  //---------------------------------------------------------------------------

  pub fn create_surface(
    noalias self: *const wl_compositor,
    noalias proxy: *Proxy,
  ) wl_surface {
    const Opcode = 0;
    const result: wl_surface = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .new_id = result.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }

  pub fn create_region(
    noalias self: *const wl_compositor,
    noalias proxy: *Proxy,
  ) wl_region {
    const Opcode = 1;
    const result: wl_region = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .new_id = result.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }
  //---------------------------------------------------------------------------

  pub const Name = "wl_compositor";
  pub const Version = 6;
};

pub const wl_shm_pool = enum (u32) {
  _,

  pub fn object(self: wl_shm_pool) Object {
    return .{ .wl_shm_pool = self };
  }

  pub fn toInt(self: wl_shm_pool) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wl_shm_pool {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wl_shm_pool MESSAGES
  //---------------------------------------------------------------------------

  pub fn create_buffer(
    noalias self: *const wl_shm_pool,
    noalias proxy: *Proxy,
    offset: i32,
    width: i32,
    height: i32,
    stride: i32,
    format: wl_shm.Format,
  ) wl_buffer {
    const Opcode = 0;
    const result: wl_buffer = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .new_id = result.toInt() },
        .{ .int = offset },
        .{ .int = width },
        .{ .int = height },
        .{ .int = stride },
        .{ .uint = format.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }

  pub fn destroy(
    noalias self: *const wl_shm_pool,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 1;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn resize(
    noalias self: *const wl_shm_pool,
    noalias proxy: *Proxy,
    size: i32,
  ) void {
    const Opcode = 2;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .int = size },
      },
    );
  }
  //---------------------------------------------------------------------------

  pub const Name = "wl_shm_pool";
  pub const Version = 2;
};

pub const wl_shm = enum (u32) {
  _,

  pub fn object(self: wl_shm) Object {
    return .{ .wl_shm = self };
  }

  pub fn toInt(self: wl_shm) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wl_shm {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wl_shm MESSAGES
  //---------------------------------------------------------------------------

  pub fn create_pool(
    noalias self: *const wl_shm,
    noalias proxy: *Proxy,
    fd: c_int,
    size: i32,
  ) wl_shm_pool {
    const Opcode = 0;
    const result: wl_shm_pool = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .new_id = result.toInt() },
        .{ .fd = fd },
        .{ .int = size },
      },
    );

    proxy.put_object(result.object());
    return result;
  }

  pub fn release(
    noalias self: *const wl_shm,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 1;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub const format = struct {
    format: Format,
  };

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_shm_format = .{
              .format = .fromInt(args_in[0].uint),
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN wl_shm ENUMS
  //---------------------------------------------------------------------------

  pub const Error = enum (u32) {
    invalid_format = 0,
    invalid_stride = 1,
    invalid_fd = 2,

    pub fn toInt(self: Error) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Error {
      return @enumFromInt(int);
    }
  };

  pub const Format = enum (u32) {
    argb8888 = 0,
    xrgb8888 = 1,
    c8 = 0x20203843,
    rgb332 = 0x38424752,
    bgr233 = 0x38524742,
    xrgb4444 = 0x32315258,
    xbgr4444 = 0x32314258,
    rgbx4444 = 0x32315852,
    bgrx4444 = 0x32315842,
    argb4444 = 0x32315241,
    abgr4444 = 0x32314241,
    rgba4444 = 0x32314152,
    bgra4444 = 0x32314142,
    xrgb1555 = 0x35315258,
    xbgr1555 = 0x35314258,
    rgbx5551 = 0x35315852,
    bgrx5551 = 0x35315842,
    argb1555 = 0x35315241,
    abgr1555 = 0x35314241,
    rgba5551 = 0x35314152,
    bgra5551 = 0x35314142,
    rgb565 = 0x36314752,
    bgr565 = 0x36314742,
    rgb888 = 0x34324752,
    bgr888 = 0x34324742,
    xbgr8888 = 0x34324258,
    rgbx8888 = 0x34325852,
    bgrx8888 = 0x34325842,
    abgr8888 = 0x34324241,
    rgba8888 = 0x34324152,
    bgra8888 = 0x34324142,
    xrgb2101010 = 0x30335258,
    xbgr2101010 = 0x30334258,
    rgbx1010102 = 0x30335852,
    bgrx1010102 = 0x30335842,
    argb2101010 = 0x30335241,
    abgr2101010 = 0x30334241,
    rgba1010102 = 0x30334152,
    bgra1010102 = 0x30334142,
    yuyv = 0x56595559,
    yvyu = 0x55595659,
    uyvy = 0x59565955,
    vyuy = 0x59555956,
    ayuv = 0x56555941,
    nv12 = 0x3231564e,
    nv21 = 0x3132564e,
    nv16 = 0x3631564e,
    nv61 = 0x3136564e,
    yuv410 = 0x39565559,
    yvu410 = 0x39555659,
    yuv411 = 0x31315559,
    yvu411 = 0x31315659,
    yuv420 = 0x32315559,
    yvu420 = 0x32315659,
    yuv422 = 0x36315559,
    yvu422 = 0x36315659,
    yuv444 = 0x34325559,
    yvu444 = 0x34325659,
    r8 = 0x20203852,
    r16 = 0x20363152,
    rg88 = 0x38384752,
    gr88 = 0x38385247,
    rg1616 = 0x32334752,
    gr1616 = 0x32335247,
    xrgb16161616f = 0x48345258,
    xbgr16161616f = 0x48344258,
    argb16161616f = 0x48345241,
    abgr16161616f = 0x48344241,
    xyuv8888 = 0x56555958,
    vuy888 = 0x34325556,
    vuy101010 = 0x30335556,
    y210 = 0x30313259,
    y212 = 0x32313259,
    y216 = 0x36313259,
    y410 = 0x30313459,
    y412 = 0x32313459,
    y416 = 0x36313459,
    xvyu2101010 = 0x30335658,
    xvyu12_16161616 = 0x36335658,
    xvyu16161616 = 0x38345658,
    y0l0 = 0x304c3059,
    x0l0 = 0x304c3058,
    y0l2 = 0x324c3059,
    x0l2 = 0x324c3058,
    yuv420_8bit = 0x38305559,
    yuv420_10bit = 0x30315559,
    xrgb8888_a8 = 0x38415258,
    xbgr8888_a8 = 0x38414258,
    rgbx8888_a8 = 0x38415852,
    bgrx8888_a8 = 0x38415842,
    rgb888_a8 = 0x38413852,
    bgr888_a8 = 0x38413842,
    rgb565_a8 = 0x38413552,
    bgr565_a8 = 0x38413542,
    nv24 = 0x3432564e,
    nv42 = 0x3234564e,
    p210 = 0x30313250,
    p010 = 0x30313050,
    p012 = 0x32313050,
    p016 = 0x36313050,
    axbxgxrx106106106106 = 0x30314241,
    nv15 = 0x3531564e,
    q410 = 0x30313451,
    q401 = 0x31303451,
    xrgb16161616 = 0x38345258,
    xbgr16161616 = 0x38344258,
    argb16161616 = 0x38345241,
    abgr16161616 = 0x38344241,
    c1 = 0x20203143,
    c2 = 0x20203243,
    c4 = 0x20203443,
    d1 = 0x20203144,
    d2 = 0x20203244,
    d4 = 0x20203444,
    d8 = 0x20203844,
    r1 = 0x20203152,
    r2 = 0x20203252,
    r4 = 0x20203452,
    r10 = 0x20303152,
    r12 = 0x20323152,
    avuy8888 = 0x59555641,
    xvuy8888 = 0x59555658,
    p030 = 0x30333050,
    rgb161616 = 0x38344752,
    bgr161616 = 0x38344742,
    r16f = 0x48202052,
    gr1616f = 0x48205247,
    bgr161616f = 0x48524742,
    r32f = 0x46202052,
    gr3232f = 0x46205247,
    bgr323232f = 0x46524742,
    abgr32323232f = 0x46384241,
    nv20 = 0x3032564e,
    nv30 = 0x3033564e,
    s010 = 0x30313053,
    s210 = 0x30313253,
    s410 = 0x30313453,
    s012 = 0x32313053,
    s212 = 0x32313253,
    s412 = 0x32313453,
    s016 = 0x36313053,
    s216 = 0x36313253,
    s416 = 0x36313453,

    pub fn toInt(self: Format) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Format {
      return @enumFromInt(int);
    }
  };
  //---------------------------------------------------------------------------

  pub const Name = "wl_shm";
  pub const Version = 2;
};

pub const wl_buffer = enum (u32) {
  _,

  pub fn object(self: wl_buffer) Object {
    return .{ .wl_buffer = self };
  }

  pub fn toInt(self: wl_buffer) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wl_buffer {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wl_buffer MESSAGES
  //---------------------------------------------------------------------------

  pub fn destroy(
    noalias self: *const wl_buffer,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub const release = void;

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_buffer_release = {
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  pub const Name = "wl_buffer";
  pub const Version = 1;
};

pub const wl_data_offer = enum (u32) {
  _,

  pub fn object(self: wl_data_offer) Object {
    return .{ .wl_data_offer = self };
  }

  pub fn toInt(self: wl_data_offer) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wl_data_offer {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wl_data_offer MESSAGES
  //---------------------------------------------------------------------------

  pub fn accept(
    noalias self: *const wl_data_offer,
    noalias proxy: *Proxy,
    serial: u32,
    mime_type: [:0]const u8,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .uint = serial },
        .{ .string = mime_type },
      },
    );
  }

  pub fn receive(
    noalias self: *const wl_data_offer,
    noalias proxy: *Proxy,
    mime_type: [:0]const u8,
    fd: c_int,
  ) void {
    const Opcode = 1;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .string = mime_type },
        .{ .fd = fd },
      },
    );
  }

  pub fn destroy(
    noalias self: *const wl_data_offer,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 2;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn finish(
    noalias self: *const wl_data_offer,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 3;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn set_actions(
    noalias self: *const wl_data_offer,
    noalias proxy: *Proxy,
    dnd_actions: wl_data_device_manager.DndAction,
    preferred_action: wl_data_device_manager.DndAction,
  ) void {
    const Opcode = 4;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .uint = dnd_actions.toInt() },
        .{ .uint = preferred_action.toInt() },
      },
    );
  }

  pub const offer = struct {
    mime_type: [:0]const u8,
  };

  pub const source_actions = struct {
    source_actions: wl_data_device_manager.DndAction,
  };

  pub const action = struct {
    dnd_action: wl_data_device_manager.DndAction,
  };

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
            .{ .string = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_data_offer_offer = .{
              .mime_type = args_in[0].string,
            }
          };
        },
        1 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_data_offer_source_actions = .{
              .source_actions = .fromInt(args_in[0].uint),
            }
          };
        },
        2 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_data_offer_action = .{
              .dnd_action = .fromInt(args_in[0].uint),
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN wl_data_offer ENUMS
  //---------------------------------------------------------------------------

  pub const Error = enum (u32) {
    invalid_finish = 0,
    invalid_action_mask = 1,
    invalid_action = 2,
    invalid_offer = 3,

    pub fn toInt(self: Error) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Error {
      return @enumFromInt(int);
    }
  };
  //---------------------------------------------------------------------------

  pub const Name = "wl_data_offer";
  pub const Version = 3;
};

pub const wl_data_source = enum (u32) {
  _,

  pub fn object(self: wl_data_source) Object {
    return .{ .wl_data_source = self };
  }

  pub fn toInt(self: wl_data_source) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wl_data_source {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wl_data_source MESSAGES
  //---------------------------------------------------------------------------

  pub fn offer(
    noalias self: *const wl_data_source,
    noalias proxy: *Proxy,
    mime_type: [:0]const u8,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .string = mime_type },
      },
    );
  }

  pub fn destroy(
    noalias self: *const wl_data_source,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 1;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn set_actions(
    noalias self: *const wl_data_source,
    noalias proxy: *Proxy,
    dnd_actions: wl_data_device_manager.DndAction,
  ) void {
    const Opcode = 2;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .uint = dnd_actions.toInt() },
      },
    );
  }

  pub const target = struct {
    mime_type: [:0]const u8,
  };

  pub const send = struct {
    mime_type: [:0]const u8,
    fd: c_int,
  };

  pub const cancelled = void;

  pub const dnd_drop_performed = void;

  pub const dnd_finished = void;

  pub const action = struct {
    dnd_action: wl_data_device_manager.DndAction,
  };

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
            .{ .string = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_data_source_target = .{
              .mime_type = args_in[0].string,
            }
          };
        },
        1 => {
          var args_in = [_]MessageArg{
            .{ .string = undefined },
            .{ .fd = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_data_source_send = .{
              .mime_type = args_in[0].string,
              .fd = args_in[1].fd,
            }
          };
        },
        2 => {
          var args_in = [_]MessageArg{
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_data_source_cancelled = {
            }
          };
        },
        3 => {
          var args_in = [_]MessageArg{
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_data_source_dnd_drop_performed = {
            }
          };
        },
        4 => {
          var args_in = [_]MessageArg{
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_data_source_dnd_finished = {
            }
          };
        },
        5 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_data_source_action = .{
              .dnd_action = .fromInt(args_in[0].uint),
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN wl_data_source ENUMS
  //---------------------------------------------------------------------------

  pub const Error = enum (u32) {
    invalid_action_mask = 0,
    invalid_source = 1,

    pub fn toInt(self: Error) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Error {
      return @enumFromInt(int);
    }
  };
  //---------------------------------------------------------------------------

  pub const Name = "wl_data_source";
  pub const Version = 3;
};

pub const wl_data_device = enum (u32) {
  _,

  pub fn object(self: wl_data_device) Object {
    return .{ .wl_data_device = self };
  }

  pub fn toInt(self: wl_data_device) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wl_data_device {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wl_data_device MESSAGES
  //---------------------------------------------------------------------------

  pub fn start_drag(
    noalias self: *const wl_data_device,
    noalias proxy: *Proxy,
    source: wl_data_source,
    origin: wl_surface,
    icon: wl_surface,
    serial: u32,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .object = source.toInt() },
        .{ .object = origin.toInt() },
        .{ .object = icon.toInt() },
        .{ .uint = serial },
      },
    );
  }

  pub fn set_selection(
    noalias self: *const wl_data_device,
    noalias proxy: *Proxy,
    source: wl_data_source,
    serial: u32,
  ) void {
    const Opcode = 1;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .object = source.toInt() },
        .{ .uint = serial },
      },
    );
  }

  pub fn release(
    noalias self: *const wl_data_device,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 2;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub const data_offer = struct {
    id: u32,
  };

  pub const enter = struct {
    serial: u32,
    surface: wl_surface,
    x: f32,
    y: f32,
    id: wl_data_offer,
  };

  pub const leave = void;

  pub const motion = struct {
    time: u32,
    x: f32,
    y: f32,
  };

  pub const drop = void;

  pub const selection = struct {
    id: wl_data_offer,
  };

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
            .{ .new_id = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_data_device_data_offer = .{
              .id = args_in[0].new_id,
            }
          };
        },
        1 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .object = undefined },
            .{ .fixed = undefined },
            .{ .fixed = undefined },
            .{ .object = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_data_device_enter = .{
              .serial = args_in[0].uint,
              .surface = .fromInt(args_in[1].object),
              .x = args_in[2].fixed,
              .y = args_in[3].fixed,
              .id = .fromInt(args_in[4].object),
            }
          };
        },
        2 => {
          var args_in = [_]MessageArg{
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_data_device_leave = {
            }
          };
        },
        3 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .fixed = undefined },
            .{ .fixed = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_data_device_motion = .{
              .time = args_in[0].uint,
              .x = args_in[1].fixed,
              .y = args_in[2].fixed,
            }
          };
        },
        4 => {
          var args_in = [_]MessageArg{
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_data_device_drop = {
            }
          };
        },
        5 => {
          var args_in = [_]MessageArg{
            .{ .object = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_data_device_selection = .{
              .id = .fromInt(args_in[0].object),
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN wl_data_device ENUMS
  //---------------------------------------------------------------------------

  pub const Error = enum (u32) {
    role = 0,
    used_source = 1,

    pub fn toInt(self: Error) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Error {
      return @enumFromInt(int);
    }
  };
  //---------------------------------------------------------------------------

  pub const Name = "wl_data_device";
  pub const Version = 3;
};

pub const wl_data_device_manager = enum (u32) {
  _,

  pub fn object(self: wl_data_device_manager) Object {
    return .{ .wl_data_device_manager = self };
  }

  pub fn toInt(self: wl_data_device_manager) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wl_data_device_manager {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wl_data_device_manager MESSAGES
  //---------------------------------------------------------------------------

  pub fn create_data_source(
    noalias self: *const wl_data_device_manager,
    noalias proxy: *Proxy,
  ) wl_data_source {
    const Opcode = 0;
    const result: wl_data_source = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .new_id = result.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }

  pub fn get_data_device(
    noalias self: *const wl_data_device_manager,
    noalias proxy: *Proxy,
    seat: wl_seat,
  ) wl_data_device {
    const Opcode = 1;
    const result: wl_data_device = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .new_id = result.toInt() },
        .{ .object = seat.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN wl_data_device_manager ENUMS
  //---------------------------------------------------------------------------

  pub const DndAction = packed struct (u32) {
    none: bool = false,
    copy: bool = false,
    move: bool = false,
    ask: bool = false,

    __reserved_bits: u28 = 0,

    pub const toInt = Mixin.toInt;
    pub const fromInt = Mixin.fromInt;
    pub const not = Mixin.not;
    pub const either = Mixin.either;
    pub const both = Mixin.both;
    pub const eql = Mixin.eql;
    pub const contains = Mixin.contains;

    const Mixin = BitfieldMixin(@This());
  };
  //---------------------------------------------------------------------------

  pub const Name = "wl_data_device_manager";
  pub const Version = 3;
};

pub const wl_shell = enum (u32) {
  _,

  pub fn object(self: wl_shell) Object {
    return .{ .wl_shell = self };
  }

  pub fn toInt(self: wl_shell) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wl_shell {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wl_shell MESSAGES
  //---------------------------------------------------------------------------

  pub fn get_shell_surface(
    noalias self: *const wl_shell,
    noalias proxy: *Proxy,
    surface: wl_surface,
  ) wl_shell_surface {
    const Opcode = 0;
    const result: wl_shell_surface = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .new_id = result.toInt() },
        .{ .object = surface.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN wl_shell ENUMS
  //---------------------------------------------------------------------------

  pub const Error = enum (u32) {
    role = 0,

    pub fn toInt(self: Error) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Error {
      return @enumFromInt(int);
    }
  };
  //---------------------------------------------------------------------------

  pub const Name = "wl_shell";
  pub const Version = 1;
};

pub const wl_shell_surface = enum (u32) {
  _,

  pub fn object(self: wl_shell_surface) Object {
    return .{ .wl_shell_surface = self };
  }

  pub fn toInt(self: wl_shell_surface) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wl_shell_surface {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wl_shell_surface MESSAGES
  //---------------------------------------------------------------------------

  pub fn pong(
    noalias self: *const wl_shell_surface,
    noalias proxy: *Proxy,
    serial: u32,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .uint = serial },
      },
    );
  }

  pub fn move(
    noalias self: *const wl_shell_surface,
    noalias proxy: *Proxy,
    seat: wl_seat,
    serial: u32,
  ) void {
    const Opcode = 1;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .object = seat.toInt() },
        .{ .uint = serial },
      },
    );
  }

  pub fn resize(
    noalias self: *const wl_shell_surface,
    noalias proxy: *Proxy,
    seat: wl_seat,
    serial: u32,
    edges: Resize,
  ) void {
    const Opcode = 2;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .object = seat.toInt() },
        .{ .uint = serial },
        .{ .uint = edges.toInt() },
      },
    );
  }

  pub fn set_toplevel(
    noalias self: *const wl_shell_surface,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 3;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn set_transient(
    noalias self: *const wl_shell_surface,
    noalias proxy: *Proxy,
    parent: wl_surface,
    x: i32,
    y: i32,
    flags: Transient,
  ) void {
    const Opcode = 4;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .object = parent.toInt() },
        .{ .int = x },
        .{ .int = y },
        .{ .uint = flags.toInt() },
      },
    );
  }

  pub fn set_fullscreen(
    noalias self: *const wl_shell_surface,
    noalias proxy: *Proxy,
    method: FullscreenMethod,
    framerate: u32,
    output: wl_output,
  ) void {
    const Opcode = 5;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .uint = method.toInt() },
        .{ .uint = framerate },
        .{ .object = output.toInt() },
      },
    );
  }

  pub fn set_popup(
    noalias self: *const wl_shell_surface,
    noalias proxy: *Proxy,
    seat: wl_seat,
    serial: u32,
    parent: wl_surface,
    x: i32,
    y: i32,
    flags: Transient,
  ) void {
    const Opcode = 6;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .object = seat.toInt() },
        .{ .uint = serial },
        .{ .object = parent.toInt() },
        .{ .int = x },
        .{ .int = y },
        .{ .uint = flags.toInt() },
      },
    );
  }

  pub fn set_maximized(
    noalias self: *const wl_shell_surface,
    noalias proxy: *Proxy,
    output: wl_output,
  ) void {
    const Opcode = 7;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .object = output.toInt() },
      },
    );
  }

  pub fn set_title(
    noalias self: *const wl_shell_surface,
    noalias proxy: *Proxy,
    title: [:0]const u8,
  ) void {
    const Opcode = 8;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .string = title },
      },
    );
  }

  pub fn set_class(
    noalias self: *const wl_shell_surface,
    noalias proxy: *Proxy,
    class_: [:0]const u8,
  ) void {
    const Opcode = 9;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .string = class_ },
      },
    );
  }

  pub const ping = struct {
    serial: u32,
  };

  pub const configure = struct {
    edges: Resize,
    width: i32,
    height: i32,
  };

  pub const popup_done = void;

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_shell_surface_ping = .{
              .serial = args_in[0].uint,
            }
          };
        },
        1 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .int = undefined },
            .{ .int = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_shell_surface_configure = .{
              .edges = .fromInt(args_in[0].uint),
              .width = args_in[1].int,
              .height = args_in[2].int,
            }
          };
        },
        2 => {
          var args_in = [_]MessageArg{
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_shell_surface_popup_done = {
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN wl_shell_surface ENUMS
  //---------------------------------------------------------------------------

  pub const Resize = packed struct (u32) {
    none: bool = false,
    top: bool = false,
    bottom: bool = false,
    left: bool = false,
    top_left: bool = false,
    bottom_left: bool = false,
    right: bool = false,
    top_right: bool = false,
    bottom_right: bool = false,

    __reserved_bits: u23 = 0,

    pub const toInt = Mixin.toInt;
    pub const fromInt = Mixin.fromInt;
    pub const not = Mixin.not;
    pub const either = Mixin.either;
    pub const both = Mixin.both;
    pub const eql = Mixin.eql;
    pub const contains = Mixin.contains;

    const Mixin = BitfieldMixin(@This());
  };

  pub const Transient = packed struct (u32) {
    inactive: bool = false,

    __reserved_bits: u31 = 0,

    pub const toInt = Mixin.toInt;
    pub const fromInt = Mixin.fromInt;
    pub const not = Mixin.not;
    pub const either = Mixin.either;
    pub const both = Mixin.both;
    pub const eql = Mixin.eql;
    pub const contains = Mixin.contains;

    const Mixin = BitfieldMixin(@This());
  };

  pub const FullscreenMethod = enum (u32) {
    default = 0,
    scale = 1,
    driver = 2,
    fill = 3,

    pub fn toInt(self: FullscreenMethod) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) FullscreenMethod {
      return @enumFromInt(int);
    }
  };
  //---------------------------------------------------------------------------

  pub const Name = "wl_shell_surface";
  pub const Version = 1;
};

pub const wl_surface = enum (u32) {
  _,

  pub fn object(self: wl_surface) Object {
    return .{ .wl_surface = self };
  }

  pub fn toInt(self: wl_surface) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wl_surface {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wl_surface MESSAGES
  //---------------------------------------------------------------------------

  pub fn destroy(
    noalias self: *const wl_surface,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn attach(
    noalias self: *const wl_surface,
    noalias proxy: *Proxy,
    buffer: wl_buffer,
    x: i32,
    y: i32,
  ) void {
    const Opcode = 1;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .object = buffer.toInt() },
        .{ .int = x },
        .{ .int = y },
      },
    );
  }

  pub fn damage(
    noalias self: *const wl_surface,
    noalias proxy: *Proxy,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
  ) void {
    const Opcode = 2;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .int = x },
        .{ .int = y },
        .{ .int = width },
        .{ .int = height },
      },
    );
  }

  pub fn frame(
    noalias self: *const wl_surface,
    noalias proxy: *Proxy,
  ) wl_callback {
    const Opcode = 3;
    const result: wl_callback = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .new_id = result.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }

  pub fn set_opaque_region(
    noalias self: *const wl_surface,
    noalias proxy: *Proxy,
    region: wl_region,
  ) void {
    const Opcode = 4;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .object = region.toInt() },
      },
    );
  }

  pub fn set_input_region(
    noalias self: *const wl_surface,
    noalias proxy: *Proxy,
    region: wl_region,
  ) void {
    const Opcode = 5;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .object = region.toInt() },
      },
    );
  }

  pub fn commit(
    noalias self: *const wl_surface,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 6;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn set_buffer_transform(
    noalias self: *const wl_surface,
    noalias proxy: *Proxy,
    transform: i32,
  ) void {
    const Opcode = 7;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .int = transform },
      },
    );
  }

  pub fn set_buffer_scale(
    noalias self: *const wl_surface,
    noalias proxy: *Proxy,
    scale: i32,
  ) void {
    const Opcode = 8;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .int = scale },
      },
    );
  }

  pub fn damage_buffer(
    noalias self: *const wl_surface,
    noalias proxy: *Proxy,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
  ) void {
    const Opcode = 9;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .int = x },
        .{ .int = y },
        .{ .int = width },
        .{ .int = height },
      },
    );
  }

  pub fn offset(
    noalias self: *const wl_surface,
    noalias proxy: *Proxy,
    x: i32,
    y: i32,
  ) void {
    const Opcode = 10;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .int = x },
        .{ .int = y },
      },
    );
  }

  pub const enter = struct {
    output: wl_output,
  };

  pub const leave = struct {
    output: wl_output,
  };

  pub const preferred_buffer_scale = struct {
    factor: i32,
  };

  pub const preferred_buffer_transform = struct {
    transform: wl_output.Transform,
  };

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
            .{ .object = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_surface_enter = .{
              .output = .fromInt(args_in[0].object),
            }
          };
        },
        1 => {
          var args_in = [_]MessageArg{
            .{ .object = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_surface_leave = .{
              .output = .fromInt(args_in[0].object),
            }
          };
        },
        2 => {
          var args_in = [_]MessageArg{
            .{ .int = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_surface_preferred_buffer_scale = .{
              .factor = args_in[0].int,
            }
          };
        },
        3 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_surface_preferred_buffer_transform = .{
              .transform = .fromInt(args_in[0].uint),
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN wl_surface ENUMS
  //---------------------------------------------------------------------------

  pub const Error = enum (u32) {
    invalid_scale = 0,
    invalid_transform = 1,
    invalid_size = 2,
    invalid_offset = 3,
    defunct_role_object = 4,

    pub fn toInt(self: Error) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Error {
      return @enumFromInt(int);
    }
  };
  //---------------------------------------------------------------------------

  pub const Name = "wl_surface";
  pub const Version = 6;
};

pub const wl_seat = enum (u32) {
  _,

  pub fn object(self: wl_seat) Object {
    return .{ .wl_seat = self };
  }

  pub fn toInt(self: wl_seat) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wl_seat {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wl_seat MESSAGES
  //---------------------------------------------------------------------------

  pub fn get_pointer(
    noalias self: *const wl_seat,
    noalias proxy: *Proxy,
  ) wl_pointer {
    const Opcode = 0;
    const result: wl_pointer = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .new_id = result.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }

  pub fn get_keyboard(
    noalias self: *const wl_seat,
    noalias proxy: *Proxy,
  ) wl_keyboard {
    const Opcode = 1;
    const result: wl_keyboard = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .new_id = result.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }

  pub fn get_touch(
    noalias self: *const wl_seat,
    noalias proxy: *Proxy,
  ) wl_touch {
    const Opcode = 2;
    const result: wl_touch = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .new_id = result.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }

  pub fn release(
    noalias self: *const wl_seat,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 3;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub const capabilities = struct {
    capabilities: Capability,
  };

  pub const name = struct {
    name: [:0]const u8,
  };

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_seat_capabilities = .{
              .capabilities = .fromInt(args_in[0].uint),
            }
          };
        },
        1 => {
          var args_in = [_]MessageArg{
            .{ .string = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_seat_name = .{
              .name = args_in[0].string,
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN wl_seat ENUMS
  //---------------------------------------------------------------------------

  pub const Capability = packed struct (u32) {
    pointer: bool = false,
    keyboard: bool = false,
    touch: bool = false,

    __reserved_bits: u29 = 0,

    pub const toInt = Mixin.toInt;
    pub const fromInt = Mixin.fromInt;
    pub const not = Mixin.not;
    pub const either = Mixin.either;
    pub const both = Mixin.both;
    pub const eql = Mixin.eql;
    pub const contains = Mixin.contains;

    const Mixin = BitfieldMixin(@This());
  };

  pub const Error = enum (u32) {
    missing_capability = 0,

    pub fn toInt(self: Error) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Error {
      return @enumFromInt(int);
    }
  };
  //---------------------------------------------------------------------------

  pub const Name = "wl_seat";
  pub const Version = 10;
};

pub const wl_pointer = enum (u32) {
  _,

  pub fn object(self: wl_pointer) Object {
    return .{ .wl_pointer = self };
  }

  pub fn toInt(self: wl_pointer) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wl_pointer {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wl_pointer MESSAGES
  //---------------------------------------------------------------------------

  pub fn set_cursor(
    noalias self: *const wl_pointer,
    noalias proxy: *Proxy,
    serial: u32,
    surface: wl_surface,
    hotspot_x: i32,
    hotspot_y: i32,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .uint = serial },
        .{ .object = surface.toInt() },
        .{ .int = hotspot_x },
        .{ .int = hotspot_y },
      },
    );
  }

  pub fn release(
    noalias self: *const wl_pointer,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 1;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub const enter = struct {
    serial: u32,
    surface: wl_surface,
    surface_x: f32,
    surface_y: f32,
  };

  pub const leave = struct {
    serial: u32,
    surface: wl_surface,
  };

  pub const motion = struct {
    time: u32,
    surface_x: f32,
    surface_y: f32,
  };

  pub const button = struct {
    serial: u32,
    time: u32,
    button: u32,
    state: ButtonState,
  };

  pub const axis = struct {
    time: u32,
    axis: Axis,
    value: f32,
  };

  pub const frame = void;

  pub const axis_source = struct {
    axis_source: AxisSource,
  };

  pub const axis_stop = struct {
    time: u32,
    axis: Axis,
  };

  pub const axis_discrete = struct {
    axis: Axis,
    discrete: i32,
  };

  pub const axis_value120 = struct {
    axis: Axis,
    value120: i32,
  };

  pub const axis_relative_direction = struct {
    axis: Axis,
    direction: AxisRelativeDirection,
  };

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .object = undefined },
            .{ .fixed = undefined },
            .{ .fixed = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_pointer_enter = .{
              .serial = args_in[0].uint,
              .surface = .fromInt(args_in[1].object),
              .surface_x = args_in[2].fixed,
              .surface_y = args_in[3].fixed,
            }
          };
        },
        1 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .object = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_pointer_leave = .{
              .serial = args_in[0].uint,
              .surface = .fromInt(args_in[1].object),
            }
          };
        },
        2 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .fixed = undefined },
            .{ .fixed = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_pointer_motion = .{
              .time = args_in[0].uint,
              .surface_x = args_in[1].fixed,
              .surface_y = args_in[2].fixed,
            }
          };
        },
        3 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .uint = undefined },
            .{ .uint = undefined },
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_pointer_button = .{
              .serial = args_in[0].uint,
              .time = args_in[1].uint,
              .button = args_in[2].uint,
              .state = .fromInt(args_in[3].uint),
            }
          };
        },
        4 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .uint = undefined },
            .{ .fixed = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_pointer_axis = .{
              .time = args_in[0].uint,
              .axis = .fromInt(args_in[1].uint),
              .value = args_in[2].fixed,
            }
          };
        },
        5 => {
          var args_in = [_]MessageArg{
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_pointer_frame = {
            }
          };
        },
        6 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_pointer_axis_source = .{
              .axis_source = .fromInt(args_in[0].uint),
            }
          };
        },
        7 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_pointer_axis_stop = .{
              .time = args_in[0].uint,
              .axis = .fromInt(args_in[1].uint),
            }
          };
        },
        8 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .int = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_pointer_axis_discrete = .{
              .axis = .fromInt(args_in[0].uint),
              .discrete = args_in[1].int,
            }
          };
        },
        9 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .int = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_pointer_axis_value120 = .{
              .axis = .fromInt(args_in[0].uint),
              .value120 = args_in[1].int,
            }
          };
        },
        10 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_pointer_axis_relative_direction = .{
              .axis = .fromInt(args_in[0].uint),
              .direction = .fromInt(args_in[1].uint),
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN wl_pointer ENUMS
  //---------------------------------------------------------------------------

  pub const Error = enum (u32) {
    role = 0,

    pub fn toInt(self: Error) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Error {
      return @enumFromInt(int);
    }
  };

  pub const ButtonState = enum (u32) {
    released = 0,
    pressed = 1,

    pub fn toInt(self: ButtonState) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) ButtonState {
      return @enumFromInt(int);
    }
  };

  pub const Axis = enum (u32) {
    vertical_scroll = 0,
    horizontal_scroll = 1,

    pub fn toInt(self: Axis) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Axis {
      return @enumFromInt(int);
    }
  };

  pub const AxisSource = enum (u32) {
    wheel = 0,
    finger = 1,
    continuous = 2,
    wheel_tilt = 3,

    pub fn toInt(self: AxisSource) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) AxisSource {
      return @enumFromInt(int);
    }
  };

  pub const AxisRelativeDirection = enum (u32) {
    identical = 0,
    inverted = 1,

    pub fn toInt(self: AxisRelativeDirection) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) AxisRelativeDirection {
      return @enumFromInt(int);
    }
  };
  //---------------------------------------------------------------------------

  pub const Name = "wl_pointer";
  pub const Version = 10;
};

pub const wl_keyboard = enum (u32) {
  _,

  pub fn object(self: wl_keyboard) Object {
    return .{ .wl_keyboard = self };
  }

  pub fn toInt(self: wl_keyboard) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wl_keyboard {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wl_keyboard MESSAGES
  //---------------------------------------------------------------------------

  pub fn release(
    noalias self: *const wl_keyboard,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub const keymap = struct {
    format: KeymapFormat,
    fd: c_int,
    size: u32,
  };

  pub const enter = struct {
    serial: u32,
    surface: wl_surface,
    keys: []const u8,
  };

  pub const leave = struct {
    serial: u32,
    surface: wl_surface,
  };

  pub const key = struct {
    serial: u32,
    time: u32,
    key: u32,
    state: KeyState,
  };

  pub const modifiers = struct {
    serial: u32,
    mods_depressed: u32,
    mods_latched: u32,
    mods_locked: u32,
    group: u32,
  };

  pub const repeat_info = struct {
    rate: i32,
    delay: i32,
  };

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .fd = undefined },
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_keyboard_keymap = .{
              .format = .fromInt(args_in[0].uint),
              .fd = args_in[1].fd,
              .size = args_in[2].uint,
            }
          };
        },
        1 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .object = undefined },
            .{ .array = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_keyboard_enter = .{
              .serial = args_in[0].uint,
              .surface = .fromInt(args_in[1].object),
              .keys = args_in[2].array,
            }
          };
        },
        2 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .object = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_keyboard_leave = .{
              .serial = args_in[0].uint,
              .surface = .fromInt(args_in[1].object),
            }
          };
        },
        3 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .uint = undefined },
            .{ .uint = undefined },
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_keyboard_key = .{
              .serial = args_in[0].uint,
              .time = args_in[1].uint,
              .key = args_in[2].uint,
              .state = .fromInt(args_in[3].uint),
            }
          };
        },
        4 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .uint = undefined },
            .{ .uint = undefined },
            .{ .uint = undefined },
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_keyboard_modifiers = .{
              .serial = args_in[0].uint,
              .mods_depressed = args_in[1].uint,
              .mods_latched = args_in[2].uint,
              .mods_locked = args_in[3].uint,
              .group = args_in[4].uint,
            }
          };
        },
        5 => {
          var args_in = [_]MessageArg{
            .{ .int = undefined },
            .{ .int = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_keyboard_repeat_info = .{
              .rate = args_in[0].int,
              .delay = args_in[1].int,
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN wl_keyboard ENUMS
  //---------------------------------------------------------------------------

  pub const KeymapFormat = enum (u32) {
    no_keymap = 0,
    xkb_v1 = 1,

    pub fn toInt(self: KeymapFormat) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) KeymapFormat {
      return @enumFromInt(int);
    }
  };

  pub const KeyState = enum (u32) {
    released = 0,
    pressed = 1,
    repeated = 2,

    pub fn toInt(self: KeyState) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) KeyState {
      return @enumFromInt(int);
    }
  };
  //---------------------------------------------------------------------------

  pub const Name = "wl_keyboard";
  pub const Version = 10;
};

pub const wl_touch = enum (u32) {
  _,

  pub fn object(self: wl_touch) Object {
    return .{ .wl_touch = self };
  }

  pub fn toInt(self: wl_touch) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wl_touch {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wl_touch MESSAGES
  //---------------------------------------------------------------------------

  pub fn release(
    noalias self: *const wl_touch,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub const down = struct {
    serial: u32,
    time: u32,
    surface: wl_surface,
    id: i32,
    x: f32,
    y: f32,
  };

  pub const up = struct {
    serial: u32,
    time: u32,
    id: i32,
  };

  pub const motion = struct {
    time: u32,
    id: i32,
    x: f32,
    y: f32,
  };

  pub const frame = void;

  pub const cancel = void;

  pub const shape = struct {
    id: i32,
    major: f32,
    minor: f32,
  };

  pub const orientation = struct {
    id: i32,
    orientation: f32,
  };

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .uint = undefined },
            .{ .object = undefined },
            .{ .int = undefined },
            .{ .fixed = undefined },
            .{ .fixed = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_touch_down = .{
              .serial = args_in[0].uint,
              .time = args_in[1].uint,
              .surface = .fromInt(args_in[2].object),
              .id = args_in[3].int,
              .x = args_in[4].fixed,
              .y = args_in[5].fixed,
            }
          };
        },
        1 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .uint = undefined },
            .{ .int = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_touch_up = .{
              .serial = args_in[0].uint,
              .time = args_in[1].uint,
              .id = args_in[2].int,
            }
          };
        },
        2 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .int = undefined },
            .{ .fixed = undefined },
            .{ .fixed = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_touch_motion = .{
              .time = args_in[0].uint,
              .id = args_in[1].int,
              .x = args_in[2].fixed,
              .y = args_in[3].fixed,
            }
          };
        },
        3 => {
          var args_in = [_]MessageArg{
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_touch_frame = {
            }
          };
        },
        4 => {
          var args_in = [_]MessageArg{
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_touch_cancel = {
            }
          };
        },
        5 => {
          var args_in = [_]MessageArg{
            .{ .int = undefined },
            .{ .fixed = undefined },
            .{ .fixed = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_touch_shape = .{
              .id = args_in[0].int,
              .major = args_in[1].fixed,
              .minor = args_in[2].fixed,
            }
          };
        },
        6 => {
          var args_in = [_]MessageArg{
            .{ .int = undefined },
            .{ .fixed = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_touch_orientation = .{
              .id = args_in[0].int,
              .orientation = args_in[1].fixed,
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  pub const Name = "wl_touch";
  pub const Version = 10;
};

pub const wl_output = enum (u32) {
  _,

  pub fn object(self: wl_output) Object {
    return .{ .wl_output = self };
  }

  pub fn toInt(self: wl_output) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wl_output {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wl_output MESSAGES
  //---------------------------------------------------------------------------

  pub fn release(
    noalias self: *const wl_output,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub const geometry = struct {
    x: i32,
    y: i32,
    physical_width: i32,
    physical_height: i32,
    subpixel: i32,
    make: [:0]const u8,
    model: [:0]const u8,
    transform: i32,
  };

  pub const mode = struct {
    flags: Mode,
    width: i32,
    height: i32,
    refresh: i32,
  };

  pub const done = void;

  pub const scale = struct {
    factor: i32,
  };

  pub const name = struct {
    name: [:0]const u8,
  };

  pub const description = struct {
    description: [:0]const u8,
  };

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
            .{ .int = undefined },
            .{ .int = undefined },
            .{ .int = undefined },
            .{ .int = undefined },
            .{ .int = undefined },
            .{ .string = undefined },
            .{ .string = undefined },
            .{ .int = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_output_geometry = .{
              .x = args_in[0].int,
              .y = args_in[1].int,
              .physical_width = args_in[2].int,
              .physical_height = args_in[3].int,
              .subpixel = args_in[4].int,
              .make = args_in[5].string,
              .model = args_in[6].string,
              .transform = args_in[7].int,
            }
          };
        },
        1 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
            .{ .int = undefined },
            .{ .int = undefined },
            .{ .int = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_output_mode = .{
              .flags = .fromInt(args_in[0].uint),
              .width = args_in[1].int,
              .height = args_in[2].int,
              .refresh = args_in[3].int,
            }
          };
        },
        2 => {
          var args_in = [_]MessageArg{
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_output_done = {
            }
          };
        },
        3 => {
          var args_in = [_]MessageArg{
            .{ .int = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_output_scale = .{
              .factor = args_in[0].int,
            }
          };
        },
        4 => {
          var args_in = [_]MessageArg{
            .{ .string = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_output_name = .{
              .name = args_in[0].string,
            }
          };
        },
        5 => {
          var args_in = [_]MessageArg{
            .{ .string = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .wl_output_description = .{
              .description = args_in[0].string,
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN wl_output ENUMS
  //---------------------------------------------------------------------------

  pub const Subpixel = enum (u32) {
    unknown = 0,
    none = 1,
    horizontal_rgb = 2,
    horizontal_bgr = 3,
    vertical_rgb = 4,
    vertical_bgr = 5,

    pub fn toInt(self: Subpixel) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Subpixel {
      return @enumFromInt(int);
    }
  };

  pub const Transform = enum (u32) {
    normal = 0,
    @"90" = 1,
    @"180" = 2,
    @"270" = 3,
    flipped = 4,
    flipped_90 = 5,
    flipped_180 = 6,
    flipped_270 = 7,

    pub fn toInt(self: Transform) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Transform {
      return @enumFromInt(int);
    }
  };

  pub const Mode = packed struct (u32) {
    current: bool = false,
    preferred: bool = false,

    __reserved_bits: u30 = 0,

    pub const toInt = Mixin.toInt;
    pub const fromInt = Mixin.fromInt;
    pub const not = Mixin.not;
    pub const either = Mixin.either;
    pub const both = Mixin.both;
    pub const eql = Mixin.eql;
    pub const contains = Mixin.contains;

    const Mixin = BitfieldMixin(@This());
  };
  //---------------------------------------------------------------------------

  pub const Name = "wl_output";
  pub const Version = 4;
};

pub const wl_region = enum (u32) {
  _,

  pub fn object(self: wl_region) Object {
    return .{ .wl_region = self };
  }

  pub fn toInt(self: wl_region) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wl_region {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wl_region MESSAGES
  //---------------------------------------------------------------------------

  pub fn destroy(
    noalias self: *const wl_region,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn add(
    noalias self: *const wl_region,
    noalias proxy: *Proxy,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
  ) void {
    const Opcode = 1;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .int = x },
        .{ .int = y },
        .{ .int = width },
        .{ .int = height },
      },
    );
  }

  pub fn subtract(
    noalias self: *const wl_region,
    noalias proxy: *Proxy,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
  ) void {
    const Opcode = 2;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .int = x },
        .{ .int = y },
        .{ .int = width },
        .{ .int = height },
      },
    );
  }
  //---------------------------------------------------------------------------

  pub const Name = "wl_region";
  pub const Version = 1;
};

pub const wl_subcompositor = enum (u32) {
  _,

  pub fn object(self: wl_subcompositor) Object {
    return .{ .wl_subcompositor = self };
  }

  pub fn toInt(self: wl_subcompositor) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wl_subcompositor {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wl_subcompositor MESSAGES
  //---------------------------------------------------------------------------

  pub fn destroy(
    noalias self: *const wl_subcompositor,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn get_subsurface(
    noalias self: *const wl_subcompositor,
    noalias proxy: *Proxy,
    surface: wl_surface,
    parent: wl_surface,
  ) wl_subsurface {
    const Opcode = 1;
    const result: wl_subsurface = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .new_id = result.toInt() },
        .{ .object = surface.toInt() },
        .{ .object = parent.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN wl_subcompositor ENUMS
  //---------------------------------------------------------------------------

  pub const Error = enum (u32) {
    bad_surface = 0,
    bad_parent = 1,

    pub fn toInt(self: Error) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Error {
      return @enumFromInt(int);
    }
  };
  //---------------------------------------------------------------------------

  pub const Name = "wl_subcompositor";
  pub const Version = 1;
};

pub const wl_subsurface = enum (u32) {
  _,

  pub fn object(self: wl_subsurface) Object {
    return .{ .wl_subsurface = self };
  }

  pub fn toInt(self: wl_subsurface) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wl_subsurface {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wl_subsurface MESSAGES
  //---------------------------------------------------------------------------

  pub fn destroy(
    noalias self: *const wl_subsurface,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn set_position(
    noalias self: *const wl_subsurface,
    noalias proxy: *Proxy,
    x: i32,
    y: i32,
  ) void {
    const Opcode = 1;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .int = x },
        .{ .int = y },
      },
    );
  }

  pub fn place_above(
    noalias self: *const wl_subsurface,
    noalias proxy: *Proxy,
    sibling: wl_surface,
  ) void {
    const Opcode = 2;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .object = sibling.toInt() },
      },
    );
  }

  pub fn place_below(
    noalias self: *const wl_subsurface,
    noalias proxy: *Proxy,
    sibling: wl_surface,
  ) void {
    const Opcode = 3;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .object = sibling.toInt() },
      },
    );
  }

  pub fn set_sync(
    noalias self: *const wl_subsurface,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 4;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn set_desync(
    noalias self: *const wl_subsurface,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 5;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN wl_subsurface ENUMS
  //---------------------------------------------------------------------------

  pub const Error = enum (u32) {
    bad_surface = 0,

    pub fn toInt(self: Error) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Error {
      return @enumFromInt(int);
    }
  };
  //---------------------------------------------------------------------------

  pub const Name = "wl_subsurface";
  pub const Version = 1;
};

pub const wl_fixes = enum (u32) {
  _,

  pub fn object(self: wl_fixes) Object {
    return .{ .wl_fixes = self };
  }

  pub fn toInt(self: wl_fixes) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) wl_fixes {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN wl_fixes MESSAGES
  //---------------------------------------------------------------------------

  pub fn destroy(
    noalias self: *const wl_fixes,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn destroy_registry(
    noalias self: *const wl_fixes,
    noalias proxy: *Proxy,
    registry: wl_registry,
  ) void {
    const Opcode = 1;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .object = registry.toInt() },
      },
    );
  }
  //---------------------------------------------------------------------------

  pub const Name = "wl_fixes";
  pub const Version = 1;
};

//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// BEGIN Protocol xdg_decoration_unstable_v1
//-----------------------------------------------------------------------------

pub const zxdg_decoration_manager_v1 = enum (u32) {
  _,

  pub fn object(self: zxdg_decoration_manager_v1) Object {
    return .{ .zxdg_decoration_manager_v1 = self };
  }

  pub fn toInt(self: zxdg_decoration_manager_v1) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) zxdg_decoration_manager_v1 {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN zxdg_decoration_manager_v1 MESSAGES
  //---------------------------------------------------------------------------

  pub fn destroy(
    noalias self: *const zxdg_decoration_manager_v1,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn get_toplevel_decoration(
    noalias self: *const zxdg_decoration_manager_v1,
    noalias proxy: *Proxy,
    toplevel: xdg_toplevel,
  ) zxdg_toplevel_decoration_v1 {
    const Opcode = 1;
    const result: zxdg_toplevel_decoration_v1 = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .new_id = result.toInt() },
        .{ .object = toplevel.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }
  //---------------------------------------------------------------------------

  pub const Name = "zxdg_decoration_manager_v1";
  pub const Version = 1;
};

pub const zxdg_toplevel_decoration_v1 = enum (u32) {
  _,

  pub fn object(self: zxdg_toplevel_decoration_v1) Object {
    return .{ .zxdg_toplevel_decoration_v1 = self };
  }

  pub fn toInt(self: zxdg_toplevel_decoration_v1) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) zxdg_toplevel_decoration_v1 {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN zxdg_toplevel_decoration_v1 MESSAGES
  //---------------------------------------------------------------------------

  pub fn destroy(
    noalias self: *const zxdg_toplevel_decoration_v1,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn set_mode(
    noalias self: *const zxdg_toplevel_decoration_v1,
    noalias proxy: *Proxy,
    mode: Mode,
  ) void {
    const Opcode = 1;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .uint = mode.toInt() },
      },
    );
  }

  pub fn unset_mode(
    noalias self: *const zxdg_toplevel_decoration_v1,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 2;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub const configure = struct {
    mode: Mode,
  };

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .zxdg_toplevel_decoration_v1_configure = .{
              .mode = .fromInt(args_in[0].uint),
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN zxdg_toplevel_decoration_v1 ENUMS
  //---------------------------------------------------------------------------

  pub const Error = enum (u32) {
    unconfigured_buffer = 0,
    already_constructed = 1,
    orphaned = 2,
    invalid_mode = 3,

    pub fn toInt(self: Error) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Error {
      return @enumFromInt(int);
    }
  };

  pub const Mode = enum (u32) {
    client_side = 1,
    server_side = 2,

    pub fn toInt(self: Mode) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Mode {
      return @enumFromInt(int);
    }
  };
  //---------------------------------------------------------------------------

  pub const Name = "zxdg_toplevel_decoration_v1";
  pub const Version = 1;
};

//-----------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// BEGIN Protocol xdg_shell
//-----------------------------------------------------------------------------

pub const xdg_wm_base = enum (u32) {
  _,

  pub fn object(self: xdg_wm_base) Object {
    return .{ .xdg_wm_base = self };
  }

  pub fn toInt(self: xdg_wm_base) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) xdg_wm_base {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN xdg_wm_base MESSAGES
  //---------------------------------------------------------------------------

  pub fn destroy(
    noalias self: *const xdg_wm_base,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn create_positioner(
    noalias self: *const xdg_wm_base,
    noalias proxy: *Proxy,
  ) xdg_positioner {
    const Opcode = 1;
    const result: xdg_positioner = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .new_id = result.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }

  pub fn get_xdg_surface(
    noalias self: *const xdg_wm_base,
    noalias proxy: *Proxy,
    surface: wl_surface,
  ) xdg_surface {
    const Opcode = 2;
    const result: xdg_surface = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .new_id = result.toInt() },
        .{ .object = surface.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }

  pub fn pong(
    noalias self: *const xdg_wm_base,
    noalias proxy: *Proxy,
    serial: u32,
  ) void {
    const Opcode = 3;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .uint = serial },
      },
    );
  }

  pub const ping = struct {
    serial: u32,
  };

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .xdg_wm_base_ping = .{
              .serial = args_in[0].uint,
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN xdg_wm_base ENUMS
  //---------------------------------------------------------------------------

  pub const Error = enum (u32) {
    role = 0,
    defunct_surfaces = 1,
    not_the_topmost_popup = 2,
    invalid_popup_parent = 3,
    invalid_surface_state = 4,
    invalid_positioner = 5,
    unresponsive = 6,

    pub fn toInt(self: Error) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Error {
      return @enumFromInt(int);
    }
  };
  //---------------------------------------------------------------------------

  pub const Name = "xdg_wm_base";
  pub const Version = 7;
};

pub const xdg_positioner = enum (u32) {
  _,

  pub fn object(self: xdg_positioner) Object {
    return .{ .xdg_positioner = self };
  }

  pub fn toInt(self: xdg_positioner) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) xdg_positioner {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN xdg_positioner MESSAGES
  //---------------------------------------------------------------------------

  pub fn destroy(
    noalias self: *const xdg_positioner,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn set_size(
    noalias self: *const xdg_positioner,
    noalias proxy: *Proxy,
    width: i32,
    height: i32,
  ) void {
    const Opcode = 1;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .int = width },
        .{ .int = height },
      },
    );
  }

  pub fn set_anchor_rect(
    noalias self: *const xdg_positioner,
    noalias proxy: *Proxy,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
  ) void {
    const Opcode = 2;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .int = x },
        .{ .int = y },
        .{ .int = width },
        .{ .int = height },
      },
    );
  }

  pub fn set_anchor(
    noalias self: *const xdg_positioner,
    noalias proxy: *Proxy,
    anchor: Anchor,
  ) void {
    const Opcode = 3;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .uint = anchor.toInt() },
      },
    );
  }

  pub fn set_gravity(
    noalias self: *const xdg_positioner,
    noalias proxy: *Proxy,
    gravity: Gravity,
  ) void {
    const Opcode = 4;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .uint = gravity.toInt() },
      },
    );
  }

  pub fn set_constraint_adjustment(
    noalias self: *const xdg_positioner,
    noalias proxy: *Proxy,
    constraint_adjustment: ConstraintAdjustment,
  ) void {
    const Opcode = 5;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .uint = constraint_adjustment.toInt() },
      },
    );
  }

  pub fn set_offset(
    noalias self: *const xdg_positioner,
    noalias proxy: *Proxy,
    x: i32,
    y: i32,
  ) void {
    const Opcode = 6;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .int = x },
        .{ .int = y },
      },
    );
  }

  pub fn set_reactive(
    noalias self: *const xdg_positioner,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 7;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn set_parent_size(
    noalias self: *const xdg_positioner,
    noalias proxy: *Proxy,
    parent_width: i32,
    parent_height: i32,
  ) void {
    const Opcode = 8;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .int = parent_width },
        .{ .int = parent_height },
      },
    );
  }

  pub fn set_parent_configure(
    noalias self: *const xdg_positioner,
    noalias proxy: *Proxy,
    serial: u32,
  ) void {
    const Opcode = 9;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .uint = serial },
      },
    );
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN xdg_positioner ENUMS
  //---------------------------------------------------------------------------

  pub const Error = enum (u32) {
    invalid_input = 0,

    pub fn toInt(self: Error) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Error {
      return @enumFromInt(int);
    }
  };

  pub const Anchor = enum (u32) {
    none = 0,
    top = 1,
    bottom = 2,
    left = 3,
    right = 4,
    top_left = 5,
    bottom_left = 6,
    top_right = 7,
    bottom_right = 8,

    pub fn toInt(self: Anchor) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Anchor {
      return @enumFromInt(int);
    }
  };

  pub const Gravity = enum (u32) {
    none = 0,
    top = 1,
    bottom = 2,
    left = 3,
    right = 4,
    top_left = 5,
    bottom_left = 6,
    top_right = 7,
    bottom_right = 8,

    pub fn toInt(self: Gravity) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Gravity {
      return @enumFromInt(int);
    }
  };

  pub const ConstraintAdjustment = packed struct (u32) {
    none: bool = false,
    slide_x: bool = false,
    slide_y: bool = false,
    flip_x: bool = false,
    flip_y: bool = false,
    resize_x: bool = false,
    resize_y: bool = false,

    __reserved_bits: u25 = 0,

    pub const toInt = Mixin.toInt;
    pub const fromInt = Mixin.fromInt;
    pub const not = Mixin.not;
    pub const either = Mixin.either;
    pub const both = Mixin.both;
    pub const eql = Mixin.eql;
    pub const contains = Mixin.contains;

    const Mixin = BitfieldMixin(@This());
  };
  //---------------------------------------------------------------------------

  pub const Name = "xdg_positioner";
  pub const Version = 7;
};

pub const xdg_surface = enum (u32) {
  _,

  pub fn object(self: xdg_surface) Object {
    return .{ .xdg_surface = self };
  }

  pub fn toInt(self: xdg_surface) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) xdg_surface {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN xdg_surface MESSAGES
  //---------------------------------------------------------------------------

  pub fn destroy(
    noalias self: *const xdg_surface,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn get_toplevel(
    noalias self: *const xdg_surface,
    noalias proxy: *Proxy,
  ) xdg_toplevel {
    const Opcode = 1;
    const result: xdg_toplevel = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .new_id = result.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }

  pub fn get_popup(
    noalias self: *const xdg_surface,
    noalias proxy: *Proxy,
    parent: xdg_surface,
    positioner: xdg_positioner,
  ) xdg_popup {
    const Opcode = 2;
    const result: xdg_popup = .fromInt(proxy.get_id());
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .new_id = result.toInt() },
        .{ .object = parent.toInt() },
        .{ .object = positioner.toInt() },
      },
    );

    proxy.put_object(result.object());
    return result;
  }

  pub fn set_window_geometry(
    noalias self: *const xdg_surface,
    noalias proxy: *Proxy,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
  ) void {
    const Opcode = 3;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .int = x },
        .{ .int = y },
        .{ .int = width },
        .{ .int = height },
      },
    );
  }

  pub fn ack_configure(
    noalias self: *const xdg_surface,
    noalias proxy: *Proxy,
    serial: u32,
  ) void {
    const Opcode = 4;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .uint = serial },
      },
    );
  }

  pub const configure = struct {
    serial: u32,
  };

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .xdg_surface_configure = .{
              .serial = args_in[0].uint,
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN xdg_surface ENUMS
  //---------------------------------------------------------------------------

  pub const Error = enum (u32) {
    not_constructed = 1,
    already_constructed = 2,
    unconfigured_buffer = 3,
    invalid_serial = 4,
    invalid_size = 5,
    defunct_role_object = 6,

    pub fn toInt(self: Error) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Error {
      return @enumFromInt(int);
    }
  };
  //---------------------------------------------------------------------------

  pub const Name = "xdg_surface";
  pub const Version = 7;
};

pub const xdg_toplevel = enum (u32) {
  _,

  pub fn object(self: xdg_toplevel) Object {
    return .{ .xdg_toplevel = self };
  }

  pub fn toInt(self: xdg_toplevel) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) xdg_toplevel {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN xdg_toplevel MESSAGES
  //---------------------------------------------------------------------------

  pub fn destroy(
    noalias self: *const xdg_toplevel,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn set_parent(
    noalias self: *const xdg_toplevel,
    noalias proxy: *Proxy,
    parent: xdg_toplevel,
  ) void {
    const Opcode = 1;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .object = parent.toInt() },
      },
    );
  }

  pub fn set_title(
    noalias self: *const xdg_toplevel,
    noalias proxy: *Proxy,
    title: [:0]const u8,
  ) void {
    const Opcode = 2;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .string = title },
      },
    );
  }

  pub fn set_app_id(
    noalias self: *const xdg_toplevel,
    noalias proxy: *Proxy,
    app_id: [:0]const u8,
  ) void {
    const Opcode = 3;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .string = app_id },
      },
    );
  }

  pub fn show_window_menu(
    noalias self: *const xdg_toplevel,
    noalias proxy: *Proxy,
    seat: wl_seat,
    serial: u32,
    x: i32,
    y: i32,
  ) void {
    const Opcode = 4;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .object = seat.toInt() },
        .{ .uint = serial },
        .{ .int = x },
        .{ .int = y },
      },
    );
  }

  pub fn move(
    noalias self: *const xdg_toplevel,
    noalias proxy: *Proxy,
    seat: wl_seat,
    serial: u32,
  ) void {
    const Opcode = 5;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .object = seat.toInt() },
        .{ .uint = serial },
      },
    );
  }

  pub fn resize(
    noalias self: *const xdg_toplevel,
    noalias proxy: *Proxy,
    seat: wl_seat,
    serial: u32,
    edges: ResizeEdge,
  ) void {
    const Opcode = 6;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .object = seat.toInt() },
        .{ .uint = serial },
        .{ .uint = edges.toInt() },
      },
    );
  }

  pub fn set_max_size(
    noalias self: *const xdg_toplevel,
    noalias proxy: *Proxy,
    width: i32,
    height: i32,
  ) void {
    const Opcode = 7;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .int = width },
        .{ .int = height },
      },
    );
  }

  pub fn set_min_size(
    noalias self: *const xdg_toplevel,
    noalias proxy: *Proxy,
    width: i32,
    height: i32,
  ) void {
    const Opcode = 8;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .int = width },
        .{ .int = height },
      },
    );
  }

  pub fn set_maximized(
    noalias self: *const xdg_toplevel,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 9;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn unset_maximized(
    noalias self: *const xdg_toplevel,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 10;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn set_fullscreen(
    noalias self: *const xdg_toplevel,
    noalias proxy: *Proxy,
    output: wl_output,
  ) void {
    const Opcode = 11;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .object = output.toInt() },
      },
    );
  }

  pub fn unset_fullscreen(
    noalias self: *const xdg_toplevel,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 12;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn set_minimized(
    noalias self: *const xdg_toplevel,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 13;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub const configure = struct {
    width: i32,
    height: i32,
    states: []const u8,
  };

  pub const close = void;

  pub const configure_bounds = struct {
    width: i32,
    height: i32,
  };

  pub const wm_capabilities = struct {
    capabilities: []const u8,
  };

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
            .{ .int = undefined },
            .{ .int = undefined },
            .{ .array = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .xdg_toplevel_configure = .{
              .width = args_in[0].int,
              .height = args_in[1].int,
              .states = args_in[2].array,
            }
          };
        },
        1 => {
          var args_in = [_]MessageArg{
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .xdg_toplevel_close = {
            }
          };
        },
        2 => {
          var args_in = [_]MessageArg{
            .{ .int = undefined },
            .{ .int = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .xdg_toplevel_configure_bounds = .{
              .width = args_in[0].int,
              .height = args_in[1].int,
            }
          };
        },
        3 => {
          var args_in = [_]MessageArg{
            .{ .array = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .xdg_toplevel_wm_capabilities = .{
              .capabilities = args_in[0].array,
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN xdg_toplevel ENUMS
  //---------------------------------------------------------------------------

  pub const Error = enum (u32) {
    invalid_resize_edge = 0,
    invalid_parent = 1,
    invalid_size = 2,

    pub fn toInt(self: Error) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Error {
      return @enumFromInt(int);
    }
  };

  pub const ResizeEdge = enum (u32) {
    none = 0,
    top = 1,
    bottom = 2,
    left = 4,
    top_left = 5,
    bottom_left = 6,
    right = 8,
    top_right = 9,
    bottom_right = 10,

    pub fn toInt(self: ResizeEdge) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) ResizeEdge {
      return @enumFromInt(int);
    }
  };

  pub const State = enum (u32) {
    maximized = 1,
    fullscreen = 2,
    resizing = 3,
    activated = 4,
    tiled_left = 5,
    tiled_right = 6,
    tiled_top = 7,
    tiled_bottom = 8,
    suspended = 9,
    constrained_left = 10,
    constrained_right = 11,
    constrained_top = 12,
    constrained_bottom = 13,

    pub fn toInt(self: State) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) State {
      return @enumFromInt(int);
    }
  };

  pub const WmCapabilities = enum (u32) {
    window_menu = 1,
    maximize = 2,
    fullscreen = 3,
    minimize = 4,

    pub fn toInt(self: WmCapabilities) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) WmCapabilities {
      return @enumFromInt(int);
    }
  };
  //---------------------------------------------------------------------------

  pub const Name = "xdg_toplevel";
  pub const Version = 7;
};

pub const xdg_popup = enum (u32) {
  _,

  pub fn object(self: xdg_popup) Object {
    return .{ .xdg_popup = self };
  }

  pub fn toInt(self: xdg_popup) u32 {
    return @intFromEnum(self);
  }

  pub fn fromInt(int: u32) xdg_popup {
    return @enumFromInt(int);
  }

  //---------------------------------------------------------------------------
  // BEGIN xdg_popup MESSAGES
  //---------------------------------------------------------------------------

  pub fn destroy(
    noalias self: *const xdg_popup,
    noalias proxy: *Proxy,
  ) void {
    const Opcode = 0;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
      },
    );
  }

  pub fn grab(
    noalias self: *const xdg_popup,
    noalias proxy: *Proxy,
    seat: wl_seat,
    serial: u32,
  ) void {
    const Opcode = 1;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .object = seat.toInt() },
        .{ .uint = serial },
      },
    );
  }

  pub fn reposition(
    noalias self: *const xdg_popup,
    noalias proxy: *Proxy,
    positioner: xdg_positioner,
    token: u32,
  ) void {
    const Opcode = 2;
    proxy.message_encode(
      self.toInt(),
      Opcode,
      &.{
        .{ .object = positioner.toInt() },
        .{ .uint = token },
      },
    );
  }

  pub const configure = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
  };

  pub const popup_done = void;

  pub const repositioned = struct {
    token: u32,
  };

  pub fn message_decode(
    proxy: *Proxy,
    opcode: u16,
    data: []const u8
  ) Event {
    return event: {
      switch (opcode) {
        0 => {
          var args_in = [_]MessageArg{
            .{ .int = undefined },
            .{ .int = undefined },
            .{ .int = undefined },
            .{ .int = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .xdg_popup_configure = .{
              .x = args_in[0].int,
              .y = args_in[1].int,
              .width = args_in[2].int,
              .height = args_in[3].int,
            }
          };
        },
        1 => {
          var args_in = [_]MessageArg{
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .xdg_popup_popup_done = {
            }
          };
        },
        2 => {
          var args_in = [_]MessageArg{
            .{ .uint = undefined },
          };
          proxy.message_decode(&args_in, data);
          break :event .{
            .xdg_popup_repositioned = .{
              .token = args_in[0].uint,
            }
          };
        },
        else => @panic("Invalid Opcode"),
      }
    };
  }
  //---------------------------------------------------------------------------

  //---------------------------------------------------------------------------
  // BEGIN xdg_popup ENUMS
  //---------------------------------------------------------------------------

  pub const Error = enum (u32) {
    invalid_grab = 0,

    pub fn toInt(self: Error) u32 {
      return @intFromEnum(self);
    }
    pub fn fromInt(int: u32) Error {
      return @enumFromInt(int);
    }
  };
  //---------------------------------------------------------------------------

  pub const Name = "xdg_popup";
  pub const Version = 7;
};

//-----------------------------------------------------------------------------

pub const Enum = union (enum) {
  invalid: void,
  zwp_linux_buffer_params_v1_error: zwp_linux_buffer_params_v1.Error,
  zwp_linux_buffer_params_v1_flags: zwp_linux_buffer_params_v1.Flags,
  zwp_linux_dmabuf_feedback_v1_tranche_flags: zwp_linux_dmabuf_feedback_v1.TrancheFlags,
  wp_presentation_error: wp_presentation.Error,
  wp_presentation_feedback_kind: wp_presentation_feedback.Kind,
  wl_display_error: wl_display.Error,
  wl_shm_error: wl_shm.Error,
  wl_shm_format: wl_shm.Format,
  wl_data_offer_error: wl_data_offer.Error,
  wl_data_source_error: wl_data_source.Error,
  wl_data_device_error: wl_data_device.Error,
  wl_data_device_manager_dnd_action: wl_data_device_manager.DndAction,
  wl_shell_error: wl_shell.Error,
  wl_shell_surface_resize: wl_shell_surface.Resize,
  wl_shell_surface_transient: wl_shell_surface.Transient,
  wl_shell_surface_fullscreen_method: wl_shell_surface.FullscreenMethod,
  wl_surface_error: wl_surface.Error,
  wl_seat_capability: wl_seat.Capability,
  wl_seat_error: wl_seat.Error,
  wl_pointer_error: wl_pointer.Error,
  wl_pointer_button_state: wl_pointer.ButtonState,
  wl_pointer_axis: wl_pointer.Axis,
  wl_pointer_axis_source: wl_pointer.AxisSource,
  wl_pointer_axis_relative_direction: wl_pointer.AxisRelativeDirection,
  wl_keyboard_keymap_format: wl_keyboard.KeymapFormat,
  wl_keyboard_key_state: wl_keyboard.KeyState,
  wl_output_subpixel: wl_output.Subpixel,
  wl_output_transform: wl_output.Transform,
  wl_output_mode: wl_output.Mode,
  wl_subcompositor_error: wl_subcompositor.Error,
  wl_subsurface_error: wl_subsurface.Error,
  zxdg_toplevel_decoration_v1_error: zxdg_toplevel_decoration_v1.Error,
  zxdg_toplevel_decoration_v1_mode: zxdg_toplevel_decoration_v1.Mode,
  xdg_wm_base_error: xdg_wm_base.Error,
  xdg_positioner_error: xdg_positioner.Error,
  xdg_positioner_anchor: xdg_positioner.Anchor,
  xdg_positioner_gravity: xdg_positioner.Gravity,
  xdg_positioner_constraint_adjustment: xdg_positioner.ConstraintAdjustment,
  xdg_surface_error: xdg_surface.Error,
  xdg_toplevel_error: xdg_toplevel.Error,
  xdg_toplevel_resize_edge: xdg_toplevel.ResizeEdge,
  xdg_toplevel_state: xdg_toplevel.State,
  xdg_toplevel_wm_capabilities: xdg_toplevel.WmCapabilities,
  xdg_popup_error: xdg_popup.Error,
};
pub const Event = union (enum) {
  invalid: void,
  zwp_linux_dmabuf_v1_format: zwp_linux_dmabuf_v1.format,
  zwp_linux_dmabuf_v1_modifier: zwp_linux_dmabuf_v1.modifier,
  zwp_linux_buffer_params_v1_created: zwp_linux_buffer_params_v1.created,
  zwp_linux_buffer_params_v1_failed: zwp_linux_buffer_params_v1.failed,
  zwp_linux_dmabuf_feedback_v1_done: zwp_linux_dmabuf_feedback_v1.done,
  zwp_linux_dmabuf_feedback_v1_format_table: zwp_linux_dmabuf_feedback_v1.format_table,
  zwp_linux_dmabuf_feedback_v1_main_device: zwp_linux_dmabuf_feedback_v1.main_device,
  zwp_linux_dmabuf_feedback_v1_tranche_done: zwp_linux_dmabuf_feedback_v1.tranche_done,
  zwp_linux_dmabuf_feedback_v1_tranche_target_device: zwp_linux_dmabuf_feedback_v1.tranche_target_device,
  zwp_linux_dmabuf_feedback_v1_tranche_formats: zwp_linux_dmabuf_feedback_v1.tranche_formats,
  zwp_linux_dmabuf_feedback_v1_tranche_flags: zwp_linux_dmabuf_feedback_v1.tranche_flags,
  wp_presentation_clock_id: wp_presentation.clock_id,
  wp_presentation_feedback_sync_output: wp_presentation_feedback.sync_output,
  wp_presentation_feedback_presented: wp_presentation_feedback.presented,
  wp_presentation_feedback_discarded: wp_presentation_feedback.discarded,
  wl_display_error: wl_display.@"error",
  wl_display_delete_id: wl_display.delete_id,
  wl_registry_global: wl_registry.global,
  wl_registry_global_remove: wl_registry.global_remove,
  wl_callback_done: wl_callback.done,
  wl_shm_format: wl_shm.format,
  wl_buffer_release: wl_buffer.release,
  wl_data_offer_offer: wl_data_offer.offer,
  wl_data_offer_source_actions: wl_data_offer.source_actions,
  wl_data_offer_action: wl_data_offer.action,
  wl_data_source_target: wl_data_source.target,
  wl_data_source_send: wl_data_source.send,
  wl_data_source_cancelled: wl_data_source.cancelled,
  wl_data_source_dnd_drop_performed: wl_data_source.dnd_drop_performed,
  wl_data_source_dnd_finished: wl_data_source.dnd_finished,
  wl_data_source_action: wl_data_source.action,
  wl_data_device_data_offer: wl_data_device.data_offer,
  wl_data_device_enter: wl_data_device.enter,
  wl_data_device_leave: wl_data_device.leave,
  wl_data_device_motion: wl_data_device.motion,
  wl_data_device_drop: wl_data_device.drop,
  wl_data_device_selection: wl_data_device.selection,
  wl_shell_surface_ping: wl_shell_surface.ping,
  wl_shell_surface_configure: wl_shell_surface.configure,
  wl_shell_surface_popup_done: wl_shell_surface.popup_done,
  wl_surface_enter: wl_surface.enter,
  wl_surface_leave: wl_surface.leave,
  wl_surface_preferred_buffer_scale: wl_surface.preferred_buffer_scale,
  wl_surface_preferred_buffer_transform: wl_surface.preferred_buffer_transform,
  wl_seat_capabilities: wl_seat.capabilities,
  wl_seat_name: wl_seat.name,
  wl_pointer_enter: wl_pointer.enter,
  wl_pointer_leave: wl_pointer.leave,
  wl_pointer_motion: wl_pointer.motion,
  wl_pointer_button: wl_pointer.button,
  wl_pointer_axis: wl_pointer.axis,
  wl_pointer_frame: wl_pointer.frame,
  wl_pointer_axis_source: wl_pointer.axis_source,
  wl_pointer_axis_stop: wl_pointer.axis_stop,
  wl_pointer_axis_discrete: wl_pointer.axis_discrete,
  wl_pointer_axis_value120: wl_pointer.axis_value120,
  wl_pointer_axis_relative_direction: wl_pointer.axis_relative_direction,
  wl_keyboard_keymap: wl_keyboard.keymap,
  wl_keyboard_enter: wl_keyboard.enter,
  wl_keyboard_leave: wl_keyboard.leave,
  wl_keyboard_key: wl_keyboard.key,
  wl_keyboard_modifiers: wl_keyboard.modifiers,
  wl_keyboard_repeat_info: wl_keyboard.repeat_info,
  wl_touch_down: wl_touch.down,
  wl_touch_up: wl_touch.up,
  wl_touch_motion: wl_touch.motion,
  wl_touch_frame: wl_touch.frame,
  wl_touch_cancel: wl_touch.cancel,
  wl_touch_shape: wl_touch.shape,
  wl_touch_orientation: wl_touch.orientation,
  wl_output_geometry: wl_output.geometry,
  wl_output_mode: wl_output.mode,
  wl_output_done: wl_output.done,
  wl_output_scale: wl_output.scale,
  wl_output_name: wl_output.name,
  wl_output_description: wl_output.description,
  zxdg_toplevel_decoration_v1_configure: zxdg_toplevel_decoration_v1.configure,
  xdg_wm_base_ping: xdg_wm_base.ping,
  xdg_surface_configure: xdg_surface.configure,
  xdg_toplevel_configure: xdg_toplevel.configure,
  xdg_toplevel_close: xdg_toplevel.close,
  xdg_toplevel_configure_bounds: xdg_toplevel.configure_bounds,
  xdg_toplevel_wm_capabilities: xdg_toplevel.wm_capabilities,
  xdg_popup_configure: xdg_popup.configure,
  xdg_popup_popup_done: xdg_popup.popup_done,
  xdg_popup_repositioned: xdg_popup.repositioned,
};
pub const Object = union (enum) {
  zwp_linux_dmabuf_v1: zwp_linux_dmabuf_v1,
  zwp_linux_buffer_params_v1: zwp_linux_buffer_params_v1,
  zwp_linux_dmabuf_feedback_v1: zwp_linux_dmabuf_feedback_v1,
  wp_presentation: wp_presentation,
  wp_presentation_feedback: wp_presentation_feedback,
  wl_display: wl_display,
  wl_registry: wl_registry,
  wl_callback: wl_callback,
  wl_compositor: wl_compositor,
  wl_shm_pool: wl_shm_pool,
  wl_shm: wl_shm,
  wl_buffer: wl_buffer,
  wl_data_offer: wl_data_offer,
  wl_data_source: wl_data_source,
  wl_data_device: wl_data_device,
  wl_data_device_manager: wl_data_device_manager,
  wl_shell: wl_shell,
  wl_shell_surface: wl_shell_surface,
  wl_surface: wl_surface,
  wl_seat: wl_seat,
  wl_pointer: wl_pointer,
  wl_keyboard: wl_keyboard,
  wl_touch: wl_touch,
  wl_output: wl_output,
  wl_region: wl_region,
  wl_subcompositor: wl_subcompositor,
  wl_subsurface: wl_subsurface,
  wl_fixes: wl_fixes,
  zxdg_decoration_manager_v1: zxdg_decoration_manager_v1,
  zxdg_toplevel_decoration_v1: zxdg_toplevel_decoration_v1,
  xdg_wm_base: xdg_wm_base,
  xdg_positioner: xdg_positioner,
  xdg_surface: xdg_surface,
  xdg_toplevel: xdg_toplevel,
  xdg_popup: xdg_popup,

  pub fn message_decode(o: Object, proxy: *Proxy, op: u16, data: []const u8) Event {
    return switch (o) {
      .zwp_linux_dmabuf_v1 => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .zwp_linux_buffer_params_v1 => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .zwp_linux_dmabuf_feedback_v1 => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .wp_presentation => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .wp_presentation_feedback => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .wl_display => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .wl_registry => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .wl_callback => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .wl_shm => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .wl_buffer => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .wl_data_offer => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .wl_data_source => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .wl_data_device => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .wl_shell_surface => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .wl_surface => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .wl_seat => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .wl_pointer => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .wl_keyboard => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .wl_touch => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .wl_output => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .zxdg_toplevel_decoration_v1 => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .xdg_wm_base => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .xdg_surface => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .xdg_toplevel => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      .xdg_popup => |interface_t| @TypeOf(interface_t).message_decode(proxy, op, data),
      else => .invalid,
    };
  }
};
const log = @import("std").log.scoped(.WaylandProtocols);
