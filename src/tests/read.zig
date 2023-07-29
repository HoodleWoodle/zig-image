const std = @import("std");
const Image = @import("../lib/image.zig");
const StreamSource = std.io.StreamSource;

fn readTestImage(relative_path: []const u8) !Image {
    var file = try std.fs.cwd().openFile(relative_path, .{});
    defer file.close();

    const buffer: []const u8 = try file.reader().readAllAlloc(std.testing.allocator, 1024);
    defer std.testing.allocator.destroy(buffer.ptr);

    var stream = StreamSource{ .const_buffer = std.io.fixedBufferStream(buffer) };
    return Image.init(std.testing.allocator, &stream);
}

fn testReadImage1x1Success(relative_path: []const u8) !void {
    var image = try readTestImage(relative_path);
    defer image.deinit();

    try std.testing.expect(image.width == 1);
    try std.testing.expect(image.height == 1);
    try std.testing.expect(image.pixels[0].r == 0x44);
    try std.testing.expect(image.pixels[0].g == 0xAA);
    try std.testing.expect(image.pixels[0].b == 0x44);
    try std.testing.expect(image.pixels[0].a == 0xFF);
}

fn testReadImageFailure(relative_path: []const u8, expected_error: Image.Error) !void {
    var image = readTestImage(relative_path);
    try std.testing.expectError(expected_error, image);
}

test "reading simple PNG image" {
    try testReadImage1x1Success("images/test-1x1.png");
}

test "reading simple BMP image" {
    try testReadImage1x1Success("images/test-1x1.bmp");
}

test "reading unsupported image format" {
    try testReadImageFailure("images/test-1x1.ico", Image.Error.FormatNotSupported);
}

test "reading unknown image format" {
    try testReadImageFailure("images/test-1x1.jpg", Image.Error.FormatUnkown);
}
