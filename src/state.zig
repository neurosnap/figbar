const std = @import("std");
const wayland = @import("wayland");
const wl = wayland.client.wl;
const zwlr = wayland.client.zwlr;
const wp = wayland.client.wp;
const c = @import("c.zig").c;

pub const State = @This();

pub const max_items = 1024;

anchor: zwlr.LayerSurfaceV1.Anchor = .{ .top = true, .left = true, .right = true },
valign: zwlr.LayerSurfaceV1.Anchor = .{ .left = true },
font: []const u8 = "monospace 16",
font_desc: ?*c.PangoFontDescription = null,
normal_bg: u32 = 0x000000ff,
select_bg: u32 = 0xffffffff,
normal_fg: u32 = 0xffffffff,
select_fg: u32 = 0x000000ff,

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
width: u32 = 0,
height: u32 = 0,
items: [max_items][]const u8 = undefined,
item_count: usize = 0,

pub fn init() State {
    return .{};
}

pub fn deinit(state: *State) void {
    if (state.font_desc) |desc| {
        c.pango_font_description_free(desc);
        state.font_desc = null;
    }
}

fn getFontHeight(desc: *const c.PangoFontDescription) u32 {
    const fontmap = c.pango_cairo_font_map_get_default();
    const ctx = c.pango_font_map_create_context(fontmap);
    defer c.g_object_unref(ctx);
    const font = c.pango_font_map_load_font(fontmap, ctx, desc);
    defer c.g_object_unref(font);
    const metrics = c.pango_font_get_metrics(font, null);
    defer c.pango_font_metrics_unref(metrics);
    const height = c.pango_font_metrics_get_height(metrics);
    return @intCast(@divTrunc(height, c.PANGO_SCALE));
}

fn parseColor(color: []const u8) ?u32 {
    var s = color;
    if (s.len > 0 and s[0] == '#') s = s[1..];
    if (s.len != 6 and s.len != 8) return null;
    const parsed = std.fmt.parseInt(u32, s, 16) catch return null;
    return if (s.len == 6) (parsed << 8) | 0xff else parsed;
}

pub fn parse_args(state: *State, arg_iter: *std.process.Args.Iterator) !void {
    _ = arg_iter.next(); // skip argv[0]
    while (arg_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "-b")) {
            state.anchor.top = false;
            state.anchor.bottom = true;
        } else if (std.mem.eql(u8, arg, "-r")) {
            state.valign.left = false;
            state.valign.right = true;
        } else if (std.mem.eql(u8, arg, "-f")) {
            state.font = arg_iter.next() orelse return error.MissingArg;
        } else if (std.mem.eql(u8, arg, "-N")) {
            const val = arg_iter.next() orelse return error.MissingArg;
            state.normal_bg = parseColor(val) orelse {
                std.debug.print("Invalid normal background color: {s}\n", .{val});
                return error.InvalidColor;
            };
        } else if (std.mem.eql(u8, arg, "-n")) {
            const val = arg_iter.next() orelse return error.MissingArg;
            state.normal_fg = parseColor(val) orelse {
                std.debug.print("Invalid normal foreground color: {s}\n", .{val});
                return error.InvalidColor;
            };
        } else if (std.mem.eql(u8, arg, "-S")) {
            const val = arg_iter.next() orelse return error.MissingArg;
            state.select_bg = parseColor(val) orelse {
                std.debug.print("Invalid select background color: {s}\n", .{val});
                return error.InvalidColor;
            };
        } else if (std.mem.eql(u8, arg, "-s")) {
            const val = arg_iter.next() orelse return error.MissingArg;
            state.select_fg = parseColor(val) orelse {
                std.debug.print("Invalid select foreground color: {s}\n", .{val});
                return error.InvalidColor;
            };
        } else {
            std.debug.print("Usage: figbar [-br] [-f font] [-N color] [-n color] [-S color] [-s color]\n", .{});
            return error.UnknownArg;
        }
    }

    // Parse and cache the Pango font description
    var font_buf: [256]u8 = undefined;
    const font_z = std.fmt.bufPrintZ(&font_buf, "{s}", .{state.font}) catch return error.FontNameTooLong;
    const desc = c.pango_font_description_from_string(font_z.ptr) orelse return error.InvalidFont;
    state.font_desc = desc;

    // derive height from font metrics if not set
    if (state.height == 0) {
        state.height = getFontHeight(desc) + 2;
    }
}

pub fn parse_line(state: *State, line: []const u8) !void {
    // Strip trailing newline
    var input = line;
    if (input.len > 0 and input[input.len - 1] == '\n') {
        input = input[0 .. input.len - 1];
    }

    state.item_count = 0;

    // Split on '^', with '\^' as an escape for a literal '^'
    var i: usize = 0;
    var start: usize = 0;
    while (i < input.len) {
        if (input[i] == '^') {
            if (i > 0 and input[i - 1] == '\\') {
                // escaped caret — would need in-place removal; for now just split
                i += 1;
                continue;
            }
            if (state.item_count < max_items) {
                state.items[state.item_count] = input[start..i];
                state.item_count += 1;
            }
            start = i + 1;
        }
        i += 1;
    }
    // last segment
    if (state.item_count < max_items) {
        state.items[state.item_count] = input[start..];
        state.item_count += 1;
    }
}
