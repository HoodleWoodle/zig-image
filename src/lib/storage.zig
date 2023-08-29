const std = @import("std");
const Allocator = std.mem.Allocator;
const color = @import("color.zig");

pub const Indexed1 = Indexed(color.RGBA32F, u1);
pub const Indexed4 = Indexed(color.RGBA32F, u4);
pub const Indexed8 = Indexed(color.RGBA32F, u8);

pub fn Indexed(comptime Col: type, comptime Idx: type) type {
    return struct {
        pub const Error = error{ NotEnoughSlotsInColorPalette, IndexedCorrupted };

        pub const Color = Col;
        pub const Index = Idx;
        const Self = @This();

        palette: []Color,
        indices: []Index,

        pub fn init(pixel_count: usize, allocator: Allocator) !Self {
            var palette = try allocator.alloc(Color, std.math.maxInt(Index) + 1);
            for (palette) |*col| {
                const nan = std.math.nan(f32);
                col.* = Color.init(nan, nan, nan, nan);
            }
            return Self{
                .palette = palette,
                .indices = try allocator.alloc(Index, pixel_count),
            };
        }

        pub fn deinit(self: Self, allocator: Allocator) void {
            allocator.free(self.palette);
            allocator.free(self.indices);
        }

        pub fn isColorInPalette(self: Self, c: Color) bool {
            for (self.palette) |col| {
                if (col.eql(c)) {
                    return true;
                }
            }
            return false;
        }

        pub fn isEmptySlotInPalette(self: Self) bool {
            for (self.palette) |col| {
                if (std.math.isNan(col.r)) {
                    return true;
                }
            }
            return false;
        }

        pub fn at(self: Self, pos: usize) !Color {
            const col = self.palette[self.indices[pos]];
            if (std.math.isNan(col.r)) {
                return Error.IndexedCorrupted;
            }
            return col;
        }

        pub fn set(self: *Self, pos: usize, c: Color) !void {
            var index: Index = loop: for (self.palette, 0..) |col, i| {
                const idx = std.math.cast(Index, i) orelse unreachable;
                if (std.math.isNan(col.r)) {
                    self.palette[idx] = c;
                    break :loop idx;
                } else if (col.eql(c)) {
                    break :loop idx;
                }
            } else {
                return Error.NotEnoughSlotsInColorPalette;
            };

            self.indices[pos] = index;
        }
    };
}

pub const Format = enum {
    indexed1,
    indexed4,
    indexed8,
    rgba32f,
    rgba32,
    bgra32,
    argb32,
    abgr32,
    rgb24,
    bgr24,
    argb4444,
    argb1555,
    rgb565,
    rgb555,
    a2r10g10b10,
    a2b10g10r10,
    grayscale1,
    grayscale4,
    grayscale8,

    const Self = @This();

    fn StorageType(comptime self: Self) type {
        return switch (self) {
            .indexed1 => Indexed1,
            .indexed4 => Indexed4,
            .indexed8 => Indexed8,
            else => []self.ColorType(),
        };
    }

    fn ColorType(comptime self: Self) type {
        return switch (self) {
            .indexed1 => self.StorageType().Color,
            .indexed4 => self.StorageType().Color,
            .indexed8 => self.StorageType().Color,
            .rgba32f => color.RGBA32F,
            .rgba32 => color.RGBA32,
            .bgra32 => color.BGRA32,
            .argb32 => color.ARGB32,
            .abgr32 => color.ABGR32,
            .rgb24 => color.RGB24,
            .bgr24 => color.BGR24,
            .argb4444 => color.ARGB4444,
            .argb1555 => color.ARGB1555,
            .rgb565 => color.RGB565,
            .rgb555 => color.RGB555,
            .a2r10g10b10 => color.A2R10G10B10,
            .a2b10g10r10 => color.A2B10G10R10,
            .grayscale1 => color.Grayscale1,
            .grayscale4 => color.Grayscale4,
            .grayscale8 => color.Grayscale8,
        };
    }

    fn isConversionLossy(comptime self: Self, comptime from: Self) bool {
        comptime return self.ColorType().isConversionLossy(from.ColorType());
    }
};

pub fn Storage(comptime format: Format) type {
    return struct {
        const Color = format.ColorType();
        const Self = @This();

        data: format.StorageType(),

        pub fn init(pixel_count: usize, allocator: Allocator) !Self {
            return .{ .data = try switch (format) {
                .indexed1 => Indexed1.init(pixel_count, allocator),
                .indexed4 => Indexed4.init(pixel_count, allocator),
                .indexed8 => Indexed8.init(pixel_count, allocator),
                else => allocator.alloc(Color, pixel_count),
            } };
        }

        pub fn from(comptime from_format: Format, from_value: Storage(from_format), allocator: Allocator) !Self {
            if (comptime format.isConversionLossy(from_format)) {
                @compileError("Conversion from '" ++ @tagName(from_format) ++ "' to '" ++ @tagName(format) ++ "' is lossy! Use 'Storage.fromLossy' instead.");
            }

            return fromInternal(from_format, from_value, allocator);
        }

        pub fn fromLossy(comptime from_format: Format, from_value: Storage(from_format), allocator: Allocator) !Self {
            if (comptime !format.isConversionLossy(from_format)) {
                @compileError("Conversion from '" ++ @tagName(from_format) ++ "' to '" ++ @tagName(format) ++ "' is lossless! Use 'Storage.from' instead.");
            }

            return fromInternal(from_format, from_value, allocator);
        }

        fn fromInternal(comptime from_format: Format, from_value: Storage(from_format), allocator: Allocator) !Self {
            const pixel_count = from_value.len();
            var self = try init(pixel_count, allocator);

            var i: u32 = 0;
            while (i < pixel_count) : (i += 1) {
                const pixel_src = try from_value.at(i);
                const pixel_rst = Color.from(from_format.ColorType(), pixel_src);
                try self.set(i, pixel_rst);
            }

            return self;
        }

        pub fn deinit(self: Self, allocator: Allocator) void {
            switch (format) {
                .indexed1 => self.data.deinit(allocator),
                .indexed4 => self.data.deinit(allocator),
                .indexed8 => self.data.deinit(allocator),
                else => allocator.free(self.data),
            }
        }

        pub fn len(self: Self) usize {
            return switch (format) {
                .indexed1 => self.data.indices.len,
                .indexed4 => self.data.indices.len,
                .indexed8 => self.data.indices.len,
                else => self.data.len,
            };
        }

        pub fn at(self: Self, pos: usize) !Color {
            return switch (format) {
                .indexed1 => try self.data.at(pos),
                .indexed4 => try self.data.at(pos),
                .indexed8 => try self.data.at(pos),
                else => self.data[pos],
            };
        }

        pub fn set(self: *Self, pos: usize, pixel: Color) !void {
            return switch (format) {
                .indexed1 => try self.data.set(pos, pixel),
                .indexed4 => try self.data.set(pos, pixel),
                .indexed8 => try self.data.set(pos, pixel),
                else => self.data[pos] = pixel,
            };
        }

        pub fn bytes(self: Self) []u8 {
            return switch (format) {
                .indexed1 => std.mem.sliceAsBytes(self.data.indices),
                .indexed4 => std.mem.sliceAsBytes(self.data.indices),
                .indexed8 => std.mem.sliceAsBytes(self.data.indices),
                else => std.mem.sliceAsBytes(self.data),
            };
        }
    };
}

