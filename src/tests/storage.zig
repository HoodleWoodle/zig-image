const std = @import("std");
const color = @import("../lib/color.zig");
const storage = @import("../lib/storage.zig");
const StorageFormat = storage.Format;
const PixelStorage = storage.Storage;

// TODO: TEST: storage
test "example:" {
    std.debug.print("----------------------------------\n", .{});
    {
        const s = try PixelStorage.init(StorageFormat.rgb555, 4, std.testing.allocator);
        defer s.deinit(std.testing.allocator);
        s.rgb555[0] = color.RGB555.init(1, 2, 4);
        s.rgb555[1] = color.RGB555.init(8, 16, 3);
        s.rgb555[2] = color.RGB555.init(31, 12, 14);
        s.rgb555[3] = color.RGB555.init(13, 28, 22);

        tmpPrintBytes(s);
        tmpPrintPixels(s);

        std.debug.print("vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\n", .{});
        const s2 = try PixelStorage.from(StorageFormat.bgra32, s, std.testing.allocator);
        defer s2.deinit(std.testing.allocator);
        tmpPrintPixels(s2);

        std.debug.print("vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\n", .{});
        const s3 = try PixelStorage.from(StorageFormat.indexed4, s2, std.testing.allocator);
        defer s3.deinit(std.testing.allocator);
        tmpPrintPixels(s3);

        std.debug.print("vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\n", .{});
        const s4 = try PixelStorage.from(StorageFormat.grayscale1, s3, std.testing.allocator);
        defer s4.deinit(std.testing.allocator);
        tmpPrintPixels(s4);
    }
    std.debug.print("----------------------------------\n", .{});
    {
        const s = try PixelStorage.init(StorageFormat.grayscale1, 16, std.testing.allocator);
        defer s.deinit(std.testing.allocator);
        var i: u32 = 0;
        while (i < 16) : (i += 1) {
            s.grayscale1[i] = color.Grayscale1.init(if (i % 2 == 0) 1 else 0);
        }

        tmpPrintBytes(s);
        tmpPrintPixels(s);

        std.debug.print("vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\n", .{});
        const s2 = try PixelStorage.from(StorageFormat.rgba32f, s, std.testing.allocator);
        defer s2.deinit(std.testing.allocator);
        tmpPrintPixels(s2);

        std.debug.print("vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\n", .{});
        const s3 = try PixelStorage.from(StorageFormat.indexed1, s2, std.testing.allocator);
        defer s3.deinit(std.testing.allocator);
        tmpPrintPixels(s3);
    }
}

pub fn tmpPrintBytes(s: PixelStorage) void {
    for (s.bytes()) |b| {
        std.debug.print("{b:0>8} - 0x{x:0>2}\n", .{ b, b });
    }
}

pub fn tmpPrintPixels(s: PixelStorage) void {
    var i: u32 = 0;
    while (i < s.len()) : (i += 1) {
        switch (s) {
            .rgba32f => |data| std.debug.print("{any}\n", .{data[i]}),
            .rgba32 => |data| std.debug.print("{any}\n", .{data[i]}),
            .bgra32 => |data| std.debug.print("{any}\n", .{data[i]}),
            .argb32 => |data| std.debug.print("{any}\n", .{data[i]}),
            .abgr32 => |data| std.debug.print("{any}\n", .{data[i]}),
            .rgb24 => |data| std.debug.print("{any}\n", .{data[i]}),
            .bgr24 => |data| std.debug.print("{any}\n", .{data[i]}),
            .argb4444 => |data| std.debug.print("{any}\n", .{data[i]}),
            .argb1555 => |data| std.debug.print("{any}\n", .{data[i]}),
            .rgb565 => |data| std.debug.print("{any}\n", .{data[i]}),
            .rgb555 => |data| std.debug.print("{any}\n", .{data[i]}),
            .a2r10g10b10 => |data| std.debug.print("{any}\n", .{data[i]}),
            .a2b10g10r10 => |data| std.debug.print("{any}\n", .{data[i]}),
            .grayscale1 => |data| std.debug.print("{any}\n", .{data[i]}),
            .grayscale4 => |data| std.debug.print("{any}\n", .{data[i]}),
            .grayscale8 => |data| std.debug.print("{any}\n", .{data[i]}),
            .indexed1 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .indexed4 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .indexed8 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
        }
    }
}
