pub const c = struct {
    // Cairo types
    pub const cairo_t = opaque {};
    pub const cairo_surface_t = opaque {};
    pub const cairo_format_t = enum(c_int) {
        INVALID = -1,
        ARGB32 = 0,
        RGB24 = 1,
        A8 = 2,
        A1 = 3,
        RGB16_565 = 4,
        RGB30 = 5,
    };
    pub const CAIRO_FORMAT_ARGB32 = cairo_format_t.ARGB32;

    pub const cairo_antialias_t = enum(c_int) {
        DEFAULT = 0,
        NONE = 1,
        GRAY = 2,
        SUBPIXEL = 3,
        FAST = 4,
        GOOD = 5,
        BEST = 6,
    };
    pub const CAIRO_ANTIALIAS_BEST = cairo_antialias_t.BEST;

    pub const cairo_operator_t = enum(c_int) {
        CLEAR = 0,
        SRC = 1,
        OVER = 2,
        IN = 3,
        OUT = 4,
        ATOP = 5,
        DEST = 6,
        DEST_OVER = 7,
        DEST_IN = 8,
        DEST_OUT = 9,
        DEST_ATOP = 10,
        XOR = 11,
        ADD = 12,
        SATURATE = 13,
    };
    pub const CAIRO_OPERATOR_CLEAR = cairo_operator_t.CLEAR;
    pub const CAIRO_OPERATOR_OVER = cairo_operator_t.OVER;

    // Cairo functions
    pub extern "c" fn cairo_format_stride_for_width(format: cairo_format_t, width: c_int) c_int;
    pub extern "c" fn cairo_image_surface_create_for_data(
        data: [*]u8,
        format: cairo_format_t,
        width: c_int,
        height: c_int,
        stride: c_int,
    ) ?*cairo_surface_t;
    pub extern "c" fn cairo_surface_destroy(surface: ?*cairo_surface_t) void;

    pub extern "c" fn cairo_create(target: ?*cairo_surface_t) ?*cairo_t;
    pub extern "c" fn cairo_destroy(cr: ?*cairo_t) void;

    pub extern "c" fn cairo_scale(cr: ?*cairo_t, sx: f64, sy: f64) void;
    pub extern "c" fn cairo_set_antialias(cr: ?*cairo_t, antialias: cairo_antialias_t) void;
    pub extern "c" fn cairo_set_operator(cr: ?*cairo_t, op: cairo_operator_t) void;
    pub extern "c" fn cairo_set_source_rgba(cr: ?*cairo_t, red: f64, green: f64, blue: f64, alpha: f64) void;
    pub extern "c" fn cairo_paint(cr: ?*cairo_t) void;
    pub extern "c" fn cairo_rectangle(cr: ?*cairo_t, x: f64, y: f64, width: f64, height: f64) void;
    pub extern "c" fn cairo_fill(cr: ?*cairo_t) void;
    pub extern "c" fn cairo_move_to(cr: ?*cairo_t, x: f64, y: f64) void;

    // Pango types
    pub const PangoLayout = opaque {};
    pub const PangoFontDescription = opaque {};
    pub const PangoFontMap = opaque {};
    pub const PangoContext = opaque {};
    pub const PangoFont = opaque {};
    pub const PangoFontMetrics = opaque {};
    pub const PANGO_SCALE: c_int = 1024;

    // Pango / PangoCairo functions
    pub extern "c" fn pango_cairo_create_layout(cr: ?*cairo_t) ?*PangoLayout;
    pub extern "c" fn pango_cairo_show_layout(cr: ?*cairo_t, layout: ?*PangoLayout) void;
    pub extern "c" fn pango_cairo_font_map_get_default() ?*PangoFontMap;

    pub extern "c" fn pango_layout_new(context: ?*PangoContext) ?*PangoLayout;
    pub extern "c" fn pango_layout_set_font_description(layout: ?*PangoLayout, desc: ?*const PangoFontDescription) void;
    pub extern "c" fn pango_layout_set_text(layout: ?*PangoLayout, text: [*]const u8, length: c_int) void;
    pub extern "c" fn pango_layout_get_pixel_size(layout: ?*PangoLayout, width: ?*c_int, height: ?*c_int) void;

    pub extern "c" fn pango_font_description_from_string(str: [*:0]const u8) ?*PangoFontDescription;
    pub extern "c" fn pango_font_description_free(desc: ?*PangoFontDescription) void;

    pub extern "c" fn pango_font_map_create_context(fontmap: ?*PangoFontMap) ?*PangoContext;
    pub extern "c" fn pango_font_map_load_font(fontmap: ?*PangoFontMap, context: ?*PangoContext, desc: ?*const PangoFontDescription) ?*PangoFont;

    pub extern "c" fn pango_font_get_metrics(font: ?*PangoFont, language: ?*anyopaque) ?*PangoFontMetrics;
    pub extern "c" fn pango_font_metrics_get_height(metrics: ?*PangoFontMetrics) c_int;
    pub extern "c" fn pango_font_metrics_unref(metrics: ?*PangoFontMetrics) void;

    // GObject functions
    pub extern "c" fn g_object_unref(object: ?*anyopaque) void;
};
