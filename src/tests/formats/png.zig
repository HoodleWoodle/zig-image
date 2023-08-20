const tests = @import("../tests.zig");
const Image = @import("../../lib/image.zig");

test "reading simple PNG image" {
    try tests.testReadImage1x1Success("images/test-1x1.png");
}

test "reading 8x4 PNG image" {
    try tests.testReadImage8x4Success("images/test-8x4.png", .Alpha);
}
