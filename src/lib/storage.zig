const std = @import("std");
const Allocator = std.mem.Allocator;
const color = @import("color.zig");

pub const Indexed1 = Indexed(color.RGBA128f, u1);
pub const Indexed4 = Indexed(color.RGBA128f, u4);
pub const Indexed8 = Indexed(color.RGBA128f, u8);

pub const StorageError = error{ IndexedNotEnoughSlotsInColorPalette, IndexedCorrupted };

pub fn Indexed(comptime Col: type, comptime Idx: type) type {
    return struct {
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
                return StorageError.IndexedCorrupted;
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
                return StorageError.IndexedNotEnoughSlotsInColorPalette;
            };

            self.indices[pos] = index;
        }
    };
}

pub const Format = enum {
    indexed1,
    indexed4,
    indexed8,
    rgba128f,
    rgba64,
    rgba32,
    bgra32,
    argb32,
    abgr32,
    rgb48,
    rgb24,
    bgr24,
    argb4444,
    argb1555,
    rgb565,
    rgb555,
    a2r10g10b10,
    a2b10g10r10,
    grayscale1,
    grayscale2,
    grayscale4,
    grayscale8,
    grayscale16,

    const Self = @This();

    fn StorageType(comptime self: Self) type {
        return switch (self) {
            .indexed1 => Indexed1,
            .indexed4 => Indexed4,
            .indexed8 => Indexed8,
            else => []self.ColorType(),
        };
    }

    pub fn ColorType(comptime self: Self) type {
        return switch (self) {
            .indexed1 => self.StorageType().Color,
            .indexed4 => self.StorageType().Color,
            .indexed8 => self.StorageType().Color,
            .rgba128f => color.RGBA128f,
            .rgba64 => color.RGBA64,
            .rgba32 => color.RGBA32,
            .bgra32 => color.BGRA32,
            .argb32 => color.ARGB32,
            .abgr32 => color.ABGR32,
            .rgb48 => color.RGB48,
            .rgb24 => color.RGB24,
            .bgr24 => color.BGR24,
            .argb4444 => color.ARGB4444,
            .argb1555 => color.ARGB1555,
            .rgb565 => color.RGB565,
            .rgb555 => color.RGB555,
            .a2r10g10b10 => color.A2R10G10B10,
            .a2b10g10r10 => color.A2B10G10R10,
            .grayscale1 => color.Grayscale1,
            .grayscale2 => color.Grayscale2,
            .grayscale4 => color.Grayscale4,
            .grayscale8 => color.Grayscale8,
            .grayscale16 => color.Grayscale16,
        };
    }

    fn isConversionLossy(comptime self: Self, comptime from: Self) bool {
        comptime return self.ColorType().isConversionLossy(from.ColorType());
    }
};

