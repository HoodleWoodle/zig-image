const common = @import("../common.zig");

test "[BMP] reading: 1x1 (V3, BI_BITFIELDS, BI_BITCOUNT_6)" {
    try common.testReadImage1x1Success(.argb32, "images/test-1x1.bmp");
}

test "[BMP] reading: 2x2 (V1, BI_RGB, BI_BITCOUNT_5) - padding" {
    try common.testReadImage2x2Success(.rgb24, "images/test-2x2.bmp");
}

test "[BMP] reading: 8x4 (V3, BI_BITFIELDS, BI_BITCOUNT_6)" {
    try common.testReadImage8x4Success(.argb32, "images/test-8x4-bit-6.bmp", .Alpha);
}

test "[BMP] reading: 8x4 (V3, BI_BITFIELDS, BI_BITCOUNT_4)" {
    try common.testReadImage8x4Success(.argb1555, "images/test-8x4-bit-4.bmp", .Alpha);
}

test "[BMP] reading: 8x4 (V1, BI_RGB, BI_BITCOUNT_1)" {
    try common.testReadImage8x4Success(.indexed1, "images/test-8x4-rgb-1.bmp", .Mono);
}

test "[BMP] reading: 8x4 (V1, BI_RGB, BI_BITCOUNT_2)" {
    try common.testReadImage8x4Success(.indexed4, "images/test-8x4-rgb-2.bmp", .Default);
}

test "[BMP] reading: 8x4 (V1, BI_RGB, BI_BITCOUNT_2, negative-height)" {
    try common.testReadImage8x4Success(.indexed4, "images/test-8x4-rgb-2-nh.bmp", .Default);
}

test "[BMP] reading: 8x4 (V1, BI_RGB, BI_BITCOUNT_3)" {
    try common.testReadImage8x4Success(.indexed8, "images/test-8x4-rgb-3.bmp", .Default);
}

test "[BMP] reading: 8x4 (V1, BI_RGB, BI_BITCOUNT_4)" {
    try common.testReadImage8x4Success(.rgb555, "images/test-8x4-rgb-4.bmp", .Default);
}

test "[BMP] reading: 8x4 (V1, BI_RGB, BI_BITCOUNT_5)" {
    try common.testReadImage8x4Success(.rgb24, "images/test-8x4-rgb-5.bmp", .Default);
}

test "[BMP] reading: 8x4 (V1, BI_RGB, BI_BITCOUNT_6)" {
    try common.testReadImage8x4Success(.rgb24, "images/test-8x4-rgb-6.bmp", .Default);
}
