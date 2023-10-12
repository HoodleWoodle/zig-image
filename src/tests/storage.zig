const std = @import("std");
const color = @import("../lib/color.zig");
const storage = @import("../lib/storage.zig");
const StorageFormat = storage.Format;
const PixelStorage = storage.Storage;
const PixelStorageRT = storage.StorageRT;

// TODO: TEST: storage
test "example:" {
    const PixelStorageRGB555 = PixelStorage(StorageFormat.rgb555);
    const PixelStorageBGRA32 = PixelStorage(StorageFormat.bgra32);
    const PixelStorageIndexed4 = PixelStorage(StorageFormat.indexed4);
    const PixelStorageGrayscale1 = PixelStorage(StorageFormat.grayscale1);
    const PixelStorageRGBA32F = PixelStorage(StorageFormat.rgba32f);
    const PixelStorageIndexed1 = PixelStorage(StorageFormat.indexed1);

    std.debug.print("----------------------------------\n", .{});
    {
        const s = try PixelStorageRGB555.init(4, std.testing.allocator);
        defer s.deinit(std.testing.allocator);
        s.data[0] = color.RGB555.init(1, 2, 4);
        s.data[1] = color.RGB555.init(8, 16, 3);
        s.data[2] = color.RGB555.init(31, 12, 14);
        s.data[3] = color.RGB555.init(13, 28, 22);

        tmpPrintBytes(s);
        tmpPrintPixels(s);

        std.debug.print("vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\n", .{});
        const s2 = try PixelStorageBGRA32.from(StorageFormat.rgb555, s, std.testing.allocator);
        defer s2.deinit(std.testing.allocator);
        tmpPrintPixels(s2);

        std.debug.print("vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\n", .{});
        const s3 = try PixelStorageIndexed4.from(StorageFormat.bgra32, s2, std.testing.allocator);
        defer s3.deinit(std.testing.allocator);
        tmpPrintPixels(s3);

        std.debug.print("vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\n", .{});
        const s4 = try PixelStorageGrayscale1.fromLossy(StorageFormat.indexed4, s3, std.testing.allocator);
        defer s4.deinit(std.testing.allocator);
        tmpPrintPixels(s4);
    }
    std.debug.print("----------------------------------\n", .{});
    {
        const s = try PixelStorageGrayscale1.init(16, std.testing.allocator);
        defer s.deinit(std.testing.allocator);
        var i: u32 = 0;
        while (i < 16) : (i += 1) {
            s.data[i] = color.Grayscale1.init(if (i % 2 == 0) 1 else 0);
        }

        tmpPrintBytes(s);
        tmpPrintPixels(s);

        std.debug.print("vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\n", .{});
        const s2 = try PixelStorageRGBA32F.from(StorageFormat.grayscale1, s, std.testing.allocator);
        defer s2.deinit(std.testing.allocator);
        tmpPrintPixels(s2);

        std.debug.print("vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\n", .{});
        const s3 = try PixelStorageIndexed1.from(StorageFormat.rgba32f, s2, std.testing.allocator);
        defer s3.deinit(std.testing.allocator);
        tmpPrintPixels(s3);
    }
}

pub fn tmpPrintBytes(s: anytype) void {
    for (s.bytes()) |b| {
        std.debug.print("{b:0>8} - 0x{x:0>2}\n", .{ b, b });
    }
}

pub fn tmpPrintPixels(s: anytype) void {
    var i: u32 = 0;
    while (i < s.len()) : (i += 1) {
        std.debug.print("{any}\n", .{s.at(i)});
    }
}

// TODO: TEST: storageRT
test "exampleRT:" {
    std.debug.print("\n\n\n\n\n\n\n\n\n\n\n\n\n\n", .{});
    {
        var s = try PixelStorageRT.init(StorageFormat.rgb555, 4, std.testing.allocator);
        defer s.deinit(std.testing.allocator);
        try s.rgb555.set(0, color.RGB555.init(1, 2, 4));
        try s.rgb555.set(1, color.RGB555.init(8, 16, 3));
        try s.rgb555.set(2, color.RGB555.init(31, 12, 14));
        try s.rgb555.set(3, color.RGB555.init(13, 28, 22));

        tmpPrintBytes(s);
        tmpPrintPixelsRT(s);

        std.debug.print("vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\n", .{});
        const s2 = try PixelStorageRT.from(StorageFormat.bgra32, s, std.testing.allocator);
        defer s2.deinit(std.testing.allocator);
        tmpPrintPixelsRT(s2);

        std.debug.print("vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\n", .{});
        const s3 = try PixelStorageRT.from(StorageFormat.indexed4, s2, std.testing.allocator);
        defer s3.deinit(std.testing.allocator);
        tmpPrintPixelsRT(s3);

        std.debug.print("vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\n", .{});
        const s4 = try PixelStorageRT.from(StorageFormat.grayscale1, s3, std.testing.allocator);
        defer s4.deinit(std.testing.allocator);
        tmpPrintPixelsRT(s4);
    }
    std.debug.print("----------------------------------\n", .{});
    {
        var s = try PixelStorageRT.init(StorageFormat.grayscale1, 16, std.testing.allocator);
        defer s.deinit(std.testing.allocator);
        var i: u32 = 0;
        while (i < 16) : (i += 1) {
            try s.grayscale1.set(i, color.Grayscale1.init(if (i % 2 == 0) 1 else 0));
        }

        tmpPrintBytes(s);
        tmpPrintPixelsRT(s);

        std.debug.print("vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\n", .{});
        const s2 = try PixelStorageRT.from(StorageFormat.rgba32f, s, std.testing.allocator);
        defer s2.deinit(std.testing.allocator);
        tmpPrintPixelsRT(s2);

        std.debug.print("vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv\n", .{});
        const s3 = try PixelStorageRT.from(StorageFormat.indexed1, s2, std.testing.allocator);
        defer s3.deinit(std.testing.allocator);
        tmpPrintPixelsRT(s3);
    }
}

pub fn tmpPrintPixelsRT(s: PixelStorageRT) void {
    var i: u32 = 0;
    while (i < s.len()) : (i += 1) {
        switch (s) {
            .rgba64f => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .rgba32f => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .rgba64 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .rgba32 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .bgra32 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .argb32 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .abgr32 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .rgb48 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .rgb24 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .bgr24 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .argb4444 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .argb1555 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .rgb565 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .rgb555 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .a2r10g10b10 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .a2b10g10r10 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .grayscale1 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .grayscale2 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .grayscale4 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .grayscale8 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .grayscale16 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .indexed1 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .indexed4 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
            .indexed8 => |data| std.debug.print("{any}\n", .{data.at(i) catch unreachable}),
        }
    }
}
