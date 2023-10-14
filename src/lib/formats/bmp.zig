const std = @import("std");
const Allocator = std.mem.Allocator;
const StreamSource = std.io.StreamSource;

const Image = @import("../image.zig").ImageRT;

pub const Error = error{BMPNotImplemented};

const file_signature = "BM"; // TODO: "BA", "CI", "CP", "IC", "PT"

pub fn is_format(stream: *StreamSource) !bool {
    return stream.reader().isBytes(file_signature);
}

pub fn init(allocator: Allocator, stream: *StreamSource) !Image {
    if (!try is_format(stream)) {
        unreachable;
    }

    _ = allocator;
    // TODO: stefan
    return Error.BMPNotImplemented;
}
