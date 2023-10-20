const std = @import("std");
const StreamSource = std.io.StreamSource;
const zimg = @import("../lib/zig-image.zig");
const RGBA32 = zimg.color.RGBA32;
const Format = zimg.PixelFormat;
const ImageError = zimg.ImageError;
const Image = zimg.ImageCT(Format.rgba32);
const ImageRT = zimg.Image;

pub const TestImageColorization = enum { Default, Alpha, Mono };

const red: RGBA32 = .{ .r = 0xF7, .g = 0x08, .b = 0x08, .a = 0xFF };
const green: RGBA32 = .{ .r = 0x08, .g = 0xEF, .b = 0x08, .a = 0xFF };
const blue: RGBA32 = .{ .r = 0x08, .g = 0x08, .b = 0xE7, .a = 0xFF };
const gray: RGBA32 = .{ .r = 0x5A, .g = 0x5A, .b = 0x5A, .a = 0xFF };
const black: RGBA32 = .{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xFF };
const white: RGBA32 = .{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };

fn readTestImage(comptime expected_format: Format, relative_path: []const u8) !Image {
    var file = try std.fs.cwd().openFile(relative_path, .{});
    defer file.close();

    const buffer: []const u8 = try file.reader().readAllAlloc(std.testing.allocator, 2048);
    defer std.testing.allocator.free(buffer);

    var stream = StreamSource{ .const_buffer = std.io.fixedBufferStream(buffer) };
    const image_rt = try ImageRT.init(std.testing.allocator, &stream);
    defer image_rt.deinit();

    try std.testing.expect(image_rt.pixels.format() == expected_format);

    return Image{
        .allocator = image_rt.allocator,
        .width = image_rt.width,
        .height = image_rt.height,
        .pixels = try Image.Storage.fromRT(image_rt.pixels, image_rt.allocator),
    };
}

fn expectRGBA32(image: Image, x: u32, y: u32, expected: RGBA32) !void {
    const actual = image.pixels.data[x + y * image.width];
    std.testing.expect(actual.eql(expected)) catch |err| {
        std.debug.print("At pixel ({},{}):\n", .{ x, y });
        std.debug.print("\tactual:   {any}\n", .{actual});
        std.debug.print("\texpected: {any}\n", .{expected});
        return err;
    };
}

pub fn testReadImage1x1Success(comptime expected_format: Format, relative_path: []const u8) !void {
    var image = try readTestImage(expected_format, relative_path);
    defer image.deinit();

    try std.testing.expect(image.width == 1);
    try std.testing.expect(image.height == 1);

    try expectRGBA32(image, 0, 0, red);
}

pub fn testReadImage2x2Success(comptime expected_format: Format, relative_path: []const u8) !void {
    var image = try readTestImage(expected_format, relative_path);
    defer image.deinit();

    try std.testing.expect(image.width == 2);
    try std.testing.expect(image.height == 2);

    try expectRGBA32(image, 0, 0, red);
    try expectRGBA32(image, 1, 0, green);
    try expectRGBA32(image, 0, 1, blue);
    try expectRGBA32(image, 1, 1, white);
}

pub fn testReadImage8x4Success(comptime expected_format: Format, relative_path: []const u8, comptime col: TestImageColorization) !void {
    const colors = switch (col) {
        .Default => .{ red, green, blue, gray, black },
        .Alpha => .{ red, green, blue, gray, .{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0x00 } },
        .Mono => .{ white, white, white, white, black },
    };

    var image = try readTestImage(expected_format, relative_path);
    defer image.deinit();

    try std.testing.expect(image.width == 8);
    try std.testing.expect(image.height == 4);

    try expectRGBA32(image, 0, 0, colors[0]);
    try expectRGBA32(image, 7, 0, colors[2]);
    try expectRGBA32(image, 2, 1, colors[3]);
    try expectRGBA32(image, 4, 1, colors[1]);
    try expectRGBA32(image, 3, 2, colors[4]);
    try expectRGBA32(image, 5, 2, colors[2]);
    try expectRGBA32(image, 0, 3, colors[3]);
    try expectRGBA32(image, 7, 3, colors[4]);
}

pub fn testReadImageFailure(relative_path: []const u8, expected_error: ImageError) !void {
    var image = readTestImage(.grayscale1, relative_path); // expected format is not used
    try std.testing.expectError(expected_error, image);
}

test "reading: unknown format" {
    try testReadImageFailure("images/test.noimg", ImageError.FormatUnkown);
}
