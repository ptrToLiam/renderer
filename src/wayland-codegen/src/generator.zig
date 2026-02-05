pub fn main(init: std.process.Init) !void {
  const allocator = init.arena.allocator();
  var threaded: Io.Threaded = .init(allocator, .{ .environ = init.minimal.environ });
  defer threaded.deinit();
  const io = threaded.io();
  var args = try init.minimal.args.iterateAllocator(allocator);

  const program_name = args.next() orelse "wayland-protocols-generator";
  const cwd = Io.Dir.cwd();

  var debug = false;
  var out_path_opt: ?[]const u8 = null;
  var first_protocol_file_opt: ?*EntryNode = null;
  var last_protocol_file_opt: ?*EntryNode = null;
  var protocol_count: u32 = 0;

  var arg_count: u16 = 0;
  while (args.next()) |arg| : (arg_count += 1) {
    if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
      var backing: [1024]u8 = undefined;
      var stdout = Io.File.stdout().writer(io, &backing);
      try stdout.interface.print(UsageMsgFmt, .{program_name});
    } else if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--out")) {
      out_path_opt = args.next();
    } else if (std.mem.eql(u8, arg, "--debug")) {
      debug = true;
    } else {
      const protocol_path = try allocator.create(EntryNode);
      protocol_path.* = .{
        .type = .file_name,
        .name = arg,
      };
      sll_push_end(
        protocol_path,
        &first_protocol_file_opt,
        &last_protocol_file_opt,
        &protocol_count,
      );
    }
  }

  if (arg_count == 0) {
    var backing: [1024]u8 = undefined;
    var stdout = Io.File.stdout().writer(io, &backing);
    try stdout.interface.print(UsageMsgFmt, .{program_name});
  }

  var cur_protocol_file_opt: ?*EntryNode = first_protocol_file_opt;
  var output: Output = .{};
  while (cur_protocol_file_opt) |cur_protocol_file| {
    cur_protocol_file_opt = cur_protocol_file.next;
    std.debug.print(
      "reading protocol file :: {s}\n",
      .{ cur_protocol_file.name },
    );
    try generate_protocol_code(
      io,
      allocator,
      &output,
      cur_protocol_file.name,
    );
  }

  std.debug.print("found {} protocols!\n", .{output.protocol_count});

  const out_file = if (out_path_opt) |out_path|
    try cwd.createFile(
      io,
      out_path,
      .{},
    )
  else return error.FileNotFound;
  var buf: [1024]u8 = undefined;
  var out = out_file.writerStreaming(io, &buf);
  var out_writer = &out.interface;

  var protocol_opt: ?*EntryNode = output.protocol_first;
  _ = try out_writer.write(OutputBeginMsg);
  _ = try out_writer.write(WaylandGeneralTypesCodePaste);
  while (protocol_opt) |protocol| : (protocol_opt = protocol.next) {
    std.debug.print(
      "found {} interfaces in protocol {s}!\n",
      .{
        protocol.interface_count,
        protocol.name,
      },
    );

    try out_writer.print(
      ProtocolBeginFmt,
      .{ protocol.name },
    );

    var interface_opt: ?*EntryNode = protocol.interface_first;
    while (interface_opt) |interface| : (interface_opt = interface.next) {
      try write_wl_interface(
        out_writer,
        allocator,
        interface,
      );
    }

    try out_writer.print(
      ProtocolEndString,
      .{},
    );
  }

  // Write Combined Event Union
  {
    _ = try out_writer.write(CombinedEnumBeginMsg);
    protocol_opt = output.protocol_first;
    while (protocol_opt) |protocol| : (protocol_opt = protocol.next) {
      var interface_opt: ?*EntryNode = protocol.interface_first;
      while (interface_opt) |interface| : (interface_opt = interface.next) {
        var enum_opt: ?*EntryNode = interface.enum_first;
        while (enum_opt) |@"enum"| : (enum_opt = @"enum".next) {
          try out_writer.print(
            CombinedEnumEntryFmt,
            .{ interface.name, @"enum".name, interface.name, @"enum".identifier },
          );
        }
      }
    }
    _ = try out_writer.write(CombinedEnumEndMsg);
  }

  // Write Combined Event Union
  {
    _ = try out_writer.write(CombinedEventBeginMsg);
    protocol_opt = output.protocol_first;
    while (protocol_opt) |protocol| : (protocol_opt = protocol.next) {
      var interface_opt: ?*EntryNode = protocol.interface_first;
      while (interface_opt) |interface| : (interface_opt = interface.next) {
        var event_opt: ?*EntryNode = interface.event_first;
        while (event_opt) |event| : (event_opt = event.next) {
          try out_writer.print(
            CombinedEventEntryFmt,
            .{interface.name, event.name, interface.name, event.identifier},
          );
        }
      }
    }
    _ = try out_writer.write(CombinedEventEndMsg);
  }

  // Write Combined Object Union
  {
    _ = try out_writer.write(CombinedInterfaceBeginMsg);
    protocol_opt = output.protocol_first;
    while (protocol_opt) |protocol| : (protocol_opt = protocol.next) {
      var interface_opt: ?*EntryNode = protocol.interface_first;
      while (interface_opt) |interface| : (interface_opt = interface.next) {
        try out_writer.print(
          CombinedInterfaceEntryFmt,
          .{ interface.name, interface.identifier },
        );
      }
    }
    _ = try out_writer.write(CombinedInterfaceEndMsg);
  }

  try out.flush();
}

