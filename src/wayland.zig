const std = @import("std");
const State = @import("state.zig");

const c = @import("c.zig").c;

fn registry_global(data *State, wl_registry *c.wl_registry, name u32, interface []const u8, version u32) void {
	struct state *state = data;
	if (strcmp(interface, wl_shm_interface.name) == 0) {
		state->wl_shm = wl_registry_bind(
			wl_registry, name, &wl_shm_interface, 1);
	} else if (strcmp(interface, wl_compositor_interface.name) == 0) {
		state->wl_compositor = wl_registry_bind(
			wl_registry, name, &wl_compositor_interface, 4);
	} else if (strcmp(interface, zwlr_layer_shell_v1_interface.name) == 0) {
		state->zwlr_layer_shell_v1 = wl_registry_bind(
			wl_registry, name, &zwlr_layer_shell_v1_interface, 1);
	} else if (strcmp(interface, wl_output_interface.name) == 0) {
		state->wl_output = wl_registry_bind(
			wl_registry, name, &wl_output_interface, 4);
	} else if (strcmp(interface, wp_fractional_scale_manager_v1_interface.name) == 0) {
		state->wp_fractional_scale_manager_v1 = wl_registry_bind(
			wl_registry, name, &wp_fractional_scale_manager_v1_interface, 1);
	} else if (strcmp(interface, wp_viewporter_interface.name) == 0) {
		state->wp_viewporter = wl_registry_bind(
			wl_registry, name, &wp_viewporter_interface, 1);
	}
}

const wl_registry_listener: c.wl_registry_listener = .{
	.global = registry_global,
	.global_remove = registry_global_remove,
};

pub fn wayland_init(state: *State) !void {
    state.wl_display = c.wl_display_connect(null) orelse return error.DisplayConnectFailed;
    state.wl_registry = c.wl_display_get_registry(state.wl_display);
    c.wl_registry_add_listener(state.wl_registry, &wl_registry_listener, state);
}

// state->wl_registry = wl_display_get_registry(state->wl_display);
// wl_registry_add_listener(state->wl_registry, &wl_registry_listener, state);
// wl_display_roundtrip(state->wl_display);

// state->wl_surface = wl_compositor_create_surface(state->wl_compositor);
// if (state->wp_fractional_scale_manager_v1) {
// state->wp_fractional_scale_v1 = wp_fractional_scale_manager_v1_get_fractional_scale(
// state->wp_fractional_scale_manager_v1, state->wl_surface);
// wp_fractional_scale_v1_add_listener(
//   state->wp_fractional_scale_v1, &fractional_scale_listener, state);
// }
// if (state->wp_viewporter) {
//  state->wp_viewport = wp_viewporter_get_viewport(
//  state->wp_viewporter, state->wl_surface);
// }

// state->zwlr_layer_surface_v1 = zwlr_layer_shell_v1_get_layer_surface(
// state->zwlr_layer_shell_v1,
// state->wl_surface,
// state->wl_output,
// ZWLR_LAYER_SHELL_V1_LAYER_TOP,
//  "figbar"
// );
// zwlr_layer_surface_v1_set_anchor(state->zwlr_layer_surface_v1,
//  ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT | ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT | state->anchor
// );
// zwlr_layer_surface_v1_set_size(state->zwlr_layer_surface_v1, state->width, state->height);
// zwlr_layer_surface_v1_set_exclusive_zone(state->zwlr_layer_surface_v1, state->height);
// zwlr_layer_surface_v1_add_listener(state->zwlr_layer_surface_v1, &zwlr_layer_surface_v1_listener, state);

// wl_surface_commit(state->wl_surface);
// wl_display_roundtrip(state->wl_display);
