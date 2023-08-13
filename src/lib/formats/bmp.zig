const std = @import("std");
const Allocator = std.mem.Allocator;
const StreamSource = std.io.StreamSource;
const Endian = std.builtin.Endian;

const Image = @import("../image.zig");

pub const Error = error{ BMPDIBHeaderNotSupported, BMPCompressionFormatNotSupported, BMPBitCountNotSupported, BMPCorrupted };

const FileHeader = packed struct {
    signature_B: u8,
    signature_M: u8, // TODO: ZIG: '[2]u8', but arrays not supported in packed structs
    file_size: u32,
    reserved: u32, // these are actually two u16 but since they are not used it does not matter
    bitmap_offset: u32,
};

const GamutMappingIntent = enum(u32) {
    LCS_GM_BUSINESS = 1,
    LCS_GM_GRAPHICS = 2,
    LCS_GM_IMAGES = 4,
    LCS_GM_ABS_COLORIMETRIC = 8,
};

// fixed point types: 'n': integer bits, 'f' fraction bits
const Placeholder_nnffffffffffffffffffffffffffffff = u32; // TODO: ZIG: seems to be not supported yet ?
const Placeholder_00000000nnnnnnnnffffffff00000000 = u32; // TODO: that is so weird that it needs to be supported "manually"

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
    planes: u16,
    bit_count: BitCount,
    compression: Compression,
    image_size: u32,
    xpels_per_meter: i32,
    ypels_per_meter: i32,
    color_used: u32,
    color_important: u32,

    const Self = @This();

    fn check(self: *const Self) !void {
        // width
        if (self.width <= 0) {
            return Error.BMPCorrupted;
        }
        // TODO: IMPL: BitmapInfoHeader.check: This field SHOULD specify the width of the decompressed image file, if the Compression value specifies JPEG or PNG format.
        // height
        if (self.height == 0) {
            return Error.BMPCorrupted;
        }
        // planes
        if (self.planes != 1) {
            return Error.BMPCorrupted;
        }
        // bit_count
        if (self.bit_count != .BI_BITCOUNT_6) {
            return Error.BMPBitCountNotSupported; // TODO: IMPL: support bit_count options
        }
        if (self.bit_count == .BI_BITCOUNT_0 and !(self.compression == .BI_JPEG or self.compression == .BI_PNG)) {
            return Error.BMPCorrupted;
        }
        // TODO: IMPL: BitmapInfoHeader.check: BI_BITCOUNT_4: When the Compression field is set to BI_BITFIELDS, bits set in each DWORD mask MUST be contiguous and SHOULD NOT overlap the bits of another mask
        // TODO: IMPL: BitmapInfoHeader.check: BI_BITCOUNT_6: When the Compression field is set to BI_BITFIELDS, bits set in each DWORD mask MUST be contiguous and MUST NOT overlap the bits of another mask.
        // compression
        if (self.compression == .BI_ALPHABITFIELDS) {
            return Error.BMPCompressionFormatNotSupported;
        }
        if (self.compression == .BI_RLE8 or self.compression == .BI_RLE4 or self.compression == .BI_JPEG or self.compression == .BI_PNG or self.compression == .BI_CMYKRLE8 or self.compression == .BI_CMYKRLE4) {
            return Error.BMPCompressionFormatNotSupported; // TODO: IMPL: support more complex compression formats
        }
        if (self.compression == .BI_RGB or self.compression == .BI_CMYK) {
            return Error.BMPCompressionFormatNotSupported; // TODO: IMPL: support compressionless compression formats
        }
        //if (self.compression == .BI_BITFIELDS) {
        //    return Error.BMPCompressionFormatNotSupported; // TODO: IMPL: support compressionless compression formats
        //}
        if (self.compression.is_compressed() and self.height < 0) {
            return Error.BMPCorrupted;
        }
        // image_size
        if (self.compression == .BI_RGB and self.image_size != 0) {
            return Error.BMPCorrupted;
        }
        // TODO: IMPL: BitmapInfoHeader.check: If the Compression value is BI_JPEG or BI_PNG, this value MUST specify the size of the JPEG or PNG image buffer, respectively.
        // color_important
        // TODO: IMPL: BitmapInfoHeader.check: When the array of pixels in the DIB immediately follows the BitmapInfoHeader, the DIB is a packed bitmap. In a packed bitmap, the ColorUsed value MUST be either 0x00000000 or the actual size of the color table.
    }
};

// not documented in MS-WMF
const BitmapV2Header = packed struct {
    red_mask: u32,
    green_mask: u32,
    blue_mask: u32,
};

// not documented in MS-WMF
const BitmapV3Header = packed struct {
    alpha_mask: u32,
};

const BitmapV4Header = packed struct {
    color_space_type: LogicalColorSpace,
    endpoints: CIEXYZTripleObject,
    gamma_red: Placeholder_00000000nnnnnnnnffffffff00000000,
    gamma_green: Placeholder_00000000nnnnnnnnffffffff00000000,
    gamma_blue: Placeholder_00000000nnnnnnnnffffffff00000000,

    const Self = @This();

    fn check(self: *const Self) !void {
        _ = self;
        return Error.BMPDIBHeaderNotSupported; // TODO: IMPL: BitmapV4Header
    }
};