fn write_wl_interface(
  writer: *Io.Writer,
  allocator: std.mem.Allocator,
  wl_interface: *EntryNode,
) !void {
  try writer.print(
    InterfaceBeginFmt,
    .{ wl_interface.name, wl_interface.name, wl_interface.name },
  );

  // write requests / events
  {
    try writer.print(
      InterfaceBeginSectionFmt,
      .{ wl_interface.name, "MESSAGES" },
    );

    var message_opt: ?*EntryNode = wl_interface.request_first;
    while (message_opt) |wl_request| : (message_opt = wl_request.next) {
      try write_wl_message(writer, allocator, wl_interface, wl_request);
    }

    message_opt = wl_interface.event_first;
    while (message_opt) |wl_event| : (message_opt = wl_event.next) {
      try write_wl_message(writer, allocator, wl_interface, wl_event);
    }

    try writer.print(
      InterfaceEndSectionFmt,
      .{},
    );
  }

  // write enums / bitfields
  {
    try writer.print(
      InterfaceBeginSectionFmt,
      .{ wl_interface.name, "ENUMS" },
    );

    var enum_opt: ?*EntryNode = wl_interface.enum_first;
    while (enum_opt) |wl_enum| : (enum_opt = wl_enum.next) {
      try write_wl_enum(writer, wl_enum);
    }

    try writer.print(
      InterfaceEndSectionFmt,
      .{},
    );
  }

  try writer.print(
    InterfaceEndFmt,
    .{ wl_interface.name, wl_interface.version.? },
  );
}

fn write_wl_message(
  writer: *Io.Writer,
  arena: std.mem.Allocator,
  wl_interface: *EntryNode,
  wl_message: *EntryNode,
) !void {
  _ = arena;
  switch (wl_message.type) {
    .request => {
      try writer.print(
        ClientRequestBeginFmt,
        .{ wl_message.identifier, wl_interface.identifier },
      );
      if (wl_message.arg_count > 0) {
        try write_wl_args(
          writer,
          wl_message,
        );
      }
      try writer.print(
        ClientRequestArgsEndFmt,
        .{ wl_message.arg_type.? },
      );
      try writer.print(
        ClientRequestEndFmt,
        .{},
      );
    },
    .event => {
      if (wl_message.arg_count > 0) {
        try writer.print(
          ClientEventBeginFmt,
          .{wl_message.identifier},
        );
        try write_wl_args(
          writer,
          wl_message,
        );
        try writer.print(
          ClientEventEndFmt,
          .{},
        );
      } else {
        try writer.print(
          ClientEventBeginEmptyFmt,
          .{wl_message.identifier},
        );
      }
    },
    else => return error.NotAWlMessage,
  }
}

