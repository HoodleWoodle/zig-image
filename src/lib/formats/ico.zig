const std = @import("std");
const StreamSource = std.io.StreamSource;

const file_signature = [_]u8{ 0x00, 0x00, 0x01, 0x00 };

pub fn is_format(stream: *StreamSource) !bool {
    return stream.reader().isBytes(&file_signature);
}
