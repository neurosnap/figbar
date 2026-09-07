const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const wayland_protocols_path = b.run(&.{
        "pkg-config", "--variable=pkgdatadir", "wayland-protocols",
    });
    const trimmed_protocols_path = std.mem.trim(u8, wayland_protocols_path, " \r\n");

    const proto_files = [_]struct {
        xml: []const u8,
        header: []const u8,
        code: []const u8,
    }{
        .{
            .xml = b.pathJoin(&.{ trimmed_protocols_path, "stable/xdg-shell/xdg-shell.xml" }),
            .header = "src/xdg-shell-client-protocol.h",
            .code = "src/xdg-shell-protocol.c",
        },
        .{
            .xml = "protocols/wlr-layer-shell-unstable-v1.xml",
            .header = "src/wlr-layer-shell-unstable-v1-client-protocol.h",
            .code = "src/wlr-layer-shell-unstable-v1-protocol.c",
        },
        .{
            .xml = b.pathJoin(&.{ trimmed_protocols_path, "staging/fractional-scale/fractional-scale-v1.xml" }),
            .header = "src/fractional-scale-v1-client-protocol.h",
            .code = "src/fractional-scale-v1-protocol.c",
        },
        .{
            .xml = b.pathJoin(&.{ trimmed_protocols_path, "stable/viewporter/viewporter.xml" }),
            .header = "src/viewporter-client-protocol.h",
            .code = "src/viewporter-protocol.c",
        },
    };

    const scan_step = b.step("scan-protocols", "Generate Wayland protocol C/H files");

    for (proto_files) |p| {
        const header_cmd = b.addSystemCommand(&.{
            "wayland-scanner", "client-header", p.xml, p.header,
        });
        const code_cmd = b.addSystemCommand(&.{
            "wayland-scanner", "private-code", p.xml, p.code,
        });
        scan_step.dependOn(&header_cmd.step);
        scan_step.dependOn(&code_cmd.step);
    }

    const wayland_dep = b.dependency("wayland", .{});
    const Scanner = @import("wayland").Scanner;
    _ = wayland_dep;
    const scanner = Scanner.create(b, .{});

    scanner.addSystemProtocol("stable/xdg-shell/xdg-shell.xml");
    scanner.addSystemProtocol("staging/fractional-scale/fractional-scale-v1.xml");
    scanner.addSystemProtocol("stable/viewporter/viewporter.xml");
    scanner.addCustomProtocol(b.path("protocols/wlr-layer-shell-unstable-v1.xml"));

    scanner.generate("wl_compositor", 4);
    scanner.generate("wl_shm", 1);
    scanner.generate("wl_output", 4);
    scanner.generate("zwlr_layer_shell_v1", 4);
    scanner.generate("wp_fractional_scale_manager_v1", 1);
    scanner.generate("wp_viewporter", 1);
    scanner.generate("xdg_wm_base", 2);

    const wayland_mod = b.createModule(.{
        .root_source_file = scanner.result,
        .target = target,
        .optimize = optimize,
    });

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    mod.addImport("wayland", wayland_mod);


    mod.addIncludePath(b.path("src"));

    // Link system libraries via pkg-config
    mod.linkSystemLibrary("wayland-client", .{});
    mod.linkSystemLibrary("cairo", .{});
    mod.linkSystemLibrary("pangocairo", .{});
    mod.linkSystemLibrary("rt", .{});

    // Pull in generated protocol C files + existing C modules
    mod.addCSourceFiles(.{
        .files = &.{
            "src/xdg-shell-protocol.c",
            "src/wlr-layer-shell-unstable-v1-protocol.c",
            "src/fractional-scale-v1-protocol.c",
            "src/viewporter-protocol.c",
            "src/shm.c",
            "src/wayland.c",
            "src/state.c",
        },
        .flags = &.{
            "-Wall",
            "-Wextra",
            "-Wno-unused-parameter",
            "-std=c99",
        },
    });

    const exe = b.addExecutable(.{
        .name = "figbar",
        .root_module = mod,
    });

    exe.step.dependOn(scan_step);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
