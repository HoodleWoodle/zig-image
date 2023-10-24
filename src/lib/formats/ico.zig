const std = @import("std");
const StreamSource = std.io.StreamSource;

const FILE_SIGNATURE = [_]u8{ 0x00, 0x00, 0x01, 0x00 };

pub fn isFormat(stream: *StreamSource) !bool {
    return stream.reader().isBytes(&FILE_SIGNATURE);
}
