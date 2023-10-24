const std = @import("std");
const StreamSource = std.io.StreamSource;
const zimg = @import("../lib/zig-image.zig");
const RGB24 = zimg.color.RGB24;
const Image = zimg.ImageCT(.rgb24);
const ansi = @import("ansi.zig");
const select = @import("selection.zig");

fn show_at(writer: anytype, image: Image, x_off: u32, y_off: u32, comptime select_fn: select.Function) !void {
    var y: u32 = 0;
    while (y < image.height) : (y += 1) {
        try ansi.setCursor(writer, x_off, y_off + y);

        var x: u32 = 0;
        while (x < image.width) : (x += 1) {
            const color = try image.pixels.at(y * image.width + x);
            const selection = select_fn(color);

            try ansi.setForegroundColor(writer, selection.foreground);
            try writer.writeAll(selection.char);
        }

        try writer.print("\n", .{});
    }
}

fn show(image: Image, align_horizontally: bool) !void {
    const writer = std.io.getStdOut().writer();

    try ansi.clearScreen(writer);
    const BLACK = RGB24.init(0, 0, 0);
    try ansi.setBackgroundColor(writer, BLACK);

    const X_GAP = 5;
    const Y_GAP = 2;

    const x_grid_increase_primary: u32 = if (align_horizontally) 1 else 0;
    const y_grid_increase_primary: u32 = if (align_horizontally) 0 else 1;
    const x_grid_reset: u32 = if (align_horizontally) 0 else 1;
    const y_grid_reset: u32 = if (align_horizontally) 1 else 0;

    var x_grid: u32 = 0;
    var y_grid: u32 = 0;
    try show_at(writer, image, x_grid * (image.width + X_GAP), y_grid * (image.height + Y_GAP), select.byRGB);
    x_grid += x_grid_increase_primary;
    y_grid += y_grid_increase_primary;
    try show_at(writer, image, x_grid * (image.width + X_GAP), y_grid * (image.height + Y_GAP), select.byAVG);
    x_grid += x_grid_increase_primary;
    y_grid += y_grid_increase_primary;
    try show_at(writer, image, x_grid * (image.width + X_GAP), y_grid * (image.height + Y_GAP), select.byR);
    x_grid += x_grid_increase_primary;
    y_grid += y_grid_increase_primary;
    try show_at(writer, image, x_grid * (image.width + X_GAP), y_grid * (image.height + Y_GAP), select.byG);
    x_grid += x_grid_increase_primary;
    y_grid += y_grid_increase_primary;
    try show_at(writer, image, x_grid * (image.width + X_GAP), y_grid * (image.height + Y_GAP), select.byB);

    x_grid = x_grid_reset;
    y_grid = y_grid_reset;

    try show_at(writer, image, x_grid * (image.width + X_GAP), y_grid * (image.height + Y_GAP), select.byRGB_ASCII);
    x_grid += x_grid_increase_primary;
    y_grid += y_grid_increase_primary;
    try show_at(writer, image, x_grid * (image.width + X_GAP), y_grid * (image.height + Y_GAP), select.byAVG_ASCII);
    x_grid += x_grid_increase_primary;
    y_grid += y_grid_increase_primary;
    try show_at(writer, image, x_grid * (image.width + X_GAP), y_grid * (image.height + Y_GAP), select.byR_ASCII);
    x_grid += x_grid_increase_primary;
    y_grid += y_grid_increase_primary;
    try show_at(writer, image, x_grid * (image.width + X_GAP), y_grid * (image.height + Y_GAP), select.byG_ASCII);
    x_grid += x_grid_increase_primary;
    y_grid += y_grid_increase_primary;
    try show_at(writer, image, x_grid * (image.width + X_GAP), y_grid * (image.height + Y_GAP), select.byB_ASCII);

    try ansi.resetColors(writer);
}

fn readImageFromFile(relative_path: []const u8, allocator: std.mem.Allocator) !Image {
    const file = try std.fs.cwd().openFile(relative_path, .{});
    defer file.close();
    const file_metadata = try file.metadata();

    const buffer: []const u8 = try file.reader().readAllAlloc(allocator, file_metadata.size());
    defer allocator.free(buffer);

    var stream = StreamSource{ .const_buffer = std.io.fixedBufferStream(buffer) };
    return Image.init(allocator, &stream);
}

pub fn run() !void {
    // TODO: IMPROVE: cli arguments
    const relative_path = "images/example.bmp";
    const align_horizontally = true;

    const image = try readImageFromFile(relative_path, std.heap.page_allocator);
    defer image.deinit();

    try show(image, align_horizontally);
}
