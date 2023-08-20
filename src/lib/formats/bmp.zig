const std = @import("std");
const Allocator = std.mem.Allocator;
const StreamSource = std.io.StreamSource;
const Endian = std.builtin.Endian;

const Image = @import("../image.zig");

pub const Error = error{ BMPDIBHeaderNotSupported, BMPCompressionFormatNotSupported, BMPBitCountNotSupported, BMPCorrupted };

const FileHeader = extern struct {
    signature: [2]u8,
    file_size: u32, // unused
    reserved: u32, // unused; these are actually two u16 but since they are not used it does not matter
    bitmap_offset: u32, // unused
};

const GamutMappingIntent = enum(u32) {
    LCS_GM_BUSINESS = 1,
    LCS_GM_GRAPHICS = 2,
    LCS_GM_IMAGES = 4,
    LCS_GM_ABS_COLORIMETRIC = 8,
};

// fixed point types: 'n': integer bits, 'f' fraction bits
const Placeholder_nnffffffffffffffffffffffffffffff = u32;
const Placeholder_00000000nnnnnnnnffffffff00000000 = u32;

const CIEXYZObject = packed struct {
    x: Placeholder_nnffffffffffffffffffffffffffffff,
    y: Placeholder_nnffffffffffffffffffffffffffffff,
    z: Placeholder_nnffffffffffffffffffffffffffffff,
};

const CIEXYZTripleObject = packed struct {
    red: CIEXYZObject,
    green: CIEXYZObject,
    blue: CIEXYZObject,
};

const LogicalColorSpace = enum(u32) {
    LCS_CALIBRATED_RGB = 0,
    LCS_sRGB = 0x73524742,
    LCS_WINDOWS_COLOR_SPACE = 0x57696E20,
    LCS_PROFILE_LINKED = 0x4C494E4B, // LogicalColorSpaceV5
    LCS_PROFILE_EMBEDDED = 0x4D424544, // LogicalColorSpaceV5
};

const Compression = enum(u32) {
    BI_RGB = 0x0000,
    BI_RLE8 = 0x0001,
    BI_RLE4 = 0x0002,
    BI_BITFIELDS = 0x0003,
    BI_JPEG = 0x0004,
    BI_PNG = 0x0005,
    BI_ALPHABITFIELDS = 0x0006, // not supported
    BI_CMYK = 0x000B,
    BI_CMYKRLE8 = 0x000C,
    BI_CMYKRLE4 = 0x000D,

    const Self = @This();

    fn is_compressed(self: Self) bool {
        return switch (self) {
            .BI_RGB => false,
            .BI_BITFIELDS => false,
            .BI_ALPHABITFIELDS => false,
            .BI_CMYK => false,
            else => true,
        };
    }
};

const BitCount = enum(u16) {
    BI_BITCOUNT_0 = 0x0000,
    BI_BITCOUNT_1 = 0x0001,
    BI_BITCOUNT_2 = 0x0004,
    BI_BITCOUNT_3 = 0x0008,
    BI_BITCOUNT_4 = 0x0010,
    BI_BITCOUNT_5 = 0x0018,
    BI_BITCOUNT_6 = 0x0020,
};

const HeaderSize = enum(u32) {
    OS21XBITMAPHEADER = 12, // not supported
    OS22XBITMAPHEADER = 64, // not supported
    OS22XBITMAPHEADER_SMALL = 16, // not supported
    BitmapInfoHeader = 40,
    BitmapV2Header = 52, // not supported
    BitmapV3Header = 56,
    BitmapV4Header = 108,
    BitmapV5Header = 124,

    const Self = @This();

    fn has_header(self: Self, header_size: HeaderSize) bool {
        if (header_size == .OS21XBITMAPHEADER or header_size == .OS22XBITMAPHEADER or header_size == .OS22XBITMAPHEADER_SMALL) {
            return false;
        }

        return @intFromEnum(header_size) <= @intFromEnum(self);
    }
};

