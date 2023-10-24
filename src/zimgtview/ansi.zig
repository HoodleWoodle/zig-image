const RGB24 = @import("../lib/zig-image.zig").color.RGB24;

pub const CHAR_BLOCK_FULL = "\u{2588}";
pub const CHAR_LIGHT_SHADE = "\u{2591}";
pub const CHAR_MEDIUM_SHADE = "\u{2592}";
pub const CHAR_DARK_SHADE = "\u{2593}";

const ESC = "\x1B";
const CSI = ESC ++ "[";

var color_background: ?RGB24 = null;
var color_foreground: ?RGB24 = null;

pub fn clearScreen(writer: anytype) !void {
    try writer.writeAll(CSI ++ "2J");
}

pub fn setCursor(writer: anytype, x: usize, y: usize) !void {
    try writer.print(CSI ++ "{};{}H", .{ y + 1, x + 1 });
}

pub fn setBackgroundColor(writer: anytype, color: RGB24) !void {
    if (color_background) |background| {
        if (color.eql(background)) return;
    }
    color_background = color;

    try writer.print(CSI ++ "48;2;{};{};{}m", .{ color.r, color.g, color.b });
}

pub fn setForegroundColor(writer: anytype, color: RGB24) !void {
    if (color_foreground) |foreground| {
        if (color.eql(foreground)) return;
    }
    color_foreground = color;

    try writer.print(CSI ++ "38;2;{};{};{}m", .{ color.r, color.g, color.b });
}

pub fn resetColors(writer: anytype) !void {
    try writer.print(CSI ++ "0m", .{});
}