fn write_wl_enum(
  writer: *Io.Writer,
  wl_enum: *EntryNode,
) !void {
  if (wl_enum.type == .bitfield)
    try writer.print(BitfieldBeginFmt, .{wl_enum.identifier})
  else if (wl_enum.type == .@"enum")
    try writer.print(EnumBeginFmt, .{wl_enum.identifier})
  else
    return error.NotAWlEnum;

  try write_wl_args(writer, wl_enum);

  if (wl_enum.type == .bitfield)
    try writer.print(
      BitfieldEndFmt,
      .{ 32 - wl_enum.arg_count },
    )
  else if (wl_enum.type == .@"enum")
    try writer.print(
      EnumEndFmt,
      .{}
    );
}

fn write_wl_args(
  writer: *Io.Writer,
  wl_interface_entry: *EntryNode,
) !void {
  switch (wl_interface_entry.type) {
    .bitfield => {
      var bitfield_entry_opt: ?*EntryNode = wl_interface_entry.arg_first;
      while (bitfield_entry_opt) |entry| : (bitfield_entry_opt = entry.next) {
        try writer.print(BitfieldEntryFmt, .{entry.identifier});
      }
    },
    .@"enum" => {
      var enum_entry_opt: ?*EntryNode = wl_interface_entry.arg_first;
      while (enum_entry_opt) |entry| : (enum_entry_opt = entry.next) {
        if (entry.value) |entry_value| {
          try writer.print(EnumEntryValueFmt, .{entry.identifier, entry_value});
        } else {
          try writer.print(EnumEntryNoValueFmt, .{entry.identifier});
        }
      }
    },
    .event => {
      var event_arg_opt: ?*EntryNode = wl_interface_entry.arg_first;
      while (event_arg_opt) |event_arg| : (event_arg_opt = event_arg.next) {
        try writer.print(
          ClientEventEntryFmt,
          .{ event_arg.identifier, event_arg.arg_type.? },
        );
      }
    },
    .request => {
      var request_arg_opt: ?*EntryNode = wl_interface_entry.arg_first;
      while (request_arg_opt) |request_arg| : (request_arg_opt = request_arg.next) {
        try writer.print(
          ClientEventEntryFmt,
          .{ request_arg.identifier, request_arg.arg_type.? },
        );
      }
    },
    .invalid, .file_name, .protocol, .interface, .arg => return error.InvalidNodeType,
  }
}

fn generate_protocol_code(
  io: Io,
  arena: std.mem.Allocator,
  output: *Output,
  spec_filename: []const u8,
) !void {
  var local_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
  defer local_arena.deinit();
  const local_allocator = local_arena.allocator();

  const xml_spec_data = try Io.Dir.cwd().readFileAlloc(
    io,
    spec_filename,
    arena,
    .unlimited
  );
  const spec = try Xml.parse(local_allocator, xml_spec_data);

  const protocol = try arena.create(EntryNode);
  try fetch_entry_data(arena, protocol, spec.root, .protocol);

  defer sll_push_end(
    protocol,
    &output.protocol_first,
    &output.protocol_last,
    &output.protocol_count,
  );

  var spec_interfaces = spec.root.findChildrenByTag("interface");
  while (spec_interfaces.next()) |spec_interface| {
    const interface = try arena.create(EntryNode);
    try fetch_entry_data(arena, interface, spec_interface, .interface);
    defer sll_push_end(
      interface,
      &protocol.interface_first,
      &protocol.interface_last,
      &protocol.interface_count,
    );

    var spec_interface_enums = spec_interface.findChildrenByTag("enum");
    while (spec_interface_enums.next()) |spec_interface_enum| {
      const @"enum" = try arena.create(EntryNode);
      try fetch_entry_data(arena, @"enum", spec_interface_enum, .@"enum");
      defer sll_push_end(
        @"enum",
        &interface.enum_first,
        &interface.enum_last,
        &interface.enum_count,
      );

      var enum_entries = spec_interface_enum.findChildrenByTag("entry");
      while (enum_entries.next()) |enum_entry| {
        const entry = try arena.create(EntryNode);
        try fetch_entry_data(arena, entry, enum_entry, .@"arg");
        defer sll_push_end(
          entry,
          &@"enum".arg_first,
          &@"enum".arg_last,
          &@"enum".arg_count,
        );
      }
    }

    var spec_interface_events = spec_interface.findChildrenByTag("event");
    while (spec_interface_events.next()) |spec_interface_event| {
      const event = try arena.create(EntryNode);
      try fetch_entry_data(arena, event, spec_interface_event, .event);
      defer sll_push_end(
        event,
        &interface.event_first,
        &interface.event_last,
        &interface.event_count,
      );

      var event_entries = spec_interface_event.findChildrenByTag("arg");
      while (event_entries.next()) |event_entry| {
        const entry = try arena.create(EntryNode);
        try fetch_entry_data(arena, entry, event_entry, .@"arg");
        defer sll_push_end(
          entry,
          &event.arg_first,
          &event.arg_last,
          &event.arg_count,
        );
      }
    }

    var spec_interface_requests = spec_interface.findChildrenByTag("request");
    while (spec_interface_requests.next()) |spec_interface_request| {
      const request = try arena.create(EntryNode);
      try fetch_entry_data(arena, request, spec_interface_request, .request);
      request.arg_type = "void";
      defer sll_push_end(
        request,
        &interface.request_first,
        &interface.request_last,
        &interface.request_count,
      );

      var request_args = spec_interface_request.findChildrenByTag("arg");
      while (request_args.next()) |request_arg| {
        const arg = try arena.create(EntryNode);
        try fetch_entry_data(arena, arg, request_arg, .@"arg");
        if (arg.data_type == .new_id) {
          if (arg.interface == null) {
            arg.arg_type = "type";
            arg.identifier = "comptime InterfaceT";
            request.arg_type = "InterfaceT";
            sll_push_front(
              arg,
              &request.arg_first,
              &request.arg_last,
              &request.arg_count,
            );
            continue;
          }
          request.arg_type = arg.interface;
        }
        sll_push_end(
          arg,
          &request.arg_first,
          &request.arg_last,
          &request.arg_count,
        );
      }
    }
  }
}

