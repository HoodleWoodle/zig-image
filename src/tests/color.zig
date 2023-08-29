const std = @import("std");
const color = @import("../lib/color.zig");

// TODO: TEST: color
test "example:" {
    std.debug.print("\n-\n", .{});
    {
        const v0 = color.RGB24.init(2, 3, 4);
        const v1 = color.RGBA32F.from(color.RGB24, v0);
        const v2 = color.Grayscale4.from(color.RGBA32F, v1);
        std.debug.print("{any}\n", .{v0});
        std.debug.print("-> {any}\n", .{v1});
        std.debug.print("-> {any}\n", .{v2});
    }
    std.debug.print("----------------------------------\n", .{});
    {
        const v0 = color.RGBA32.init(255, 128, 0, 0xB0);
        const v1 = color.RGBA32F.from(color.RGBA32, v0);
        const v2 = color.A2R10G10B10.from(color.RGBA32F, v1);
        std.debug.print("{any}\n", .{v0});
        std.debug.print("-> {any}\n", .{v1});
        std.debug.print("-> {any}\n", .{v2});
    }
}
