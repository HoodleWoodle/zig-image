const tests = @import("../common.zig");

test "reading simple PNG image" {
    try tests.testReadImage1x1Success("images/test-1x1.png");
}

test "reading 8x4 PNG image" {
    try tests.testReadImage8x4Success("images/test-8x4.png", .Alpha);
}
