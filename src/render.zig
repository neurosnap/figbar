const std = @import("std");
const State = @import("state.zig");
const c = @import("c.zig").c;

/// Converts an RGBA hexadecimal color formatted as 0xRRGGBBAA into normalized
/// floating-point components (0.0 - 1.0) and applies it as the active drawing
/// color on the Cairo context.
fn cairoSetSourceU32(cairo: *c.cairo_t, color: u32) void {
    c.cairo_set_source_rgba(
        cairo,
        @as(f64, @floatFromInt((color >> 24) & 0xff)) / 255.0,
        @as(f64, @floatFromInt((color >> 16) & 0xff)) / 255.0,
        @as(f64, @floatFromInt((color >> 8) & 0xff)) / 255.0,
        @as(f64, @floatFromInt((color >> 0) & 0xff)) / 255.0,
    );
}

/// Returns the byte stride for an ARGB32 buffer of the given pixel width according to Cairo's alignment rules.
pub fn getStride(buf_width: i32) i32 {
    return c.cairo_format_stride_for_width(c.CAIRO_FORMAT_ARGB32, buf_width);
}

/// Renders the current state (background and item text) directly into the shared memory
/// pixel buffer backing a Wayland wl_buffer.
///
/// Workflow:
/// - Calculate physical pixel dimensions from logical dimensions + fractional scale factor.
/// - Wrap the raw shared memory buffer (`data`) in a Cairo ARGB32 image surface.
/// - Scale the Cairo coordinate space so drawing coordinates match logical units.
/// - Clear the canvas by painting the full background (`normal_bg`).
/// - Configure a Pango layout with the requested font to measure each item's text extent.
/// - Compute starting horizontal offset based on alignment (left vs right).
/// - Draw items sequentially, alternating between selected and normal color themes:
///   - If selected: draw a filled background rectangle with `select_bg`, then text with `select_fg`.
///   - If normal: draw text directly with `normal_fg` over the default background.
pub fn render(data: []u8, state: *State) void {
    // Account for HiDPI fractional scaling: convert logical units to physical buffer pixels
    const buf_width: c_int = @intFromFloat(@as(f64, @floatFromInt(state.width)) * state.scale + 0.5);
    const buf_height: c_int = @intFromFloat(@as(f64, @floatFromInt(state.height)) * state.scale + 0.5);
    if (buf_width <= 0 or buf_height <= 0) return;

    // Use Cairo's standard stride calculation for ARGB32
    const stride = getStride(buf_width);

    // Wrap the existing Wayland shared memory buffer into a Cairo image surface
    const surface = c.cairo_image_surface_create_for_data(
        data.ptr,
        c.CAIRO_FORMAT_ARGB32,
        buf_width,
        buf_height,
        stride,
    ) orelse return;
    defer c.cairo_surface_destroy(surface);

    // Create the Cairo 2D drawing context bound to our target surface
    const cairo = c.cairo_create(surface) orelse return;
    defer c.cairo_destroy(cairo);

    // Clear the buffer first to prevent translucent/transparent backgrounds from blending over garbage memory
    c.cairo_set_operator(cairo, c.CAIRO_OPERATOR_CLEAR);
    c.cairo_paint(cairo);
    c.cairo_set_operator(cairo, c.CAIRO_OPERATOR_OVER);

    // Scale coordinate space by the HiDPI factor so all subsequent drawing uses logical pixels
    c.cairo_scale(cairo, state.scale, state.scale);
    c.cairo_set_antialias(cairo, c.CAIRO_ANTIALIAS_BEST);

    // Fill the entire bar with the default background color
    cairoSetSourceU32(cairo, state.normal_bg);
    c.cairo_paint(cairo);

    // Create a Pango layout for font handling and text layout/metrics via Cairo
    const layout = c.pango_cairo_create_layout(cairo);
    defer c.g_object_unref(layout);

    if (state.font_desc) |desc| {
        c.pango_layout_set_font_description(layout, desc);
    }

    // First pass: measure text width of every item and compute total combined width
    var width_array: [State.max_items]c_int = undefined;
    var total_width: c_int = 0;
    var max_text_height: c_int = 0;

    for (state.items[0..state.item_count], 0..) |item, i| {
        var w: c_int = 0;
        var h: c_int = 0;
        c.pango_layout_set_text(layout, item.ptr, @intCast(item.len));
        c.pango_layout_get_pixel_size(layout, &w, &h);
        width_array[i] = w;
        total_width += w;
        if (h > max_text_height) max_text_height = h;
    }

    // Set starting X coordinate depending on horizontal alignment (-r flag)
    var x: c_int = if (state.valign.right)
        @as(c_int, @intCast(state.width)) - total_width
    else
        0;

    const y = @divTrunc(@as(c_int, @intCast(state.height)) - max_text_height, 2);

    // Second pass: render each item, alternating styles (normal vs selected highlight)
    var select = false;
    for (state.items[0..state.item_count], 0..) |item, i| {
        c.pango_layout_set_text(layout, item.ptr, @intCast(item.len));

        if (select) {
            // Draw highlight background rectangle for selected item
            cairoSetSourceU32(cairo, state.select_bg);
            c.cairo_rectangle(cairo, @floatFromInt(x), 0, @floatFromInt(width_array[i]), @floatFromInt(state.height));
            c.cairo_fill(cairo);

            // Set foreground text color for selected item
            cairoSetSourceU32(cairo, state.select_fg);
            select = false;
        } else {
            // Set standard text color for normal item
            select = true;
            cairoSetSourceU32(cairo, state.normal_fg);
        }

        c.cairo_move_to(cairo, @floatFromInt(x), @floatFromInt(y));
        c.pango_cairo_show_layout(cairo, layout);

        // Advance horizontal pen position by item width
        x += width_array[i];
    }
}
