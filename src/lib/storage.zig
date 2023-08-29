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
