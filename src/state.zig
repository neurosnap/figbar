const std = @import("std");

pub const State = @This();

const Position = enum {
    top,
    bottom,
};

const Align = enum {
    left,
    right,
};

anchor: Position = .top,
valign: Align = .left,
font: []const u8 = "monospace 16",
normal_bg: u32 = 0x000000ff,
select_bg: u32 = 0x000000ff,
normal_fg: u32 = 0xffffffff,
select_fg: u32 = 0xffffffff,
// scale: uint8 = 1.0,
// wp_fractional_scale_manager_v1 = null,
// wp_fractional_scale_v1 = null,
// wp_viewporter = null,
// wp_viewport = null,
// item_count: usize = 0,

pub fn init() State {
    return .{};
}

pub fn parse_args(state: *State, arg_iter: *std.process.Args.Iterator) !void {
    _ = arg_iter.next(); // cmd name
    while (arg_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "-b")) {
            state.anchor = .bottom;
        } else if (std.mem.eql(u8, arg, "-r")) {
            state.valign = .right;
        } else if (std.mem.eql(u8, arg, "-f")) {
            if (arg_iter.next()) |font| {
                state.font = font;
            }
        } else if (std.mem.eql(u8, arg, "-N")) {
            state.normal_bg = try parse_hex_str(arg_iter.next());
        } else if (std.mem.eql(u8, arg, "-n")) {
            state.normal_fg = try parse_hex_str(arg_iter.next());
        } else if (std.mem.eql(u8, arg, "-S")) {
            state.select_bg = try parse_hex_str(arg_iter.next());
        } else if (std.mem.eql(u8, arg, "-s")) {
            state.select_fg = try parse_hex_str(arg_iter.next());
        }
    }
    std.debug.print(
        "state anchor={s} valign={s} font={s} normal_bg={x} normal_fg={x} select_bg={x} select_fg={x}\n",
        .{ @tagName(state.anchor), @tagName(state.valign), state.font, state.normal_bg, state.normal_fg, state.select_bg, state.select_fg },
    );
}

fn parse_hex_str(hex_str_opt: ?[]const u8) !u32 {
    if (hex_str_opt) |hex_str| {
        return try std.fmt.parseInt(u32, hex_str, 16);
    }
    return error.MissingArgValue;
}

pub fn parse_line(_: *State, line: []const u8) !void {
    std.debug.print("line: {s}\n", .{line});
}

// struct state *state = malloc(sizeof(struct state));
// state->scale = 1.0;
// state->wp_fractional_scale_manager_v1 = NULL;
// state->wp_fractional_scale_v1 = NULL;
// state->wp_viewporter = NULL;
// state->wp_viewport = NULL;
// state->font = "monospace 16";
// state->normal_bg = state->select_fg = 0x000000ff;
// state->normal_fg = state->select_bg = 0xffffffff;
// state->anchor = ZWLR_LAYER_SURFACE_V1_ANCHOR_TOP;
// state->right = false;
// state->item_count = 0;
// const char *usage = "Usage: figbar [-br] [-f font] [-N color] [-n color] [-S color] [-s color]\n";