const BitmapInfoHeader = packed struct {
    // HeaderSize
    width: i32,
    height: i32,
    planes: u16, // unused
    bit_count: BitCount,
    compression: Compression,
    image_size: u32, // unused
    xpels_per_meter: i32, // unused
    ypels_per_meter: i32, // unused
    color_used: u32, // unused
    color_important: u32, // unused

    const Self = @This();

    fn check(self: *const Self, has_color_table: bool) !void {
        // width
        if (self.width <= 0) {
            return Error.BMPCorrupted;
        }
        // CONSTRAINT: This field SHOULD specify the width of the decompressed image file, if the Compression value specifies JPEG or PNG format.
        // height
        if (self.height == 0) {
            return Error.BMPCorrupted;
        }
        // planes
        if (self.planes != 1) {
            return Error.BMPCorrupted;
        }
        // bit_count
        if (self.bit_count == .BI_BITCOUNT_0) {
            return Error.BMPBitCountNotSupported; // IMPL: support bit_count option
        }
        if (self.bit_count == .BI_BITCOUNT_0 and !(self.compression == .BI_JPEG or self.compression == .BI_PNG)) {
            return Error.BMPCorrupted;
        }
        if ((self.bit_count == .BI_BITCOUNT_1 or self.bit_count == .BI_BITCOUNT_2 or self.bit_count == .BI_BITCOUNT_3) and !has_color_table) {
            return Error.BMPCorrupted;
        }
        if ((self.bit_count == .BI_BITCOUNT_0 or self.bit_count == .BI_BITCOUNT_4 or self.bit_count == .BI_BITCOUNT_5 or self.bit_count == .BI_BITCOUNT_6) and has_color_table) {
            return Error.BMPCorrupted; // implies BI_BITFIELDS, BI_JPEG, BI_RGB
        }
        // compression
        if (self.compression == .BI_ALPHABITFIELDS) {
            return Error.BMPCompressionFormatNotSupported;
        }
        if (self.compression == .BI_CMYK or self.compression == .BI_CMYKRLE8 or self.compression == .BI_CMYKRLE4) {
            return Error.BMPCompressionFormatNotSupported;
        }
        if (self.compression == .BI_RLE8 or self.compression == .BI_RLE4 or self.compression == .BI_JPEG or self.compression == .BI_PNG) {
            return Error.BMPCompressionFormatNotSupported; // IMPL: support compression formats
        }
        if (self.compression == .BI_RLE8 and self.bit_count != .BI_BITCOUNT_3) {
            return Error.BMPCorrupted;
        }
        if (self.compression == .BI_RLE4 and self.bit_count != .BI_BITCOUNT_2) {
            return Error.BMPCorrupted;
        }
        if (self.compression == .BI_BITFIELDS and (self.bit_count != .BI_BITCOUNT_4 and self.bit_count != .BI_BITCOUNT_6)) {
            return Error.BMPCorrupted;
        }
        if ((self.compression == .BI_JPEG or self.compression == .BI_PNG) and self.bit_count != .BI_BITCOUNT_0) {
            return Error.BMPCorrupted;
        }
        if (self.compression.is_compressed() and self.height < 0) {
            return Error.BMPCorrupted;
        }
        // image_size
        //if (self.compression == .BI_RGB and self.image_size != 0) { // some implementations seem ignore this constraint
        //    return Error.BMPCorrupted;
        //}
        // CONSTRAINT: If the Compression value is BI_JPEG or BI_PNG, this value MUST specify the size of the JPEG or PNG image buffer, respectively.
    }
};

// not documented in MS-WMF
const BitmapV2Header = packed struct {
    red_mask: u32,
    green_mask: u32,
    blue_mask: u32,

    const Self = @This();

    fn check(self: *const Self) !void {
        if (self.red_mask == 0x00) {
            return Error.BMPCorrupted;
        }
        if (self.green_mask == 0x00) {
            return Error.BMPCorrupted;
        }
        if (self.blue_mask == 0x00) {
            return Error.BMPCorrupted;
        }
        //  CONSTRAINT: BI_BITCOUNT_4: When the Compression field is set to BI_BITFIELDS, bits set in each DWORD mask MUST be contiguous and SHOULD NOT overlap the bits of another mask
        //  CONSTRAINT: BI_BITCOUNT_6: When the Compression field is set to BI_BITFIELDS, bits set in each DWORD mask MUST be contiguous and MUST NOT overlap the bits of another mask.
    }
};

