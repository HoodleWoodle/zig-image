const std = @import("std");
const StreamSource = std.io.StreamSource;
const zimg = @import("../lib/zig-image.zig");
const RGBA32 = zimg.color.RGBA32;
const PixelFormat = zimg.PixelFormat;
const ImageError = zimg.ImageError;
const ImageFormat = zimg.ImageFormat;
const ImageCT = zimg.ImageCT(.rgba32);
const ImageRT = zimg.Image;

pub const TestImageColorization = enum { Default, Alpha, Mono };

const RED: RGBA32 = .{ .r = 0xF7, .g = 0x08, .b = 0x08, .a = 0xFF };
const GREEN: RGBA32 = .{ .r = 0x08, .g = 0xEF, .b = 0x08, .a = 0xFF };
const BLUE: RGBA32 = .{ .r = 0x08, .g = 0x08, .b = 0xE7, .a = 0xFF };
const GRAY: RGBA32 = .{ .r = 0x5A, .g = 0x5A, .b = 0x5A, .a = 0xFF };
const BLACK: RGBA32 = .{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xFF };
const WHITE: RGBA32 = .{ .r = 0xFF, .g = 0xFF, .b = 0xFF, .a = 0xFF };

const BUFFER_SIZE = 4096;

fn readBufferFromFile(relative_path: []const u8) ![]const u8 {
    var file = try std.fs.cwd().openFile(relative_path, .{});
    defer file.close();

    return try file.reader().readAllAlloc(std.testing.allocator, BUFFER_SIZE);
}

fn readTestImageFromBuffer(comptime Image: type, expected_format: ?PixelFormat, buffer: []const u8) !Image {
    var stream = StreamSource{ .const_buffer = std.io.fixedBufferStream(buffer) };
    const image_rt = try ImageRT.initRead(std.testing.allocator, &stream);

    if (expected_format) |expected| {
        try std.testing.expect(image_rt.storage.format() == expected);
    }

    if (Image == ImageCT) {
        defer image_rt.deinit();
        return ImageCT{
            .allocator = image_rt.allocator,
            .width = image_rt.width,
            .height = image_rt.height,
            .storage = try ImageCT.Storage.initFromRT(image_rt.storage, image_rt.allocator),
        };
    } else {
        return image_rt;
    }
}

fn readTestImage(comptime Image: type, expected_format: ?PixelFormat, relative_path: []const u8) !Image {
    const buffer = try readBufferFromFile(relative_path);
    defer std.testing.allocator.free(buffer);

    return readTestImageFromBuffer(Image, expected_format, buffer);
}

fn expectRGBA32(image: ImageCT, x: u32, y: u32, expected: RGBA32) !void {
    const actual = image.storage.data[x + y * image.width];
    std.testing.expect(actual.eql(expected)) catch |err| {
        std.debug.print("At pixel ({},{}):\n", .{ x, y });
        std.debug.print("\tactual:   {any}\n", .{actual});
        std.debug.print("\texpected: {any}\n", .{expected});
        return err;
    };
}

const WriteImageResult = struct {
    buffer: []const u8,
    format: PixelFormat,
};

fn writeImageToBuffer(format: ImageFormat, relative_path: []const u8) !WriteImageResult {
    const image = try readTestImage(ImageRT, null, relative_path);
    defer image.deinit();

    var buffer = try std.testing.allocator.alloc(u8, BUFFER_SIZE);
    var stream = std.io.fixedBufferStream(buffer);
    try image.write(format, stream.writer());

    return .{ .buffer = buffer, .format = image.storage.format() };
}

fn testReadImage1x1SuccessFromBuffer(expected_format: PixelFormat, buffer: []const u8) !void {
    var image = try readTestImageFromBuffer(ImageCT, expected_format, buffer);
    defer image.deinit();

    try std.testing.expect(image.width == 1);
    try std.testing.expect(image.height == 1);

    try expectRGBA32(image, 0, 0, RED);
}

fn testReadImage2x2SuccessFromBuffer(expected_format: PixelFormat, buffer: []const u8) !void {
    var image = try readTestImageFromBuffer(ImageCT, expected_format, buffer);
    defer image.deinit();

    try std.testing.expect(image.width == 2);
    try std.testing.expect(image.height == 2);

    try expectRGBA32(image, 0, 0, RED);
    try expectRGBA32(image, 1, 0, GREEN);
    try expectRGBA32(image, 0, 1, BLUE);
    try expectRGBA32(image, 1, 1, WHITE);
}

fn testReadImage8x4SuccessFromBuffer(expected_format: PixelFormat, buffer: []const u8, comptime col: TestImageColorization) !void {
    const colors = switch (col) {
        .Default => .{ RED, GREEN, BLUE, GRAY, BLACK },
        .Alpha => .{ RED, GREEN, BLUE, GRAY, .{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0x00 } },
        .Mono => .{ WHITE, WHITE, WHITE, WHITE, BLACK },
    };

    var image = try readTestImageFromBuffer(ImageCT, expected_format, buffer);
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

pub fn testReadImage1x1Success(comptime expected_format: PixelFormat, relative_path: []const u8) !void {
    const buffer = try readBufferFromFile(relative_path);
    defer std.testing.allocator.free(buffer);

    try testReadImage1x1SuccessFromBuffer(expected_format, buffer);
}

pub fn testReadImage2x2Success(comptime expected_format: PixelFormat, relative_path: []const u8) !void {
    const buffer = try readBufferFromFile(relative_path);
    defer std.testing.allocator.free(buffer);

    try testReadImage2x2SuccessFromBuffer(expected_format, buffer);
}

pub fn testReadImage8x4Success(comptime expected_format: PixelFormat, relative_path: []const u8, comptime col: TestImageColorization) !void {
    const buffer = try readBufferFromFile(relative_path);
    defer std.testing.allocator.free(buffer);

    try testReadImage8x4SuccessFromBuffer(expected_format, buffer, col);
}

pub fn testReadImageFailure(relative_path: []const u8, expected_error: ImageError) !void {
    var image = readTestImage(ImageCT, null, relative_path);
    try std.testing.expectError(expected_error, image);
}

pub fn testWriteImage1x1Success(format: ImageFormat, relative_path: []const u8) !void {
    const rst = try writeImageToBuffer(format, relative_path);
    defer std.testing.allocator.free(rst.buffer);

    try testReadImage1x1SuccessFromBuffer(rst.format, rst.buffer);
}

pub fn testWriteImage2x2Success(format: ImageFormat, relative_path: []const u8) !void {
    const rst = try writeImageToBuffer(format, relative_path);
    defer std.testing.allocator.free(rst.buffer);

    try testReadImage2x2SuccessFromBuffer(rst.format, rst.buffer);
}

pub fn testWriteImage8x4Success(format: ImageFormat, relative_path: []const u8, comptime col: TestImageColorization) !void {
    const rst = try writeImageToBuffer(format, relative_path);
    defer std.testing.allocator.free(rst.buffer);

    try testReadImage8x4SuccessFromBuffer(rst.format, rst.buffer, col);
}

test "reading: unknown format" {
    try testReadImageFailure("images/test.noimg", ImageError.FormatUnkown);
}
