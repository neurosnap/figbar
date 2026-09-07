const std = @import("std");
const State = @import("./state.zig");

const c = @cImport({
    @cDefine("_FORTIFY_SOURCE", "0");
    @cInclude("cairo/cairo.h");
    @cInclude("pango/pangocairo.h");
});

fn cairoSetSourceU32(cairo: *c.cairo_t, color: u32) void {
    c.cairo_set_source_rgba(
        cairo,
        @as(f64, @floatFromInt((color >> 24) & 0xff)) / 255.0,
        @as(f64, @floatFromInt((color >> 16) & 0xff)) / 255.0,
        @as(f64, @floatFromInt((color >> 8) & 0xff)) / 255.0,
        @as(f64, @floatFromInt((color >> 0) & 0xff)) / 255.0,
    );
}

pub fn render(data: []u8, state: *State) void {
    const buf_width: c_int = @intFromFloat(@as(f64, @floatFromInt(state.width)) * state.scale + 0.5);
    const buf_height: c_int = @intFromFloat(@as(f64, @floatFromInt(state.height)) * state.scale + 0.5);
    if (buf_width <= 0 or buf_height <= 0) return;

    const stride = buf_width * 4;

    const surface = c.cairo_image_surface_create_for_data(
        data.ptr,
        c.CAIRO_FORMAT_ARGB32,
        buf_width,
        buf_height,
        stride,
    );
    defer c.cairo_surface_destroy(surface);

    const cairo = c.cairo_create(surface);
    defer c.cairo_destroy(cairo);

    c.cairo_scale(cairo, state.scale, state.scale);
    c.cairo_set_antialias(cairo, c.CAIRO_ANTIALIAS_BEST);
    cairoSetSourceU32(cairo, state.normal_bg);
    c.cairo_paint(cairo);

    const layout = c.pango_cairo_create_layout(cairo);
    defer c.g_object_unref(layout);

    // null-terminate the font string for C
    var font_buf: [256]u8 = undefined;
    const font_z = std.fmt.bufPrintZ(&font_buf, "{s}", .{state.font}) catch "monospace 16";
    const desc = c.pango_font_description_from_string(font_z.ptr);
    c.pango_layout_set_font_description(layout, desc);
    c.pango_font_description_free(desc);

    // measure each item
    var width_array: [State.max_items]c_int = undefined;
    var total_width: c_int = 0;
    var text_height: c_int = 0;

    for (state.items[0..state.item_count], 0..) |item, i| {
        var w: c_int = 0;
        var h: c_int = 0;
        c.pango_layout_set_text(layout, item.ptr, @intCast(item.len));
        c.pango_layout_get_pixel_size(layout, &w, &h);
        width_array[i] = w;
        total_width += w;
        text_height = h;
    }

    var x: c_int = if (state.valign.right)
        @as(c_int, @intCast(state.width)) - total_width
    else
        0;

    var select = false;
    for (state.items[0..state.item_count], 0..) |item, i| {
        c.pango_layout_set_text(layout, item.ptr, @intCast(item.len));

        if (select) {
            cairoSetSourceU32(cairo, state.select_bg);
            c.cairo_rectangle(cairo, @floatFromInt(x), 0, @floatFromInt(width_array[i]), @floatFromInt(state.height));
            c.cairo_fill(cairo);
            cairoSetSourceU32(cairo, state.select_fg);
            select = false;
        } else {
            select = true;
            cairoSetSourceU32(cairo, state.normal_fg);
        }

        const y = (@as(c_int, @intCast(state.height)) - text_height) / 2;
        c.cairo_move_to(cairo, @floatFromInt(x), @floatFromInt(y));
        c.pango_cairo_show_layout(cairo, layout);

        x += width_array[i];
    }
}
