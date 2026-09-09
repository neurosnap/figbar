const std = @import("std");
const wayland = @import("wayland");
const wl = wayland.client.wl;
const zwlr = wayland.client.zwlr;
const wp = wayland.client.wp;
const c = @import("c.zig").c;

pub const State = @This();

pub const Item = struct {
    key: ?[]const u8 = null,
    text: []const u8 = "",
    select: bool = false,
    x_start: i32 = 0,
    x_end: i32 = 0,
};

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
wl_seat: ?*wl.Seat = null,
wl_pointer: ?*wl.Pointer = null,
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
configured: bool = false,
pointer_x: f64 = -1.0,
pointer_y: f64 = -1.0,
pointer_inside: bool = false,
line_buffer: [8192]u8 = undefined,
line_len: usize = 0,
items: [max_items]Item = undefined,
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

fn appendItemsFromSegment(state: *State, segment: []const u8, select: bool) void {
    if (segment.len == 0) return;

    var rem = segment;
    while (rem.len > 0 and state.item_count < max_items) {
        if (std.mem.startsWith(u8, rem, "[[")) {
            if (std.mem.indexOf(u8, rem[2..], "]]")) |close_idx| {
                const key = rem[2 .. 2 + close_idx];
                const after_key = rem[2 + close_idx + 2 ..];
                // Find next "[[" if any, which marks the start of the next item within this segment
                const next_key_idx = std.mem.indexOf(u8, after_key, "[[") orelse after_key.len;
                const text = after_key[0..next_key_idx];
                state.items[state.item_count] = .{
                    .key = key,
                    .text = text,
                    .select = select,
                };
                state.item_count += 1;
                rem = after_key[next_key_idx..];
                continue;
            }
        }

        // Doesn't start with "[["
        if (std.mem.indexOf(u8, rem, "[[")) |next_key_idx| {
            // Text before the next "[["
            state.items[state.item_count] = .{
                .key = null,
                .text = rem[0..next_key_idx],
                .select = select,
            };
            state.item_count += 1;
            rem = rem[next_key_idx..];
        } else {
            // Remaining text has no more "[["
            state.items[state.item_count] = .{
                .key = null,
                .text = rem,
                .select = select,
            };
            state.item_count += 1;
            break;
        }
    }
}

pub fn findItemAt(state: *const State, x: i32) ?struct { item: Item, index: usize } {
    for (state.items[0..state.item_count], 0..) |item, idx| {
        if (x >= item.x_start and x < item.x_end) {
            return .{ .item = item, .index = idx };
        }
    }
    return null;
}

pub fn parse_line(state: *State, line: []const u8) !void {
    // Strip trailing newline
    var input = line;
    if (input.len > 0 and input[input.len - 1] == '\n') {
        input = input[0 .. input.len - 1];
    }

    const copy_len = @min(input.len, state.line_buffer.len);
    @memcpy(state.line_buffer[0..copy_len], input[0..copy_len]);
    state.line_len = copy_len;
    input = state.line_buffer[0..copy_len];

    state.item_count = 0;

    // Split on '^', with '\^' as an escape for a literal '^'
    // Segments alternate: normal (select = false), selected (select = true), normal, etc.
    var current_select = false;
    var i: usize = 0;
    var start: usize = 0;
    while (i < input.len) {
        if (input[i] == '^') {
            if (i > 0 and input[i - 1] == '\\') {
                // escaped caret
                i += 1;
                continue;
            }
            appendItemsFromSegment(state, input[start..i], current_select);
            current_select = !current_select;
            start = i + 1;
        }
        i += 1;
    }
    // last segment
    appendItemsFromSegment(state, input[start..], current_select);
}

test "parse_line multiple items and carets" {
    var state = State.init();
    try state.parse_line("[[ws_1]] 1 [[ws_2]] 2 ^[[ws_3]] 3 ^  |  [[vol]]VOL 100%");

    // Item 0: key="ws_1", text=" 1 ", select=false
    try std.testing.expectEqual(@as(usize, 5), state.item_count);
    try std.testing.expectEqualStrings("ws_1", state.items[0].key.?);
    try std.testing.expectEqualStrings(" 1 ", state.items[0].text);
    try std.testing.expectEqual(false, state.items[0].select);

    // Item 1: key="ws_2", text=" 2 ", select=false
    try std.testing.expectEqualStrings("ws_2", state.items[1].key.?);
    try std.testing.expectEqualStrings(" 2 ", state.items[1].text);
    try std.testing.expectEqual(false, state.items[1].select);

    // Item 2: key="ws_3", text=" 3 ", select=true
    try std.testing.expectEqualStrings("ws_3", state.items[2].key.?);
    try std.testing.expectEqualStrings(" 3 ", state.items[2].text);
    try std.testing.expectEqual(true, state.items[2].select);

    // Item 3: key=null, text="  |  ", select=false
    try std.testing.expect(state.items[3].key == null);
    try std.testing.expectEqualStrings("  |  ", state.items[3].text);
    try std.testing.expectEqual(false, state.items[3].select);

    // Item 4: key="vol", text="VOL 100%", select=false
    try std.testing.expectEqualStrings("vol", state.items[4].key.?);
    try std.testing.expectEqualStrings("VOL 100%", state.items[4].text);
    try std.testing.expectEqual(false, state.items[4].select);
}
