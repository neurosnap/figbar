#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#include "state.h"
#include "wayland.h"
#include "viewporter-client-protocol.h"

int
main(int argc, char *argv[])
{
	struct state *state = state_init(argc, argv);
	char input[BUFSIZ];
	do { 
		if (fgets(input, BUFSIZ, stdin)) {
			parse_input(state, input);
			if (state->wp_viewport) {
				wp_viewport_set_destination(state->wp_viewport, state->width, state->height);
			}
			struct wl_buffer *buffer = create_buffer(state);
			if (buffer) {
				wl_surface_attach(state->wl_surface, buffer, 0, 0);
				wl_surface_damage_buffer(state->wl_surface, 0, 0, INT32_MAX, INT32_MAX);
				wl_surface_commit(state->wl_surface);
			}
		}
	} while (wl_display_dispatch(state->wl_display) != -1);
	return 0;
}
