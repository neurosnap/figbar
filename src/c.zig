pub const c = @cImport({
    @cDefine("_FORTIFY_SOURCE", "0");
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
    @cInclude("string.h");
    @cInclude("unistd.h");
    @cInclude("sys/mman.h");
    @cInclude("wayland-client.h");
    @cInclude("wlr-layer-shell-unstable-v1-client-protocol.h");
    @cInclude("fractional-scale-v1-client-protocol.h");
    @cInclude("viewporter-client-protocol.h");
});
