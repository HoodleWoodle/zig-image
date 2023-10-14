const tests = @import("../common.zig");
const ImageError = @import("../../lib/zig-image.zig").ImageError;

test "[ICO] reading: unsupported format" {
    try tests.testReadImageFailure("images/test-1x1.ico", ImageError.FormatNotSupported);
}