fn fetch_entry_data(
  arena: std.mem.Allocator,
  entry: *EntryNode,
  element: *const Xml.Element,
  @"type": EntryType,
) !void {
  const entry_name = try arena.dupe(u8, element.getAttribute("name").?);
  const entry_version = if (element.getAttribute("version")) |ver|
    try arena.dupe(u8, ver)
  else null;
  const entry_summary = if (element.getAttribute("summary")) |sum|
    try arena.dupe(u8, sum)
  else null;
  const entry_description = if (element.getCharData("description")) |desc|
    try arena.dupe(u8, desc)
  else null;
  const entry_value = if (element.getAttribute("value")) |val|
    try arena.dupe(u8, val)
  else null;
  const entry_interface = if (element.getAttribute("interface")) |int|
    try arena.dupe(u8, int)
  else null;
  const entry_nullable = (element.getAttribute("nullable") != null);
  const entry_type =
    if (@"type" == .@"enum" and
    element.getAttribute("bitfield") != null)
      .bitfield
    else
      @"type";

  const entry_identifier = try toIdentifier(
    arena,
    entry_name,
    entry_type,
  );

  const entry_arg_type, const entry_data_type = arg_type: {
    // TODO: Convert to zig type OR interface type IF interface present
    if (element.getAttribute("type")) |typ| {
      const data_type = std.meta.stringToEnum(DataType, typ).?;
      break :arg_type
      .{
        if (data_type == .object and entry_interface != null)
          entry_interface
        else
          data_type.zigTypeString(),
        data_type,
      };
    }

    break :arg_type .{ null, .invalid };
  };

  entry.* = .{
    .description = entry_description,
    .version = entry_version,
    .summary = entry_summary,
    .nullable = entry_nullable,
    .value = entry_value,
    .arg_type = entry_arg_type,
    .interface = entry_interface,
    .name = entry_name,
    .identifier = entry_identifier,
    .data_type = entry_data_type,
    .type = entry_type,
  };
}