// not documented in MS-WMF
const BitmapV3Header = packed struct {
    alpha_mask: u32,

    const Self = @This();

    fn check(self: *const Self) !void {
        _ = self;
        //  CONSTRAINT: BI_BITCOUNT_4: When the Compression field is set to BI_BITFIELDS, bits set in each DWORD mask MUST be contiguous and SHOULD NOT overlap the bits of another mask
        //  CONSTRAINT: BI_BITCOUNT_6: When the Compression field is set to BI_BITFIELDS, bits set in each DWORD mask MUST be contiguous and MUST NOT overlap the bits of another mask.
    }
};

const BitmapV4Header = packed struct {
    color_space_type: LogicalColorSpace, // unused
    endpoints: CIEXYZTripleObject, // unused
    gamma_red: Placeholder_00000000nnnnnnnnffffffff00000000, // unused
    gamma_green: Placeholder_00000000nnnnnnnnffffffff00000000, // unused
    gamma_blue: Placeholder_00000000nnnnnnnnffffffff00000000, // unused

    const Self = @This();

    fn check(self: *const Self) !void {
        _ = self;
    }
};

const BitmapV5Header = packed struct {
    intent: GamutMappingIntent, // unused
    profile_data: u32, // unused
    profile_size: u32, // unused
    reserved: u32, // unused

    const Self = @This();

    fn check(self: *const Self) !void {
        _ = self;
    }
};

const file_signature = "BM"; // "BA", "CI", "CP", "IC", "PT" not supported

pub fn is_format(stream: *StreamSource) !bool {
    return stream.reader().isBytes(file_signature);
}

