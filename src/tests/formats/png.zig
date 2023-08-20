const tests = @import("../tests.zig");
const Image = @import("../../lib/image.zig");

test "reading simple PNG image" {
    // TODO: temporarily skipped (PNG)
    //try tests.testReadImage1x1Success("images/test-1x1.png");
    return error.SkipZigTest;
}

test "reading 8x4 PNG image" {
    // TODO: temporarily skipped (PNG)
    //try tests.testReadImage8x4Success("images/test-8x4.png", .Alpha);
    return error.SkipZigTest;
}
