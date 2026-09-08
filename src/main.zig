const std = @import("std");
const State = @import("state.zig");
const wayland_init = @import("wayland.zig").wayland_init;
const create_buffer = @import("wayland.zig").create_buffer;

pub fn main(init: std.process.Init) !void {
    const args = init.minimal.args;
    var iter = args.iterate();
    var state: State = .init();
    try state.parse_args(&iter);
    try wayland_init(&state);
    const display = state.wl_display.?;

    var stdin_buffer: [4096]u8 = undefined;
    var stdin_file_reader: std.Io.File.Reader = .init(
        .stdin(),
        init.io,
        &stdin_buffer,
    );
    const stdin = &stdin_file_reader.interface;

    while (true) {
        if (try stdin.takeDelimiter('\n')) |line| {
            try state.parse_line(line);

            if (state.wp_viewport) |vp| {
                vp.setDestination(@intCast(state.width), @intCast(state.height));
            }

            const buffer = create_buffer(&state) catch null;
            if (state.wl_surface) |surf| {
                if (buffer) |buf| {
                    surf.attach(buf, 0, 0);
                    surf.damageBuffer(0, 0, std.math.maxInt(i32), std.math.maxInt(i32));
                }
                surf.commit();
            }
        } else {
            break; // EOF
        }

        if (display.dispatch() != .SUCCESS) break;
    }
}
