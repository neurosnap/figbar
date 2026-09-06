const std = @import("std");
const wayland = @import("wayland");
const wl = wayland.client.wl;
const zwlr = wayland.client.zwlr;
const wp = wayland.client.wp;

pub const State = @This();

const Align = enum {
    left,
    right,
};

anchor: zwlr.LayerSurfaceV1.Anchor = .{ .top = true },
valign: zwlr.LayerSurfaceV1.Anchor = .{ .left = true },
font: []const u8 = "monospace 16",
normal_bg: u32 = 0x000000ff,
select_bg: u32 = 0x000000ff,
normal_fg: u32 = 0xffffffff,
select_fg: u32 = 0xffffffff,

wl_display: ?*wl.Display = null,
wl_registry: ?*wl.Registry = null,
wl_compositor: ?*wl.Compositor = null,
wl_surface: ?*wl.Surface = null,
wl_shm: ?*wl.Shm = null,
wl_output: ?*wl.Output = null,
zwlr_layer_shell_v1: ?*zwlr.LayerShellV1 = null,
zwlr_layer_surface_v1: ?*zwlr.LayerSurfaceV1 = null,
wp_fractional_scale_manager_v1: ?*wp.FractionalScaleManagerV1 = null,
wp_fraction_scale_v1: ?*wp.FractionalScaleV1 = null,
wp_viewporter: ?*wp.Viewporter = null,
wp_viewport: ?*wp.Viewport = null,
scale: f64 = 1.0,
width: u32 = 80,
height: u32 = 24,
// item_count: usize = 0,

pub fn init() State {
    return .{};
}

pub fn parse_args(state: *State, arg_iter: *std.process.Args.Iterator) !void {
    _ = arg_iter.next(); // cmd name
    while (arg_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "-b")) {
            state.anchor.top = false;
            state.anchor.bottom = true;
        } else if (std.mem.eql(u8, arg, "-r")) {
            state.valign.left = false;
            state.valign.right = true;
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
        "state font={s} normal_bg={x} normal_fg={x} select_bg={x} select_fg={x}\n",
        .{ state.font, state.normal_bg, state.normal_fg, state.select_bg, state.select_fg },
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
