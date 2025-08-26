const std = @import("std");

const Arena = @import("arena");
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

    var filename: []const u8 = "";
    var pathname: []const u8 = "";
    var protocol_files: StrList = .{};
    var write_to_cli: bool = false;
    var debug: bool = false;

    var args = std.process.args();
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--name")) {
            filename = args.next().?;
        } else if (std.mem.eql(u8, arg, "--prefix")) {
            pathname = args.next().?;
        } else if (std.mem.eql(u8, arg, "--cli")) {
            write_to_cli = true;
        } else if (std.mem.eql(u8, arg, "--debug")) {
            debug = true;
        } else {
            protocol_files.push(program_arena, arg);
        }
    }

    if (!write_to_cli and filename.len == 0) {
        log.warn("No output file provided, will write to CLI", .{});
        write_to_cli = true;
    }

    // Parse protocol inputs
    var protocols: ProtocolList = .{};
    const allocator = program_arena.allocator();
    while (protocol_files.top()) |spec_file| : (protocol_files.pop()) {
        if (debug) log.debug("parsing spec {s}", .{spec_file});
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
                            .nullable = if (xml_arg.getAttribute("allow-null")) |_| true else false,
                        };
                        request_args.push(program_arena, arg);
                    }

                    const request: Message = .{
                        .request = .{
                            .name = try allocator.dupe(u8, xml_request.getAttribute("name").?),
                            .description = if (xml_request.getCharData("description")) |description| try allocator.dupe(u8, description) else null,
                            .args = request_args,
                            .destructor = if (xml_request.getAttribute("type")) |_| true else false,
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
                            .nullable = if (xml_arg.getAttribute("allow-null")) |_| true else false,
                        };
                        event_args.push(program_arena, arg);
                    }

                    const event: Message = .{
                        .event = .{
                            .name = try allocator.dupe(u8, xml_event.getAttribute("name").?),
                            .description = if (xml_event.getCharData("description")) |description| try allocator.dupe(u8, description) else null,
                            .args = event_args,
                            .destructor = if (xml_event.getAttribute("type")) |_| true else false,
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

    if (debug) log.debug("Creating unified output", .{});
    var protocol_node_opt: ?*ProtocolList.Node = null;
    var out_contents: std.io.Writer.Allocating = try .initCapacity(allocator, 2048);
    try out_contents.writer.print(
        \\//                  :: WARNING ::
        \\// This file is auto-generated and should not be edited.
        \\// Any issues with this file should be addressed in the tool
        \\// that produced this file.
        \\// 
        \\// - LM
        \\ 
        \\ const WaylandProtocols = @This();
        \\
        \\
    , .{});

    // Write protocol structs
    {
        protocol_node_opt = protocols.first;
        while (protocol_node_opt) |protocol_node| : (protocol_node_opt = protocol_node.next) {
            // Write start of protocol
            const protocol = protocol_node.val;
            const protocol_name = try std.fmt.allocPrint(allocator, "{f}", .{to_pascal(protocol.name)});
            if (debug) log.debug("Writing Protocol :: {s}", .{protocol_name});
            try out_contents.writer.print("pub const @\"{s}\" = struct {{\n", .{protocol_name});

            var interface_node_opt: ?*InterfaceList.Node = protocol.interfaces.first;
            while (interface_node_opt) |interface_node| : (interface_node_opt = interface_node.next) {
                const interface = interface_node.val;
                const interface_name = try std.fmt.allocPrint(allocator, "{f}", .{to_identifier(interface.name)});

                if (debug) log.debug("Writing {s} Interface :: {s}", .{
                    protocol_name,
                    interface_name,
                });

                // Begin Interface
                if (interface.description) |description| {
                    var lines = std.mem.splitScalar(u8, description, '\n');
                    while (lines.next()) |line|
                        if (trim_leading_whitespace(line).len > 1)
                            try out_contents.writer.print("  /// {s}\n", .{trim_leading_whitespace(line)});
                }
                const interface_t_ref_str = if (std.mem.eql(u8, protocol_name, interface_name))
                    "@This()"
                else
                    try std.fmt.allocPrint(allocator, "@\"{s}\"", .{interface_name});
                try out_contents.writer.print(
                    \\  pub const @"{s}" = enum (u32) {{
                    \\    _,
                    \\
                    \\  pub fn object(self: *const {s}) Object {{
                    \\    return .{{
                    \\      .ptr = @ptrCast(self),
                    \\      .vtable = .{{
                    \\        .msg_parse_fn = msg_parse,
                    \\      }},
                    \\    }};
                    \\  }}
                    \\
                    \\  pub fn fromInt(id: u32) {s} {{
                    \\    return @enumFromInt(id);
                    \\  }}
                    \\
                    \\  pub fn toInt(self: {s}) u32 {{
                    \\    return @intFromEnum(self);
                    \\  }}
                    \\
                    \\  pub fn msg_parse(noalias ctx: *const anyopaque,
                    \\               noalias proxy: *const Proxy,
                    \\               op: u16,
                    \\               data: []const u8,
                    \\  ) ParseError!WaylandProtocols.Event {{
                    \\
                    \\    _ = ctx;    
                    \\    return try {s}.Event.parse(proxy, op, data);
                    \\  }}
                    \\
                    \\
                , .{
                    interface_name,
                    interface_t_ref_str,
                    interface_t_ref_str,
                    interface_t_ref_str,
                    interface_t_ref_str,
                });

                // Begin Interface Requests
                if (debug) log.debug("Writing {s}::{s} Requests", .{
                    protocol_name,
                    interface_name,
                });

                var request_node_opt: ?*MessageList.Node = null;
                var request_idx: usize = 0;
                request_node_opt = interface.requests.first;
                while (request_node_opt) |request_node| : (request_node_opt = request_node.next) {
                    defer request_idx += 1;
                    const request = request_node.val.request;

                    const returns_new_id = if (request.args.count > 0) 
                            (request.args.first.?.val.type == .type and
                             request.args.first.?.val.type.type == .new_id)
                        else 
                            false;

                    try out_contents.writer.print("  pub fn @\"{s}\"(noalias self: *const {s}, noalias proxy: *Proxy", .{
                        request.name,
                        interface_t_ref_str,
                    });

                    var arg_node_opt: ?*ArgList.Node = request.args.first;
                    const returns_new_id_as_u32 = while (arg_node_opt) |arg_node| : (arg_node_opt = arg_node.next) {
                        const arg = arg_node.val;
                        if (arg.type == .type and arg.type.type == .new_id) break true;
                    } else false;
                    if (request.args.count == 1 and
                        returns_new_id)
                    {
                        try out_contents.writer.print(
                            \\) !{s} {{
                            \\  const request_op = {d};
                            \\  const new_id = proxy.next_id();
                            \\ 
                            \\  try proxy.msg_write(self.toInt(), request_op, &.{{ .{{ .new_id = new_id }} }},);
                            \\
                            \\  return .fromInt(new_id);
                            \\}}
                            \\
                            \\
                        , .{
                            request.args.first.?.val.interface.?,
                            request_idx,
                        });
                    } else if (request.args.count > 0) {
                        try out_contents.writer.print(", params: struct {{\n", .{});
                        var return_t: []const u8 = "void"[0..];
                        arg_node_opt = request.args.first;
                        while (arg_node_opt) |arg_node| : (arg_node_opt = arg_node.next) {
                            const arg = arg_node.val;
                            switch (arg.type) {
                                .type => |arg_t| {
                                    switch (arg_t) {
                                        .new_id => {
                                            return_t = if (arg.interface) |interface_str|
                                                interface_str
                                            else
                                                arg_t.to_zig_type_string();
                                        },
                                        .object => {
                                            try out_contents.writer.print("@\"{s}\": {s}{s},\n", .{
                                                arg.name,
                                                if (arg.nullable) "?" else "",
                                                arg.interface.?,
                                            });
                                        },
                                        else => {
                                            try out_contents.writer.print("@\"{s}\": {s},\n", .{
                                                arg.name,
                                                arg_t.to_zig_type_string(),
                                            });
                                        },
                                    }
                                },
                                .@"enum" => |enum_t| {
                                    if (std.mem.containsAtLeast(u8, enum_t, 1, ".")) {
                                        try out_contents.writer.print("@\"{s}\": {s}", .{
                                            arg.name,
                                            if (arg.nullable) "?" else "",
                                        });
                                        var part_iter = std.mem.splitScalar(u8, enum_t, '.');
                                        const interface_namespace = to_identifier(part_iter.next().?);
                                        const enum_str = part_iter.next().?;
                                        try out_contents.writer.print("@\"{f}\".Enum.@\"{f}\",\n", .{
                                            interface_namespace,
                                            to_pascal(enum_str),
                                        });
                                    } else {
                                        try out_contents.writer.print("@\"{s}\": {s}@\"{f}\".Enum.@\"{f}\",\n", .{
                                            arg.name,
                                            if (arg.nullable) "?" else "",
                                            to_identifier(interface.name),
                                            to_pascal(enum_t),
                                        });
                                    }
                                },
                            }
                        }

                        try out_contents.writer.print(
                            \\}},) !{s} {{
                            \\ const request_op = {d};
                            \\ {s}
                            \\
                            \\ try proxy.msg_write(self.toInt(), request_op, &.{{
                            \\
                            , .{
                                return_t,
                                request_idx,
                                if (returns_new_id or returns_new_id_as_u32)
                                    "const new_id = proxy.next_id();"
                                else 
                                    "",
                        });
                        arg_node_opt = request.args.first;
                        while (arg_node_opt) |arg_node| : (arg_node_opt = arg_node.next) {
                            const arg = arg_node.val;

                            switch (arg.type) {
                                .type => |arg_type| switch (arg_type) {
                                    .new_id => {
                                        try out_contents.writer.print(
                                            \\ .{{ .new_id = new_id }},
                                            \\
                                            , .{});
                                    },
                                    .object => {
                                        try out_contents.writer.print(
                                            \\ .{{ .object = params.{s}.toInt() }},
                                            \\
                                            , .{arg.name});
                                    },
                                    else => {
                                        try out_contents.writer.print(
                                            \\ .{{ .{s} = params.{s} }},
                                            \\
                                            , .{ arg_type.to_string(), arg.name });
                                    },
                                },
                                .@"enum" => |enum_t| {
                                    const interface_str, const enum_str = blk: {
                                        if (std.mem.containsAtLeast(u8, enum_t, 1, ".")) {
                                            var iter = std.mem.splitScalar(u8, enum_t, '.');
                                            break :blk .{ iter.next().?, iter.next().? };
                                        } else {
                                            break :blk .{ interface.name, enum_t };
                                        }
                                    };
                                    try out_contents.writer.print(
                                        \\ .{{
                                        \\   .@"enum" = .{{
                                        \\     .@"{s}" = .{{
                                        \\       .@"{s}" = params.{s}
                                        \\     }},
                                        \\   }},
                                        \\ }},
                                        \\
                                    , .{
                                        interface_str,
                                        enum_str,
                                        arg.name,
                                    });
                                },
                            }
                        }
                        try out_contents.writer.print(
                            \\  }},);
                            \\  {s}
                            \\}}
                            \\
                            \\
                        , .{
                            if (returns_new_id)
                                "\nreturn .fromInt(new_id);"
                            else if (returns_new_id_as_u32)
                                "\nreturn new_id;"
                            else 
                                ""
                        });
                    } else {
                        try out_contents.writer.print(
                            \\) !void {{
                            \\  const request_op = {d};
                            \\  
                            \\  try proxy.msg_write(self.toInt(), request_op, &.{{}});
                            \\}}
                            \\  
                            \\  
                            , .{ request_idx });
                    }
                }

                // Begin Interface Events
                if (debug) log.debug("Writing {f}::{f} Event union", .{
                    capitalize(protocol.name),
                    to_identifier(interface.name),
                });
                if (interface.events.count > 0) {
                    var event_node_opt: ?*MessageList.Node = null;
                    try out_contents.writer.print("    pub const Event = union (enum) {{\n", .{});

                    // Event Type Declarations
                    event_node_opt = interface.events.first;
                    while (event_node_opt) |event_node| : (event_node_opt = event_node.next) {
                        const event = event_node.val.event;
                        try out_contents.writer.print("      @\"{s}\": Interface.Event.@\"{f}\",\n", .{
                            event.name,
                            to_pascal(event.name),
                        });
                    }

                    try out_contents.writer.print("\n", .{});

                    // Event parse
                    event_node_opt = interface.events.first;
                    try out_contents.writer.print(
                        \\      inline fn parse(proxy: *const Proxy, op: u16, data: []const u8,) ParseError!WaylandProtocols.Event {{
                        \\        const event: WaylandProtocols.Event = blk: {{
                        \\          switch (op) {{
                        \\      
                    , .{});

                    var event_idx: u32 = 0;
                    while (event_node_opt) |event_node| : (event_node_opt = event_node.next) {
                        try out_contents.writer.print(
                            \\          {d} => {{
                            \\
                        , .{event_idx});
                        defer event_idx += 1;
                        const event = event_node.val.event;
                        if (event.args.count > 0) {
                            try out_contents.writer.print(
                                \\ var event_fields: [{d}]MessageArg = [{d}]MessageArg {{
                            , .{
                                event.args.count,
                                event.args.count,
                            });
                            var arg_node_opt: ?*ArgList.Node = event.args.first;
                            while (arg_node_opt) |arg_node| : (arg_node_opt = arg_node.next) {
                                const arg = arg_node.val;
                                switch (arg.type) {
                                    .@"enum" => |enum_t| {
                                        const interface_str, const enum_str = blk: {
                                            if (std.mem.containsAtLeast(u8, enum_t, 1, ".")) {
                                                var iter = std.mem.splitScalar(u8, enum_t, '.');
                                                break :blk .{ iter.next().?, iter.next().? };
                                            } else {
                                                break :blk .{ interface.name, enum_t };
                                            }
                                        };
                                        try out_contents.writer.print(
                                            \\ .{{
                                            \\   .@"enum" = .{{
                                            \\     .@"{s}" = .{{
                                            \\       .@"{s}" = .fromInt(0)
                                            \\     }},
                                            \\   }},
                                            \\ }},
                                            \\
                                        , .{
                                            interface_str,
                                            enum_str,
                                        });
                                    },
                                    .type => |@"type"| switch (@"type") {
                                        .string, .array => |type_field| try out_contents.writer.print(
                                            \\ .{{
                                            \\   .{s} = ""
                                            \\ }},
                                            \\
                                        , .{@tagName(type_field)}),

                                        else => |type_field| try out_contents.writer.print(
                                            \\ .{{
                                            \\   .{s} = 0
                                            \\ }},
                                            \\
                                        , .{@tagName(type_field)}),
                                    },
                                }
                            }

                            try out_contents.writer.print(
                                \\ }};
                                \\ try proxy.msg_parse(&event_fields, data);
                                \\ break :blk .{{
                                \\   .@"{s}" = .{{
                                \\     .@"{s}" = .fromMsgArgs(&event_fields),
                                \\   }},
                                \\ }};
                                \\ }},
                                \\ 
                            , .{
                                interface.name,
                                event.name,
                            });
                        } else {
                            try out_contents.writer.print(
                                \\ _ = &proxy; _ = &data;
                                \\ break :blk .{{
                                \\   .@"{s}" = .{{
                                \\     .@"{s}" = {{}},
                                \\   }},
                                \\ }};
                                \\ }},
                                \\ 
                            , .{
                                interface.name,
                                event.name,
                            });
                        }
                    }
                    try out_contents.writer.print(
                        \\        else => {{
                        \\          log.err("Unknown Event Code :: {{d}}", .{{op}});
                        \\          return ParseError.InvalidOp;
                        \\        }},
                        \\      }}
                        \\    }};
                        \\    return event;
                        \\
                    , .{});
                    try out_contents.writer.print("    }}\n\n", .{});

                    // Event Type Definitions
                    event_node_opt = interface.events.first;
                    while (event_node_opt) |event_node| : (event_node_opt = event_node.next) {
                        const event = event_node.val.event;

                        // Begin Event
                        try out_contents.writer.print("\n", .{});
                        if (event.description) |description| {
                            var lines = std.mem.splitScalar(u8, description, '\n');
                            while (lines.next()) |line|
                                if (trim_leading_whitespace(line).len > 1)
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
                                try out_contents.writer.print("        @\"{s}\": {s}{s},\n", .{
                                    arg.name,
                                    if (arg.nullable) "?" else "",
                                    switch (arg.type) {
                                        .type => |@"type"| switch (@"type") {
                                            .object => |T| arg.interface orelse T.to_zig_type_string(),
                                            else => |T| T.to_zig_type_string(),
                                        },
                                        .@"enum" => |enum_t| str: {
                                            const interface_str, const enum_str = blk: {
                                                if (std.mem.containsAtLeast(u8, enum_t, 1, ".")) {
                                                    var iter = std.mem.splitScalar(u8, enum_t, '.');
                                                    break :blk .{ iter.next().?, iter.next().? };
                                                } else {
                                                    break :blk .{ interface.name, enum_t };
                                                }
                                            };
                                            break :str try std.fmt.allocPrint(allocator, "@\"{f}\".Enum.@\"{f}\"", .{
                                                to_identifier(interface_str),
                                                to_pascal(enum_str),
                                            });
                                        },
                                    },
                                });
                            }

                            try out_contents.writer.print(
                                \\
                                \\        pub inline fn fromMsgArgs(msg_args: []MessageArg,) Interface.Event.@"{f}" {{
                                \\          return .{{
                                \\
                            , .{
                                to_pascal(event.name),
                            });
                            arg_node_opt = event.args.first;
                            var arg_idx: u32 = 0;
                            while (arg_node_opt) |arg_node| : (arg_node_opt = arg_node.next) {
                                defer arg_idx += 1;
                                const arg = arg_node.val;
                                if (arg.interface) |_| {
                                    try out_contents.writer.print("       .@\"{s}\" = .{{ .id = msg_args[{d}].{s} }},\n", .{
                                        arg.name,
                                        arg_idx,
                                        @tagName(arg.type.type),
                                    });
                                } else {
                                    try out_contents.writer.print("       .@\"{s}\" = msg_args[{d}].{s},\n", .{
                                        arg.name,
                                        arg_idx,
                                        switch (arg.type) {
                                            .type => |@"type"| @tagName(@"type"),
                                            .@"enum" => |enum_str| try std.fmt.allocPrint(allocator, "@\"enum\".@\"{s}\".@\"{s}\"", .{
                                                interface.name,
                                                enum_str,
                                            }),
                                        },
                                    });
                                }
                            }
                            try out_contents.writer.print(
                                \\
                                \\          }};
                                \\        }}
                                \\
                            , .{});
                            // End Event
                            try out_contents.writer.print("      }};\n", .{});
                        } else try out_contents.writer.print("void;\n", .{});
                    }

                    // End Interface Events
                    try out_contents.writer.print("    }};\n\n", .{});
                }

                // Begin Interface Enums
                if (interface.enums.count > 0) {
                    if (debug) log.debug("Writing {f}::{f} Enums (count={d})", .{
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
                                if (debug) log.debug("Writing {f}::{f} Enum {s}", .{
                                    capitalize(protocol.name),
                                    capitalize(interface.name),
                                    enum_val.name,
                                });
                                try out_contents.writer.print("    pub const {f} = enum (u32) {{\n", .{to_pascal(enum_val.name)});
                                entry_node_opt = enum_val.entries.first;
                                while (entry_node_opt) |entry_node| : (entry_node_opt = entry_node.next) {
                                    const entry = entry_node.val;
                                    if (debug) log.debug("Writing {f}::{f}::{s} Entry {s}", .{
                                        capitalize(protocol.name),
                                        to_identifier(interface.name),
                                        enum_val.name,
                                        entry.name,
                                    });
                                    try out_contents.writer.print("      @\"{s}\" = {s},\n", .{
                                        entry.name,
                                        entry.value,
                                    });
                                }
                                try out_contents.writer.print(
                                    \\
                                    \\      pub inline fn fromInt(int: u32) {f} {{
                                    \\        return @enumFromInt(int);
                                    \\      }}
                                    \\
                                , .{
                                    to_pascal(enum_val.name),
                                });
                                try out_contents.writer.print("    }};\n\n", .{});
                            },
                            .bitfield => |bitfield_val| {
                                try out_contents.writer.print("    pub const {f} = packed struct (u32) {{\n", .{to_pascal(bitfield_val.name)});
                                entry_node_opt = bitfield_val.entries.first;
                                var bits_remaining: u16 = 32;
                                while (entry_node_opt) |entry_node| : (entry_node_opt = entry_node.next) {
                                    const entry = entry_node.val;
                                    try out_contents.writer.print("      @\"{s}\": bool = false,\n", .{
                                        entry.name,
                                    });
                                    bits_remaining -= 1;
                                }
                                try out_contents.writer.print("      __reserved_bits: u{d} = 0,\n", .{bits_remaining});
                                try out_contents.writer.print(
                                    \\
                                    \\      pub inline fn fromInt(int: u32) {f} {{
                                    \\        return @bitCast(int);
                                    \\      }}
                                    \\
                                , .{
                                    to_pascal(bitfield_val.name),
                                });
                                try out_contents.writer.print("    }};\n\n", .{});
                            },
                        }
                    }
                    try out_contents.writer.print("\n", .{});
                    // Write composite `Enum` type
                    if (debug) log.debug("Writing {f}::{f} Enum Union", .{
                        capitalize(protocol.name),
                        capitalize(interface.name),
                    });
                    // End Interface Enums
                    try out_contents.writer.print("    }};\n\n", .{});
                }

                // Begin Interface Enums

                // End Interface
                try out_contents.writer.print(
                    \\
                    \\    pub const Interface = @This();
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
        // TODO
        // - Give every wl_interface an 'object()' function
        //   to return an 'Object' interface instance.
        // - Finish writing `Object` interface methods for parse and write.
        try out_contents.writer.print(
            \\
            \\pub const Object = struct {{
            \\  ptr: *const anyopaque,
            \\  vtable: VTable,
            \\
            \\  pub inline fn parse_msg(noalias object: *const Object, noalias proxy: *const Proxy, op: u16, data: []const u8) ParseError!WaylandProtocols.Event {{
            \\    return try @call(.auto, object.vtable.msg_parse_fn, .{{ object.ptr, proxy, op, data }});
            \\  }}
            \\
            \\  pub const VTable = struct {{
            \\    msg_parse_fn: *const fn (noalias ctx: *const anyopaque, noalias proxy: *const Proxy , op: u16, data: []const u8) ParseError!WaylandProtocols.Event,
            \\  }};
            \\}};
            \\
        , .{});

        try out_contents.writer.print(
            \\
            \\pub const Proxy = struct {{
            \\  ctx: *anyopaque,
            \\  vtable: VTable,
            \\
            \\  pub inline fn msg_parse(noalias proxy: *const Proxy, args_out: []MessageArg, data: []const u8) ParseError!void {{
            \\    try @call(.auto, proxy.vtable.msg_parse_fn, .{{ proxy.ctx, args_out, data }});
            \\  }}
            \\  pub inline fn msg_write(noalias proxy: *const Proxy, id: u32, op: u16, noalias args: []const ?MessageArg) WriteError!void {{
            \\    try @call(.auto, proxy.vtable.msg_write_fn, .{{ proxy.ctx, id, op, args }});
            \\  }}
            \\  pub inline fn next_id(noalias proxy: *const Proxy) u32 {{
            \\    return @call(.auto, proxy.vtable.next_id_fn, .{{ proxy.ctx }});
            \\  }}
            \\
            \\  const VTable = struct {{
            \\    msg_parse_fn: *const fn(noalias ctx: *anyopaque, args_out: []MessageArg, data: []const u8) ParseError!void,
            \\    msg_write_fn: *const fn(noalias ctx: *anyopaque, id: u32, op: u16, noalias args: []const ?MessageArg) WriteError!void,
            \\    next_id_fn: *const fn(noalias ctx: *anyopaque) u32,
            \\    obj_push_fn: *const fn(noalias ctx: *anyopaque, id: u32, noalias object: *Object) void,
            \\    obj_destroy_fn: *const fn(noalias ctx: *anyopaque, id: u32) void,
            \\  }};
            \\}};
            \\
            \\pub const ParseError = error{{
            \\  ParseFailed,
            \\  InvalidOp,
            \\}};
            \\pub const WriteError = error{{
            \\  WriteFailed,
            \\}};
            \\
        , .{});

        try out_contents.writer.print(
            \\
            \\pub const MessageArg = union(enum) {{
            \\  int: i32,
            \\  uint: u32,
            \\  fixed: f32,
            \\  object: u32,
            \\  string: [:0]const u8,
            \\  array: []const u8,
            \\  new_id: u32,
            \\  fd: std.posix.fd_t,
            \\  @"enum": Enum,
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

    try out_contents.writer.writeAll("\nconst log = std.log.scoped(.WaylandProtocols);\n");
    try out_contents.writer.writeAll("\nconst std = @import(\"std\");");

    // Validate & Format
    const formatted = blk: {
        // Validate Zig AST parse of output
        const tree = try std.zig.Ast.parse(xml_arena.allocator(), try xml_arena.allocator().dupeZ(u8, out_contents.written()), .zig);
        // Format output
        const i_formatted = if (tree.errors.len > 0) i_blk: {
            break :i_blk try out_contents.toOwnedSlice();
        } else try tree.renderAlloc(program_arena.allocator());

        break :blk i_formatted;
    };

    // check if prefix dir is present, if not, create
    if (filename.len > 0) {
        const cwd = std.fs.cwd();
        const dir_out = if (pathname.len > 0)
            cwd.openDir(pathname, .{}) catch dir: {
                log.warn("Directory '{s}/{s}' does not exist. Attempting to create it now.", .{
                    try cwd.realpathAlloc(allocator, "."),
                    pathname,
                });
                break :dir cwd.makeOpenPath(pathname, .{}) catch |err| {
                    log.err("Failed to create path '{s}/{s}' with error :: {s}", .{
                        try cwd.realpathAlloc(allocator, "."),
                        pathname,
                        @errorName(err),
                    });
                    return error.FailedToCreateOutputDir;
                };
            }
        else
            cwd;

        const file_out = dir_out.createFile(filename, .{}) catch |err| {
            log.err("Failed to create file '{s}/{s}/{s}' with error :: {s}", .{
                try cwd.realpathAlloc(allocator, "."),
                pathname,
                filename,
                @errorName(err),
            });
            return error.FailedToCreateOutputFile;
        };
        try file_out.writeAll(formatted);
        if (debug) log.debug("Wrote output to file :: {s}/{s}", .{
            pathname,
            filename,
        });
    }

    if (write_to_cli) {
        try stdout.writeAll(formatted);
    }
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
        destructor: bool = false,
    };

    const Event = struct {
        name: []const u8,
        description: ?[]const u8,
        args: ArgList = .{},
        destructor: bool = false,
    };
};

const Arg = struct {
    name: []const u8,
    type: union(enum) {
        type: Type,
        @"enum": []const u8,
    },
    nullable: bool,
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
    pub fn to_string(T: Type) []const u8 {
        return switch (T) {
            .int => "int",
            .uint => "uint",
            .fixed => "fixed",
            .string => "string",
            .object => "object",
            .new_id => "new_id",
            .array => "array",
            .fd => "fd",
        };
    }
    pub fn to_zig_type_string(T: Type) []const u8 {
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

// Helpers

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

fn trim_leading_whitespace(str: []const u8) []const u8 {
    var start_idx: usize = 0;
    for (str, 0..) |char, idx| {
        if (!(char == ' ' or
            char == '\t' or
            char == '\x00') or
            (idx == str.len))
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

const StrList = List([]const u8);
const ProtocolList = List(Protocol);
const InterfaceList = List(Interface);
const MessageList = List(Message);
const ArgList = List(Arg);
const EnumList = List(EnumOrBitfield);
const EntryList = List(Entry);

const Thread = linux.Thread;
const log = std.log.scoped(.wl_codegen);
