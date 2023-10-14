const tests = @import("../tests.zig");
const Image = @import("../../lib/image.zig");

test "[ICO] reading: unsupported format" {
    try tests.testReadImageFailure("images/test-1x1.ico", Image.Error.FormatNotSupported);
}
