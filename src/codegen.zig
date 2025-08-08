const std = @import("std");

const Arena = @import("Arena.zig");
const Xml = @import("xml.zig");
const linux = @import("linux.zig");

pub fn main() !void {
    Thread.ctx_init();
    const program_arena: *Arena = .init(.default);
    const xml_arena: *Arena = .init(.default);

    defer {
        Thread.ctx_deinit();
        program_arena.release();
        xml_arena.release();
    }

    var out_file: []const u8 = undefined;
    var out_dir: []const u8 = undefined;
    var protocol_files: StrList = .{};

    var args = std.process.args();
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--out")) {
            out_file = args.next().?;
        } else if (std.mem.eql(u8, arg, "--prefix")) {
            out_dir = args.next().?;
        } else {
            protocol_files.push(program_arena, arg);
        }
    }

    // Parse protocol inputs
    var protocols: ProtocolList = .{};
    const allocator = program_arena.allocator();
    while (protocol_files.top()) |spec_file| : (protocol_files.pop()) {
        log.debug("parsing spec {s}", .{spec_file});
        const spec_xml = try std.fs.cwd().readFileAlloc(
            xml_arena.allocator(),
            spec_file,
            std.math.maxInt(usize),
        );
        const spec = try Xml.parse(xml_arena.allocator(), spec_xml);
        defer xml_arena.clear();

        var interfaces: InterfaceList = .{};
        var xml_interfaces = spec.root.findChildrenByTag("interface");
        while (xml_interfaces.next()) |xml_interface| {
            // Enums/Bitfields
            var enums: EnumList = .{};
            {
                var iter = xml_interface.findChildrenByTag("enum");
                while (iter.next()) |xml_enum| {
                    var entries: EntryList = .{};
                    var entry_iter = xml_enum.findChildrenByTag("entry");
                    while (entry_iter.next()) |xml_enum_entry| {
                        const entry: Entry = .{
                            .name = try allocator.dupe(u8, xml_enum_entry.getAttribute("name").?),
                            .value = try allocator.dupe(u8, xml_enum_entry.getAttribute("value").?),
                            .summary = if (xml_enum_entry.getAttribute("summary")) |summary| try allocator.dupe(u8, summary) else null,
                        };
                        entries.push(program_arena, entry);
                    }

                    const @"enum": EnumOrBitfield =
                        if (xml_enum.getAttribute("bitfield")) |_|
                            .{ .bitfield = .{
                                .name = try allocator.dupe(u8, xml_enum.getAttribute("name").?),
                                .description = if (xml_enum.getCharData("description")) |description| try allocator.dupe(u8, description) else null,
                                .entries = entries,
                            } }
                        else
                            .{ .@"enum" = .{
                                .name = try allocator.dupe(u8, xml_enum.getAttribute("name").?),
                                .description = if (xml_enum.getCharData("description")) |description| try allocator.dupe(u8, description) else null,
                                .entries = entries,
                            } };

                    enums.push(program_arena, @"enum");
                }
            }

            // Requests
            var requests: MessageList = .{};
            {
                var iter = xml_interface.findChildrenByTag("request");
                while (iter.next()) |xml_request| {
                    var request_args: ArgList = .{};
                    var arg_iter = xml_request.findChildrenByTag("arg");
                    while (arg_iter.next()) |xml_arg| {
                        const arg: Arg = .{
                            .name = try allocator.dupe(u8, xml_arg.getAttribute("name").?),
                            .type = if (xml_arg.getAttribute("enum")) |enum_t| .{
                                .@"enum" = try allocator.dupe(u8, enum_t),
                            } else .{ .type = try .from_string(xml_arg.getAttribute("type").?) },
                            .interface = blk: {
                                const interface_str = xml_arg.getAttribute("interface") orelse break :blk null;
                                break :blk try allocator.dupe(u8, interface_str);
                            },
                            .summary = if (xml_arg.getAttribute("summary")) |summary| try allocator.dupe(u8, summary) else null,
                        };
                        request_args.push(program_arena, arg);
                    }

                    const request: Message = .{
                        .request = .{
                            .name = try allocator.dupe(u8, xml_request.getAttribute("name").?),
                            .description = if (xml_request.getCharData("description")) |description| try allocator.dupe(u8, description) else null,
                            .args = request_args,
                        },
                    };
                    requests.push(program_arena, request);
                }
            }

            // Events
            var events: MessageList = .{};
            {
                var iter = xml_interface.findChildrenByTag("event");
                while (iter.next()) |xml_event| {
                    var event_args: ArgList = .{};
                    var arg_iter = xml_event.findChildrenByTag("arg");
                    while (arg_iter.next()) |xml_arg| {
                        const arg: Arg = .{
                            .name = try allocator.dupe(u8, xml_arg.getAttribute("name").?),
                            .type = if (xml_arg.getAttribute("enum")) |enum_t| .{
                                .@"enum" = try allocator.dupe(u8, enum_t),
                            } else .{ .type = try .from_string(xml_arg.getAttribute("type").?) },
                            .interface = blk: {
                                const interface_str = xml_arg.getAttribute("interface") orelse break :blk null;
                                break :blk try allocator.dupe(u8, interface_str);
                            },
                            .summary = if (xml_arg.getAttribute("summary")) |summary| try allocator.dupe(u8, summary) else null,
                        };
                        event_args.push(program_arena, arg);
                    }

                    const event: Message = .{
                        .event = .{
                            .name = try allocator.dupe(u8, xml_event.getAttribute("name").?),
                            .description = if (xml_event.getCharData("description")) |description| try allocator.dupe(u8, description) else null,
                            .args = event_args,
                        },
                    };
                    events.push(program_arena, event);
                }
            }

            const interface: Interface = .{
                .name = try allocator.dupe(u8, xml_interface.getAttribute("name").?),
                .version = try allocator.dupe(u8, xml_interface.getAttribute("version").?),
                .description = if (xml_interface.getCharData("description")) |interface_description|
                    try allocator.dupe(u8, interface_description)
                else
                    null,
                .enums = enums,
                .requests = requests,
                .events = events,
            };
            interfaces.push(program_arena, interface);
        }

        const protocol: Protocol = .{
            .name = try allocator.dupe(u8, spec.root.getAttribute("name").?),
            .interfaces = interfaces,
        };
        defer protocols.push(program_arena, protocol);
    }

    const stdout = std.fs.File.stdout();

    // Write protocol output

    log.debug("Writing unified output", .{});
    var protocol_node_opt: ?*ProtocolList.Node = null;
    var out_contents: std.io.Writer.Allocating = try .initCapacity(allocator, 2048);
    try out_contents.writer.print(
        \\// WARNING :: This file is auto-generated and should not be edited.
        \\//            Any issues with this file should be addressed in the tool
        \\//            that produced this file.
        \\//            
        \\//            - LM
        \\ 
        \\
    , .{});

    // Write protocol structs
    {
        protocol_node_opt = protocols.first;
        while (protocol_node_opt) |protocol_node| : (protocol_node_opt = protocol_node.next) {
            // Write start of protocol
            const protocol = protocol_node.val;
            log.debug("Writing Protocol :: {f}", .{capitalize(protocol.name)});
            try out_contents.writer.print("pub const @\"{f}\" = struct {{\n", .{to_pascal(protocol.name)});

            var interface_node_opt: ?*InterfaceList.Node = protocol.interfaces.first;
            while (interface_node_opt) |interface_node| : (interface_node_opt = interface_node.next) {
                const interface = interface_node.val;
                log.debug("Writing {f} Interface :: {f}", .{
                    capitalize(protocol.name),
                    capitalize(interface.name),
                });

                // Begin Interface
                if (interface.description) |description| {
                    var lines = std.mem.splitScalar(u8, description, '\n');
                    while (lines.next()) |line|
                        if (trim_leading_whitespace(line).len > 1)
                            try out_contents.writer.print("  /// {s}\n", .{trim_leading_whitespace(line)});
                }
                try out_contents.writer.print("  pub const @\"{f}\" = struct {{\n", .{
                    to_identifier(interface.name),
                });

                // Begin Interface Events
                log.debug("Writing {f}::{f} Event union", .{
                    capitalize(protocol.name),
                    capitalize(interface.name),
                });
                if (interface.events.count > 0) {
                    var event_node_opt: ?*MessageList.Node = null;
                    try out_contents.writer.print("    pub const Event = union (enum) {{\n", .{});

                    event_node_opt = interface.events.first;
                    while (event_node_opt) |event_node| : (event_node_opt = event_node.next) {
                        const event = event_node.val.event;
                        try out_contents.writer.print("      @\"{s}\": @This().@\"{f}\",\n", .{
                            event.name,
                            to_pascal(event.name),
                        });
                    }

                    try out_contents.writer.print("\n", .{});
                    event_node_opt = interface.events.first;
                    while (event_node_opt) |event_node| : (event_node_opt = event_node.next) {
                        const event = event_node.val.event;

                        // Begin Event
                        try out_contents.writer.print("\n", .{});
                        if (event.description) |description| {
                            var lines = std.mem.splitScalar(u8, description, '\n');
                            while (lines.next()) |line|
                                if (line.len > 1)
                                    try out_contents.writer.print("      /// {s}\n", .{trim_leading_whitespace(line)});
                        }
                        try out_contents.writer.print("      pub const @\"{f}\" = ", .{
                            to_pascal(event.name),
                        });

                        if (event.args.count > 0) {
                            try out_contents.writer.print("struct {{\n", .{});
                            var arg_node_opt: ?*ArgList.Node = event.args.first;
                            while (arg_node_opt) |arg_node| : (arg_node_opt = arg_node.next) {
                                const arg = arg_node.val;
                                try out_contents.writer.print("        @\"{s}\": \"{s}\",\n", .{
                                    arg.name,
                                    switch (arg.type) {
                                        .type => |zig_type| zig_type.to_zig_type_string().?,
                                        .@"enum" => |enum_str| enum_str,
                                    },
                                });
                            }

                            // End Event
                            try out_contents.writer.print("      }};\n", .{});
                        } else try out_contents.writer.print("void;\n", .{});
                    }

                    // End Interface Events
                    try out_contents.writer.print("    }};\n\n", .{});
                }

                // Begin Interface Enums
                if (interface.enums.count > 0) {
                    log.debug("Writing {f}::{f} Enums (count={d})", .{
                        capitalize(protocol.name),
                        capitalize(interface.name),
                        interface.enums.count,
                    });
                    var enum_node_opt: ?*EnumList.Node = null;

                    try out_contents.writer.print("    pub const Enum = union (enum) {{\n", .{});
                    enum_node_opt = interface.enums.first;
                    while (enum_node_opt) |enum_node| : (enum_node_opt = enum_node.next) {
                        const @"enum" = enum_node.val;
                        const name = switch (@"enum") {
                            .@"enum" => |enum_val| enum_val.name,
                            .bitfield => |bitfield_val| bitfield_val.name,
                        };
                        try out_contents.writer.print("      @\"{s}\": @\"{f}\",\n", .{
                            name, to_pascal(name),
                        });
                    }
                    try out_contents.writer.print("\n", .{});

                    enum_node_opt = interface.enums.first;
                    while (enum_node_opt) |enum_node| : (enum_node_opt = enum_node.next) {
                        var entry_node_opt: ?*EntryList.Node = null;
                        const @"enum" = enum_node.val;
                        switch (@"enum") {
                            .@"enum" => |enum_val| {
                                log.debug("Writing {f}::{f} Enum {s}", .{
                                    capitalize(protocol.name),
                                    capitalize(interface.name),
                                    enum_val.name,
                                });
                                try out_contents.writer.print("    pub const {f} = enum (u32) {{\n", .{ to_pascal(enum_val.name) });
                                entry_node_opt = enum_val.entries.first;
                                while (entry_node_opt) |entry_node| : (entry_node_opt = entry_node.next) {
                                    const entry = entry_node.val;
                                    log.debug("Writing {f}::{f}::{s} Entry {s}", .{
                                        capitalize(protocol.name),
                                        capitalize(interface.name),
                                        enum_val.name,
                                        entry.name,
                                    });
                                    try out_contents.writer.print("      @\"{s}\" = {s},\n", .{
                                        entry.name,
                                        entry.value,
                                    });
                                }
                                try out_contents.writer.print("    }};\n\n", .{});
                            },
                            .bitfield => |bitfield_val| {
                                try out_contents.writer.print("    pub const {f} = packed struct (u32) {{\n", .{ to_pascal(bitfield_val.name) });
                                entry_node_opt = bitfield_val.entries.first;
                                var bits_remaining: u16 = 32;
                                while (entry_node_opt) |entry_node| : (entry_node_opt = entry_node.next) {
                                    const entry = entry_node.val;
                                    try out_contents.writer.print("      @\"{s}\": bool = false,\n", .{
                                        entry.name,
                                    });
                                    bits_remaining -= 1;
                                }
                                try out_contents.writer.print("      __reserved_bits: u{d} = 0,\n", .{ bits_remaining });
                                try out_contents.writer.print("    }};\n\n", .{});
                            }
                        }
                    }
                    try out_contents.writer.print("\n", .{});
                    // Write composite `Enum` type
                    log.debug("Writing {f}::{f} Enum Union", .{
                        capitalize(protocol.name),
                        capitalize(interface.name),
                    });
                    // End Interface Enums
                    try out_contents.writer.print("    }};\n\n", .{});
                }

                // Begin Interface Enums

                // End Interface
                try out_contents.writer.print(
                    \\    pub const InterfaceName = "{s}";
                    \\    pub const InterfaceVersion = {s};
                    \\  }};
                    \\
                    \\
                , .{ interface.name, interface.version });
            }

            // Write end of Protocol
            try out_contents.writer.print("}};\n\n", .{});
        }
    }

    // Write composite types
    {
        // Object
        // try out_contents.writer.print("pub const Object = union (enum) {{\n", .{});
        // protocol_node_opt = protocols.first;
        // while (protocol_node_opt) |protocol_node| : (protocol_node_opt = protocol_node.next) {
        //     const protocol = protocol_node.val;
        //     var interface_node_opt: ?*InterfaceList.Node = protocol.interfaces.first;
        //     while (interface_node_opt) |interface_node| : (interface_node_opt = interface_node.next) {
        //         const interface = interface_node.val;
        //         try out_contents.writer.print("  @\"{s}\": @\"{s}\",\n", .{
        //             interface.name,
        //             interface.name,
        //         });
        //     }
        // }
        // try out_contents.writer.print("}};\n\n", .{});

        // TODO
        // - Give every wl_interface an 'object()' function
        //   to return an 'Object' interface instance.
        // - Finish writing `Object` interface methods for parse and write.
        try out_contents.writer.print(
            \\
            \\pub const Object = struct {{
            \\  ptr: *anyopaque,
            \\  vtable: VTable,
            \\
            \\  pub inline fn parse_msg(noalias object: *Object, op: u16, data: []const u8) Proxy.ParseError!void {{
            \\    try @call(.auto, object.vtable.parse_msg, .{{op, data}});
            \\  }}
            \\
            \\  pub inline fn write_msg(noalias object: *Object, op: u16, args: []MessageArg) Proxy.WriteError!void {{
            \\    try @call(.auto, object.vtable.write_msg, .{{op, args}});
            \\  }}
            \\
            \\  pub const VTable = struct {{
            \\    parse_msg: *const fn (ctx: *anyopaque, op: u16, data: []const u8) Proxy.ParseError!void,
            \\    write_msg: *const fn (ctx: *anyopaque, op: u16, args: []MessageArg) Proxy.WriteError!void,
            \\  }};
            \\}};
            \\
        , .{});

        try out_contents.writer.print(
            \\
            \\const Proxy = struct {{
            \\    ctx: *anyopaque,
            \\    vtable: VTable,
            \\
            \\    pub inline fn msg_parse(noalias proxy: *const Proxy, args_out: []MessageArg, data: []const u8) ParseError!void {{
            \\        try @call(.auto, proxy.vtable.msg_parse_fn, .{{args_out, data}});
            \\    }}
            \\    pub inline fn msg_write(noalias proxy: *const Proxy, id: u32, op: u16, args: []MessageArg) WriteError!void {{
            \\        try @call(.auto, proxy.vtable.msg_write_fn, .{{id, op, args}});
            \\    }}
            \\
            \\    const VTable = struct {{
            \\        msg_parse_fn: *const fn(ctx: *anyopaque, args_out: []MessageArg, data: []const u8) ParseError!void,
            \\        msg_write_fn: *const fn(ctx: *anyopaque, id: u32, op: u16, args: []MessageArg) WriteError!void,
            \\    }};
            \\
            \\    pub const ParseError = error{{
            \\        ParseFailed,
            \\    }};
            \\    pub const WriteError = error{{
            \\        WriteFailed,
            \\    }};
            \\}};
            \\
        , .{});

        try out_contents.writer.print(
            \\
            \\const MessageArg = union(enum) {{
            \\    int: i32,
            \\    uint: u32,
            \\    fixed: f32,
            \\    object: u32,
            \\    string: [:0]const u8,
            \\    array: []const u8,
            \\    new_id: u32,
            \\    fd: std.posix.fd_t,
            \\    @"enum": Enum,
            \\}};
            \\
        , .{});

        // Event
        try out_contents.writer.print("\npub const Event = union (enum) {{\n", .{});
        protocol_node_opt = protocols.first;
        while (protocol_node_opt) |protocol_node| : (protocol_node_opt = protocol_node.next) {
            const protocol = protocol_node.val;
            var interface_node_opt: ?*InterfaceList.Node = protocol.interfaces.first;
            while (interface_node_opt) |interface_node| : (interface_node_opt = interface_node.next) {
                const interface = interface_node.val;
                if (interface.events.count > 0)
                    try out_contents.writer.print("  @\"{s}\": @\"{s}\".Event,\n", .{
                        interface.name,
                        interface.name,
                    });
            }
        }
        try out_contents.writer.print("}};\n\n", .{});

        // Enum
        try out_contents.writer.print("\npub const Enum = union (enum) {{\n", .{});
        protocol_node_opt = protocols.first;
        while (protocol_node_opt) |protocol_node| : (protocol_node_opt = protocol_node.next) {
            const protocol = protocol_node.val;
            var interface_node_opt: ?*InterfaceList.Node = protocol.interfaces.first;
            while (interface_node_opt) |interface_node| : (interface_node_opt = interface_node.next) {
                const interface = interface_node.val;
                if (interface.enums.count > 0)
                    try out_contents.writer.print("  @\"{s}\": @\"{s}\".Enum,\n", .{
                        interface.name,
                        interface.name,
                    });
            }
        }
        try out_contents.writer.print("}};\n\n", .{});
    }

    // Write interface aliases
    {
        protocol_node_opt = protocols.first;
        while (protocol_node_opt) |protocol_node| : (protocol_node_opt = protocol_node.next) {
            const protocol = protocol_node.val;
            var interface_node_opt: ?*InterfaceList.Node = protocol.interfaces.first;
            while (interface_node_opt) |interface_node| : (interface_node_opt = interface_node.next) {
                const interface = interface_node.val;
                try out_contents.writer.print("const @\"{s}\" = @\"{f}\".@\"{f}\";\n", .{
                    interface.name,
                    to_pascal(protocol.name),
                    to_identifier(interface.name),
                });
            }
        }
    }

    try out_contents.writer.writeAll("\nconst std = @import(\"std\");");

    // Validate & Format
    const formatted = blk: {
        // Validate Zig AST parse of output
        const tree = try std.zig.Ast.parse(xml_arena.allocator(), try xml_arena.allocator().dupeZ(u8, out_contents.getWritten()), .zig);
        // Format output
        const i_formatted = if (tree.errors.len > 0) i_blk: {
            break :i_blk try out_contents.toOwnedSlice();
        } else try tree.renderAlloc(program_arena.allocator());

        break :blk i_formatted;
    };

    log.debug(":: Formatted ::\n{s}", .{formatted});
    try stdout.writeAll(formatted);
}

