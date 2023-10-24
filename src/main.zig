pub fn main() !void {
    try @import("zimgtview/zimgtview.zig").run();
}

test {
    const std = @import("std");
    std.testing.refAllDeclsRecursive(@This());
    inline for (.{
        @import("tests/color.zig"),
        @import("tests/storage.zig"),
        @import("tests/common.zig"),
        @import("tests/formats/bmp.zig"),
        @import("tests/formats/ico.zig"),
        @import("tests/formats/png.zig"),
    }) |source_file| std.testing.refAllDeclsRecursive(source_file);
}
