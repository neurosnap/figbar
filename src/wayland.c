#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wayland-client.h>
#include <unistd.h>
#include <sys/mman.h>

#include "wlr-layer-shell-unstable-v1-client-protocol.h"
#include "fractional-scale-v1-client-protocol.h"
#include "viewporter-client-protocol.h"

#include "state.h"
#include "render.h"
#include "wayland.h"
#include "shm.h"

void
wl_buffer_release(void *data, struct wl_buffer *wl_buffer)
{
	wl_buffer_destroy(wl_buffer);
}

static const struct wl_buffer_listener wl_buffer_listener = {
	.release = wl_buffer_release
};

static void
fractional_scale_preferred_scale(void *data,
		struct wp_fractional_scale_v1 *wp_fractional_scale_v1,
		uint32_t scale)
{
	struct state *state = data;
	state->scale = (double)scale / 120.0;
}

static const struct wp_fractional_scale_v1_listener fractional_scale_listener = {
	.preferred_scale = fractional_scale_preferred_scale,
};

static void
zwlr_layer_surface_v1_configure(void *data,
		struct zwlr_layer_surface_v1 *zwlr_layer_surface_v1,
		uint32_t serial, uint32_t width, uint32_t height)
{
	struct state *state = data;
	state->width = width;
	state->height = height;
	zwlr_layer_surface_v1_ack_configure(zwlr_layer_surface_v1, serial);

	if (state->wp_viewport) {
		wp_viewport_set_destination(state->wp_viewport, state->width, state->height);
	}

	struct wl_buffer *buffer = create_buffer(state);
	if (buffer) {
		wl_surface_attach(state->wl_surface, buffer, 0, 0);
		wl_surface_commit(state->wl_surface);
	}
}

static void
zwlr_layer_surface_v1_closed(void *data,
		struct zwlr_layer_surface_v1 *zwlr_layer_surface_v1)
{
	(void)data;
	zwlr_layer_surface_v1_destroy(zwlr_layer_surface_v1);
	exit(EXIT_SUCCESS);
}

static const struct zwlr_layer_surface_v1_listener zwlr_layer_surface_v1_listener = {
	.configure = zwlr_layer_surface_v1_configure,
	.closed = zwlr_layer_surface_v1_closed,
};


static void
registry_global(void *data, struct wl_registry *wl_registry,
		uint32_t name, const char *interface, uint32_t version)
{
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

static void
registry_global_remove(void *data, struct wl_registry *wl_registry,
		uint32_t name)
{
	(void)data;
	(void)wl_registry;
	(void)name;
}

static const struct wl_registry_listener wl_registry_listener = {
	.global = registry_global,
	.global_remove = registry_global_remove,
};

void
wayland_init(struct state *state)
{
	state->wl_display = wl_display_connect(NULL);

	if (!state->wl_display) {
		fprintf(stderr, "Failed to connect to display.\n");
		exit(EXIT_FAILURE);
	}
	
	state->wl_registry = wl_display_get_registry(state->wl_display);
	wl_registry_add_listener(state->wl_registry, &wl_registry_listener, state);
	wl_display_roundtrip(state->wl_display);

	state->wl_surface = wl_compositor_create_surface(state->wl_compositor);
	if (state->wp_fractional_scale_manager_v1) {
		state->wp_fractional_scale_v1 = wp_fractional_scale_manager_v1_get_fractional_scale(
			state->wp_fractional_scale_manager_v1, state->wl_surface);
		wp_fractional_scale_v1_add_listener(
			state->wp_fractional_scale_v1, &fractional_scale_listener, state);
	}
	if (state->wp_viewporter) {
		state->wp_viewport = wp_viewporter_get_viewport(
			state->wp_viewporter, state->wl_surface);
	}

	state->zwlr_layer_surface_v1 = zwlr_layer_shell_v1_get_layer_surface(
		state->zwlr_layer_shell_v1,
		state->wl_surface,
		state->wl_output,
		ZWLR_LAYER_SHELL_V1_LAYER_TOP,
		"figbar"
	);
	zwlr_layer_surface_v1_set_anchor(state->zwlr_layer_surface_v1,
		ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT | ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT | state->anchor
	);
	zwlr_layer_surface_v1_set_size(state->zwlr_layer_surface_v1, state->width, state->height);
	zwlr_layer_surface_v1_set_exclusive_zone(state->zwlr_layer_surface_v1, state->height);
	zwlr_layer_surface_v1_add_listener(state->zwlr_layer_surface_v1, &zwlr_layer_surface_v1_listener, state);

	wl_surface_commit(state->wl_surface);
	wl_display_roundtrip(state->wl_display);
}

struct wl_buffer *
create_buffer(struct state *state)
{
	int buf_width = (int)(state->width * state->scale + 0.5);
	int buf_height = (int)(state->height * state->scale + 0.5);
	if (buf_width <= 0 || buf_height <= 0) {
		return NULL;
	}

	int stride = buf_width * 4;
	int size = stride * buf_height;

	int fd = allocate_shm_file(size);
	if (fd == -1) {
		return NULL;
	}

	void *data = mmap(NULL, size,
			PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if (data == MAP_FAILED) {
		close(fd);
		return NULL;
	}

	struct wl_shm_pool *pool = wl_shm_create_pool(state->wl_shm, fd, size);
	struct wl_buffer *buffer = wl_shm_pool_create_buffer(pool, 0,
			buf_width, buf_height, stride, WL_SHM_FORMAT_ARGB8888);
	wl_shm_pool_destroy(pool);
	close(fd);

	render(data, state);

	munmap(data, size);
	wl_buffer_add_listener(buffer, &wl_buffer_listener, NULL);
	return buffer;
}
