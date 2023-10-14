const tests = @import("../tests.zig");
const Image = @import("../../lib/image.zig");

test "[BMP] reading: 1x1 (V3, BI_BITFIELDS, BI_BITCOUNT_6)" {
    try tests.testReadImage1x1Success("images/test-1x1.bmp");
}

test "[BMP] reading: 2x2 (V1, BI_RGB, BI_BITCOUNT_5) - padding" {
    try tests.testReadImage2x2Success("images/test-2x2.bmp");
}

test "[BMP] reading: 8x4 (V3, BI_BITFIELDS, BI_BITCOUNT_6)" {
    try tests.testReadImage8x4Success("images/test-8x4-bit-6.bmp", .Alpha);
}

test "[BMP] reading: 8x4 (V3, BI_BITFIELDS, BI_BITCOUNT_4)" {
    try tests.testReadImage8x4Success("images/test-8x4-bit-4.bmp", .Alpha);
}

test "[BMP] reading: 8x4 (V1, BI_RGB, BI_BITCOUNT_1)" {
    try tests.testReadImage8x4Success("images/test-8x4-rgb-1.bmp", .Mono);
}

test "[BMP] reading: 8x4 (V1, BI_RGB, BI_BITCOUNT_2)" {
    try tests.testReadImage8x4Success("images/test-8x4-rgb-2.bmp", .Default);
}

test "[BMP] reading: 8x4 (V1, BI_RGB, BI_BITCOUNT_2, negative-height)" {
    try tests.testReadImage8x4Success("images/test-8x4-rgb-2-nh.bmp", .Default);
}

test "[BMP] reading: 8x4 (V1, BI_RGB, BI_BITCOUNT_3)" {
    try tests.testReadImage8x4Success("images/test-8x4-rgb-3.bmp", .Default);
}

test "[BMP] reading: 8x4 (V1, BI_RGB, BI_BITCOUNT_4)" {
    try tests.testReadImage8x4Success("images/test-8x4-rgb-4.bmp", .Default);
}

test "[BMP] reading: 8x4 (V1, BI_RGB, BI_BITCOUNT_5)" {
    try tests.testReadImage8x4Success("images/test-8x4-rgb-5.bmp", .Default);
}

test "[BMP] reading: 8x4 (V1, BI_RGB, BI_BITCOUNT_6)" {
    try tests.testReadImage8x4Success("images/test-8x4-rgb-6.bmp", .Default);
}