pub fn init(allocator: Allocator, stream: *StreamSource) !Image {
    var reader = stream.reader();
    // DEBUG: std.debug.print("\n", .{});

    // file header
    // TODO: ZIG: const file_header = try reader.readStruct(FileHeader); // TODO: ZIG: Endian.Little ?
    const file_header = try readStructFileHeader(reader);
    // DEBUG: std.debug.print("{any}\n", .{file_header});
    // CONSTRAINT: file_size correctness - some implementations seem to ignore this constraint

    // dib header info
    const header_size = try reader.readEnum(HeaderSize, Endian.Little);
    // DEBUG: std.debug.print("header-size: {any}\n", .{header_size});
    if (header_size == .OS21XBITMAPHEADER or header_size == .OS22XBITMAPHEADER or header_size == .OS22XBITMAPHEADER_SMALL) {
        return Error.BMPDIBHeaderNotSupported;
    }
    if (header_size == .BitmapV2Header) {
        return Error.BMPDIBHeaderNotSupported;
    }

    // TODO: ZIG: const info_header = try reader.readStruct(BitmapInfoHeader); // TODO: ZIG: Endian.Little ?
    const info_header = try readStructBitmapInfoHeader(reader);
    // DEBUG: std.debug.print("{any}\n", .{info_header});
    const has_color_table = file_header.bitmap_offset > 14 + @intFromEnum(header_size);
    // DEBUG: std.debug.print("has_color_table: {any}\n", .{has_color_table});
    try info_header.check(has_color_table);

    const v2_header = if (header_size.has_header(.BitmapV2Header))
        // TODO: ZIG: try reader.readStruct(BitmapV2Header) // TODO: ZIG: Endian.Little ?
        try readStructBitmapV2Header(reader)
    else
        null;
    // DEBUG: std.debug.print("{any}\n", .{v2_header});
    if (v2_header) |*header| {
        try header.check();
    }

    const v3_header = if (header_size.has_header(.BitmapV3Header))
        // TODO: ZIG: try reader.readStruct(BitmapV3Header) // TODO: ZIG: Endian.Little ?
        try readStructBitmapV3Header(reader)
    else
        null;
    // DEBUG: std.debug.print("{any}\n", .{v3_header});
    if (v3_header) |*header| {
        try header.check();
    }

    const v4_header = if (header_size.has_header(.BitmapV4Header))
        // TODO: ZIG: try reader.readStruct(BitmapV4Header) // TODO: ZIG: Endian.Little ?
        try readStructBitmapV4Header(reader)
    else
        null;
    // DEBUG: std.debug.print("{any}\n", .{v4_header});
    if (v4_header) |*header| {
        try header.check();
    }

    const v5_header = if (header_size.has_header(.BitmapV5Header))
        // TODO: ZIG: try reader.readStruct(BitmapV5Header) // TODO: ZIG: Endian.Little ?
        try readStructBitmapV5Header(reader)
    else
        null;
    // DEBUG: std.debug.print("{any}\n", .{v5_header});
    if (v5_header) |*header| {
        try header.check();
    }

    //
    const is_indexed = info_header.bit_count == .BI_BITCOUNT_1 or info_header.bit_count == .BI_BITCOUNT_2 or info_header.bit_count == .BI_BITCOUNT_3;

    // color masks
    //const MASK = enum(u32) { R, G, B, A };
    const MASK_COUNT = 4;
    const R = 0;
    const G = 1;
    const B = 2;
    const A = 3;

    var masks: [MASK_COUNT]u32 = undefined;
    switch (info_header.compression) {
        .BI_BITFIELDS => {
            if (v2_header) |header| {
                masks[R] = header.red_mask;
                masks[G] = header.green_mask;
                masks[B] = header.blue_mask;
            } else {
                return Error.BMPCorrupted;
            }
            if (v3_header) |header| {
                masks[A] = header.alpha_mask;
            } else {
                return Error.BMPCorrupted; // this may not be entirely true (BI_ALPHABITFIELDS)
            }

            if (info_header.bit_count == .BI_BITCOUNT_4) { // this is unfortunatly just a conjecture...
                var m: u32 = 0;
                while (m < MASK_COUNT) : (m += 1) {
                    masks[m] = ((masks[m] >> 8) & 0xFF00) | masks[m] >> 24;
                }
            }
        },
        .BI_RGB => {
            if (info_header.bit_count == .BI_BITCOUNT_4) {
                // RGB555LE
                masks[R] = 0b0111110000000000;
                masks[G] = 0b0000001111100000;
                masks[B] = 0b0000000000011111;
                masks[A] = 0b0000000000000000;
            } else {
                // used only with .BI_BITCOUNT_5 and .BI_BITCOUNT_6
                masks[R] = 0x0000FF00;
                masks[G] = 0x00FF0000;
                masks[B] = 0xFF000000;
                masks[A] = 0x00000000;
            }
        },
        else => unreachable,
    }

    var bit_counts = [MASK_COUNT]u5{ 0, 0, 0, 0 };
    var bit_shifts = [MASK_COUNT]u5{ 0, 0, 0, 0 };

    var was_set = [MASK_COUNT]bool{ false, false, false, false };
    if (!is_indexed) {
        var m: u32 = 0;
        while (m < MASK_COUNT) : (m += 1) {
            var b: u32 = 0;
            while (b < @bitSizeOf(u32)) : (b += 1) {
                const is_set = masks[m] & (@as(u32, 1) << std.math.cast(u5, b).?) != 0;
                if (is_set) {
                    bit_counts[m] += 1;
                    was_set[m] = true;
                } else if (!was_set[m]) {
                    bit_shifts[m] +%= 1;
                }
            }
        }
    }

    // DEBUG: var m: u32 = 0;
    // DEBUG: while (m < MASK_COUNT) : (m += 1) {
    // DEBUG:     std.debug.print("mask: {x}; bit_count: {any}; bit_shift: {any}\n", .{ masks[m], bit_counts[m], bit_shifts[m] });
    // DEBUG: }

    // colors
    var color_table: [256]Image.RGBA32 = undefined;
    if (info_header.compression == .BI_RGB) {
        const color_count: usize = switch (info_header.bit_count) {
            .BI_BITCOUNT_1 => 2,
            .BI_BITCOUNT_2 => 16,
            .BI_BITCOUNT_3 => 256,
            else => 0,
        };

        var i: u32 = 0;
        while (i < color_count) : (i += 1) {
            color_table[i].b = try reader.readByte();
            color_table[i].g = try reader.readByte();
            color_table[i].r = try reader.readByte();
            color_table[i].a = 0xFF;
            _ = try reader.readByte();

            // DEBUG: std.debug.print("color-table[{any}]: {any}\n", .{ i, color_table[i] });
        }
    }

    // bitmap_buffer
    try stream.seekTo(file_header.bitmap_offset);

    const flip_y = info_header.height < 0;
    const w = @as(u32, @bitCast(info_header.width));
    const h = std.math.absCast(info_header.height);
    const pixel_count = w * h;
    var pixels = try allocator.alloc(Image.RGBA32, pixel_count);
    errdefer allocator.free(pixels);

    const indices_per_byte: u32 = switch (info_header.bit_count) {
        .BI_BITCOUNT_1 => 8,
        .BI_BITCOUNT_2 => 2,
        .BI_BITCOUNT_3 => 1,
        else => 0,
    };
    const index_shift: u32 = switch (info_header.bit_count) {
        .BI_BITCOUNT_1 => 1,
        .BI_BITCOUNT_2 => 4,
        .BI_BITCOUNT_3 => 8,
        else => 0,
    };
    const index_mask: u8 = switch (info_header.bit_count) {
        .BI_BITCOUNT_1 => 0b00000001,
        .BI_BITCOUNT_2 => 0b00001111,
        .BI_BITCOUNT_3 => 0b11111111,
        else => 0,
    };

    var byte_count: u32 = 0;
    var yp: u32 = 0;
    while (yp < h) : (yp += 1) {
        var xp: u32 = 0;
        xloop: while (xp < w) : (xp += 1) {
            const x = xp;
            const y = if (flip_y) yp else h - yp - 1;
            const idx = x + y * w;

            if (is_indexed) {
                // could be "improved" by separating .BI_BITCOUNT_1, .BI_BITCOUNT_shift
                const buffer = try reader.readByte();
                byte_count += 1;

                var i: u32 = 0;
                while (i < indices_per_byte) : (i += 1) {
                    if (xp >= w) {
                        xp += i;
                        continue :xloop;
                    }

                    const offset = std.math.cast(u3, 8 - index_shift * (i + 1)).?;
                    const index = (buffer >> offset) & index_mask;
                    pixels[idx + i] = color_table[index];

                    // DEBUG: std.debug.print("({any},{any}) : [{any}] {any}\n", .{ xp + i, yp, index, pixels[idx + i] });
                }

                xp += indices_per_byte - 1;
            } else {
                var buffer: u32 = undefined;
                switch (info_header.bit_count) {
                    .BI_BITCOUNT_4 => {
                        buffer = try reader.readInt(u16, Endian.Little); // this is unfortunatly just a conjecture...
                        byte_count += 2;
                    },
                    .BI_BITCOUNT_5 => {
                        buffer = try reader.readInt(u24, Endian.Big);
                        buffer = buffer << 8;
                        byte_count += 3;
                    },
                    .BI_BITCOUNT_6 => {
                        buffer = try reader.readInt(u32, Endian.Big);
                        byte_count += 4;
                    },
                    else => unreachable,
                }

                pixels[idx].r = extract(buffer, masks[R], bit_counts[R], bit_shifts[R]);
                pixels[idx].g = extract(buffer, masks[G], bit_counts[G], bit_shifts[G]);
                pixels[idx].b = extract(buffer, masks[B], bit_counts[B], bit_shifts[B]);
                if (masks[A] != 0) {
                    pixels[idx].a = extract(buffer, masks[A], bit_counts[A], bit_shifts[A]);
                } else {
                    pixels[idx].a = 0xFF;
                }
            }
        }

        // padding
        while (byte_count % 4 != 0) : (byte_count += 1) {
            _ = try reader.readByte();
        }
    }

    return Image{ .allocator = allocator, .width = w, .height = h, .pixels = pixels };
}

