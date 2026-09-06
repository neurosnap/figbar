const std = @import("std");
const wayland = @import("wayland");
const wl = wayland.client.wl;
const zwlr = wayland.client.zwlr;
const zwlr_ls = zwlr.LayerSurfaceV1;
const wp = wayland.client.wp;
const wp_fs = wp.FractionalScaleManagerV1;
const wp_vp = wp.Viewporter;
const State = @import("state.zig");

fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, state: *State) void {
    switch (event) {
        .global => |global| {
            if (std.mem.orderZ(u8, global.interface, wl.Compositor.interface.name) == .eq) {
                state.wl_compositor = registry.bind(global.name, wl.Compositor, 4) catch return;
            } else if (std.mem.orderZ(u8, global.interface, wl.Shm.interface.name) == .eq) {
                state.wl_shm = registry.bind(global.name, wl.Shm, 1) catch return;
            } else if (std.mem.orderZ(u8, global.interface, wl.Output.interface.name) == .eq) {
                state.wl_output = registry.bind(global.name, wl.Output, 4) catch return;
            } else if (std.mem.orderZ(u8, global.interface, wl.Output.interface.name) == .eq) {
                state.zwlr_layer_shell_v1 = registry.bind(global.name, zwlr.LayerShellV1, 4) catch return;
            } else if (std.mem.orderZ(u8, global.interface, wp_fs.interface.name) == .eq) {
                state.wp_fractional_scale_manager_v1 = registry.bind(global.name, wp_fs, 1) catch return;
            } else if (std.mem.orderZ(u8, global.interface, wp_vp.interface.name) == .eq) {
                state.wp_viewporter = registry.bind(global.name, wp_vp, 1) catch return;
            }
        },
        .global_remove => {},
    }
}

fn fractionalScaleListener(
    _: *wp.FractionalScaleV1,
    event: wp.FractionalScaleV1.Event,
    state: *State,
) void {
    switch (event) {
        .preferred_scale => |ev| {
            // Note: Wayland fractional scale is numerator with denominator 120 (e.g. 120 = 1.0, 180 = 1.5)
            const scale: f64 = @as(f64, @floatFromInt(ev.scale)) / 120.0;
            std.debug.print("Preferred scale: {d:.2}\n", .{scale});
            state.scale = scale;
        },
    }
}

pub fn wayland_init(state: *State) !void {
    const display = try wl.Display.connect(null);
    state.wl_display = display;
    const registry = try display.getRegistry();
    state.wl_registry = registry;
    registry.setListener(*State, registryListener, state);
    _ = display.roundtrip();

    const surface = try wl.Compositor.createSurface(state.wl_compositor.?);
    state.wl_surface = surface;
    if (state.wp_fractional_scale_manager_v1) |wpfs| {
        const fs = try wpfs.getFractionalScale(surface);
        state.wp_fraction_scale_v1 = fs;
        fs.setListener(*State, fractionalScaleListener, state);
    }

    if (state.wp_viewporter) |vp| {
        state.wp_viewport = try vp.getViewport(surface);
    }
    const ls = try state.zwlr_layer_shell_v1.?.getLayerSurface(
        surface,
        state.wl_output,
        .top,
        "figbar",
    );
    ls.setAnchor(state.anchor);
    ls.setSize(state.width, state.height);
    ls.setExclusiveZone(state.height);

    surface.commit();
    _ = display.roundtrip();

	// zwlr_layer_surface_v1_add_listener(state->zwlr_layer_surface_v1, &zwlr_layer_surface_v1_listener, state);
}