pub const StorageRT = union(Format) {
    indexed1: Storage(.indexed1),
    indexed4: Storage(.indexed4),
    indexed8: Storage(.indexed8),
    rgba32f: Storage(.rgba32f),
    rgba32: Storage(.rgba32),
    bgra32: Storage(.bgra32),
    argb32: Storage(.argb32),
    abgr32: Storage(.abgr32),
    rgb24: Storage(.rgb24),
    bgr24: Storage(.bgr24),
    argb4444: Storage(.argb4444),
    argb1555: Storage(.argb1555),
    rgb565: Storage(.rgb565),
    rgb555: Storage(.rgb555),
    a2r10g10b10: Storage(.a2r10g10b10),
    a2b10g10r10: Storage(.a2b10g10r10),
    grayscale1: Storage(.grayscale1),
    grayscale4: Storage(.grayscale4),
    grayscale8: Storage(.grayscale8),

    const Self = @This();

    pub fn init(fmt: Format, pixel_count: usize, allocator: Allocator) !Self {
        return switch (fmt) {
            .indexed1 => .{ .indexed1 = try Storage(.indexed1).init(pixel_count, allocator) },
            .indexed4 => .{ .indexed4 = try Storage(.indexed4).init(pixel_count, allocator) },
            .indexed8 => .{ .indexed8 = try Storage(.indexed8).init(pixel_count, allocator) },
            .rgba32f => .{ .rgba32f = try Storage(.rgba32f).init(pixel_count, allocator) },
            .rgba32 => .{ .rgba32 = try Storage(.rgba32).init(pixel_count, allocator) },
            .bgra32 => .{ .bgra32 = try Storage(.bgra32).init(pixel_count, allocator) },
            .argb32 => .{ .argb32 = try Storage(.argb32).init(pixel_count, allocator) },
            .abgr32 => .{ .abgr32 = try Storage(.abgr32).init(pixel_count, allocator) },
            .rgb24 => .{ .rgb24 = try Storage(.rgb24).init(pixel_count, allocator) },
            .bgr24 => .{ .bgr24 = try Storage(.bgr24).init(pixel_count, allocator) },
            .argb4444 => .{ .argb4444 = try Storage(.argb4444).init(pixel_count, allocator) },
            .argb1555 => .{ .argb1555 = try Storage(.argb1555).init(pixel_count, allocator) },
            .rgb565 => .{ .rgb565 = try Storage(.rgb565).init(pixel_count, allocator) },
            .rgb555 => .{ .rgb555 = try Storage(.rgb555).init(pixel_count, allocator) },
            .a2r10g10b10 => .{ .a2r10g10b10 = try Storage(.a2r10g10b10).init(pixel_count, allocator) },
            .a2b10g10r10 => .{ .a2b10g10r10 = try Storage(.a2b10g10r10).init(pixel_count, allocator) },
            .grayscale1 => .{ .grayscale1 = try Storage(.grayscale1).init(pixel_count, allocator) },
            .grayscale4 => .{ .grayscale4 = try Storage(.grayscale4).init(pixel_count, allocator) },
            .grayscale8 => .{ .grayscale8 = try Storage(.grayscale8).init(pixel_count, allocator) },
        };
    }

    /// conversion may be lossy
    pub fn from(fmt: Format, from_value: StorageRT, allocator: Allocator) !Self {
        switch (from_value) {
            .indexed1 => |data| {
                const From = .indexed1;
                return switch (fmt) {
                    .indexed1 => .{ .indexed1 = try Storage(.indexed1).fromInternal(From, data, allocator) },
                    .indexed4 => .{ .indexed4 = try Storage(.indexed4).fromInternal(From, data, allocator) },
                    .indexed8 => .{ .indexed8 = try Storage(.indexed8).fromInternal(From, data, allocator) },
                    .rgba32f => .{ .rgba32f = try Storage(.rgba32f).fromInternal(From, data, allocator) },
                    .rgba32 => .{ .rgba32 = try Storage(.rgba32).fromInternal(From, data, allocator) },
                    .bgra32 => .{ .bgra32 = try Storage(.bgra32).fromInternal(From, data, allocator) },
                    .argb32 => .{ .argb32 = try Storage(.argb32).fromInternal(From, data, allocator) },
                    .abgr32 => .{ .abgr32 = try Storage(.abgr32).fromInternal(From, data, allocator) },
                    .rgb24 => .{ .rgb24 = try Storage(.rgb24).fromInternal(From, data, allocator) },
                    .bgr24 => .{ .bgr24 = try Storage(.bgr24).fromInternal(From, data, allocator) },
                    .argb4444 => .{ .argb4444 = try Storage(.argb4444).fromInternal(From, data, allocator) },
                    .argb1555 => .{ .argb1555 = try Storage(.argb1555).fromInternal(From, data, allocator) },
                    .rgb565 => .{ .rgb565 = try Storage(.rgb565).fromInternal(From, data, allocator) },
                    .rgb555 => .{ .rgb555 = try Storage(.rgb555).fromInternal(From, data, allocator) },
                    .a2r10g10b10 => .{ .a2r10g10b10 = try Storage(.a2r10g10b10).fromInternal(From, data, allocator) },
                    .a2b10g10r10 => .{ .a2b10g10r10 = try Storage(.a2b10g10r10).fromInternal(From, data, allocator) },
                    .grayscale1 => .{ .grayscale1 = try Storage(.grayscale1).fromInternal(From, data, allocator) },
                    .grayscale4 => .{ .grayscale4 = try Storage(.grayscale4).fromInternal(From, data, allocator) },
                    .grayscale8 => .{ .grayscale8 = try Storage(.grayscale8).fromInternal(From, data, allocator) },
                };
            },
            .indexed4 => |data| {
                const From = .indexed4;
                return switch (fmt) {
                    .indexed1 => .{ .indexed1 = try Storage(.indexed1).fromInternal(From, data, allocator) },
                    .indexed4 => .{ .indexed4 = try Storage(.indexed4).fromInternal(From, data, allocator) },
                    .indexed8 => .{ .indexed8 = try Storage(.indexed8).fromInternal(From, data, allocator) },
                    .rgba32f => .{ .rgba32f = try Storage(.rgba32f).fromInternal(From, data, allocator) },
                    .rgba32 => .{ .rgba32 = try Storage(.rgba32).fromInternal(From, data, allocator) },
                    .bgra32 => .{ .bgra32 = try Storage(.bgra32).fromInternal(From, data, allocator) },
                    .argb32 => .{ .argb32 = try Storage(.argb32).fromInternal(From, data, allocator) },
                    .abgr32 => .{ .abgr32 = try Storage(.abgr32).fromInternal(From, data, allocator) },
                    .rgb24 => .{ .rgb24 = try Storage(.rgb24).fromInternal(From, data, allocator) },
                    .bgr24 => .{ .bgr24 = try Storage(.bgr24).fromInternal(From, data, allocator) },
                    .argb4444 => .{ .argb4444 = try Storage(.argb4444).fromInternal(From, data, allocator) },
                    .argb1555 => .{ .argb1555 = try Storage(.argb1555).fromInternal(From, data, allocator) },
                    .rgb565 => .{ .rgb565 = try Storage(.rgb565).fromInternal(From, data, allocator) },
                    .rgb555 => .{ .rgb555 = try Storage(.rgb555).fromInternal(From, data, allocator) },
                    .a2r10g10b10 => .{ .a2r10g10b10 = try Storage(.a2r10g10b10).fromInternal(From, data, allocator) },
                    .a2b10g10r10 => .{ .a2b10g10r10 = try Storage(.a2b10g10r10).fromInternal(From, data, allocator) },
                    .grayscale1 => .{ .grayscale1 = try Storage(.grayscale1).fromInternal(From, data, allocator) },
                    .grayscale4 => .{ .grayscale4 = try Storage(.grayscale4).fromInternal(From, data, allocator) },
                    .grayscale8 => .{ .grayscale8 = try Storage(.grayscale8).fromInternal(From, data, allocator) },
                };
            },
            .indexed8 => |data| {
                const From = .indexed8;
                return switch (fmt) {
                    .indexed1 => .{ .indexed1 = try Storage(.indexed1).fromInternal(From, data, allocator) },
                    .indexed4 => .{ .indexed4 = try Storage(.indexed4).fromInternal(From, data, allocator) },
                    .indexed8 => .{ .indexed8 = try Storage(.indexed8).fromInternal(From, data, allocator) },
                    .rgba32f => .{ .rgba32f = try Storage(.rgba32f).fromInternal(From, data, allocator) },
                    .rgba32 => .{ .rgba32 = try Storage(.rgba32).fromInternal(From, data, allocator) },
                    .bgra32 => .{ .bgra32 = try Storage(.bgra32).fromInternal(From, data, allocator) },
                    .argb32 => .{ .argb32 = try Storage(.argb32).fromInternal(From, data, allocator) },
                    .abgr32 => .{ .abgr32 = try Storage(.abgr32).fromInternal(From, data, allocator) },
                    .rgb24 => .{ .rgb24 = try Storage(.rgb24).fromInternal(From, data, allocator) },
                    .bgr24 => .{ .bgr24 = try Storage(.bgr24).fromInternal(From, data, allocator) },
                    .argb4444 => .{ .argb4444 = try Storage(.argb4444).fromInternal(From, data, allocator) },
                    .argb1555 => .{ .argb1555 = try Storage(.argb1555).fromInternal(From, data, allocator) },
                    .rgb565 => .{ .rgb565 = try Storage(.rgb565).fromInternal(From, data, allocator) },
                    .rgb555 => .{ .rgb555 = try Storage(.rgb555).fromInternal(From, data, allocator) },
                    .a2r10g10b10 => .{ .a2r10g10b10 = try Storage(.a2r10g10b10).fromInternal(From, data, allocator) },
                    .a2b10g10r10 => .{ .a2b10g10r10 = try Storage(.a2b10g10r10).fromInternal(From, data, allocator) },
                    .grayscale1 => .{ .grayscale1 = try Storage(.grayscale1).fromInternal(From, data, allocator) },
                    .grayscale4 => .{ .grayscale4 = try Storage(.grayscale4).fromInternal(From, data, allocator) },
                    .grayscale8 => .{ .grayscale8 = try Storage(.grayscale8).fromInternal(From, data, allocator) },
                };
            },
            .rgba32f => |data| {
                const From = .rgba32f;
                return switch (fmt) {
                    .indexed1 => .{ .indexed1 = try Storage(.indexed1).fromInternal(From, data, allocator) },
                    .indexed4 => .{ .indexed4 = try Storage(.indexed4).fromInternal(From, data, allocator) },
                    .indexed8 => .{ .indexed8 = try Storage(.indexed8).fromInternal(From, data, allocator) },
                    .rgba32f => .{ .rgba32f = try Storage(.rgba32f).fromInternal(From, data, allocator) },
                    .rgba32 => .{ .rgba32 = try Storage(.rgba32).fromInternal(From, data, allocator) },
                    .bgra32 => .{ .bgra32 = try Storage(.bgra32).fromInternal(From, data, allocator) },
                    .argb32 => .{ .argb32 = try Storage(.argb32).fromInternal(From, data, allocator) },
                    .abgr32 => .{ .abgr32 = try Storage(.abgr32).fromInternal(From, data, allocator) },
                    .rgb24 => .{ .rgb24 = try Storage(.rgb24).fromInternal(From, data, allocator) },
                    .bgr24 => .{ .bgr24 = try Storage(.bgr24).fromInternal(From, data, allocator) },
                    .argb4444 => .{ .argb4444 = try Storage(.argb4444).fromInternal(From, data, allocator) },
                    .argb1555 => .{ .argb1555 = try Storage(.argb1555).fromInternal(From, data, allocator) },
                    .rgb565 => .{ .rgb565 = try Storage(.rgb565).fromInternal(From, data, allocator) },
                    .rgb555 => .{ .rgb555 = try Storage(.rgb555).fromInternal(From, data, allocator) },
                    .a2r10g10b10 => .{ .a2r10g10b10 = try Storage(.a2r10g10b10).fromInternal(From, data, allocator) },
                    .a2b10g10r10 => .{ .a2b10g10r10 = try Storage(.a2b10g10r10).fromInternal(From, data, allocator) },
                    .grayscale1 => .{ .grayscale1 = try Storage(.grayscale1).fromInternal(From, data, allocator) },
                    .grayscale4 => .{ .grayscale4 = try Storage(.grayscale4).fromInternal(From, data, allocator) },
                    .grayscale8 => .{ .grayscale8 = try Storage(.grayscale8).fromInternal(From, data, allocator) },
                };
            },
            .rgba32 => |data| {
                const From = .rgba32;
                return switch (fmt) {
                    .indexed1 => .{ .indexed1 = try Storage(.indexed1).fromInternal(From, data, allocator) },
                    .indexed4 => .{ .indexed4 = try Storage(.indexed4).fromInternal(From, data, allocator) },
                    .indexed8 => .{ .indexed8 = try Storage(.indexed8).fromInternal(From, data, allocator) },
                    .rgba32f => .{ .rgba32f = try Storage(.rgba32f).fromInternal(From, data, allocator) },
                    .rgba32 => .{ .rgba32 = try Storage(.rgba32).fromInternal(From, data, allocator) },
                    .bgra32 => .{ .bgra32 = try Storage(.bgra32).fromInternal(From, data, allocator) },
                    .argb32 => .{ .argb32 = try Storage(.argb32).fromInternal(From, data, allocator) },
                    .abgr32 => .{ .abgr32 = try Storage(.abgr32).fromInternal(From, data, allocator) },
                    .rgb24 => .{ .rgb24 = try Storage(.rgb24).fromInternal(From, data, allocator) },
                    .bgr24 => .{ .bgr24 = try Storage(.bgr24).fromInternal(From, data, allocator) },
                    .argb4444 => .{ .argb4444 = try Storage(.argb4444).fromInternal(From, data, allocator) },
                    .argb1555 => .{ .argb1555 = try Storage(.argb1555).fromInternal(From, data, allocator) },
                    .rgb565 => .{ .rgb565 = try Storage(.rgb565).fromInternal(From, data, allocator) },
                    .rgb555 => .{ .rgb555 = try Storage(.rgb555).fromInternal(From, data, allocator) },
                    .a2r10g10b10 => .{ .a2r10g10b10 = try Storage(.a2r10g10b10).fromInternal(From, data, allocator) },
                    .a2b10g10r10 => .{ .a2b10g10r10 = try Storage(.a2b10g10r10).fromInternal(From, data, allocator) },
                    .grayscale1 => .{ .grayscale1 = try Storage(.grayscale1).fromInternal(From, data, allocator) },
                    .grayscale4 => .{ .grayscale4 = try Storage(.grayscale4).fromInternal(From, data, allocator) },
                    .grayscale8 => .{ .grayscale8 = try Storage(.grayscale8).fromInternal(From, data, allocator) },
                };
            },
            .bgra32 => |data| {
                const From = .bgra32;
                return switch (fmt) {
                    .indexed1 => .{ .indexed1 = try Storage(.indexed1).fromInternal(From, data, allocator) },
                    .indexed4 => .{ .indexed4 = try Storage(.indexed4).fromInternal(From, data, allocator) },
                    .indexed8 => .{ .indexed8 = try Storage(.indexed8).fromInternal(From, data, allocator) },
                    .rgba32f => .{ .rgba32f = try Storage(.rgba32f).fromInternal(From, data, allocator) },
                    .rgba32 => .{ .rgba32 = try Storage(.rgba32).fromInternal(From, data, allocator) },
                    .bgra32 => .{ .bgra32 = try Storage(.bgra32).fromInternal(From, data, allocator) },
                    .argb32 => .{ .argb32 = try Storage(.argb32).fromInternal(From, data, allocator) },
                    .abgr32 => .{ .abgr32 = try Storage(.abgr32).fromInternal(From, data, allocator) },
                    .rgb24 => .{ .rgb24 = try Storage(.rgb24).fromInternal(From, data, allocator) },
                    .bgr24 => .{ .bgr24 = try Storage(.bgr24).fromInternal(From, data, allocator) },
                    .argb4444 => .{ .argb4444 = try Storage(.argb4444).fromInternal(From, data, allocator) },
                    .argb1555 => .{ .argb1555 = try Storage(.argb1555).fromInternal(From, data, allocator) },
                    .rgb565 => .{ .rgb565 = try Storage(.rgb565).fromInternal(From, data, allocator) },
                    .rgb555 => .{ .rgb555 = try Storage(.rgb555).fromInternal(From, data, allocator) },
                    .a2r10g10b10 => .{ .a2r10g10b10 = try Storage(.a2r10g10b10).fromInternal(From, data, allocator) },
                    .a2b10g10r10 => .{ .a2b10g10r10 = try Storage(.a2b10g10r10).fromInternal(From, data, allocator) },
                    .grayscale1 => .{ .grayscale1 = try Storage(.grayscale1).fromInternal(From, data, allocator) },
                    .grayscale4 => .{ .grayscale4 = try Storage(.grayscale4).fromInternal(From, data, allocator) },
                    .grayscale8 => .{ .grayscale8 = try Storage(.grayscale8).fromInternal(From, data, allocator) },
                };
            },
            .argb32 => |data| {
                const From = .argb32;
                return switch (fmt) {
                    .indexed1 => .{ .indexed1 = try Storage(.indexed1).fromInternal(From, data, allocator) },
                    .indexed4 => .{ .indexed4 = try Storage(.indexed4).fromInternal(From, data, allocator) },
                    .indexed8 => .{ .indexed8 = try Storage(.indexed8).fromInternal(From, data, allocator) },
                    .rgba32f => .{ .rgba32f = try Storage(.rgba32f).fromInternal(From, data, allocator) },
                    .rgba32 => .{ .rgba32 = try Storage(.rgba32).fromInternal(From, data, allocator) },
                    .bgra32 => .{ .bgra32 = try Storage(.bgra32).fromInternal(From, data, allocator) },
                    .argb32 => .{ .argb32 = try Storage(.argb32).fromInternal(From, data, allocator) },
                    .abgr32 => .{ .abgr32 = try Storage(.abgr32).fromInternal(From, data, allocator) },
                    .rgb24 => .{ .rgb24 = try Storage(.rgb24).fromInternal(From, data, allocator) },
                    .bgr24 => .{ .bgr24 = try Storage(.bgr24).fromInternal(From, data, allocator) },
                    .argb4444 => .{ .argb4444 = try Storage(.argb4444).fromInternal(From, data, allocator) },
                    .argb1555 => .{ .argb1555 = try Storage(.argb1555).fromInternal(From, data, allocator) },
                    .rgb565 => .{ .rgb565 = try Storage(.rgb565).fromInternal(From, data, allocator) },
                    .rgb555 => .{ .rgb555 = try Storage(.rgb555).fromInternal(From, data, allocator) },
                    .a2r10g10b10 => .{ .a2r10g10b10 = try Storage(.a2r10g10b10).fromInternal(From, data, allocator) },
                    .a2b10g10r10 => .{ .a2b10g10r10 = try Storage(.a2b10g10r10).fromInternal(From, data, allocator) },
                    .grayscale1 => .{ .grayscale1 = try Storage(.grayscale1).fromInternal(From, data, allocator) },
                    .grayscale4 => .{ .grayscale4 = try Storage(.grayscale4).fromInternal(From, data, allocator) },
                    .grayscale8 => .{ .grayscale8 = try Storage(.grayscale8).fromInternal(From, data, allocator) },
                };
            },
            .abgr32 => |data| {
                const From = .abgr32;
                return switch (fmt) {
                    .indexed1 => .{ .indexed1 = try Storage(.indexed1).fromInternal(From, data, allocator) },
                    .indexed4 => .{ .indexed4 = try Storage(.indexed4).fromInternal(From, data, allocator) },
                    .indexed8 => .{ .indexed8 = try Storage(.indexed8).fromInternal(From, data, allocator) },
                    .rgba32f => .{ .rgba32f = try Storage(.rgba32f).fromInternal(From, data, allocator) },
                    .rgba32 => .{ .rgba32 = try Storage(.rgba32).fromInternal(From, data, allocator) },
                    .bgra32 => .{ .bgra32 = try Storage(.bgra32).fromInternal(From, data, allocator) },
                    .argb32 => .{ .argb32 = try Storage(.argb32).fromInternal(From, data, allocator) },
                    .abgr32 => .{ .abgr32 = try Storage(.abgr32).fromInternal(From, data, allocator) },
                    .rgb24 => .{ .rgb24 = try Storage(.rgb24).fromInternal(From, data, allocator) },
                    .bgr24 => .{ .bgr24 = try Storage(.bgr24).fromInternal(From, data, allocator) },
                    .argb4444 => .{ .argb4444 = try Storage(.argb4444).fromInternal(From, data, allocator) },
                    .argb1555 => .{ .argb1555 = try Storage(.argb1555).fromInternal(From, data, allocator) },
                    .rgb565 => .{ .rgb565 = try Storage(.rgb565).fromInternal(From, data, allocator) },
                    .rgb555 => .{ .rgb555 = try Storage(.rgb555).fromInternal(From, data, allocator) },
                    .a2r10g10b10 => .{ .a2r10g10b10 = try Storage(.a2r10g10b10).fromInternal(From, data, allocator) },
                    .a2b10g10r10 => .{ .a2b10g10r10 = try Storage(.a2b10g10r10).fromInternal(From, data, allocator) },
                    .grayscale1 => .{ .grayscale1 = try Storage(.grayscale1).fromInternal(From, data, allocator) },
                    .grayscale4 => .{ .grayscale4 = try Storage(.grayscale4).fromInternal(From, data, allocator) },
                    .grayscale8 => .{ .grayscale8 = try Storage(.grayscale8).fromInternal(From, data, allocator) },
                };
            },
            .rgb24 => |data| {
                const From = .rgb24;
                return switch (fmt) {
                    .indexed1 => .{ .indexed1 = try Storage(.indexed1).fromInternal(From, data, allocator) },
                    .indexed4 => .{ .indexed4 = try Storage(.indexed4).fromInternal(From, data, allocator) },
                    .indexed8 => .{ .indexed8 = try Storage(.indexed8).fromInternal(From, data, allocator) },
                    .rgba32f => .{ .rgba32f = try Storage(.rgba32f).fromInternal(From, data, allocator) },
                    .rgba32 => .{ .rgba32 = try Storage(.rgba32).fromInternal(From, data, allocator) },
                    .bgra32 => .{ .bgra32 = try Storage(.bgra32).fromInternal(From, data, allocator) },
                    .argb32 => .{ .argb32 = try Storage(.argb32).fromInternal(From, data, allocator) },
                    .abgr32 => .{ .abgr32 = try Storage(.abgr32).fromInternal(From, data, allocator) },
                    .rgb24 => .{ .rgb24 = try Storage(.rgb24).fromInternal(From, data, allocator) },
                    .bgr24 => .{ .bgr24 = try Storage(.bgr24).fromInternal(From, data, allocator) },
                    .argb4444 => .{ .argb4444 = try Storage(.argb4444).fromInternal(From, data, allocator) },
                    .argb1555 => .{ .argb1555 = try Storage(.argb1555).fromInternal(From, data, allocator) },
                    .rgb565 => .{ .rgb565 = try Storage(.rgb565).fromInternal(From, data, allocator) },
                    .rgb555 => .{ .rgb555 = try Storage(.rgb555).fromInternal(From, data, allocator) },
                    .a2r10g10b10 => .{ .a2r10g10b10 = try Storage(.a2r10g10b10).fromInternal(From, data, allocator) },
                    .a2b10g10r10 => .{ .a2b10g10r10 = try Storage(.a2b10g10r10).fromInternal(From, data, allocator) },
                    .grayscale1 => .{ .grayscale1 = try Storage(.grayscale1).fromInternal(From, data, allocator) },
                    .grayscale4 => .{ .grayscale4 = try Storage(.grayscale4).fromInternal(From, data, allocator) },
                    .grayscale8 => .{ .grayscale8 = try Storage(.grayscale8).fromInternal(From, data, allocator) },
                };
            },
            .bgr24 => |data| {
                const From = .bgr24;
                return switch (fmt) {
                    .indexed1 => .{ .indexed1 = try Storage(.indexed1).fromInternal(From, data, allocator) },
                    .indexed4 => .{ .indexed4 = try Storage(.indexed4).fromInternal(From, data, allocator) },
                    .indexed8 => .{ .indexed8 = try Storage(.indexed8).fromInternal(From, data, allocator) },
                    .rgba32f => .{ .rgba32f = try Storage(.rgba32f).fromInternal(From, data, allocator) },
                    .rgba32 => .{ .rgba32 = try Storage(.rgba32).fromInternal(From, data, allocator) },
                    .bgra32 => .{ .bgra32 = try Storage(.bgra32).fromInternal(From, data, allocator) },
                    .argb32 => .{ .argb32 = try Storage(.argb32).fromInternal(From, data, allocator) },
                    .abgr32 => .{ .abgr32 = try Storage(.abgr32).fromInternal(From, data, allocator) },
                    .rgb24 => .{ .rgb24 = try Storage(.rgb24).fromInternal(From, data, allocator) },
                    .bgr24 => .{ .bgr24 = try Storage(.bgr24).fromInternal(From, data, allocator) },
                    .argb4444 => .{ .argb4444 = try Storage(.argb4444).fromInternal(From, data, allocator) },
                    .argb1555 => .{ .argb1555 = try Storage(.argb1555).fromInternal(From, data, allocator) },
                    .rgb565 => .{ .rgb565 = try Storage(.rgb565).fromInternal(From, data, allocator) },
                    .rgb555 => .{ .rgb555 = try Storage(.rgb555).fromInternal(From, data, allocator) },
                    .a2r10g10b10 => .{ .a2r10g10b10 = try Storage(.a2r10g10b10).fromInternal(From, data, allocator) },
                    .a2b10g10r10 => .{ .a2b10g10r10 = try Storage(.a2b10g10r10).fromInternal(From, data, allocator) },
                    .grayscale1 => .{ .grayscale1 = try Storage(.grayscale1).fromInternal(From, data, allocator) },
                    .grayscale4 => .{ .grayscale4 = try Storage(.grayscale4).fromInternal(From, data, allocator) },
                    .grayscale8 => .{ .grayscale8 = try Storage(.grayscale8).fromInternal(From, data, allocator) },
                };
            },
            .argb4444 => |data| {
                const From = .argb4444;
                return switch (fmt) {
                    .indexed1 => .{ .indexed1 = try Storage(.indexed1).fromInternal(From, data, allocator) },
                    .indexed4 => .{ .indexed4 = try Storage(.indexed4).fromInternal(From, data, allocator) },
                    .indexed8 => .{ .indexed8 = try Storage(.indexed8).fromInternal(From, data, allocator) },
                    .rgba32f => .{ .rgba32f = try Storage(.rgba32f).fromInternal(From, data, allocator) },
                    .rgba32 => .{ .rgba32 = try Storage(.rgba32).fromInternal(From, data, allocator) },
                    .bgra32 => .{ .bgra32 = try Storage(.bgra32).fromInternal(From, data, allocator) },
                    .argb32 => .{ .argb32 = try Storage(.argb32).fromInternal(From, data, allocator) },
                    .abgr32 => .{ .abgr32 = try Storage(.abgr32).fromInternal(From, data, allocator) },
                    .rgb24 => .{ .rgb24 = try Storage(.rgb24).fromInternal(From, data, allocator) },
                    .bgr24 => .{ .bgr24 = try Storage(.bgr24).fromInternal(From, data, allocator) },
                    .argb4444 => .{ .argb4444 = try Storage(.argb4444).fromInternal(From, data, allocator) },
                    .argb1555 => .{ .argb1555 = try Storage(.argb1555).fromInternal(From, data, allocator) },
                    .rgb565 => .{ .rgb565 = try Storage(.rgb565).fromInternal(From, data, allocator) },
                    .rgb555 => .{ .rgb555 = try Storage(.rgb555).fromInternal(From, data, allocator) },
                    .a2r10g10b10 => .{ .a2r10g10b10 = try Storage(.a2r10g10b10).fromInternal(From, data, allocator) },
                    .a2b10g10r10 => .{ .a2b10g10r10 = try Storage(.a2b10g10r10).fromInternal(From, data, allocator) },
                    .grayscale1 => .{ .grayscale1 = try Storage(.grayscale1).fromInternal(From, data, allocator) },
                    .grayscale4 => .{ .grayscale4 = try Storage(.grayscale4).fromInternal(From, data, allocator) },
                    .grayscale8 => .{ .grayscale8 = try Storage(.grayscale8).fromInternal(From, data, allocator) },
                };
            },
            .argb1555 => |data| {
                const From = .argb1555;
                return switch (fmt) {
                    .indexed1 => .{ .indexed1 = try Storage(.indexed1).fromInternal(From, data, allocator) },
                    .indexed4 => .{ .indexed4 = try Storage(.indexed4).fromInternal(From, data, allocator) },
                    .indexed8 => .{ .indexed8 = try Storage(.indexed8).fromInternal(From, data, allocator) },
                    .rgba32f => .{ .rgba32f = try Storage(.rgba32f).fromInternal(From, data, allocator) },
                    .rgba32 => .{ .rgba32 = try Storage(.rgba32).fromInternal(From, data, allocator) },
                    .bgra32 => .{ .bgra32 = try Storage(.bgra32).fromInternal(From, data, allocator) },
                    .argb32 => .{ .argb32 = try Storage(.argb32).fromInternal(From, data, allocator) },
                    .abgr32 => .{ .abgr32 = try Storage(.abgr32).fromInternal(From, data, allocator) },
                    .rgb24 => .{ .rgb24 = try Storage(.rgb24).fromInternal(From, data, allocator) },
                    .bgr24 => .{ .bgr24 = try Storage(.bgr24).fromInternal(From, data, allocator) },
                    .argb4444 => .{ .argb4444 = try Storage(.argb4444).fromInternal(From, data, allocator) },
                    .argb1555 => .{ .argb1555 = try Storage(.argb1555).fromInternal(From, data, allocator) },
                    .rgb565 => .{ .rgb565 = try Storage(.rgb565).fromInternal(From, data, allocator) },
                    .rgb555 => .{ .rgb555 = try Storage(.rgb555).fromInternal(From, data, allocator) },
                    .a2r10g10b10 => .{ .a2r10g10b10 = try Storage(.a2r10g10b10).fromInternal(From, data, allocator) },
                    .a2b10g10r10 => .{ .a2b10g10r10 = try Storage(.a2b10g10r10).fromInternal(From, data, allocator) },
                    .grayscale1 => .{ .grayscale1 = try Storage(.grayscale1).fromInternal(From, data, allocator) },
                    .grayscale4 => .{ .grayscale4 = try Storage(.grayscale4).fromInternal(From, data, allocator) },
                    .grayscale8 => .{ .grayscale8 = try Storage(.grayscale8).fromInternal(From, data, allocator) },
                };
            },
            .rgb565 => |data| {
                const From = .rgb565;
                return switch (fmt) {
                    .indexed1 => .{ .indexed1 = try Storage(.indexed1).fromInternal(From, data, allocator) },
                    .indexed4 => .{ .indexed4 = try Storage(.indexed4).fromInternal(From, data, allocator) },
                    .indexed8 => .{ .indexed8 = try Storage(.indexed8).fromInternal(From, data, allocator) },
                    .rgba32f => .{ .rgba32f = try Storage(.rgba32f).fromInternal(From, data, allocator) },
                    .rgba32 => .{ .rgba32 = try Storage(.rgba32).fromInternal(From, data, allocator) },
                    .bgra32 => .{ .bgra32 = try Storage(.bgra32).fromInternal(From, data, allocator) },
                    .argb32 => .{ .argb32 = try Storage(.argb32).fromInternal(From, data, allocator) },
                    .abgr32 => .{ .abgr32 = try Storage(.abgr32).fromInternal(From, data, allocator) },
                    .rgb24 => .{ .rgb24 = try Storage(.rgb24).fromInternal(From, data, allocator) },
                    .bgr24 => .{ .bgr24 = try Storage(.bgr24).fromInternal(From, data, allocator) },
                    .argb4444 => .{ .argb4444 = try Storage(.argb4444).fromInternal(From, data, allocator) },
                    .argb1555 => .{ .argb1555 = try Storage(.argb1555).fromInternal(From, data, allocator) },
                    .rgb565 => .{ .rgb565 = try Storage(.rgb565).fromInternal(From, data, allocator) },
                    .rgb555 => .{ .rgb555 = try Storage(.rgb555).fromInternal(From, data, allocator) },
                    .a2r10g10b10 => .{ .a2r10g10b10 = try Storage(.a2r10g10b10).fromInternal(From, data, allocator) },
                    .a2b10g10r10 => .{ .a2b10g10r10 = try Storage(.a2b10g10r10).fromInternal(From, data, allocator) },
                    .grayscale1 => .{ .grayscale1 = try Storage(.grayscale1).fromInternal(From, data, allocator) },
                    .grayscale4 => .{ .grayscale4 = try Storage(.grayscale4).fromInternal(From, data, allocator) },
                    .grayscale8 => .{ .grayscale8 = try Storage(.grayscale8).fromInternal(From, data, allocator) },
                };
            },
            .rgb555 => |data| {
                const From = .rgb555;
                return switch (fmt) {
                    .indexed1 => .{ .indexed1 = try Storage(.indexed1).fromInternal(From, data, allocator) },
                    .indexed4 => .{ .indexed4 = try Storage(.indexed4).fromInternal(From, data, allocator) },
                    .indexed8 => .{ .indexed8 = try Storage(.indexed8).fromInternal(From, data, allocator) },
                    .rgba32f => .{ .rgba32f = try Storage(.rgba32f).fromInternal(From, data, allocator) },
                    .rgba32 => .{ .rgba32 = try Storage(.rgba32).fromInternal(From, data, allocator) },
                    .bgra32 => .{ .bgra32 = try Storage(.bgra32).fromInternal(From, data, allocator) },
                    .argb32 => .{ .argb32 = try Storage(.argb32).fromInternal(From, data, allocator) },
                    .abgr32 => .{ .abgr32 = try Storage(.abgr32).fromInternal(From, data, allocator) },
                    .rgb24 => .{ .rgb24 = try Storage(.rgb24).fromInternal(From, data, allocator) },
                    .bgr24 => .{ .bgr24 = try Storage(.bgr24).fromInternal(From, data, allocator) },
                    .argb4444 => .{ .argb4444 = try Storage(.argb4444).fromInternal(From, data, allocator) },
                    .argb1555 => .{ .argb1555 = try Storage(.argb1555).fromInternal(From, data, allocator) },
                    .rgb565 => .{ .rgb565 = try Storage(.rgb565).fromInternal(From, data, allocator) },
                    .rgb555 => .{ .rgb555 = try Storage(.rgb555).fromInternal(From, data, allocator) },
                    .a2r10g10b10 => .{ .a2r10g10b10 = try Storage(.a2r10g10b10).fromInternal(From, data, allocator) },
                    .a2b10g10r10 => .{ .a2b10g10r10 = try Storage(.a2b10g10r10).fromInternal(From, data, allocator) },
                    .grayscale1 => .{ .grayscale1 = try Storage(.grayscale1).fromInternal(From, data, allocator) },
                    .grayscale4 => .{ .grayscale4 = try Storage(.grayscale4).fromInternal(From, data, allocator) },
                    .grayscale8 => .{ .grayscale8 = try Storage(.grayscale8).fromInternal(From, data, allocator) },
                };
            },
            .a2r10g10b10 => |data| {
                const From = .a2r10g10b10;
                return switch (fmt) {
                    .indexed1 => .{ .indexed1 = try Storage(.indexed1).fromInternal(From, data, allocator) },
                    .indexed4 => .{ .indexed4 = try Storage(.indexed4).fromInternal(From, data, allocator) },
                    .indexed8 => .{ .indexed8 = try Storage(.indexed8).fromInternal(From, data, allocator) },
                    .rgba32f => .{ .rgba32f = try Storage(.rgba32f).fromInternal(From, data, allocator) },
                    .rgba32 => .{ .rgba32 = try Storage(.rgba32).fromInternal(From, data, allocator) },
                    .bgra32 => .{ .bgra32 = try Storage(.bgra32).fromInternal(From, data, allocator) },
                    .argb32 => .{ .argb32 = try Storage(.argb32).fromInternal(From, data, allocator) },
                    .abgr32 => .{ .abgr32 = try Storage(.abgr32).fromInternal(From, data, allocator) },
                    .rgb24 => .{ .rgb24 = try Storage(.rgb24).fromInternal(From, data, allocator) },
                    .bgr24 => .{ .bgr24 = try Storage(.bgr24).fromInternal(From, data, allocator) },
                    .argb4444 => .{ .argb4444 = try Storage(.argb4444).fromInternal(From, data, allocator) },
                    .argb1555 => .{ .argb1555 = try Storage(.argb1555).fromInternal(From, data, allocator) },
                    .rgb565 => .{ .rgb565 = try Storage(.rgb565).fromInternal(From, data, allocator) },
                    .rgb555 => .{ .rgb555 = try Storage(.rgb555).fromInternal(From, data, allocator) },
                    .a2r10g10b10 => .{ .a2r10g10b10 = try Storage(.a2r10g10b10).fromInternal(From, data, allocator) },
                    .a2b10g10r10 => .{ .a2b10g10r10 = try Storage(.a2b10g10r10).fromInternal(From, data, allocator) },
                    .grayscale1 => .{ .grayscale1 = try Storage(.grayscale1).fromInternal(From, data, allocator) },
                    .grayscale4 => .{ .grayscale4 = try Storage(.grayscale4).fromInternal(From, data, allocator) },
                    .grayscale8 => .{ .grayscale8 = try Storage(.grayscale8).fromInternal(From, data, allocator) },
                };
            },
            .a2b10g10r10 => |data| {
                const From = .a2b10g10r10;
                return switch (fmt) {
                    .indexed1 => .{ .indexed1 = try Storage(.indexed1).fromInternal(From, data, allocator) },
                    .indexed4 => .{ .indexed4 = try Storage(.indexed4).fromInternal(From, data, allocator) },
                    .indexed8 => .{ .indexed8 = try Storage(.indexed8).fromInternal(From, data, allocator) },
                    .rgba32f => .{ .rgba32f = try Storage(.rgba32f).fromInternal(From, data, allocator) },
                    .rgba32 => .{ .rgba32 = try Storage(.rgba32).fromInternal(From, data, allocator) },
                    .bgra32 => .{ .bgra32 = try Storage(.bgra32).fromInternal(From, data, allocator) },
                    .argb32 => .{ .argb32 = try Storage(.argb32).fromInternal(From, data, allocator) },
                    .abgr32 => .{ .abgr32 = try Storage(.abgr32).fromInternal(From, data, allocator) },
                    .rgb24 => .{ .rgb24 = try Storage(.rgb24).fromInternal(From, data, allocator) },
                    .bgr24 => .{ .bgr24 = try Storage(.bgr24).fromInternal(From, data, allocator) },
                    .argb4444 => .{ .argb4444 = try Storage(.argb4444).fromInternal(From, data, allocator) },
                    .argb1555 => .{ .argb1555 = try Storage(.argb1555).fromInternal(From, data, allocator) },
                    .rgb565 => .{ .rgb565 = try Storage(.rgb565).fromInternal(From, data, allocator) },
                    .rgb555 => .{ .rgb555 = try Storage(.rgb555).fromInternal(From, data, allocator) },
                    .a2r10g10b10 => .{ .a2r10g10b10 = try Storage(.a2r10g10b10).fromInternal(From, data, allocator) },
                    .a2b10g10r10 => .{ .a2b10g10r10 = try Storage(.a2b10g10r10).fromInternal(From, data, allocator) },
                    .grayscale1 => .{ .grayscale1 = try Storage(.grayscale1).fromInternal(From, data, allocator) },
                    .grayscale4 => .{ .grayscale4 = try Storage(.grayscale4).fromInternal(From, data, allocator) },
                    .grayscale8 => .{ .grayscale8 = try Storage(.grayscale8).fromInternal(From, data, allocator) },
                };
            },
            .grayscale1 => |data| {
                const From = .grayscale1;
                return switch (fmt) {
                    .indexed1 => .{ .indexed1 = try Storage(.indexed1).fromInternal(From, data, allocator) },
                    .indexed4 => .{ .indexed4 = try Storage(.indexed4).fromInternal(From, data, allocator) },
                    .indexed8 => .{ .indexed8 = try Storage(.indexed8).fromInternal(From, data, allocator) },
                    .rgba32f => .{ .rgba32f = try Storage(.rgba32f).fromInternal(From, data, allocator) },
                    .rgba32 => .{ .rgba32 = try Storage(.rgba32).fromInternal(From, data, allocator) },
                    .bgra32 => .{ .bgra32 = try Storage(.bgra32).fromInternal(From, data, allocator) },
                    .argb32 => .{ .argb32 = try Storage(.argb32).fromInternal(From, data, allocator) },
                    .abgr32 => .{ .abgr32 = try Storage(.abgr32).fromInternal(From, data, allocator) },
                    .rgb24 => .{ .rgb24 = try Storage(.rgb24).fromInternal(From, data, allocator) },
                    .bgr24 => .{ .bgr24 = try Storage(.bgr24).fromInternal(From, data, allocator) },
                    .argb4444 => .{ .argb4444 = try Storage(.argb4444).fromInternal(From, data, allocator) },
                    .argb1555 => .{ .argb1555 = try Storage(.argb1555).fromInternal(From, data, allocator) },
                    .rgb565 => .{ .rgb565 = try Storage(.rgb565).fromInternal(From, data, allocator) },
                    .rgb555 => .{ .rgb555 = try Storage(.rgb555).fromInternal(From, data, allocator) },
                    .a2r10g10b10 => .{ .a2r10g10b10 = try Storage(.a2r10g10b10).fromInternal(From, data, allocator) },
                    .a2b10g10r10 => .{ .a2b10g10r10 = try Storage(.a2b10g10r10).fromInternal(From, data, allocator) },
                    .grayscale1 => .{ .grayscale1 = try Storage(.grayscale1).fromInternal(From, data, allocator) },
                    .grayscale4 => .{ .grayscale4 = try Storage(.grayscale4).fromInternal(From, data, allocator) },
                    .grayscale8 => .{ .grayscale8 = try Storage(.grayscale8).fromInternal(From, data, allocator) },
                };
            },
            .grayscale4 => |data| {
                const From = .grayscale4;
                return switch (fmt) {
                    .indexed1 => .{ .indexed1 = try Storage(.indexed1).fromInternal(From, data, allocator) },
                    .indexed4 => .{ .indexed4 = try Storage(.indexed4).fromInternal(From, data, allocator) },
                    .indexed8 => .{ .indexed8 = try Storage(.indexed8).fromInternal(From, data, allocator) },
                    .rgba32f => .{ .rgba32f = try Storage(.rgba32f).fromInternal(From, data, allocator) },
                    .rgba32 => .{ .rgba32 = try Storage(.rgba32).fromInternal(From, data, allocator) },
                    .bgra32 => .{ .bgra32 = try Storage(.bgra32).fromInternal(From, data, allocator) },
                    .argb32 => .{ .argb32 = try Storage(.argb32).fromInternal(From, data, allocator) },
                    .abgr32 => .{ .abgr32 = try Storage(.abgr32).fromInternal(From, data, allocator) },
                    .rgb24 => .{ .rgb24 = try Storage(.rgb24).fromInternal(From, data, allocator) },
                    .bgr24 => .{ .bgr24 = try Storage(.bgr24).fromInternal(From, data, allocator) },
                    .argb4444 => .{ .argb4444 = try Storage(.argb4444).fromInternal(From, data, allocator) },
                    .argb1555 => .{ .argb1555 = try Storage(.argb1555).fromInternal(From, data, allocator) },
                    .rgb565 => .{ .rgb565 = try Storage(.rgb565).fromInternal(From, data, allocator) },
                    .rgb555 => .{ .rgb555 = try Storage(.rgb555).fromInternal(From, data, allocator) },
                    .a2r10g10b10 => .{ .a2r10g10b10 = try Storage(.a2r10g10b10).fromInternal(From, data, allocator) },
                    .a2b10g10r10 => .{ .a2b10g10r10 = try Storage(.a2b10g10r10).fromInternal(From, data, allocator) },
                    .grayscale1 => .{ .grayscale1 = try Storage(.grayscale1).fromInternal(From, data, allocator) },
                    .grayscale4 => .{ .grayscale4 = try Storage(.grayscale4).fromInternal(From, data, allocator) },
                    .grayscale8 => .{ .grayscale8 = try Storage(.grayscale8).fromInternal(From, data, allocator) },
                };
            },
            .grayscale8 => |data| {
                const From = .grayscale8;
                return switch (fmt) {
                    .indexed1 => .{ .indexed1 = try Storage(.indexed1).fromInternal(From, data, allocator) },
                    .indexed4 => .{ .indexed4 = try Storage(.indexed4).fromInternal(From, data, allocator) },
                    .indexed8 => .{ .indexed8 = try Storage(.indexed8).fromInternal(From, data, allocator) },
                    .rgba32f => .{ .rgba32f = try Storage(.rgba32f).fromInternal(From, data, allocator) },
                    .rgba32 => .{ .rgba32 = try Storage(.rgba32).fromInternal(From, data, allocator) },
                    .bgra32 => .{ .bgra32 = try Storage(.bgra32).fromInternal(From, data, allocator) },
                    .argb32 => .{ .argb32 = try Storage(.argb32).fromInternal(From, data, allocator) },
                    .abgr32 => .{ .abgr32 = try Storage(.abgr32).fromInternal(From, data, allocator) },
                    .rgb24 => .{ .rgb24 = try Storage(.rgb24).fromInternal(From, data, allocator) },
                    .bgr24 => .{ .bgr24 = try Storage(.bgr24).fromInternal(From, data, allocator) },
                    .argb4444 => .{ .argb4444 = try Storage(.argb4444).fromInternal(From, data, allocator) },
                    .argb1555 => .{ .argb1555 = try Storage(.argb1555).fromInternal(From, data, allocator) },
                    .rgb565 => .{ .rgb565 = try Storage(.rgb565).fromInternal(From, data, allocator) },
                    .rgb555 => .{ .rgb555 = try Storage(.rgb555).fromInternal(From, data, allocator) },
                    .a2r10g10b10 => .{ .a2r10g10b10 = try Storage(.a2r10g10b10).fromInternal(From, data, allocator) },
                    .a2b10g10r10 => .{ .a2b10g10r10 = try Storage(.a2b10g10r10).fromInternal(From, data, allocator) },
                    .grayscale1 => .{ .grayscale1 = try Storage(.grayscale1).fromInternal(From, data, allocator) },
                    .grayscale4 => .{ .grayscale4 = try Storage(.grayscale4).fromInternal(From, data, allocator) },
                    .grayscale8 => .{ .grayscale8 = try Storage(.grayscale8).fromInternal(From, data, allocator) },
                };
            },
        }
    }

    pub fn deinit(self: Self, allocator: Allocator) void {
        switch (self) {
            .indexed1 => |data| data.deinit(allocator),
            .indexed4 => |data| data.deinit(allocator),
            .indexed8 => |data| data.deinit(allocator),
            .rgba32f => |data| data.deinit(allocator),
            .rgba32 => |data| data.deinit(allocator),
            .bgra32 => |data| data.deinit(allocator),
            .argb32 => |data| data.deinit(allocator),
            .abgr32 => |data| data.deinit(allocator),
            .rgb24 => |data| data.deinit(allocator),
            .bgr24 => |data| data.deinit(allocator),
            .argb4444 => |data| data.deinit(allocator),
            .argb1555 => |data| data.deinit(allocator),
            .rgb565 => |data| data.deinit(allocator),
            .rgb555 => |data| data.deinit(allocator),
            .a2r10g10b10 => |data| data.deinit(allocator),
            .a2b10g10r10 => |data| data.deinit(allocator),
            .grayscale1 => |data| data.deinit(allocator),
            .grayscale4 => |data| data.deinit(allocator),
            .grayscale8 => |data| data.deinit(allocator),
        }
    }

    pub fn format(self: Self) Format {
        return switch (self) {
            .indexed1 => .indexed1,
            .indexed4 => .indexed4,
            .indexed8 => .indexed8,
            .rgba32f => .rgba32f,
            .rgba32 => .rgba32,
            .bgra32 => .bgra32,
            .argb32 => .argb32,
            .abgr32 => .abgr32,
            .rgb24 => .rgb24,
            .bgr24 => .bgr24,
            .argb4444 => .argb4444,
            .argb1555 => .argb1555,
            .rgb565 => .rgb565,
            .rgb555 => .rgb555,
            .a2r10g10b10 => .a2r10g10b10,
            .a2b10g10r10 => .a2b10g10r10,
            .grayscale1 => .grayscale1,
            .grayscale4 => .grayscale4,
            .grayscale8 => .grayscale8,
        };
    }

    pub fn len(self: Self) usize {
        return switch (self) {
            .indexed1 => |data| data.len(),
            .indexed4 => |data| data.len(),
            .indexed8 => |data| data.len(),
            .rgba32f => |data| data.len(),
            .rgba32 => |data| data.len(),
            .bgra32 => |data| data.len(),
            .argb32 => |data| data.len(),
            .abgr32 => |data| data.len(),
            .rgb24 => |data| data.len(),
            .bgr24 => |data| data.len(),
            .argb4444 => |data| data.len(),
            .argb1555 => |data| data.len(),
            .rgb565 => |data| data.len(),
            .rgb555 => |data| data.len(),
            .a2r10g10b10 => |data| data.len(),
            .a2b10g10r10 => |data| data.len(),
            .grayscale1 => |data| data.len(),
            .grayscale4 => |data| data.len(),
            .grayscale8 => |data| data.len(),
        };
    }

    pub fn bytes(self: Self) []u8 {
        return switch (self) {
            .indexed1 => |data| data.bytes(),
            .indexed4 => |data| data.bytes(),
            .indexed8 => |data| data.bytes(),
            .rgba32f => |data| data.bytes(),
            .rgba32 => |data| data.bytes(),
            .bgra32 => |data| data.bytes(),
            .argb32 => |data| data.bytes(),
            .abgr32 => |data| data.bytes(),
            .rgb24 => |data| data.bytes(),
            .bgr24 => |data| data.bytes(),
            .argb4444 => |data| data.bytes(),
            .argb1555 => |data| data.bytes(),
            .rgb565 => |data| data.bytes(),
            .rgb555 => |data| data.bytes(),
            .a2r10g10b10 => |data| data.bytes(),
            .a2b10g10r10 => |data| data.bytes(),
            .grayscale1 => |data| data.bytes(),
            .grayscale4 => |data| data.bytes(),
            .grayscale8 => |data| data.bytes(),
        };
    }
};