fn extract(buffer: u32, mask: u32, bit_count: u5, bit_shift: u5) u8 {
    const RST_BIT_COUNT = @bitSizeOf(u8);

    const tmp = (buffer & mask) >> bit_shift;
    const rst = if (bit_count < RST_BIT_COUNT) blk: {
        break :blk switch (bit_count) {
            1 => @as(u32, if (tmp == 0) 0x00 else 0xFF),
            2 => tmp << 6 | tmp << 4 | tmp << 2 | tmp,
            3 => tmp << 5 | tmp << 2 | tmp >> 1,
            else => blk_inner: {
                const bit_diff = RST_BIT_COUNT - bit_count;
                break :blk_inner (tmp << bit_diff) | (tmp >> (bit_count - bit_diff));
            },
        };
    } else if (bit_count > RST_BIT_COUNT) blk: {
        const bit_diff = bit_count - RST_BIT_COUNT;
        break :blk tmp >> bit_diff;
    } else tmp;

    // DEBUG: std.debug.print("extract: {x}, {x}, {any}, {any}, {any}, {any}\n", .{ buffer, mask, bit_count, bit_shift, tmp, rst });

    return std.math.cast(u8, rst).?;
}

// ########################################################################################
// TODO: ZIG: reader.readStruct seems to be broken currently:
// ########################################################################################

