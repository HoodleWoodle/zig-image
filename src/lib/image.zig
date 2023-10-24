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

pub const Format = enum { BMP, PNG };

pub fn ImageCT(comptime format: PixelFormat) type {
    return struct {
        const Self = @This();

        pub const Storage = PixelStorageCT(format);

        allocator: Allocator,
        width: u32,
        height: u32,
        storage: Storage,

        pub fn init(allocator: Allocator, width: u32, height: u32) Error!Self {
            return .{
                .allocator = allocator,
                .width = width,
                .height = height,
                .storage = try Storage.init(width * height, allocator),
            };
        }

        pub fn initRead(allocator: Allocator, stream: *StreamSource) Error!Self {
            const image_rt = try ImageRT.init_read(allocator, stream);
            defer image_rt.deinit();
            return .{
                .allocator = allocator,
                .width = image_rt.width,
                .height = image_rt.height,
                .storage = try Storage.initFromRT(image_rt.storage, allocator),
            };
        }

        pub fn write(self: Self, fmt: Format, writer: anytype) !void {
            const image_rt = .{
                .allocator = self.allocator,
                .width = self.width,
                .height = self.height,
                .storage = PixelStorageRT.initFromCTWrapped(format, self.storage),
            };
            // since it is just wrapping 'self' - there is not need for 'image_rt.deinit()'
            return switch (fmt) {
                .BMP => bmp.write(image_rt, writer),
                .PNG => png.write(image_rt, writer),
            };
        }

        pub fn deinit(self: *const Self) void {
            self.storage.deinit(self.allocator);
        }
    };
}

pub const ImageRT = struct {
    const Self = @This();

    allocator: Allocator,
    width: u32,
    height: u32,
    storage: PixelStorageRT,

    pub fn init(allocator: Allocator, pixel_fmt: PixelFormat, width: u32, height: u32) Error!Self {
        const pixel_count = width * height;
        return .{
            .allocator = allocator,
            .width = width,
            .height = height,
            .storage = try PixelStorageRT.init(pixel_fmt, pixel_count, allocator),
        };
    }

    pub fn initRead(allocator: Allocator, stream: *StreamSource) Error!Self {
        const fmt = try detectFormat(stream);
        try stream.seekTo(0);
        return switch (fmt) {
            .BMP => bmp.read(allocator, stream),
            .PNG => png.read(allocator, stream),
        };
    }

    pub fn write(self: Self, fmt: Format, writer: anytype) !void {
        return switch (fmt) {
            .BMP => bmp.write(self, writer),
            .PNG => png.write(self, writer),
        };
    }

    pub fn deinit(self: *const Self) void {
        self.storage.deinit(self.allocator);
    }
};

pub fn detectFormat(stream: *StreamSource) Error!Format {
    if (try png.isFormat(stream)) {
        return .PNG;
    }
    try stream.seekTo(0);
    if (try bmp.isFormat(stream)) {
        return .BMP;
    }
    try stream.seekTo(0);
    if (try ico.isFormat(stream)) {
        return Error.FormatNotSupported;
    }
    return Error.FormatUnkown;
}
