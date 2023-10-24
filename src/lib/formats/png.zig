const std = @import("std");
const Allocator = std.mem.Allocator;
const StreamSource = std.io.StreamSource;

const ImageRT = @import("../image.zig").ImageRT;

pub const Error = error{PNGNotImplemented};

const FILE_SIGNATURE = [_]u8{ 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };

pub fn isFormat(stream: *StreamSource) !bool {
    return stream.reader().isBytes(&FILE_SIGNATURE);
}

pub fn read(allocator: Allocator, stream: *StreamSource) !ImageRT {
    if (!try isFormat(stream)) {
        unreachable;
    }

    _ = allocator;
    // TODO: quirin
    return Error.PNGNotImplemented;
}

pub fn write(image: ImageRT, writer: anytype) !void {
    _ = image;
    _ = writer;
    // TODO: quirin
    return Error.PNGNotImplemented;
}
