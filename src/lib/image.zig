const std = @import("std");
const Allocator = std.mem.Allocator;
const StreamSource = std.io.StreamSource;

const png = @import("formats/png.zig");
const bmp = @import("formats/bmp.zig");
const ico = @import("formats/ico.zig");

pub const Error = std.mem.Allocator.Error ||
    error{InvalidValue} ||
    error{EndOfStream} || StreamSource.SeekError || StreamSource.GetSeekPosError || StreamSource.ReadError ||
    error{ FormatNotSupported, FormatUnkown } ||
    png.Error || bmp.Error;

const Self = @This();

pub const RGBA32 = packed struct {
    r: u8 = 0x00,
    g: u8 = 0x00,
    b: u8 = 0x00,
    a: u8 = 0xFF,

    pub fn eql(self: @This(), other: @This()) bool {
        return self.r == other.r and self.g == other.g and self.b == other.b and self.a == other.a;
    }

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("RGBA32{{ .r = 0x{x}, .g = 0x{x}, .b = 0x{x}, .a = 0x{x} }}", .{
            self.r, self.g, self.b, self.a,
        });
    }
};

allocator: Allocator,
width: u32,
height: u32,
pixels: []RGBA32,

pub fn init(allocator: Allocator, stream: *StreamSource) Error!Self {
    if (try png.is_format(stream)) {
        try stream.seekTo(0);
        return png.init(allocator, stream);
    }
    try stream.seekTo(0);
    if (try bmp.is_format(stream)) {
        try stream.seekTo(0);
        return bmp.init(allocator, stream);
    }
    try stream.seekTo(0);
    if (try ico.is_format(stream)) {
        return Error.FormatNotSupported;
    }
    return Error.FormatUnkown;
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.pixels);
}
