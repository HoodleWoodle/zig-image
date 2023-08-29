pub const Image = @import("lib/image.zig");

test {
    const std = @import("std");
    std.testing.refAllDeclsRecursive(@This());
    inline for (.{
        @import("tests/read.zig"),
        @import("tests/color.zig"),
        @import("tests/storage.zig"),
    }) |source_file| std.testing.refAllDeclsRecursive(source_file);
}
