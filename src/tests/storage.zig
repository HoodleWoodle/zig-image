const std = @import("std");
const color = @import("../lib/color.zig");
const storage = @import("../lib/storage.zig");
const StorageFormat = storage.Format;
const PixelStorage = storage.Storage;

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