const Protocol = struct {
    name: []const u8,
    interfaces: InterfaceList = .{},
};

const Interface = struct {
    name: []const u8,
    version: []const u8,
    description: ?[]const u8 = null,
    requests: MessageList = .{},
    events: MessageList = .{},
    enums: EnumList = .{},
};

const Message = union(enum) {
    request: Request,
    event: Event,

    const Request = struct {
        name: []const u8,
        description: ?[]const u8,
        args: ArgList = .{},
    };

    const Event = struct {
        name: []const u8,
        description: ?[]const u8,
        args: ArgList = .{},
    };
};

const Arg = struct {
    name: []const u8,
    type: union(enum) {
        type: Type,
        @"enum": []const u8,
    },
    interface: ?[]const u8,
    summary: ?[]const u8,
};

const EnumOrBitfield = union(enum) {
    @"enum": Enum,
    bitfield: Bitfield,
};

const Enum = struct {
    name: []const u8,
    description: ?[]const u8,
    entries: EntryList = .{},
};

const Bitfield = struct {
    name: []const u8,
    description: ?[]const u8,
    entries: EntryList = .{},
};

const Entry = struct {
    name: []const u8,
    value: []const u8,
    summary: ?[]const u8,
};

const Type = enum {
    int,
    uint,
    fixed,
    string,
    object,
    new_id,
    array,
    fd,

    pub fn from_string(str: []const u8) !Type {
        return std.meta.stringToEnum(Type, str) orelse {
            return error.UnknownType;
        };
    }
    pub fn to_zig_type_string(T: Type) ?[]const u8 {
        return switch (T) {
            .fd => "std.posix.fd_t",
            .int => "i32",
            .fixed => "f32",
            .array => "[]const u8",
            .string => "[:0]const u8",
            .uint, .object, .new_id => "u32",
        };
    }
};

