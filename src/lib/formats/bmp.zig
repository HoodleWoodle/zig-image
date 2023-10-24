const std = @import("std");
const Allocator = std.mem.Allocator;
const StreamSource = std.io.StreamSource;
const Endian = std.builtin.Endian;

const color = @import("../color.zig");
const ImageRT = @import("../image.zig").ImageRT;
const storage = @import("../storage.zig");
const PixelFormat = storage.Format;
const PixelStorageRT = storage.StorageRT;

pub const Error = error{ BMPDIBHeaderNotSupported, BMPCompressionFormatNotSupported, BMPBitCountNotSupported, BMPCorrupted };

const FileHeader = extern struct {
    signature: [2]u8,
    file_size: u32, // unused
    reserved: u32, // unused; these are actually two u16 but since they are not used it does not matter
    bitmap_offset: u32, // unused
};

const GamutMappingIntent = enum(u32) { // not supported
    LCS_GM_BUSINESS = 1,
    LCS_GM_GRAPHICS = 2,
    LCS_GM_IMAGES = 4,
    LCS_GM_ABS_COLORIMETRIC = 8,
};

// fixed point types: 'n': integer bits, 'f' fraction bits
const Placeholder_nnffffffffffffffffffffffffffffff = u32;
const Placeholder_00000000nnnnnnnnffffffff00000000 = u32;

const CIEXYZObject = packed struct { // not supported
    x: Placeholder_nnffffffffffffffffffffffffffffff,
    y: Placeholder_nnffffffffffffffffffffffffffffff,
    z: Placeholder_nnffffffffffffffffffffffffffffff,
};

const CIEXYZTripleObject = packed struct { // not supported
    red: CIEXYZObject,
    green: CIEXYZObject,
    blue: CIEXYZObject,
};

const LogicalColorSpace = enum(u32) { // not supported
    LCS_CALIBRATED_RGB = 0,
    LCS_sRGB = 0x73524742,
    LCS_WINDOWS_COLOR_SPACE = 0x57696E20,
    LCS_PROFILE_LINKED = 0x4C494E4B, // LogicalColorSpaceV5
    LCS_PROFILE_EMBEDDED = 0x4D424544, // LogicalColorSpaceV5
};

