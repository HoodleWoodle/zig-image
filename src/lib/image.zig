const std = @import("std");
const Allocator = std.mem.Allocator;
const StreamSource = std.io.StreamSource;

const png = @import("formats/png.zig");
const bmp = @import("formats/bmp.zig");
const ico = @import("formats/ico.zig");

const storage = @import("storage.zig");
const PixelFormat = storage.Format;
const PixelStorageCT = storage.StorageCT;
const PixelStorageRT = storage.StorageRT;

pub const Error = std.mem.Allocator.Error ||
    error{InvalidValue} ||
    error{EndOfStream} || StreamSource.SeekError || StreamSource.GetSeekPosError || StreamSource.ReadError ||
    error{ FormatNotSupported, FormatUnkown } ||
    storage.StorageError ||
    png.Error || bmp.Error;

pub fn ImageCT(comptime format: PixelFormat) type {
    return struct {
        const Self = @This();

        pub const Storage = PixelStorageCT(format);

        allocator: Allocator,
        width: u32,
        height: u32,
        pixels: Storage,

        pub fn init(allocator: Allocator, stream: *StreamSource) Error!Self {
            const image_rt = try ImageRT.init(allocator, stream);
            defer image_rt.deinit();
            return .{
                .allocator = allocator,
                .width = image_rt.width,
                .height = image_rt.height,
                .pixels = try Storage.fromRT(image_rt.pixels, allocator),
            };
        }

        pub fn deinit(self: *const Self) void {
            self.pixels.deinit(self.allocator);
        }
    };
}

pub const ImageRT = struct {
    const Self = @This();

    allocator: Allocator,
    width: u32,
    height: u32,
    pixels: PixelStorageRT,

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

    pub fn deinit(self: *const Self) void {
        self.pixels.deinit(self.allocator);
    }
};