test "packed struct sizeof" {
    return error.SkipZigTest;
    //std.debug.print("\n", .{});
    //inline for (@typeInfo(FileHeader).Struct.fields) |field| {
    //    std.debug.print("@offsetOf(FileHeader.{s})={any}\n", .{ field.name, @offsetOf(FileHeader, field.name) });
    //}
    //std.debug.print("@sizeOf(FileHeader)={any}\n", .{@sizeOf(FileHeader)});
    //try std.testing.expect(@sizeOf(FileHeader) == 14);
}

fn readStructFileHeader(reader: anytype) !FileHeader {
    var signature: [2]u8 = undefined;
    _ = try reader.read(&signature);

    return FileHeader{
        .signature = signature,
        .file_size = try reader.readInt(u32, Endian.Little),
        .reserved = try reader.readInt(u32, Endian.Little),
        .bitmap_offset = try reader.readInt(u32, Endian.Little),
    };
}

fn readStructBitmapInfoHeader(reader: anytype) !BitmapInfoHeader {
    return BitmapInfoHeader{
        .width = try reader.readInt(i32, Endian.Little),
        .height = try reader.readInt(i32, Endian.Little),
        .planes = try reader.readInt(u16, Endian.Little),
        .bit_count = try reader.readEnum(BitCount, Endian.Little),
        .compression = try reader.readEnum(Compression, Endian.Little),
        .image_size = try reader.readInt(u32, Endian.Little),
        .xpels_per_meter = try reader.readInt(i32, Endian.Little),
        .ypels_per_meter = try reader.readInt(i32, Endian.Little),
        .color_used = try reader.readInt(u32, Endian.Little),
        .color_important = try reader.readInt(u32, Endian.Little),
    };
}

fn readStructBitmapV2Header(reader: anytype) !BitmapV2Header {
    return BitmapV2Header{
        .red_mask = try reader.readInt(u32, Endian.Big),
        .green_mask = try reader.readInt(u32, Endian.Big),
        .blue_mask = try reader.readInt(u32, Endian.Big),
    };
}

fn readStructBitmapV3Header(reader: anytype) !BitmapV3Header {
    return BitmapV3Header{
        .alpha_mask = try reader.readInt(u32, Endian.Big),
    };
}

fn readStructBitmapV4Header(reader: anytype) !BitmapV4Header {
    return BitmapV4Header{
        .color_space_type = try reader.readEnum(LogicalColorSpace, Endian.Little),
        .endpoints = CIEXYZTripleObject{
            .red = CIEXYZObject{
                .x = try reader.readInt(u32, Endian.Little),
                .y = try reader.readInt(u32, Endian.Little),
                .z = try reader.readInt(u32, Endian.Little),
            },
            .green = CIEXYZObject{
                .x = try reader.readInt(u32, Endian.Little),
                .y = try reader.readInt(u32, Endian.Little),
                .z = try reader.readInt(u32, Endian.Little),
            },
            .blue = CIEXYZObject{
                .x = try reader.readInt(u32, Endian.Little),
                .y = try reader.readInt(u32, Endian.Little),
                .z = try reader.readInt(u32, Endian.Little),
            },
        },
        .gamma_red = try reader.readInt(u32, Endian.Little),
        .gamma_green = try reader.readInt(u32, Endian.Little),
        .gamma_blue = try reader.readInt(u32, Endian.Little),
    };
}

fn readStructBitmapV5Header(reader: anytype) !BitmapV5Header {
    return BitmapV5Header{
        .intent = try reader.readEnum(GamutMappingIntent, Endian.Little),
        .profile_data = try reader.readInt(u32, Endian.Little),
        .profile_size = try reader.readInt(u32, Endian.Little),
        .reserved = try reader.readInt(u32, Endian.Little),
    };
}
