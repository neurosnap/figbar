const std = @import("std");
const State = @import("state.zig");
const wayland_init = @import("wayland.zig").wayland_init;
const create_buffer = @import("wayland.zig").create_buffer;

pub fn main(init: std.process.Init) !void {
    const args = init.minimal.args;
    var iter = args.iterate();
    var state: State = .init();
    try state.parse_args(&iter);
    defer state.deinit();
    try wayland_init(&state);
    const display = state.wl_display.?;

    const wayland_fd = display.getFd();
    const stdin_fd = std.posix.STDIN_FILENO;

    var line_buf: [4096]u8 = undefined;
    var line_len: usize = 0;

    var pfd = [_]std.posix.pollfd{
        .{ .fd = wayland_fd, .events = std.posix.POLL.IN, .revents = 0 },
        .{ .fd = stdin_fd, .events = std.posix.POLL.IN, .revents = 0 },
    };

    while (true) {
        // Prepare to read from Wayland display
        while (!display.prepareRead()) {
            _ = display.dispatchPending();
        }
        _ = display.flush();

        const poll_res = std.c.poll(@ptrCast(&pfd), 2, -1);
        if (poll_res < 0) {
            display.cancelRead();
            break;
        }

        // Handle Wayland socket
        if (pfd[0].revents & (std.posix.POLL.IN | std.posix.POLL.ERR | std.posix.POLL.HUP) != 0) {
            _ = display.readEvents();
            _ = display.dispatchPending();
        } else {
            display.cancelRead();
        }

        // Handle Stdin
        if (pfd[1].revents & std.posix.POLL.IN != 0) {
            const n = std.c.read(stdin_fd, line_buf[line_len..].ptr, line_buf.len - line_len);
            if (n <= 0) {
                // EOF or error on stdin
                pfd[1].fd = -1; // stop polling stdin, but keep running Wayland event loop
            } else {
                line_len += @intCast(n);
                while (std.mem.indexOfScalar(u8, line_buf[0..line_len], '\n')) |nl_idx| {
                    const line = line_buf[0..nl_idx];
                    try state.parse_line(line);

                    if (state.wp_viewport) |vp| {
                        vp.setDestination(@intCast(state.width), @intCast(state.height));
                    }

                    if (state.width > 0) {
                        const buffer = create_buffer(&state) catch null;
                        if (state.wl_surface) |surf| {
                            if (buffer) |buf| {
                                surf.attach(buf, 0, 0);
                                surf.damageBuffer(0, 0, std.math.maxInt(i32), std.math.maxInt(i32));
                            }
                            surf.commit();
                        }
                    }

                    const remaining = line_len - (nl_idx + 1);
                    std.mem.copyForwards(u8, line_buf[0..remaining], line_buf[nl_idx + 1 .. line_len]);
                    line_len = remaining;
                }
            }
        } else if (pfd[1].revents & (std.posix.POLL.ERR | std.posix.POLL.HUP) != 0) {
            pfd[1].fd = -1;
        }
    }
}
