pub fn main(init: std.process.Init) !void {
  const io = init.io;
  const allocator = init.arena.allocator();
  var args = try init.minimal.args.iterateAllocator(allocator);

  const program_name = args.next() orelse "wayland-protocols-generator";
  const cwd = Io.Dir.cwd();
  var write_out_buffered: [512]u8 = undefined;
  const stdout = Io.File.stdout().writer(io, write_out_buffered);

  var debug = false;
  var out_path_opt: ?[]const u8 = null;
  var first_protocol_opt: ?*EntryNode = null;
  var last_protocol_opt: ?*EntryNode = null;
  var protocol_count: u32 = 0;

  while (args.next()) |arg| {
    if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
      stdout_writer.write(UsageMsg, .{program_name});
    } else if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--out")) {
      out_path_opt = arg.next();
    } else if (std.mem.eql(u8, arg, "--debug")) {
      debug = true;
    } else {
      const protocol_path = allocator.create(EntryNode);
      protocol_path.* = .{
        .type = .file_name,
        .name = arg,
      };
      dll_push(protocols_in_opt)
    }
  }
}

const UsageMsg =
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
};

const EntryType = enum (u32) {
  invalid,
  file_name,
  interface,
  request,
  event,
  @"enum",
  bitfield,
  arg,
};

const EntryNode = struct {
  next: ?*EntryNode = null,
  prev: ?*EntryNode = null,
  enum_first: ?*EntryNode = null,
  enum_count: u32 = 0,
  event_first: ?*EntryNode = null,
  event_count: u32 = 0,
  request_first: ?*EntryNode = null,
  request_count: u32 = 0,
  arg_first: ?*EntryNode = null,
  arg_count: u32 = 0,
  description: ?[]const u8 = null,
  interface: ?[]const u8 = null,
  name: []const u8,
  type: EntryType = .invalid,
  data_type: DataType = .invalid,
};

fn sll_push_end(node: *EntryNode, first: ?*EntryNode, last: ?*EntryNode, count: *u32) void {
  if (last) |last_old| {
    last_old.next = node,
    last = node,
  } else {
    first = node,
    last = node,
  }
  count.* += 1;
}

const xml = @import("xml.zig");
const std = @import("std");