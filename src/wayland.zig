const std = @import("std");
const assert = std.debug.assert;
const wayland = @import("wayland");
const wl = wayland.client.wl;
const zwlr = wayland.client.zwlr;
const zwlr_ls = zwlr.LayerSurfaceV1;
const wp = wayland.client.wp;
const wp_fs = wp.FractionalScaleManagerV1;
const wp_vp = wp.Viewporter;
const State = @import("state.zig");
const render = @import("render.zig");

fn emitClickEvent(state: *State, button: u32) void {
    const px: i32 = @intFromFloat(state.pointer_x);
    if (state.findItemAt(px)) |found| {
        var buf: [512]u8 = undefined;
        const msg = if (found.item.key) |k|
            std.fmt.bufPrint(&buf, "{{\"event\":\"click\",\"key\":\"{s}\",\"index\":{d},\"button\":{d}}}\n", .{
                k, found.index, button,
            }) catch return
        else
            std.fmt.bufPrint(&buf, "{{\"event\":\"click\",\"key\":null,\"index\":{d},\"button\":{d}}}\n", .{
                found.index, button,
            }) catch return;

        _ = std.c.write(std.posix.STDOUT_FILENO, msg.ptr, msg.len);
    }
}

fn pointerListener(pointer: *wl.Pointer, event: wl.Pointer.Event, state: *State) void {
    _ = pointer;
    switch (event) {
        .enter => |ev| {
            state.pointer_inside = true;
            state.pointer_x = ev.surface_x.toDouble();
            state.pointer_y = ev.surface_y.toDouble();
        },
        .leave => {
            state.pointer_inside = false;
        },
        .motion => |ev| {
            state.pointer_x = ev.surface_x.toDouble();
            state.pointer_y = ev.surface_y.toDouble();
        },
        .button => |ev| {
            if (ev.state == .pressed) {
                // ev.button is typically Linux input event code:
                // 0x110 (272) = BTN_LEFT -> button 1
                // 0x111 (273) = BTN_RIGHT -> button 3
                // 0x112 (274) = BTN_MIDDLE -> button 2
                const btn_num: u32 = switch (ev.button) {
                    0x110 => 1, // BTN_LEFT
                    0x111 => 3, // BTN_RIGHT
                    0x112 => 2, // BTN_MIDDLE
                    0x113 => 4, // BTN_SIDE
                    0x114 => 5, // BTN_EXTRA
                    else => ev.button,
                };
                emitClickEvent(state, btn_num);
            }
        },
        else => {},
    }
}

fn seatListener(seat: *wl.Seat, event: wl.Seat.Event, state: *State) void {
    switch (event) {
        .capabilities => |ev| {
            if (ev.capabilities.pointer) {
                if (state.wl_pointer == null) {
                    const pointer = seat.getPointer() catch return;
                    state.wl_pointer = pointer;
                    pointer.setListener(*State, pointerListener, state);
                }
            } else {
                if (state.wl_pointer) |p| {
                    p.release();
                    state.wl_pointer = null;
                }
            }
        },
        .name => {},
    }
}

fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, state: *State) void {
    switch (event) {
        .global => |global| {
            if (std.mem.orderZ(u8, global.interface, wl.Compositor.interface.name) == .eq) {
                state.wl_compositor = registry.bind(global.name, wl.Compositor, 4) catch return;
            } else if (std.mem.orderZ(u8, global.interface, wl.Shm.interface.name) == .eq) {
                state.wl_shm = registry.bind(global.name, wl.Shm, 1) catch return;
            } else if (std.mem.orderZ(u8, global.interface, wl.Output.interface.name) == .eq) {
                state.wl_output = registry.bind(global.name, wl.Output, 4) catch return;
            } else if (std.mem.orderZ(u8, global.interface, wl.Seat.interface.name) == .eq) {
                const seat = registry.bind(global.name, wl.Seat, 5) catch return;
                state.wl_seat = seat;
                seat.setListener(*State, seatListener, state);
            } else if (std.mem.orderZ(u8, global.interface, zwlr.LayerShellV1.interface.name) == .eq) {
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

fn destroySurface(state: *State) void {
    state.configured = false;
    if (state.zwlr_layer_surface_v1) |ls| {
        ls.destroy();
        state.zwlr_layer_surface_v1 = null;
    }
    if (state.wp_viewport) |vp| {
        vp.destroy();
        state.wp_viewport = null;
    }
    if (state.wp_fraction_scale_v1) |fs| {
        fs.destroy();
        state.wp_fraction_scale_v1 = null;
    }
    if (state.wl_surface) |surf| {
        surf.destroy();
        state.wl_surface = null;
    }
}

pub fn createSurface(state: *State) !void {
    destroySurface(state);

    const compositor = state.wl_compositor orelse return error.MissingWaylandCompositor;
    const layer_shell = state.zwlr_layer_shell_v1 orelse return error.MissingLayerShell;

    const surface = try compositor.createSurface();
    state.wl_surface = surface;

    if (state.wp_fractional_scale_manager_v1) |wpfs| {
        const fs = try wpfs.getFractionalScale(surface);
        state.wp_fraction_scale_v1 = fs;
        fs.setListener(*State, fractionalScaleListener, state);
    }

    if (state.wp_viewporter) |vp| {
        state.wp_viewport = try vp.getViewport(surface);
    }

    const ls = try layer_shell.getLayerSurface(
        surface,
        null, // Pass null so compositor assigns to the active output
        .top,
        "figbar",
    );
    state.zwlr_layer_surface_v1 = ls;
    ls.setAnchor(state.anchor);
    ls.setSize(state.width, state.height);
    ls.setExclusiveZone(@intCast(state.height));
    ls.setListener(*State, layerSurfaceListener, state);

    assert(state.wl_display != null);
    assert(state.wl_surface != null);
    assert(state.zwlr_layer_surface_v1 != null);
    if (state.wp_fraction_scale_v1 != null) {
        assert(state.wp_viewport != null);
    }

    surface.commit();
}

fn layerSurfaceListener(
    ls: *zwlr.LayerSurfaceV1,
    event: zwlr.LayerSurfaceV1.Event,
    state: *State,
) void {
    switch (event) {
        .configure => |ev| {
            state.configured = true;
            ls.ackConfigure(ev.serial);
            assert(state.wl_surface != null);
            // ev.width and ev.height are the compositor-assigned dimensions (0 means client decides)
            if (ev.width != 0) state.width = ev.width;
            if (ev.height != 0) state.height = ev.height;

            if (state.wp_viewport) |vp| {
                vp.setDestination(@intCast(state.width), @intCast(state.height));
            }

            const buffer = create_buffer(state) catch null;
            if (state.wl_surface) |surf| {
                if (buffer) |buf| {
                    surf.attach(buf, 0, 0);
                }
                surf.commit();
            }
        },
        .closed => {
            // compositor is removing our surface (e.g. output disabled on laptop lid close)
            destroySurface(state);
        },
    }
}

fn bufferReleaseListener(bf: *wl.Buffer, _: wl.Buffer.Event, _: *State) void {
    bf.destroy();
}

pub fn wayland_init(state: *State) !void {
    const display = try wl.Display.connect(null);
    state.wl_display = display;
    const registry = try display.getRegistry();
    state.wl_registry = registry;
    registry.setListener(*State, registryListener, state);
    _ = display.roundtrip();

    _ = state.wl_compositor orelse return error.MissingWaylandCompositor;
    _ = state.wl_shm orelse return error.MissingWaylandShm;
    _ = state.zwlr_layer_shell_v1 orelse return error.MissingLayerShell;

    try createSurface(state);
    _ = display.roundtrip();
}

pub fn create_buffer(state: *State) !*wl.Buffer {
    const shm = state.wl_shm orelse return error.MissingWaylandShm;
    assert(state.scale > 0.0);
    assert(state.width > 0);
    assert(state.height > 0);
    const buf_width: i32 = @intFromFloat(@as(f64, @floatFromInt(state.width)) * state.scale + 0.5);
    const buf_height: i32 = @intFromFloat(@as(f64, @floatFromInt(state.height)) * state.scale + 0.5);
    if (buf_width <= 0 or buf_height <= 0) return error.InvalidSize;

    const stride: i32 = render.getStride(buf_width);
    const size: usize = @intCast(stride * buf_height);

    const fd = try allocateShmFile(size);
    defer _ = std.c.close(fd); // close after mmap and pool creation

    const data = try std.posix.mmap(
        null,
        size,
        .{ .READ = true, .WRITE = true },
        .{ .TYPE = .SHARED },
        fd,
        0,
    );
    defer std.posix.munmap(data);

    const pool = try shm.createPool(fd, @intCast(size));
    defer pool.destroy();

    const buffer = try pool.createBuffer(0, buf_width, buf_height, stride, .argb8888);

    render.render(data, state);

    buffer.setListener(*State, bufferReleaseListener, state);
    return buffer;
}

pub fn allocateShmFile(size: usize) !std.posix.fd_t {
    const fd = try std.posix.memfd_create("figbar-shm", 0);
    errdefer _ = std.c.close(fd);

    if (std.c.ftruncate(fd, @intCast(size)) != 0) {
        return error.FtruncateFailed;
    }

    return fd;
}