fn trim_leading_whitespace(str: []const u8) []const u8 {
    var start_idx: usize = 0;
    for (str, 0..) |char, idx| {
        if (!(char == ' ' or
            char == '\t' or
            char == '\x00'))
        {
            start_idx = idx;
            break;
        }
    }

    return str[start_idx..];
}

pub fn List(comptime T: type) type {
    return struct {
        first: ?*Node = null,
        last: ?*Node = null,
        count: usize = 0,

        pub fn push(noalias list: *ListT, noalias arena: *Arena, val: T) void {
            const node = arena.create(Node);

            defer list.count += 1;
            defer list.last = node;

            node.* = .{
                .val = val,
            };

            if (list.last) |last| {
                last.next = node;
            } else {
                list.first = node;
            }
        }

        pub fn pop(list: *ListT) void {
            if (list.first) |first| {
                list.first = first.next;
                list.count -= 1;
            }
        }

        pub fn top(list: *ListT) ?T {
            const node = list.first orelse return null;
            return node.val;
        }

        pub const Node = struct {
            next: ?*Node = null,
            val: T,
        };

        const ListT = @This();
    };
}

const MessageArg = union(enum) {
    int: i32,
    uint: u32,
    fixed: f32,
    object: u32,
    string: [:0]const u8,
    array: []const u8,
    new_id: u32,
    fd: std.posix.fd_t,
    @"enum": Enum,
};

