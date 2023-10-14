const std = @import("std");
const StreamSource = std.io.StreamSource;
const zimg = @import("../lib/zig-image.zig");
const RGBA64 = zimg.color.RGBA64;
const Format = zimg.PixelFormat;
const ImageError = zimg.ImageError;
const Image = zimg.ImageCT(Format.rgba64);

fn readTestImage(relative_path: []const u8) !Image {
    var file = try std.fs.cwd().openFile(relative_path, .{});
    defer file.close();

    const buffer: []const u8 = try file.reader().readAllAlloc(std.testing.allocator, 1024);
    defer std.testing.allocator.free(buffer);

    var stream = StreamSource{ .const_buffer = std.io.fixedBufferStream(buffer) };
    return Image.init(std.testing.allocator, &stream);
}

fn expectRGBA64(image: Image, x: u32, y: u32, expected: RGBA64) !void {
    const actual = image.pixels[x + y * image.width];
    std.testing.expect(actual.eql(expected)) catch |err| {
        std.debug.print("At pixel ({},{}):\n", .{ x, y });
        std.debug.print("\tactual:   {any}\n", .{actual});
        std.debug.print("\texpected: {any}\n", .{expected});
        return err;
    };
}

fn testReadImage1x1Success(relative_path: []const u8) !void {
    var image = try readTestImage(relative_path);
    defer image.deinit();

    try std.testing.expect(image.width == 1);
    try std.testing.expect(image.height == 1);

    try expectRGBA64(image, 0, 0, .{ .r = 0x44, .g = 0xAA, .b = 0x44, .a = 0xFF });
}

fn testReadImage8x4Success(relative_path: []const u8) !void {
    var image = try readTestImage(relative_path);
    defer image.deinit();

    try std.testing.expect(image.width == 8);
    try std.testing.expect(image.height == 4);

    const C0 = .{ .r = 0xAC, .g = 0x32, .b = 0x32, .a = 0xFF };
    const C1 = .{ .r = 0x63, .g = 0x9B, .b = 0xFF, .a = 0xFF };
    const C2 = .{ .r = 0x6A, .g = 0xBE, .b = 0x30, .a = 0xFF };
    const C3 = .{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0x00 };
    const C4 = .{ .r = 0xDF, .g = 0x71, .b = 0x26, .a = 0xFF };

    try expectRGBA64(image, 0, 0, C0);
    try expectRGBA64(image, 7, 0, C1);
    try expectRGBA64(image, 2, 1, C4);
    try expectRGBA64(image, 4, 1, C2);
    try expectRGBA64(image, 3, 2, C3);
    try expectRGBA64(image, 5, 2, C1);
    try expectRGBA64(image, 0, 3, C4);
    try expectRGBA64(image, 7, 3, C3);
}

fn testReadImageFailure(relative_path: []const u8, expected_error: ImageError) !void {
    var image = readTestImage(relative_path);
    try std.testing.expectError(expected_error, image);
}

test "reading simple PNG image" {
    //try testReadImage1x1Success("images/test-1x1.png");
}

test "reading 8x4 PNG image" {
    //try testReadImage8x4Success("images/test-8x4.png");
}

test "reading simple BMP image" {
    //try testReadImage1x1Success("images/test-1x1.bmp");
}

test "reading 8x4 BMP image" {
    //try testReadImage8x4Success("images/test-8x4.bmp");
}

test "reading unsupported image format" {
    try testReadImageFailure("images/test-1x1.ico", ImageError.FormatNotSupported);
}

test "reading unknown image format" {
    try testReadImageFailure("images/test-1x1.jpg", ImageError.FormatUnkown);
}