const WaylandGeneralTypesCodePaste =
\\
\\pub const MessageArg = union(enum) {
\\  string: [:0]const u8,
\\  array: []const u8,
\\  @"enum": Enum,
\\  new_id: u32,
\\  object: u32,
\\  fixed: f32,
\\  uint: u32,
\\  int: i32,
\\  fd: i32,
\\};
\\
\\pub const Proxy = struct {
\\  ctx: *anyopaque,
\\  vtable: VTable,
\\
\\  pub fn message_decode(
\\    noalias proxy: *Proxy,
\\    noalias args_out: []MessageArg,
\\    noalias message: []const u8,
\\  ) void {
\\    @call(
\\      .auto,
\\      proxy.vtable.message_decode,
\\      .{ proxy.ctx, args_out, message },
\\    );
\\  }
\\
\\  pub fn message_encode(
\\    noalias proxy: *Proxy,
\\    id: u32,
\\    opcode: u16,
\\    noalias args: []const ?MessageArg,
\\  ) void {
\\    @call(
\\      .auto,
\\      proxy.vtable.message_encode,
\\      .{ proxy.ctx, id, opcode, args },
\\    );
\\  }
\\
\\  pub fn get_id(
\\    proxy: *Proxy,
\\  ) u32 {
\\    return @call(
\\      .auto,
\\      proxy.vtable.get_id,
\\      .{ proxy.ctx },
\\    );
\\  }
\\
\\  pub fn put_object(
\\    proxy: *Proxy,
\\    object: Object,
\\  ) void {
\\    @call(
\\      .auto,
\\      proxy.vtable.put_object,
\\      .{ proxy.ctx, object },
\\    );
\\  }
\\
\\  pub fn destroy_object(
\\    proxy: *Proxy,
\\    object_id: u32,
\\  ) void {
\\    @call(
\\      .auto,
\\      proxy.vtable.destroy_object,
\\      .{ proxy.ctx, object_id },
\\    );
\\  }
\\
\\  const VTable = struct {
\\    message_decode: MessageDecodeFn,
\\    message_encode: MessageEncodeFn,
\\    get_id: GetIdFn,
\\    put_object: PutObjectFn,
\\    destroy_object: DestroyObjectFn,
\\  };
\\};
\\
\\pub const MessageDecodeFn = *const fn (
\\  noalias ctx: *anyopaque,
\\  args_out: []MessageArg,
\\  noalias message: []const u8
\\) void;
\\
\\pub const MessageEncodeFn = *const fn (
\\  noalias ctx: *anyopaque,
\\  id: u32,
\\  opcode: u16,
\\  noalias args: []?MessageArg,
\\) void;
\\
\\pub const GetIdFn = *const fn (
\\  noalias ctx: *anyopaque,
\\) u32;
\\
\\pub const PutObjectFn = *const fn (
\\  noalias ctx: *anyopaque,
\\  object: Object,
\\) void;
\\
\\pub const DestroyObjectFn = *const fn (
\\  noalias ctx: *anyopaque,
\\  object_id: u32,
\\) void;
\\
\\pub fn BitfieldMixin(comptime T: type) type {
\\  const int_type = T.@"struct".backing_int.?;
\\
\\  return struct {
\\    pub fn toInt(self: T) Int {
\\      return @bitCast(self);
\\    }
\\    pub fn fromInt(int: Int) T {
\\      return @bitCast(int);
\\    }
\\    pub fn not(self: T) T {
\\      return fromInt(~toInt(self));
\\    }
\\
\\    pub fn either(a: T, b: T) T {
\\      return fromInt(toInt(a) | toInt(b));
\\    }
\\    pub fn both(a: T, b: T) T {
\\      return fromInt(toInt(a) & toInt(b));
\\    }
\\    pub fn eql(a: T, b: T) bool {
\\      return fromInt(a) == fromInt(b);
\\    }
\\    pub fn contains(a: T, b: T) bool {
\\      return toInt(both(a, b)) == toInt(b);
\\    }
\\    pub const Int = int_type;
\\  };
\\}
\\
\\
;

const UsageMsgFmt =
\\Generate code for interacting with a set of specified Wayland protocols in
\\a less callback-heavy manner.
\\
\\The core Wayland specification document can be obtained from
\\https://gitlab.freedesktop.org/wayland/wayland
\\and other protocols can be found at
\\https://gitlab.freedesktop.org/wayland/wayland-protocols
\\
\\Usage: {s} [options] <xml specification paths> -o <output zig source>
\\Options:
\\  -h --help       Show this message and exit.
\\  --debug         Write unformatted source to STDOUT in error cases.
\\  -o --out <name> Output file to write to
\\
;