const FdQueue = struct {};
inline fn parse_u32(buf: []const u8) u32 {
    return @bitCast(buf[0..4]);
}

const Proxy = struct {
    ctx: *anyopaque,
    vtable: VTable,

    pub inline fn msg_parse(noalias proxy: *const Proxy, args_out: []MessageArg, data: []const u8) ParseError!void {
        try @call(.auto, proxy.vtable.msg_parse_fn, .{ args_out, data });
    }
    pub inline fn msg_write(noalias proxy: *const Proxy, id: u32, op: u16, args: []MessageArg) WriteError!void {
        try @call(.auto, proxy.vtable.msg_write_fn, .{ id, op, args });
    }
    pub inline fn next_fd(noalias proxy: *const Proxy) ?std.posix.fd_t {
        try @call(.auto, proxy.vtable.next_fd_fn, .{});
    }

    const VTable = struct {
        msg_parse_fn: *const fn (ctx: *anyopaque, args_out: []MessageArg, data: []const u8) ParseError!void,
        msg_write_fn: *const fn (ctx: *anyopaque, id: u32, op: u16, args: []MessageArg) WriteError!void,
        next_fd_fn: *const fn (ctx: *anyopaque) ?std.posix.fd_t,
    };

    pub const ParseError = error{
        ParseFailed,
    };
    pub const WriteError = error{
        WriteFailed,
    };
};