const Compression = enum(u32) {
    BI_RGB = 0x0000,
    BI_RLE8 = 0x0001, // not supported
    BI_RLE4 = 0x0002, // not supported
    BI_BITFIELDS = 0x0003,
    BI_JPEG = 0x0004, // not supported
    BI_PNG = 0x0005, // not supported
    BI_ALPHABITFIELDS = 0x0006, // not supported
    BI_CMYK = 0x000B, // not supported
    BI_CMYKRLE8 = 0x000C, // not supported
    BI_CMYKRLE4 = 0x000D, // not supported

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
    BI_BITCOUNT_0 = 0x0000, // not supported (JPG, PNG)
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
    BitmapV2Header = 52, // not supported (without V3)
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
        if (self.compression == .BI_JPEG or self.compression == .BI_PNG or self.compression == .BI_CMYK or self.compression == .BI_CMYKRLE8 or self.compression == .BI_CMYKRLE4) {
            return Error.BMPCompressionFormatNotSupported;
        }
        if (self.compression == .BI_RLE8 or self.compression == .BI_RLE4) {
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

const FILE_SIGNATURE = "BM"; // "BA", "CI", "CP", "IC", "PT" not supported

//const MASK = enum(u32) { R, G, B, A };
const CHANNEL_COUNT = 4;
const R = 0;
const G = 1;
const B = 2;
const A = 3;

const COLOR_MASKS_RGBA32 = [CHANNEL_COUNT]u32{ 0xFF000000, 0x00FF0000, 0x0000FF00, 0x000000FF };
const COLOR_MASKS_BGRA32 = [CHANNEL_COUNT]u32{ 0x0000FF00, 0x00FF0000, 0xFF000000, 0x000000FF };
const COLOR_MASKS_ARGB32 = [CHANNEL_COUNT]u32{ 0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000 };
const COLOR_MASKS_ABGR32 = [CHANNEL_COUNT]u32{ 0x000000FF, 0x0000FF00, 0x00FF0000, 0xFF000000 };
const COLOR_MASKS_RGB24 = [CHANNEL_COUNT]u32{ 0xFF000000, 0x00FF0000, 0x0000FF00, 0x00000000 };
const COLOR_MASKS_ARGB4444 = [CHANNEL_COUNT]u32{ 0x0F00, 0x00F0, 0x000F, 0xF000 };
const COLOR_MASKS_ARGB1555 = [CHANNEL_COUNT]u32{ 0x7C00, 0x03E0, 0x001F, 0x8000 };
const COLOR_MASKS_RGB565 = [CHANNEL_COUNT]u32{ 0xF800, 0x07E0, 0x001F, 0x0000 };
const COLOR_MASKS_RGB555 = [CHANNEL_COUNT]u32{ 0x7C00, 0x03E0, 0x001F, 0x0000 };
const COLOR_MASKS_A2R10G10B10 = [CHANNEL_COUNT]u32{ 0x3FF00000, 0x000FFC00, 0x000003FF, 0xC0000000 };
const COLOR_MASKS_A2B10G10R10 = [CHANNEL_COUNT]u32{ 0x000003FF, 0x000FFC00, 0x3FF00000, 0xC0000000 };

pub fn isFormat(stream: *StreamSource) !bool {
    return stream.reader().isBytes(FILE_SIGNATURE);
}

pub fn read(allocator: Allocator, stream: *StreamSource) !ImageRT {
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
    const masks = switch (info_header.compression) {
        .BI_BITFIELDS => blk: {
            var masks: [CHANNEL_COUNT]u32 = [_]u32{ 0, 0, 0, 0 };

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

            break :blk masks;
        },
        .BI_RGB => blk: {
            if (info_header.bit_count == .BI_BITCOUNT_4) {
                break :blk COLOR_MASKS_RGB555;
            } else {
                // used only with .BI_BITCOUNT_5 and .BI_BITCOUNT_6
                break :blk COLOR_MASKS_RGB24;
            }
        },
        else => unreachable,
    };

    // DEBUG: std.debug.print("r-mask: 0x{x}\n", .{ masks[R] });
    // DEBUG: std.debug.print("g-mask: 0x{x}\n", .{ masks[G] });
    // DEBUG: std.debug.print("b-mask: 0x{x}\n", .{ masks[B] });
    // DEBUG: std.debug.print("a-mask: 0x{x}\n", .{ masks[A] });

    // format

    //.indexed1      <==    has_color_table                  and BI_BITCOUNT_1
    //.indexed4      <==    has_color_table                  and BI_BITCOUNT_2
    //.indexed8      <==    has_color_table                  and BI_BITCOUNT_3
    //.rgba32        <==   !has_color_table and BI_BITFIELDS and BI_BITCOUNT_6 <masks = .rgba32>
    //.bgra32        <==   !has_color_table and BI_BITFIELDS and BI_BITCOUNT_6 <masks = .bgra32>
    //.argb32        <==   !has_color_table and BI_BITFIELDS and BI_BITCOUNT_6 <masks = .argb32>
    //.abgr32        <==   !has_color_table and BI_BITFIELDS and BI_BITCOUNT_6 <masks = .abgr32>
    //.rgb24         <==   !has_color_table and BI_RGB       and BI_BITCOUNT_5
    //                <=   !has_color_table and BI_RGB       and BI_BITCOUNT_6    // => .rgb24 but with padding ?
    //.argb4444      <==   !has_color_table and BI_BITFIELDS and BI_BITCOUNT_4 <masks = .argb4444>
    //.argb1555      <==   !has_color_table and BI_BITFIELDS and BI_BITCOUNT_4 <masks = .argb1555>
    //.rgb565        <==   !has_color_table and BI_BITFIELDS and BI_BITCOUNT_4 <masks = .rgb565>
    //.rgb555        <==   !has_color_table and BI_BITFIELDS and BI_BITCOUNT_4 <masks = .rgb555>
    //                <=   !has_color_table and BI_RGB       and BI_BITCOUNT_4
    //.a2r10g10b10   <==   !has_color_table and BI_BITFIELDS and BI_BITCOUNT_6 and <masks = .a2r10g10b10>
    //.a2b10g10r10   <==   !has_color_table and BI_BITFIELDS and BI_BITCOUNT_6 and <masks = .a2b10g10r10>
    //
    // else: NOT SUPPORTED

    var fmt: PixelFormat = undefined;
    if (!has_color_table) {
        switch (info_header.compression) {
            .BI_BITFIELDS => {
                switch (info_header.bit_count) {
                    .BI_BITCOUNT_4 => {
                        if (std.mem.eql(u32, &masks, &COLOR_MASKS_ARGB4444)) {
                            fmt = .argb4444;
                        } else if (std.mem.eql(u32, &masks, &COLOR_MASKS_ARGB1555)) {
                            fmt = .argb1555;
                        } else if (std.mem.eql(u32, &masks, &COLOR_MASKS_RGB565)) {
                            fmt = .rgb565;
                        } else if (std.mem.eql(u32, &masks, &COLOR_MASKS_RGB555)) {
                            fmt = .rgb555;
                        } else unreachable;
                    },
                    .BI_BITCOUNT_6 => {
                        if (std.mem.eql(u32, &masks, &COLOR_MASKS_RGBA32)) {
                            fmt = .rgba32;
                        } else if (std.mem.eql(u32, &masks, &COLOR_MASKS_BGRA32)) {
                            fmt = .bgra32;
                        } else if (std.mem.eql(u32, &masks, &COLOR_MASKS_ARGB32)) {
                            fmt = .argb32;
                        } else if (std.mem.eql(u32, &masks, &COLOR_MASKS_ABGR32)) {
                            fmt = .abgr32;
                        } else if (std.mem.eql(u32, &masks, &COLOR_MASKS_A2R10G10B10)) {
                            fmt = .a2r10g10b10;
                        } else if (std.mem.eql(u32, &masks, &COLOR_MASKS_A2B10G10R10)) {
                            fmt = .a2b10g10r10;
                        } else unreachable;
                    },
                    else => unreachable,
                }
            },
            .BI_RGB => {
                switch (info_header.bit_count) {
                    .BI_BITCOUNT_4 => fmt = .rgb555,
                    .BI_BITCOUNT_5 => fmt = .rgb24,
                    .BI_BITCOUNT_6 => fmt = .rgb24,
                    else => unreachable,
                }
            },
            else => unreachable,
        }
    } else {
        std.debug.assert(is_indexed);
        switch (info_header.bit_count) {
            .BI_BITCOUNT_1 => fmt = .indexed1,
            .BI_BITCOUNT_2 => fmt = .indexed4,
            .BI_BITCOUNT_3 => fmt = .indexed8,
            else => unreachable,
        }
    }

    // DEBUG: std.debug.print("format: {any}\n", .{fmt});

    // colors
    var color_table: [256]color.RGBA128f = undefined;
    var color_count: usize = 0;
    if (info_header.compression == .BI_RGB) {
        color_count = switch (info_header.bit_count) {
            .BI_BITCOUNT_1 => 2,
            .BI_BITCOUNT_2 => 16,
            .BI_BITCOUNT_3 => 256,
            else => 0,
        };

        var i: u32 = 0;
        while (i < color_count) : (i += 1) {
            const col: color.RGBA32 = .{
                .b = try reader.readByte(), // read little endian
                .g = try reader.readByte(),
                .r = try reader.readByte(),
                .a = 0xFF,
            };
            _ = try reader.readByte(); // ignore padding

            color_table[i] = color.RGBA128f.from(color.RGBA32, col);

            // DEBUG: std.debug.print("color-table[{any}]: {any}\n", .{ i, color_table[i] });
        }
    }

    // bitmap_buffer
    try stream.seekTo(file_header.bitmap_offset);

    const flip_y = info_header.height < 0;
    const w = @as(u32, @bitCast(info_header.width));
    const h = std.math.absCast(info_header.height);
    const pixel_count = w * h;

    var pixel_storage = try PixelStorageRT.init(fmt, pixel_count, allocator);
    errdefer pixel_storage.deinit(allocator);
    if (is_indexed) {
        switch (pixel_storage) {
            .indexed1 => |s| @memcpy(s.data.palette, color_table[0..(std.math.maxInt(@TypeOf(s.data).Index) + 1)]),
            .indexed4 => |s| @memcpy(s.data.palette, color_table[0..(std.math.maxInt(@TypeOf(s.data).Index) + 1)]),
            .indexed8 => |s| @memcpy(s.data.palette, color_table[0..(std.math.maxInt(@TypeOf(s.data).Index) + 1)]),
            else => unreachable,
        }
    }

    var byte_count: u32 = 0;
    var yp: u32 = 0;
    while (yp < h) : (yp += 1) {
        const y: u32 = if (flip_y) yp else h - yp - 1;

        switch (pixel_storage) {
            .indexed1 => |*s| byte_count += try readRowIndexed(reader, @TypeOf(s.data), &s.data, w, y),
            .indexed4 => |*s| byte_count += try readRowIndexed(reader, @TypeOf(s.data), &s.data, w, y),
            .indexed8 => |*s| byte_count += try readRowIndexed(reader, @TypeOf(s.data), &s.data, w, y),
            .rgba32 => |*s| byte_count += try readRow(reader, PixelFormat.rgba32.ColorType(), s.data, w, y, 0),
            .bgra32 => |*s| byte_count += try readRow(reader, PixelFormat.bgra32.ColorType(), s.data, w, y, 0),
            .argb32 => |*s| byte_count += try readRow(reader, PixelFormat.argb32.ColorType(), s.data, w, y, 0),
            .abgr32 => |*s| byte_count += try readRow(reader, PixelFormat.abgr32.ColorType(), s.data, w, y, 0),
            .rgb24 => |*s| {
                const padding: u32 = if (info_header.bit_count == .BI_BITCOUNT_6) 1 else 0;
                byte_count += try readRow(reader, PixelFormat.rgb24.ColorType(), s.data, w, y, padding);
            },
            .argb4444 => |*s| byte_count += try readRow(reader, PixelFormat.argb4444.ColorType(), s.data, w, y, 0),
            .argb1555 => |*s| byte_count += try readRow(reader, PixelFormat.argb1555.ColorType(), s.data, w, y, 0),
            .rgb565 => |*s| byte_count += try readRow(reader, PixelFormat.rgb565.ColorType(), s.data, w, y, 0),
            .rgb555 => |*s| byte_count += try readRow(reader, PixelFormat.rgb555.ColorType(), s.data, w, y, 0),
            .a2r10g10b10 => |*s| byte_count += try readRow(reader, PixelFormat.a2r10g10b10.ColorType(), s.data, w, y, 0),
            .a2b10g10r10 => |*s| byte_count += try readRow(reader, PixelFormat.a2b10g10r10.ColorType(), s.data, w, y, 0),
            else => unreachable,
        }

        // padding
        while (byte_count % 4 != 0) : (byte_count += 1) {
            _ = try reader.readByte();
        }
    }

    return .{ .allocator = allocator, .width = w, .height = h, .storage = pixel_storage };
}

fn readRowIndexed(reader: anytype, comptime IndexedStorage: type, indexed_storage: *IndexedStorage, w: u32, y: u32) !u32 {
    const indices_per_byte = @bitSizeOf(u8) / @bitSizeOf(IndexedStorage.Index);
    const index_shift = @bitSizeOf(IndexedStorage.Index);
    const index_mask = std.math.maxInt(IndexedStorage.Index);

    var byte_count: u32 = 0;

    var x: u32 = 0;
    xloop: while (x < w) : (x += 1) {
        const base_idx = x + y * w;

        // could be "improved" by separating .BI_BITCOUNT_1, .BI_BITCOUNT_shift
        const buffer = try reader.readByte();
        byte_count += 1;

        var i: u32 = 0;
        while (i < indices_per_byte) : (i += 1) {
            if (x >= w) break :xloop;

            const offset = std.math.cast(u3, 8 - index_shift * (i + 1)).?;
            const index = std.math.cast(IndexedStorage.Index, (buffer >> offset) & index_mask).?;
            indexed_storage.indices[base_idx + i] = index;

            // DEBUG: std.debug.print("({any},{any}) : [{any}] {any}\n", .{ x + i, y, index, indexed_storage.at(base_idx + i) catch unreachable });
        }

        x += indices_per_byte - 1;
    }

    return byte_count;
}

fn readRow(reader: anytype, comptime Color: type, data: []Color, w: u32, y: u32, padding: u32) !u32 {
    const bit_size = @bitSizeOf(Color);
    const bytes_per_color = bit_size / 8 + if (bit_size % 8 != 0) 1 else 0;
    const Repr = switch (bytes_per_color) {
        1 => u8,
        2 => u16,
        3 => u24,
        4 => u32,
        else => unreachable,
    };

    var byte_count: u32 = 0;

    var x: u32 = 0;
    while (x < w) : (x += 1) { // TODO: IMPROVE: it is sometimes possible to direct memcpy the rows (sometimes also possible for whole data)
        const idx = x + y * w;

        const buffer = try reader.readInt(Repr, Endian.Little);
        try reader.skipBytes(padding, .{});
        byte_count += bytes_per_color + padding;

        if (Color == color.RGB555) {
            std.debug.assert(Repr == u16);
            data[idx].r = std.math.cast(u5, ((buffer >> 10) & 0b11111)).?;
            data[idx].g = std.math.cast(u5, ((buffer >> 5) & 0b11111)).?;
            data[idx].b = std.math.cast(u5, ((buffer >> 0) & 0b11111)).?;
        } else {
            // TODO: TEST: is 'buffer = @byteSwap(buffer)' necessary on platforms with Endian.Big ?
            @memcpy(
                @as(*[bytes_per_color]u8, @ptrCast(&data[idx])),
                @as(*const [bytes_per_color]u8, @ptrCast(&buffer)),
            );
        }

        // DEBUG: std.debug.print("({any},{any}) : {any}\n", .{ x, y, data[idx] });
    }

    return byte_count;
}

pub fn write(image: ImageRT, writer: anytype) !void {
    const format = image.storage.format();

    const bit_count: BitCount = switch (format) {
        .indexed1 => .BI_BITCOUNT_1,
        .indexed4 => .BI_BITCOUNT_2,
        .indexed8 => .BI_BITCOUNT_3,
        .rgba32 => .BI_BITCOUNT_6,
        .bgra32 => .BI_BITCOUNT_6,
        .argb32 => .BI_BITCOUNT_6,
        .abgr32 => .BI_BITCOUNT_6,
        .rgb24 => .BI_BITCOUNT_5,
        .argb4444 => .BI_BITCOUNT_4,
        .argb1555 => .BI_BITCOUNT_4,
        .rgb565 => .BI_BITCOUNT_4,
        .rgb555 => .BI_BITCOUNT_4,
        .a2r10g10b10 => .BI_BITCOUNT_6,
        .a2b10g10r10 => .BI_BITCOUNT_6,
        else => .BI_BITCOUNT_6, // not supported => .rgba32
    };
    const compression: Compression = switch (format) {
        .indexed1 => .BI_RGB,
        .indexed4 => .BI_RGB,
        .indexed8 => .BI_RGB,
        .rgb24 => .BI_RGB,
        .rgb555 => .BI_RGB,
        else => .BI_BITFIELDS, // not supported => .rgba32
    };

    const has_bitfield_headers = compression == .BI_BITFIELDS;
    const header_size: HeaderSize = if (has_bitfield_headers) .BitmapV3Header else .BitmapInfoHeader;

    const color_palette_size: u32 = switch (image.storage) {
        .indexed1 => |s| std.math.maxInt(@TypeOf(s.data).Index) + 1,
        .indexed4 => |s| std.math.maxInt(@TypeOf(s.data).Index) + 1,
        .indexed8 => |s| std.math.maxInt(@TypeOf(s.data).Index) + 1,
        else => 0, // not supported => .rgba32
    };
    const bitmap_offset = 14 + @intFromEnum(header_size) + color_palette_size * 4; // TODO: ZIG: @sizeOf(FileHeader) instead of 14
    const file_header: FileHeader = .{
        .signature = [_]u8{ FILE_SIGNATURE[0], FILE_SIGNATURE[1] },
        .file_size = undefined, // TODO: IMPL: write FileHeader.file_size
        .reserved = 0,
        .bitmap_offset = bitmap_offset,
    };
    // DEBUG: std.debug.print("{any}\n", .{file_header});
    // TODO: ZIG: try writer.writeStruct(file_header) // TODO: ZIG: Endian.Little ?
    try writeStructFileHeader(writer, file_header);

    // DEBUG: std.debug.print("header_size: {any}\n", .{header_size});
    try writer.writeInt(u32, @intFromEnum(header_size), Endian.Little);

    const raw_image_size = undefined; // TODO IMPL: write BitmapInfoHeader.file_size
    const image_size: u32 = if (compression == .BI_RGB) 0 else raw_image_size;
    const info_header: BitmapInfoHeader = .{
        .width = std.math.cast(i32, image.width).?,
        .height = std.math.cast(i32, image.height).?,
        .planes = 0x0001,
        .bit_count = bit_count,
        .compression = compression,
        .image_size = image_size,
        .xpels_per_meter = 0x00000B13,
        .ypels_per_meter = 0x00000B13,
        .color_used = 0x00000000,
        .color_important = 0x00000000,
    };
    // DEBUG: std.debug.print("{any}\n", .{info_header});
    // TODO: ZIG: try writer.writeStruct(info_header) // TODO: ZIG: Endian.Little ?
    try writeStructBitmapInfoHeader(writer, info_header);

    if (has_bitfield_headers) {
        const masks: [CHANNEL_COUNT]u32 = switch (format) {
            .rgba32 => COLOR_MASKS_RGBA32,
            .bgra32 => COLOR_MASKS_BGRA32,
            .argb32 => COLOR_MASKS_ARGB32,
            .abgr32 => COLOR_MASKS_ABGR32,
            .argb4444 => COLOR_MASKS_ARGB4444,
            .argb1555 => COLOR_MASKS_ARGB1555,
            .rgb565 => COLOR_MASKS_RGB565,
            .a2r10g10b10 => COLOR_MASKS_A2R10G10B10,
            .a2b10g10r10 => COLOR_MASKS_A2B10G10R10,
            else => COLOR_MASKS_RGBA32, // not supported => .rgba32
        };

        const v2_header: BitmapV2Header = .{
            .red_mask = masks[R],
            .green_mask = masks[G],
            .blue_mask = masks[B],
        };
        // DEBUG: std.debug.print("{any}\n", .{v2_header});
        // TODO: ZIG: try writer.writeStruct(v2_header) // TODO: ZIG: Endian.Little ?
        try writeStructBitmapV2Header(writer, v2_header);

        const v3_header: BitmapV3Header = .{
            .alpha_mask = masks[A],
        };
        // DEBUG: std.debug.print("{any}\n", .{v3_header});
        // TODO: ZIG: try writer.writeStruct(v3_header) // TODO: ZIG: Endian.Little ?
        try writeStructBitmapV3Header(writer, v3_header);
    }

    // colors
    const palette = switch (image.storage) {
        .indexed1 => |s| s.data.palette,
        .indexed4 => |s| s.data.palette,
        .indexed8 => |s| s.data.palette,
        else => null, // not supported => .rgba32
    };
    if (palette) |p| {
        for (p) |c| {
            const col = color.RGB24.from(color.RGBA128f, c);
            // DEBUG: std.debug.print("color-table[?]: {any}\n", .{col});

            try writer.writeByte(col.b); // read little endian
            try writer.writeByte(col.g);
            try writer.writeByte(col.r);
            try writer.writeByte(0x00);
        }
    }

    // bitmap_buffer
    var byte_count: u32 = 0;
    var yp: u32 = 0;
    while (yp < image.height) : (yp += 1) {
        const y: u32 = image.height - yp - 1;

        switch (image.storage) {
            .indexed1 => |s| byte_count += try writeRowIndexed(writer, @TypeOf(s.data), &s.data, image.width, y),
            .indexed4 => |s| byte_count += try writeRowIndexed(writer, @TypeOf(s.data), &s.data, image.width, y),
            .indexed8 => |s| byte_count += try writeRowIndexed(writer, @TypeOf(s.data), &s.data, image.width, y),
            .rgba128f => |s| byte_count += try writeRowUnsupported(writer, PixelFormat.rgba128f.ColorType(), s.data, image.width, y),
            .rgba64 => |s| byte_count += try writeRowUnsupported(writer, PixelFormat.rgba64.ColorType(), s.data, image.width, y),
            .rgba32 => |s| byte_count += try writeRow(writer, PixelFormat.rgba32.ColorType(), s.data, image.width, y),
            .bgra32 => |s| byte_count += try writeRow(writer, PixelFormat.bgra32.ColorType(), s.data, image.width, y),
            .argb32 => |s| byte_count += try writeRow(writer, PixelFormat.argb32.ColorType(), s.data, image.width, y),
            .abgr32 => |s| byte_count += try writeRow(writer, PixelFormat.abgr32.ColorType(), s.data, image.width, y),
            .rgb48 => |s| byte_count += try writeRowUnsupported(writer, PixelFormat.rgb48.ColorType(), s.data, image.width, y),
            .rgb24 => |s| byte_count += try writeRow(writer, PixelFormat.rgb24.ColorType(), s.data, image.width, y),
            .bgr24 => |s| byte_count += try writeRowUnsupported(writer, PixelFormat.bgr24.ColorType(), s.data, image.width, y),
            .argb4444 => |s| byte_count += try writeRow(writer, PixelFormat.argb4444.ColorType(), s.data, image.width, y),
            .argb1555 => |s| byte_count += try writeRow(writer, PixelFormat.argb1555.ColorType(), s.data, image.width, y),
            .rgb565 => |s| byte_count += try writeRow(writer, PixelFormat.rgb565.ColorType(), s.data, image.width, y),
            .rgb555 => |s| byte_count += try writeRow(writer, PixelFormat.rgb555.ColorType(), s.data, image.width, y),
            .a2r10g10b10 => |s| byte_count += try writeRow(writer, PixelFormat.a2r10g10b10.ColorType(), s.data, image.width, y),
            .a2b10g10r10 => |s| byte_count += try writeRow(writer, PixelFormat.a2b10g10r10.ColorType(), s.data, image.width, y),
            .grayscale1 => |s| byte_count += try writeRowUnsupported(writer, PixelFormat.grayscale1.ColorType(), s.data, image.width, y),
            .grayscale2 => |s| byte_count += try writeRowUnsupported(writer, PixelFormat.grayscale2.ColorType(), s.data, image.width, y),
            .grayscale4 => |s| byte_count += try writeRowUnsupported(writer, PixelFormat.grayscale4.ColorType(), s.data, image.width, y),
            .grayscale8 => |s| byte_count += try writeRowUnsupported(writer, PixelFormat.grayscale8.ColorType(), s.data, image.width, y),
            .grayscale16 => |s| byte_count += try writeRowUnsupported(writer, PixelFormat.grayscale16.ColorType(), s.data, image.width, y),
        }

        // padding
        while (byte_count % 4 != 0) : (byte_count += 1) {
            _ = try writer.writeByte(0x00);
        }
    }
}

fn writeRowIndexed(writer: anytype, comptime IndexedStorage: type, indexed_storage: *const IndexedStorage, w: u32, y: u32) !u32 {
    const indices_per_byte = @bitSizeOf(u8) / @bitSizeOf(IndexedStorage.Index);
    const index_shift = @bitSizeOf(IndexedStorage.Index);
    const index_mask = std.math.maxInt(IndexedStorage.Index);

    var byte_count: u32 = 0;

    var x: u32 = 0;
    xloop: while (x < w) : (x += 1) {
        const base_idx = x + y * w;

        var byte: u8 = 0;

        var i: u32 = 0;
        while (i < indices_per_byte) : (i += 1) {
            if (x >= w) break :xloop;

            const index = std.math.cast(u8, indexed_storage.indices[base_idx + i]).?;
            const offset = std.math.cast(u3, 8 - index_shift * (i + 1)).?;
            byte |= (index & index_mask) << offset;

            // DEBUG: std.debug.print("({any},{any}) : [{any}] {any}\n", .{ x + i, y, index, indexed_storage.at(base_idx + i) catch unreachable });
        }

        // DEBUG: std.debug.print("--> 0b{b}\n", .{byte});

        try writer.writeByte(byte);
        byte_count += 1;

        x += indices_per_byte - 1;
    }

    return byte_count;
}

fn writeRow(writer: anytype, comptime Color: type, data: []const Color, w: u32, y: u32) !u32 {
    var byte_count: u32 = 0;

    var x: u32 = 0;
    while (x < w) : (x += 1) { // TODO: IMPROVE: it is sometimes possible to direct memcpy the rows (sometimes also possible for whole data)
        const idx = x + y * w;

        byte_count += try writeColor(writer, Color, data[idx]);
    }

    return byte_count;
}

fn writeRowUnsupported(writer: anytype, comptime Color: type, data: []const Color, w: u32, y: u32) !u32 {
    var byte_count: u32 = 0;

    var x: u32 = 0;
    while (x < w) : (x += 1) { // TODO: IMPROVE: it is sometimes possible to direct memcpy the rows (sometimes also possible for whole data)
        const idx = x + y * w;

        const c = color.RGBA32.from(Color, data[idx]);
        byte_count += try writeColor(writer, color.RGBA32, c);
    }

    return byte_count;
}

fn writeColor(writer: anytype, comptime Color: type, c: Color) !u8 {
    const bit_size = @bitSizeOf(Color);
    const bytes_per_color = bit_size / 8 + if (bit_size % 8 != 0) 1 else 0;
    const Repr = switch (bytes_per_color) {
        1 => u8,
        2 => u16,
        3 => u24,
        4 => u32,
        else => unreachable,
    };

    var buffer: Repr = 0;

    if (Color == color.RGB555) {
        std.debug.assert(Repr == u16);
        buffer |= (std.math.cast(Repr, c.r).? & 0b11111) << 10;
        buffer |= (std.math.cast(Repr, c.g).? & 0b11111) << 5;
        buffer |= (std.math.cast(Repr, c.b).? & 0b11111) << 0;
    } else {
        // TODO: TEST: is 'buffer = @byteSwap(buffer)' necessary on platforms with Endian.Big ?
        @memcpy(
            @as(*[bytes_per_color]u8, @ptrCast(&buffer)),
            @as(*const [bytes_per_color]u8, @ptrCast(&c)),
        );
    }

    // DEBUG: std.debug.print("({any},{any}) : {any}\n", .{ x, y, c[idx] });

    try writer.writeInt(Repr, buffer, Endian.Little);
    return bytes_per_color;
}

// ########################################################################################
// TODO: ZIG: reader.readStruct seems to be broken currently: <-> writer.writeStruct - cannot specify endianess
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

const ENDIANESS = Endian.Little;

fn readStructFileHeader(reader: anytype) !FileHeader {
    var signature: [2]u8 = undefined;
    _ = try reader.read(&signature);

    return FileHeader{
        .signature = signature,
        .file_size = try reader.readInt(u32, ENDIANESS),
        .reserved = try reader.readInt(u32, ENDIANESS),
        .bitmap_offset = try reader.readInt(u32, ENDIANESS),
    };
}

fn writeStructFileHeader(writer: anytype, header: FileHeader) !void {
    _ = try writer.write(&header.signature);
    try writer.writeInt(u32, header.file_size, ENDIANESS);
    try writer.writeInt(u32, header.reserved, ENDIANESS);
    try writer.writeInt(u32, header.bitmap_offset, ENDIANESS);
}

fn readStructBitmapInfoHeader(reader: anytype) !BitmapInfoHeader {
    return BitmapInfoHeader{
        .width = try reader.readInt(i32, ENDIANESS),
        .height = try reader.readInt(i32, ENDIANESS),
        .planes = try reader.readInt(u16, ENDIANESS),
        .bit_count = try reader.readEnum(BitCount, ENDIANESS),
        .compression = try reader.readEnum(Compression, ENDIANESS),
        .image_size = try reader.readInt(u32, ENDIANESS),
        .xpels_per_meter = try reader.readInt(i32, ENDIANESS),
        .ypels_per_meter = try reader.readInt(i32, ENDIANESS),
        .color_used = try reader.readInt(u32, ENDIANESS),
        .color_important = try reader.readInt(u32, ENDIANESS),
    };
}

fn writeStructBitmapInfoHeader(writer: anytype, header: BitmapInfoHeader) !void {
    try writer.writeInt(i32, header.width, ENDIANESS);
    try writer.writeInt(i32, header.height, ENDIANESS);
    try writer.writeInt(u16, header.planes, ENDIANESS);
    try writer.writeInt(u16, @intFromEnum(header.bit_count), ENDIANESS);
    try writer.writeInt(u32, @intFromEnum(header.compression), ENDIANESS);
    try writer.writeInt(u32, header.image_size, ENDIANESS);
    try writer.writeInt(i32, header.xpels_per_meter, ENDIANESS);
    try writer.writeInt(i32, header.ypels_per_meter, ENDIANESS);
    try writer.writeInt(u32, header.color_used, ENDIANESS);
    try writer.writeInt(u32, header.color_important, ENDIANESS);
}

fn readStructBitmapV2Header(reader: anytype) !BitmapV2Header {
    return BitmapV2Header{
        .red_mask = try reader.readInt(u32, ENDIANESS),
        .green_mask = try reader.readInt(u32, ENDIANESS),
        .blue_mask = try reader.readInt(u32, ENDIANESS),
    };
}

fn writeStructBitmapV2Header(writer: anytype, header: BitmapV2Header) !void {
    try writer.writeInt(u32, header.red_mask, ENDIANESS);
    try writer.writeInt(u32, header.green_mask, ENDIANESS);
    try writer.writeInt(u32, header.blue_mask, ENDIANESS);
}

fn readStructBitmapV3Header(reader: anytype) !BitmapV3Header {
    return BitmapV3Header{
        .alpha_mask = try reader.readInt(u32, ENDIANESS),
    };
}

fn writeStructBitmapV3Header(writer: anytype, header: BitmapV3Header) !void {
    try writer.writeInt(u32, header.alpha_mask, ENDIANESS);
}

fn readStructBitmapV4Header(reader: anytype) !BitmapV4Header {
    return BitmapV4Header{
        .color_space_type = try reader.readEnum(LogicalColorSpace, ENDIANESS),
        .endpoints = CIEXYZTripleObject{
            .red = CIEXYZObject{
                .x = try reader.readInt(u32, ENDIANESS),
                .y = try reader.readInt(u32, ENDIANESS),
                .z = try reader.readInt(u32, ENDIANESS),
            },
            .green = CIEXYZObject{
                .x = try reader.readInt(u32, ENDIANESS),
                .y = try reader.readInt(u32, ENDIANESS),
                .z = try reader.readInt(u32, ENDIANESS),
            },
            .blue = CIEXYZObject{
                .x = try reader.readInt(u32, ENDIANESS),
                .y = try reader.readInt(u32, ENDIANESS),
                .z = try reader.readInt(u32, ENDIANESS),
            },
        },
        .gamma_red = try reader.readInt(u32, ENDIANESS),
        .gamma_green = try reader.readInt(u32, ENDIANESS),
        .gamma_blue = try reader.readInt(u32, ENDIANESS),
    };
}

fn readStructBitmapV5Header(reader: anytype) !BitmapV5Header {
    return BitmapV5Header{
        .intent = try reader.readEnum(GamutMappingIntent, ENDIANESS),
        .profile_data = try reader.readInt(u32, ENDIANESS),
        .profile_size = try reader.readInt(u32, ENDIANESS),
        .reserved = try reader.readInt(u32, ENDIANESS),
    };
}
