const RGB24 = @import("lib/zig-image.zig").color.RGB24;
const ansi = @import("ansi.zig");
const mapping = @import("mapping.zig");

const RED = RGB24.init(255, 0, 0);
const GREEN = RGB24.init(0, 255, 0);
const BLUE = RGB24.init(0, 0, 255);

const Selection = struct {
    char: []const u8 = ansi.CHAR_BLOCK_FULL,
    foreground: RGB24 = .{ .r = 0xFF, .g = 0xFF, .b = 0xFF },
};

pub const Function = fn (RGB24) Selection;

fn calcAVG(color: RGB24) f32 {
    const r = @as(f32, @floatFromInt(color.r));
    const g = @as(f32, @floatFromInt(color.g));
    const b = @as(f32, @floatFromInt(color.b));
    return (r + g + b) / (255 * 3.0);
}

fn calcValue(channel: u8) f32 {
    const v = @as(f32, @floatFromInt(channel));
    return v / 255;
}

pub fn byRGB(color: RGB24) Selection {
    return .{ .foreground = color };
}

pub fn byAVG(color: RGB24) Selection {
    const value = calcAVG(color);
    return .{ .char = mapping.DEFAULT.find(value) };
}

pub fn byR(color: RGB24) Selection {
    const value = calcValue(color.r);
    return .{ .char = mapping.DEFAULT.find(value), .foreground = RED };
}

pub fn byG(color: RGB24) Selection {
    const value = calcValue(color.g);
    return .{ .char = mapping.DEFAULT.find(value), .foreground = GREEN };
}

pub fn byB(color: RGB24) Selection {
    const value = calcValue(color.b);
    return .{ .char = mapping.DEFAULT.find(value), .foreground = BLUE };
}

pub fn byRGB_ASCII(color: RGB24) Selection {
    const value = calcAVG(color);
    return .{ .char = mapping.ASCII.find(value), .foreground = color };
}

pub fn byAVG_ASCII(color: RGB24) Selection {
    const value = calcAVG(color);
    return .{ .char = mapping.ASCII.find(value) };
}

pub fn byR_ASCII(color: RGB24) Selection {
    const value = calcValue(color.r);
    return .{ .char = mapping.ASCII.find(value), .foreground = RED };
}

pub fn byG_ASCII(color: RGB24) Selection {
    const value = calcValue(color.g);
    return .{ .char = mapping.ASCII.find(value), .foreground = GREEN };
}

pub fn byB_ASCII(color: RGB24) Selection {
    const value = calcValue(color.b);
    return .{ .char = mapping.ASCII.find(value), .foreground = BLUE };
}