const Connection = struct {};

// Interface::msg_parse(connection: *Connection) -> Event:
// var args_out = [_]MessageArg{param_1, param_2, ..., param_n};
// connection.msg_parse(&args_out)
// return .{
//   .Interface = .{
//     .event = .{
//       .param_1 = args_out[0],
//       .param_2 = args_out[1],
//       ...
//       .param_n = args_out[n-1],
//     }
//   }
// }
fn msg_parse(connection: *Connection, args_out: []MessageArg, data: []const u8) void {
    var offset: u32 = 0;
    for (args_out) |*arg| {
        switch (arg.*) {
            .fd => |*arg_fd| {
                arg_fd.* = connection.fd_queue.next().?;
            },
            .uint, .object, .new_id => |*uint_arg| {
                uint_arg.* = std.mem.bytesToValue(u32, &data[offset..][0..4]);
                offset += 4;
            },
            .int => |*int_arg| {
                int_arg.* = std.mem.bytesToValue(i32, &data[offset..][0..4]);
                offset += 4;
            },
            .@"enum" => |*enum_arg| {
                const int_ptr: *u32 = @ptrCast(enum_arg);
                int_ptr.* = std.mem.bytesToValue(u32, &data[offset..][0..4]);
                offset += 4;
            },
            .fixed => |*fixed_arg| {
                const int_val = std.mem.bytesToValue(i32, &data[offset..][0..4]);
                offset += 4;
                fixed_arg.* = @as(f32, @floatFromInt(int_val)) / 256;
            },
            .string => |*string_arg| {
                const str_len = std.mem.bytesToValue(u32, data[offset..][0..4]);
                offset += 4;
                const rounded_len = round_up(str_len, 4);
                string_arg.* = @ptrCast(data[offset..][0 .. str_len - 1 :0]);
                offset += rounded_len;
            },
            .array => |*array_arg| {
                const arr_len = std.mem.bytesToValue(u32, data[offset..][0..4]);
                offset += 4;
                const rounded_len = round_up(arr_len, 4);
                array_arg.* = data[offset..][0..arr_len];
                offset += rounded_len;
            },
        }
    }
}