const OutputBeginMsg =
\\//  This file is generated from provided Wayland XML specifications by
\\//  wayland-code-generator and should NOT be edited manually.
\\
;

const ProtocolBeginFmt =
\\//-----------------------------------------------------------------------------
\\// BEGIN Protocol {s}
\\//-----------------------------------------------------------------------------
\\
;

const ProtocolEndString =
\\
\\//-----------------------------------------------------------------------------
\\
\\
;

const InterfaceBeginFmt =
\\
\\pub const {s} = enum (u32) {{
\\  _,
\\
\\  pub fn toInt(self: {s}) u32 {{
\\    return @intFromEnum(self);
\\  }}
\\
\\  pub fn fromInt(int: u32) {s} {{
\\    return @enumFromInt(int);
\\  }}
\\
;
const InterfaceBeginSectionFmt =
\\
\\  //---------------------------------------------------------------------------
\\  // BEGIN {s} {s}
\\  //---------------------------------------------------------------------------
\\
;
const InterfaceEndSectionFmt =
\\  //---------------------------------------------------------------------------
\\
;
const InterfaceEndFmt =
\\
\\  pub const Name = "{s}";
\\  pub const Version = {s};
\\}};
\\
;

const ClientRequestBeginFmt =
\\
\\  pub fn {s}(
\\    noalias self: *const {s},
\\    noalias proxy: *Proxy,
\\
;
const ClientRequestArgEntryFmt =
\\    {s}: {s},
\\
;
const ClientRequestArgsEndFmt =
\\  ) {s} {{
\\
;
const ClientRequestEndFmt =
\\  }}
\\
;

const ClientEventBeginFmt =
\\
\\  pub const {s} = struct {{
\\
;
const ClientEventBeginEmptyFmt =
\\
\\  pub const {s} = void;
\\
;
const ClientEventEntryFmt =
\\    {s}: {s},
\\
;
const ClientEventEndFmt =
\\  }};
\\
;

const BitfieldBeginFmt =
\\
\\  pub const {s} = packed struct (u32) {{
\\
;

const BitfieldEntryFmt =
\\    {s}: bool = false,
\\
;
const BitfieldEndFmt =
\\
\\    __reserved_bits: u{},
\\
\\    pub const toInt = Mixin.toInt;
\\    pub const fromInt = Mixin.fromInt;
\\    pub const not = Mixin.not;
\\    pub const either = Mixin.either;
\\    pub const both = Mixin.both;
\\    pub const eql = Mixin.eql;
\\    pub const contains = Mixin.contains;
\\
\\    const Mixin = BitfieldMixin(@This());
\\  }};
\\
;

const EnumBeginFmt =
\\
\\  pub const {s} = enum (u32) {{
\\
;
const EnumEntryValueFmt =
\\    {s} = {s},
\\
;
const EnumEntryNoValueFmt =
\\    {s},
\\
;
const EnumEndFmt =
\\  }};
\\
;

const CombinedInterfaceBeginMsg =
\\pub const Object = union (enum) {
\\
;
const CombinedInterfaceEntryFmt =
\\  {s}: {s},
\\
;
const CombinedInterfaceEndMsg =
\\};
\\
;

const CombinedEventBeginMsg =
\\pub const Event = union (enum) {
\\
;
const CombinedEventEntryFmt =
\\  {s}_{s}: {s}.{s},
\\
;
const CombinedEventEndMsg =
\\};
\\
;

const CombinedEnumBeginMsg =
\\pub const Enum = union (enum) {
\\
;
const CombinedEnumEntryFmt =
\\  {s}_{s}: {s}.{s},
\\
;
const CombinedEnumEndMsg =
\\};
\\
;

