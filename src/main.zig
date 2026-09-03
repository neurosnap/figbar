const std = @import("std");

const c = @cImport({
    @cDefine("_FORTIFY_SOURCE", "0");
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
    @cInclude("string.h");
    @cInclude("state.h");
    @cInclude("wayland.h");
    @cInclude("viewporter-client-protocol.h");
});

pub fn main(init: std.process.Init) !void {
    const argv = init.minimal.args.vector;
    const argc: c_int = @intCast(argv.len);

    const state = c.state_init(argc, @ptrCast(@constCast(argv.ptr)));
    if (state == null) {
        return error.StateInitFailed;
    }

    var input: [c.BUFSIZ]u8 = undefined;

    while (true) {
        if (c.fgets(&input, c.BUFSIZ, c.stdin)) |_| {
            c.parse_input(state, &input);
            if (state.*.wp_viewport) |vp| {
                c.wp_viewport_set_destination(vp, state.*.width, state.*.height);
            }
            const buffer = c.create_buffer(state);
            if (buffer) |buf| {
                c.wl_surface_attach(state.*.wl_surface, buf, 0, 0);
                c.wl_surface_damage_buffer(state.*.wl_surface, 0, 0, std.math.maxInt(i32), std.math.maxInt(i32));
                c.wl_surface_commit(state.*.wl_surface);
            }
        }

        if (c.wl_display_dispatch(state.*.wl_display) == -1) {
            break;
        }
    }
}