const PascalFromSnake = struct {
    str: []const u8,

    pub fn format(
        self: *const PascalFromSnake,
        writer: anytype,
    ) !void {
        var iter = std.mem.splitScalar(u8, self.str, '_');
        if (iter.peek()) |_| {
            while (iter.next()) |segment| try writer.print("{f}", .{
                capitalize(segment),
            });
        }
    }
};

const PrefixStripPascalFromSnake = struct {
    str: []const u8,

    pub fn format(
        self: *const PrefixStripPascalFromSnake,
        writer: anytype,
    ) !void {
        var iter = std.mem.splitScalar(u8, self.str, '_');
        if (iter.peek()) |_| {
            _ = iter.next();
            while (iter.next()) |segment| try writer.print("{f}", .{
                capitalize(segment),
            });
        }
    }
};

const CapitalString = struct {
    str: []const u8,

    pub fn format(
        self: *const CapitalString,
        writer: anytype,
    ) !void {
        if (self.str.len > 1) {
            try writer.print("{c}{s}", .{
                std.ascii.toUpper(self.str[0]),
                self.str[1..],
            });
        }
    }
};

inline fn to_pascal(str: []const u8) PascalFromSnake {
    return .{
        .str = str,
    };
}
inline fn to_identifier(str: []const u8) PrefixStripPascalFromSnake {
    return .{
        .str = str,
    };
}

inline fn capitalize(str: []const u8) CapitalString {
    return .{
        .str = str,
    };
}


fn msg_write() !void {
    //...
}
inline fn round_up(val: anytype, mul: @TypeOf(val)) @TypeOf(val) {
    if (val == 0)
        return 0
    else
        return if (val % mul == 0)
            val
        else
            val + (mul - (val % mul));
}

const StrList = List([]const u8);
const ProtocolList = List(Protocol);
const InterfaceList = List(Interface);
const MessageList = List(Message);
const ArgList = List(Arg);
const EnumList = List(EnumOrBitfield);
const EntryList = List(Entry);

const Thread = linux.Thread;
const log = std.log.scoped(.wl_codegen);