const BitmapV5Header = packed struct {
    intent: GamutMappingIntent,
    profile_data: u32,
    profile_size: u32,
    reserved: u32,

    const Self = @This();

    fn check(self: *const Self) !void {
        _ = self;
        return Error.BMPDIBHeaderNotSupported; // TODO: IMPL: BitmapV5Header
    }
};

const file_signature = "BM"; // "BA", "CI", "CP", "IC", "PT" not supported

pub fn is_format(stream: *StreamSource) !bool {
    return stream.reader().isBytes(file_signature);
}

pub fn init(allocator: Allocator, stream: *StreamSource) !Image {
    var reader = stream.reader();
    std.debug.print("\n", .{});

    // file header
    // TODO: ZIG: const file_header = try reader.readStruct(FileHeader); // TODO: ZIG: Endian.Little ?
    const file_header = try readStructFileHeader(reader);
    std.debug.print("{any}\n", .{file_header});
    // TODO: IMPL: FileHeader.check: file_size constraint - but seems not to be correct for some files ?

    // dib header info
    const header_size = try reader.readEnum(HeaderSize, Endian.Little);
    std.debug.print("header-size: {any}\n", .{header_size});
    if (header_size == .OS21XBITMAPHEADER or header_size == .OS22XBITMAPHEADER or header_size == .OS22XBITMAPHEADER_SMALL) {
        return Error.BMPDIBHeaderNotSupported;
    }
    if (header_size == .BitmapV2Header) {
        return Error.BMPDIBHeaderNotSupported;
    }

    // TODO: ZIG: const info_header = try reader.readStruct(BitmapInfoHeader); // TODO: ZIG: Endian.Little ?
    const info_header = try readStructBitmapInfoHeader(reader);
    std.debug.print("{any}\n", .{info_header});
    try info_header.check();

    const v2_header = if (header_size.has_header(.BitmapV2Header))
        // TODO: ZIG: try reader.readStruct(BitmapV2Header) // TODO: ZIG: Endian.Little ?
        try readStructBitmapV2Header(reader)
    else
        null;
    std.debug.print("{any}\n", .{v2_header});

    const v3_header = if (header_size.has_header(.BitmapV3Header))
        // TODO: ZIG: try reader.readStruct(BitmapV3Header) // TODO: ZIG: Endian.Little ?
        try readStructBitmapV3Header(reader)
    else
        null;
    std.debug.print("{any}\n", .{v3_header});

    const v4_header = if (header_size.has_header(.BitmapV4Header))
        // TODO: ZIG: try reader.readStruct(BitmapV4Header) // TODO: ZIG: Endian.Little ?
        try readStructBitmapV4Header(reader)
    else
        null;
    std.debug.print("{any}\n", .{v4_header});
    if (v4_header) |*header| {
        try header.check();
    }

    const v5_header = if (header_size.has_header(.BitmapV5Header))
        // TODO: ZIG: try reader.readStruct(BitmapV5Header) // TODO: ZIG: Endian.Little ?
        try readStructBitmapV5Header(reader)
    else
        null;
    std.debug.print("{any}\n", .{v5_header});
    if (v5_header) |*header| {
        try header.check();
    }

    // colors
    // TODO: IMPL: colors (info_header.color_used, info_header.color_important, info_header.bit_count, info_header.compression)
    //var red_mask = 0x00FF0000;
    //var green_mask = 0x0000FF00;
    //var blue_mask = 0x000000FF;
    //var alpha_mask = 0x00000000;
    //if (info_header.compression == .BI_BITFIELDS) {
    //    if (v2_header) |header| {
    //        red_mask = header.red_mask;
    //        green_mask = header.green_mask;
    //        blue_mask = header.blue_mask;
    //    }
    //}
    //if (v3_header) |header| alpha_mask = header.alpha_mask; // this is just a conjecture

    // bitmap_buffer
    // TODO: IMPL: bitmap_buffer (expect packed bitmap)
    try stream.seekTo(file_header.bitmap_offset);

    const w = @as(u32, @bitCast(info_header.width));
    const h = std.math.absCast(info_header.height);
    const pixel_count = w * h;
    var pixels = try allocator.alloc(Image.RGBA32, pixel_count);
    errdefer allocator.free(pixels);

    var i: u32 = 0;
    while (i < pixel_count) : (i += 1) {
        const idx = i;
        pixels[idx].b = try reader.readByte();
        pixels[idx].g = try reader.readByte();
        pixels[idx].r = try reader.readByte();
        pixels[idx].a = try reader.readByte();
    }

    return Image{ .allocator = allocator, .width = w, .height = h, .pixels = pixels };
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
    return FileHeader{
        .signature_B = try reader.readByte(),
        .signature_M = try reader.readByte(),
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