const DataType = enum (u32) {
  invalid,
  // u32
  uint, // uint may also be an enum/bitfield
  object,
  new_id,
  // i32
  int,
  // c_int -- but sent/received in ancillary data
  fd,
  // fixed point float -> f32
  fixed,
  // []u8
  array,
  // [:0]u8
  string,

  // basically exclusive to .destroy() requests
  destructor,

  pub fn zigType(comptime data_type: DataType) type {
    return switch (data_type) {
      .destructor, .invalid => void,
      .uint, .object, .new_id => u32,
      .int => i32,
      .fd => c_int,
      .fixed => f32,
      .array => []const u8,
      .string => [:0]const u8,
    };
  }
  pub fn zigTypeString(data_type: DataType) []const u8 {
    return switch (data_type) {
      .destructor, .invalid => @typeName(void),
      .uint, .object, .new_id => @typeName(u32),
      .int => @typeName(i32),
      .fd => @typeName(c_int),
      .fixed => @typeName(f32),
      .array => @typeName([]const u8),
      .string => @typeName([:0]const u8),
    };
  }
};

const EntryType = enum (u32) {
  invalid,
  file_name,
  protocol,
  interface,
  request,
  event,
  @"enum",
  bitfield,
  arg,
};

const EntryNode = struct {
  next: ?*EntryNode = null,
  interface_first: ?*EntryNode = null,
  interface_last: ?*EntryNode = null,
  interface_count: u32 = 0,
  enum_first: ?*EntryNode = null,
  enum_last: ?*EntryNode = null,
  enum_count: u32 = 0,
  event_first: ?*EntryNode = null,
  event_last: ?*EntryNode = null,
  event_count: u32 = 0,
  request_first: ?*EntryNode = null,
  request_last: ?*EntryNode = null,
  request_count: u32 = 0,
  arg_first: ?*EntryNode = null,
  arg_last: ?*EntryNode = null,
  arg_count: u32 = 0,
  description: ?[]const u8 = null,
  summary: ?[]const u8 = null,
  interface: ?[]const u8 = null,
  version: ?[]const u8 = null,
  value: ?[]const u8 = null,
  arg_type: ?[]const u8 = null,
  name: []const u8,
  identifier: []const u8 = undefined,
  type: EntryType = .invalid,
  data_type: DataType = .invalid,
  nullable: bool = false,
};

const Output = struct {
  protocol_first: ?*EntryNode = null,
  protocol_last: ?*EntryNode = null,
  protocol_count: u32 = 0,
};

fn sll_push_front(node: *EntryNode, first: *?*EntryNode, last: *?*EntryNode, count: *u32) void {
  if (first.*) |first_old| {
    first.* = node;
    node.next = first_old;
  } else {
    first.* = node;
    last.* = node;
  }
  count.* += 1;
}

fn sll_push_end(node: *EntryNode, first: *?*EntryNode, last: *?*EntryNode, count: *u32) void {
  if (last.*) |last_old| {
    last_old.next = node;
    last.* = node;
  } else {
    first.* = node;
    last.* = node;
  }
  count.* += 1;
  }

fn sll_remove(node: *EntryNode, first: *?*EntryNode, last: *?*EntryNode, count: *u32) void {
  if (first.* == null and last.* == null) return;

  if (first.* != null and first.*.? == node) {
    first.* = node.next;
    node.next = null;
    count.* -= 1;
    if (count.* == 0) last.* = null;
  } else {
    var iter: ?*EntryNode = first.*;
    while (iter) |cur| : (iter = cur.next) {
      if (cur.next) |next| if (next == node) {
        cur.next = node.next;
        if (last.*.? == node) last.* = cur;
        node.next = null;
        count.* -= 1;
      };
    }
  }
}

fn is_digit(char: u8) bool {
  return (char >= '0' and char <= '9');
}

pub fn toIdentifier(
  allocator: std.mem.Allocator,
  string: []const u8,
  entry_type: EntryType,
) ![]const u8 {
  std.debug.assert(string.len > 0);

  if (entry_type == .@"enum" or entry_type == .bitfield) {
    const name = try allocator.dupe(u8, string);
    name[0] = std.ascii.toUpper(name[0]);
    return name;
  }

  if (is_digit(string[0]) or Keywords.has(string)) {
    return try std.fmt.allocPrint(allocator, "@\"{s}\"", .{ string });
  }

  return string;
}
const Io = std.Io;
const Keywords = std.zig.Token.keywords;

const Xml = @import("xml.zig");
const std = @import("std");
