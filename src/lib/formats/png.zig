const std = @import("std");
const Allocator = std.mem.Allocator;
const StreamSource = std.io.StreamSource;

const Image = @import("../image.zig").ImageRT;

pub const Error = error{PNGNotImplemented};

const file_signature = [_]u8{ 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A };

pub fn is_format(stream: *StreamSource) !bool {
    return stream.reader().isBytes(&file_signature);
}

pub fn init(allocator: Allocator, stream: *StreamSource) !Image {
    if (!try is_format(stream)) {
        unreachable;
    }

    _ = allocator;
    // TODO: quirin
    return Error.PNGNotImplemented;
}