pub fn StorageCT(comptime format: Format) type {
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

        pub fn initFrom(comptime from_format: Format, from_value: StorageCT(from_format), allocator: Allocator) !Self {
            if (comptime format.isConversionLossy(from_format)) {
                @compileError("Conversion from '" ++ @tagName(from_format) ++ "' to '" ++ @tagName(format) ++ "' is lossy! Use 'Storage.fromLossy' instead.");
            }

            return initFromInternal(from_format, from_value, allocator);
        }

        pub fn initFromLossy(comptime from_format: Format, from_value: StorageCT(from_format), allocator: Allocator) !Self {
            if (comptime !format.isConversionLossy(from_format)) {
                @compileError("Conversion from '" ++ @tagName(from_format) ++ "' to '" ++ @tagName(format) ++ "' is lossless! Use 'Storage.from' instead.");
            }

            return initFromInternal(from_format, from_value, allocator);
        }

        fn initFromInternal(comptime from_format: Format, from_value: StorageCT(from_format), allocator: Allocator) !Self {
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

        pub fn initFromRT(from_value: StorageRT, allocator: Allocator) !Self {
            // TODO: IMPROVE: this function ALWAYS creates a copy - a 'move' alternative may be clever
            return switch (from_value) {
                .indexed1 => |data| initFromInternal(.indexed1, data, allocator),
                .indexed4 => |data| initFromInternal(.indexed4, data, allocator),
                .indexed8 => |data| initFromInternal(.indexed8, data, allocator),
                .rgba128f => |data| initFromInternal(.rgba128f, data, allocator),
                .rgba64 => |data| initFromInternal(.rgba64, data, allocator),
                .rgba32 => |data| initFromInternal(.rgba32, data, allocator),
                .bgra32 => |data| initFromInternal(.bgra32, data, allocator),
                .argb32 => |data| initFromInternal(.argb32, data, allocator),
                .abgr32 => |data| initFromInternal(.abgr32, data, allocator),
                .rgb48 => |data| initFromInternal(.rgb48, data, allocator),
                .rgb24 => |data| initFromInternal(.rgb24, data, allocator),
                .bgr24 => |data| initFromInternal(.bgr24, data, allocator),
                .argb4444 => |data| initFromInternal(.argb4444, data, allocator),
                .argb1555 => |data| initFromInternal(.argb1555, data, allocator),
                .rgb565 => |data| initFromInternal(.rgb565, data, allocator),
                .rgb555 => |data| initFromInternal(.rgb555, data, allocator),
                .a2r10g10b10 => |data| initFromInternal(.a2r10g10b10, data, allocator),
                .a2b10g10r10 => |data| initFromInternal(.a2b10g10r10, data, allocator),
                .grayscale1 => |data| initFromInternal(.grayscale1, data, allocator),
                .grayscale2 => |data| initFromInternal(.grayscale2, data, allocator),
                .grayscale4 => |data| initFromInternal(.grayscale4, data, allocator),
                .grayscale8 => |data| initFromInternal(.grayscale8, data, allocator),
                .grayscale16 => |data| initFromInternal(.grayscale16, data, allocator),
            };
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

        pub fn set(self: *Self, pos: usize, c: Color) !void {
            return switch (format) {
                .indexed1 => try self.data.set(pos, c),
                .indexed4 => try self.data.set(pos, c),
                .indexed8 => try self.data.set(pos, c),
                else => self.data[pos] = c,
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
    indexed1: StorageCT(.indexed1),
    indexed4: StorageCT(.indexed4),
    indexed8: StorageCT(.indexed8),
    rgba128f: StorageCT(.rgba128f),
    rgba64: StorageCT(.rgba64),
    rgba32: StorageCT(.rgba32),
    bgra32: StorageCT(.bgra32),
    argb32: StorageCT(.argb32),
    abgr32: StorageCT(.abgr32),
    rgb48: StorageCT(.rgb48),
    rgb24: StorageCT(.rgb24),
    bgr24: StorageCT(.bgr24),
    argb4444: StorageCT(.argb4444),
    argb1555: StorageCT(.argb1555),
    rgb565: StorageCT(.rgb565),
    rgb555: StorageCT(.rgb555),
    a2r10g10b10: StorageCT(.a2r10g10b10),
    a2b10g10r10: StorageCT(.a2b10g10r10),
    grayscale1: StorageCT(.grayscale1),
    grayscale2: StorageCT(.grayscale2),
    grayscale4: StorageCT(.grayscale4),
    grayscale8: StorageCT(.grayscale8),
    grayscale16: StorageCT(.grayscale16),

    const Self = @This();

    pub fn init(fmt: Format, pixel_count: usize, allocator: Allocator) !Self {
        return switch (fmt) {
            .indexed1 => .{ .indexed1 = try StorageCT(.indexed1).init(pixel_count, allocator) },
            .indexed4 => .{ .indexed4 = try StorageCT(.indexed4).init(pixel_count, allocator) },
            .indexed8 => .{ .indexed8 = try StorageCT(.indexed8).init(pixel_count, allocator) },
            .rgba128f => .{ .rgba128f = try StorageCT(.rgba128f).init(pixel_count, allocator) },
            .rgba64 => .{ .rgba64 = try StorageCT(.rgba64).init(pixel_count, allocator) },
            .rgba32 => .{ .rgba32 = try StorageCT(.rgba32).init(pixel_count, allocator) },
            .bgra32 => .{ .bgra32 = try StorageCT(.bgra32).init(pixel_count, allocator) },
            .argb32 => .{ .argb32 = try StorageCT(.argb32).init(pixel_count, allocator) },
            .abgr32 => .{ .abgr32 = try StorageCT(.abgr32).init(pixel_count, allocator) },
            .rgb48 => .{ .rgb48 = try StorageCT(.rgb48).init(pixel_count, allocator) },
            .rgb24 => .{ .rgb24 = try StorageCT(.rgb24).init(pixel_count, allocator) },
            .bgr24 => .{ .bgr24 = try StorageCT(.bgr24).init(pixel_count, allocator) },
            .argb4444 => .{ .argb4444 = try StorageCT(.argb4444).init(pixel_count, allocator) },
            .argb1555 => .{ .argb1555 = try StorageCT(.argb1555).init(pixel_count, allocator) },
            .rgb565 => .{ .rgb565 = try StorageCT(.rgb565).init(pixel_count, allocator) },
            .rgb555 => .{ .rgb555 = try StorageCT(.rgb555).init(pixel_count, allocator) },
            .a2r10g10b10 => .{ .a2r10g10b10 = try StorageCT(.a2r10g10b10).init(pixel_count, allocator) },
            .a2b10g10r10 => .{ .a2b10g10r10 = try StorageCT(.a2b10g10r10).init(pixel_count, allocator) },
            .grayscale1 => .{ .grayscale1 = try StorageCT(.grayscale1).init(pixel_count, allocator) },
            .grayscale2 => .{ .grayscale2 = try StorageCT(.grayscale2).init(pixel_count, allocator) },
            .grayscale4 => .{ .grayscale4 = try StorageCT(.grayscale4).init(pixel_count, allocator) },
            .grayscale8 => .{ .grayscale8 = try StorageCT(.grayscale8).init(pixel_count, allocator) },
            .grayscale16 => .{ .grayscale16 = try StorageCT(.grayscale16).init(pixel_count, allocator) },
        };
    }

    pub fn initFrom(fmt: Format, from_value: StorageRT, allocator: Allocator) !Self {
        const pixel_count = from_value.len();
        var self = try init(fmt, pixel_count, allocator);

        var i: u32 = 0;
        while (i < pixel_count) : (i += 1) {
            const intermediate = switch (from_value) {
                .indexed1 => |data| color.RGBA128f.from(Format.ColorType(.indexed1), try data.at(i)),
                .indexed4 => |data| color.RGBA128f.from(Format.ColorType(.indexed4), try data.at(i)),
                .indexed8 => |data| color.RGBA128f.from(Format.ColorType(.indexed8), try data.at(i)),
                .rgba128f => |data| color.RGBA128f.from(Format.ColorType(.rgba128f), try data.at(i)),
                .rgba64 => |data| color.RGBA128f.from(Format.ColorType(.rgba64), try data.at(i)),
                .rgba32 => |data| color.RGBA128f.from(Format.ColorType(.rgba32), try data.at(i)),
                .bgra32 => |data| color.RGBA128f.from(Format.ColorType(.bgra32), try data.at(i)),
                .argb32 => |data| color.RGBA128f.from(Format.ColorType(.argb32), try data.at(i)),
                .abgr32 => |data| color.RGBA128f.from(Format.ColorType(.abgr32), try data.at(i)),
                .rgb48 => |data| color.RGBA128f.from(Format.ColorType(.rgb48), try data.at(i)),
                .rgb24 => |data| color.RGBA128f.from(Format.ColorType(.rgb24), try data.at(i)),
                .bgr24 => |data| color.RGBA128f.from(Format.ColorType(.bgr24), try data.at(i)),
                .argb4444 => |data| color.RGBA128f.from(Format.ColorType(.argb4444), try data.at(i)),
                .argb1555 => |data| color.RGBA128f.from(Format.ColorType(.argb1555), try data.at(i)),
                .rgb565 => |data| color.RGBA128f.from(Format.ColorType(.rgb565), try data.at(i)),
                .rgb555 => |data| color.RGBA128f.from(Format.ColorType(.rgb555), try data.at(i)),
                .a2r10g10b10 => |data| color.RGBA128f.from(Format.ColorType(.a2r10g10b10), try data.at(i)),
                .a2b10g10r10 => |data| color.RGBA128f.from(Format.ColorType(.a2b10g10r10), try data.at(i)),
                .grayscale1 => |data| color.RGBA128f.from(Format.ColorType(.grayscale1), try data.at(i)),
                .grayscale2 => |data| color.RGBA128f.from(Format.ColorType(.grayscale2), try data.at(i)),
                .grayscale4 => |data| color.RGBA128f.from(Format.ColorType(.grayscale4), try data.at(i)),
                .grayscale8 => |data| color.RGBA128f.from(Format.ColorType(.grayscale8), try data.at(i)),
                .grayscale16 => |data| color.RGBA128f.from(Format.ColorType(.grayscale16), try data.at(i)),
            };

            switch (self) {
                .indexed1 => |*data| try data.set(i, intermediate),
                .indexed4 => |*data| try data.set(i, intermediate),
                .indexed8 => |*data| try data.set(i, intermediate),
                .rgba128f => |*data| try data.set(i, Format.ColorType(.rgba128f).from(color.RGBA128f, intermediate)),
                .rgba64 => |*data| try data.set(i, Format.ColorType(.rgba64).from(color.RGBA128f, intermediate)),
                .rgba32 => |*data| try data.set(i, Format.ColorType(.rgba32).from(color.RGBA128f, intermediate)),
                .bgra32 => |*data| try data.set(i, Format.ColorType(.bgra32).from(color.RGBA128f, intermediate)),
                .argb32 => |*data| try data.set(i, Format.ColorType(.argb32).from(color.RGBA128f, intermediate)),
                .abgr32 => |*data| try data.set(i, Format.ColorType(.abgr32).from(color.RGBA128f, intermediate)),
                .rgb48 => |*data| try data.set(i, Format.ColorType(.rgb48).from(color.RGBA128f, intermediate)),
                .rgb24 => |*data| try data.set(i, Format.ColorType(.rgb24).from(color.RGBA128f, intermediate)),
                .bgr24 => |*data| try data.set(i, Format.ColorType(.bgr24).from(color.RGBA128f, intermediate)),
                .argb4444 => |*data| try data.set(i, Format.ColorType(.argb4444).from(color.RGBA128f, intermediate)),
                .argb1555 => |*data| try data.set(i, Format.ColorType(.argb1555).from(color.RGBA128f, intermediate)),
                .rgb565 => |*data| try data.set(i, Format.ColorType(.rgb565).from(color.RGBA128f, intermediate)),
                .rgb555 => |*data| try data.set(i, Format.ColorType(.rgb555).from(color.RGBA128f, intermediate)),
                .a2r10g10b10 => |*data| try data.set(i, Format.ColorType(.a2r10g10b10).from(color.RGBA128f, intermediate)),
                .a2b10g10r10 => |*data| try data.set(i, Format.ColorType(.a2b10g10r10).from(color.RGBA128f, intermediate)),
                .grayscale1 => |*data| try data.set(i, Format.ColorType(.grayscale1).from(color.RGBA128f, intermediate)),
                .grayscale2 => |*data| try data.set(i, Format.ColorType(.grayscale2).from(color.RGBA128f, intermediate)),
                .grayscale4 => |*data| try data.set(i, Format.ColorType(.grayscale4).from(color.RGBA128f, intermediate)),
                .grayscale8 => |*data| try data.set(i, Format.ColorType(.grayscale8).from(color.RGBA128f, intermediate)),
                .grayscale16 => |*data| try data.set(i, Format.ColorType(.grayscale16).from(color.RGBA128f, intermediate)),
            }
        }

        return self;
    }

    pub fn initFromCTWrapped(comptime fmt: Format, from_value: StorageCT(fmt)) Self {
        // TODO: IMPROVE: this function NEVER creates a copy - a 'owning' alternative may be clever
        return switch (fmt) {
            .indexed1 => .{ .indexed1 = from_value },
            .indexed4 => .{ .indexed4 = from_value },
            .indexed8 => .{ .indexed8 = from_value },
            .rgba128f => .{ .rgba128f = from_value },
            .rgba64 => .{ .rgba64 = from_value },
            .rgba32 => .{ .rgba32 = from_value },
            .bgra32 => .{ .bgra32 = from_value },
            .argb32 => .{ .argb32 = from_value },
            .abgr32 => .{ .abgr32 = from_value },
            .rgb48 => .{ .rgb48 = from_value },
            .rgb24 => .{ .rgb24 = from_value },
            .bgr24 => .{ .bgr24 = from_value },
            .argb4444 => .{ .argb4444 = from_value },
            .argb1555 => .{ .argb1555 = from_value },
            .rgb565 => .{ .rgb565 = from_value },
            .rgb555 => .{ .rgb555 = from_value },
            .a2r10g10b10 => .{ .a2r10g10b10 = from_value },
            .a2b10g10r10 => .{ .a2b10g10r10 = from_value },
            .grayscale1 => .{ .grayscale1 = from_value },
            .grayscale2 => .{ .grayscale2 = from_value },
            .grayscale4 => .{ .grayscale4 = from_value },
            .grayscale8 => .{ .grayscale8 = from_value },
            .grayscale16 => .{ .grayscale16 = from_value },
        };
    }

    pub fn deinit(self: Self, allocator: Allocator) void {
        switch (self) {
            .indexed1 => |data| data.deinit(allocator),
            .indexed4 => |data| data.deinit(allocator),
            .indexed8 => |data| data.deinit(allocator),
            .rgba128f => |data| data.deinit(allocator),
            .rgba64 => |data| data.deinit(allocator),
            .rgba32 => |data| data.deinit(allocator),
            .bgra32 => |data| data.deinit(allocator),
            .argb32 => |data| data.deinit(allocator),
            .abgr32 => |data| data.deinit(allocator),
            .rgb48 => |data| data.deinit(allocator),
            .rgb24 => |data| data.deinit(allocator),
            .bgr24 => |data| data.deinit(allocator),
            .argb4444 => |data| data.deinit(allocator),
            .argb1555 => |data| data.deinit(allocator),
            .rgb565 => |data| data.deinit(allocator),
            .rgb555 => |data| data.deinit(allocator),
            .a2r10g10b10 => |data| data.deinit(allocator),
            .a2b10g10r10 => |data| data.deinit(allocator),
            .grayscale1 => |data| data.deinit(allocator),
            .grayscale2 => |data| data.deinit(allocator),
            .grayscale4 => |data| data.deinit(allocator),
            .grayscale8 => |data| data.deinit(allocator),
            .grayscale16 => |data| data.deinit(allocator),
        }
    }

    pub fn format(self: Self) Format {
        return switch (self) {
            .indexed1 => .indexed1,
            .indexed4 => .indexed4,
            .indexed8 => .indexed8,
            .rgba128f => .rgba128f,
            .rgba64 => .rgba64,
            .rgba32 => .rgba32,
            .bgra32 => .bgra32,
            .argb32 => .argb32,
            .abgr32 => .abgr32,
            .rgb48 => .rgb48,
            .rgb24 => .rgb24,
            .bgr24 => .bgr24,
            .argb4444 => .argb4444,
            .argb1555 => .argb1555,
            .rgb565 => .rgb565,
            .rgb555 => .rgb555,
            .a2r10g10b10 => .a2r10g10b10,
            .a2b10g10r10 => .a2b10g10r10,
            .grayscale1 => .grayscale1,
            .grayscale2 => .grayscale2,
            .grayscale4 => .grayscale4,
            .grayscale8 => .grayscale8,
            .grayscale16 => .grayscale16,
        };
    }

    pub fn len(self: Self) usize {
        return switch (self) {
            .indexed1 => |data| data.len(),
            .indexed4 => |data| data.len(),
            .indexed8 => |data| data.len(),
            .rgba128f => |data| data.len(),
            .rgba64 => |data| data.len(),
            .rgba32 => |data| data.len(),
            .bgra32 => |data| data.len(),
            .argb32 => |data| data.len(),
            .abgr32 => |data| data.len(),
            .rgb48 => |data| data.len(),
            .rgb24 => |data| data.len(),
            .bgr24 => |data| data.len(),
            .argb4444 => |data| data.len(),
            .argb1555 => |data| data.len(),
            .rgb565 => |data| data.len(),
            .rgb555 => |data| data.len(),
            .a2r10g10b10 => |data| data.len(),
            .a2b10g10r10 => |data| data.len(),
            .grayscale1 => |data| data.len(),
            .grayscale2 => |data| data.len(),
            .grayscale4 => |data| data.len(),
            .grayscale8 => |data| data.len(),
            .grayscale16 => |data| data.len(),
        };
    }

    pub fn at(self: Self, comptime fmt: Format, pos: usize) !Format.ColorType(fmt) {
        return switch (self) {
            .indexed1 => |data| try Format.ColorType(fmt).from(Format.ColorType(.indexed1), data.at(pos)),
            .indexed4 => |data| try Format.ColorType(fmt).from(Format.ColorType(.indexed4), data.at(pos)),
            .indexed8 => |data| try Format.ColorType(fmt).from(Format.ColorType(.indexed8), data.at(pos)),
            .rgba128f => |data| Format.ColorType(fmt).from(Format.ColorType(.rgba128f), data[pos]),
            .rgba64 => |data| Format.ColorType(fmt).from(Format.ColorType(.rgba64), data[pos]),
            .rgba32 => |data| Format.ColorType(fmt).from(Format.ColorType(.rgba32), data[pos]),
            .bgra32 => |data| Format.ColorType(fmt).from(Format.ColorType(.bgra32), data[pos]),
            .argb32 => |data| Format.ColorType(fmt).from(Format.ColorType(.argb32), data[pos]),
            .abgr32 => |data| Format.ColorType(fmt).from(Format.ColorType(.abgr32), data[pos]),
            .rgb48 => |data| Format.ColorType(fmt).from(Format.ColorType(.rgb48), data[pos]),
            .rgb24 => |data| Format.ColorType(fmt).from(Format.ColorType(.rgb24), data[pos]),
            .bgr24 => |data| Format.ColorType(fmt).from(Format.ColorType(.bgr24), data[pos]),
            .argb4444 => |data| Format.ColorType(fmt).from(Format.ColorType(.argb4444), data[pos]),
            .argb1555 => |data| Format.ColorType(fmt).from(Format.ColorType(.argb1555), data[pos]),
            .rgb565 => |data| Format.ColorType(fmt).from(Format.ColorType(.rgb565), data[pos]),
            .rgb555 => |data| Format.ColorType(fmt).from(Format.ColorType(.rgb555), data[pos]),
            .a2r10g10b10 => |data| Format.ColorType(fmt).from(Format.ColorType(.a2r10g10b10), data[pos]),
            .a2b10g10r10 => |data| Format.ColorType(fmt).from(Format.ColorType(.a2b10g10r10), data[pos]),
            .grayscale1 => |data| Format.ColorType(fmt).from(Format.ColorType(.grayscale1), data[pos]),
            .grayscale2 => |data| Format.ColorType(fmt).from(Format.ColorType(.grayscale2), data[pos]),
            .grayscale4 => |data| Format.ColorType(fmt).from(Format.ColorType(.grayscale4), data[pos]),
            .grayscale8 => |data| Format.ColorType(fmt).from(Format.ColorType(.grayscale8), data[pos]),
            .grayscale16 => |data| Format.ColorType(fmt).from(Format.ColorType(.grayscale16), data[pos]),
        };
    }

    pub fn set(self: *Self, comptime Color: type, pos: usize, c: Color) !void {
        return switch (self) {
            .indexed1 => |data| try data.set(pos, Format.ColorType(.indexed1).from(Color, c)),
            .indexed4 => |data| try data.set(pos, Format.ColorType(.indexed4).from(Color, c)),
            .indexed8 => |data| try data.set(pos, Format.ColorType(.indexed).from(Color, c)),
            .rgba128f => |data| data[pos] = Format.ColorType(.rgba128f).from(Color, c),
            .rgba64 => |data| data[pos] = Format.ColorType(.rgba64).from(Color, c),
            .rgba32 => |data| data[pos] = Format.ColorType(.rgba32).from(Color, c),
            .bgra32 => |data| data[pos] = Format.ColorType(.bgra32).from(Color, c),
            .argb32 => |data| data[pos] = Format.ColorType(.argb32).from(Color, c),
            .abgr32 => |data| data[pos] = Format.ColorType(.abgr32).from(Color, c),
            .rgb48 => |data| data[pos] = Format.ColorType(.rgb48).from(Color, c),
            .rgb24 => |data| data[pos] = Format.ColorType(.rgb24).from(Color, c),
            .bgr24 => |data| data[pos] = Format.ColorType(.bgr24).from(Color, c),
            .argb4444 => |data| data[pos] = Format.ColorType(.argb4444).from(Color, c),
            .argb1555 => |data| data[pos] = Format.ColorType(.argb1555).from(Color, c),
            .rgb565 => |data| data[pos] = Format.ColorType(.rgb565).from(Color, c),
            .rgb555 => |data| data[pos] = Format.ColorType(.rgb555).from(Color, c),
            .a2r10g10b10 => |data| data[pos] = Format.ColorType(.a2r10g10b10).from(Color, c),
            .a2b10g10r10 => |data| data[pos] = Format.ColorType(.a2b10g10r10).from(Color, c),
            .grayscale1 => |data| data[pos] = Format.ColorType(.grayscale1).from(Color, c),
            .grayscale2 => |data| data[pos] = Format.ColorType(.grayscale2).from(Color, c),
            .grayscale4 => |data| data[pos] = Format.ColorType(.grayscale4).from(Color, c),
            .grayscale8 => |data| data[pos] = Format.ColorType(.grayscale8).from(Color, c),
            .grayscale16 => |data| data[pos] = Format.ColorType(.grayscale16).from(Color, c),
        };
    }

    pub fn bytes(self: Self) []u8 {
        return switch (self) {
            .indexed1 => |data| data.bytes(),
            .indexed4 => |data| data.bytes(),
            .indexed8 => |data| data.bytes(),
            .rgba128f => |data| data.bytes(),
            .rgba64 => |data| data.bytes(),
            .rgba32 => |data| data.bytes(),
            .bgra32 => |data| data.bytes(),
            .argb32 => |data| data.bytes(),
            .abgr32 => |data| data.bytes(),
            .rgb48 => |data| data.bytes(),
            .rgb24 => |data| data.bytes(),
            .bgr24 => |data| data.bytes(),
            .argb4444 => |data| data.bytes(),
            .argb1555 => |data| data.bytes(),
            .rgb565 => |data| data.bytes(),
            .rgb555 => |data| data.bytes(),
            .a2r10g10b10 => |data| data.bytes(),
            .a2b10g10r10 => |data| data.bytes(),
            .grayscale1 => |data| data.bytes(),
            .grayscale2 => |data| data.bytes(),
            .grayscale4 => |data| data.bytes(),
            .grayscale8 => |data| data.bytes(),
            .grayscale16 => |data| data.bytes(),
        };
    }
};
