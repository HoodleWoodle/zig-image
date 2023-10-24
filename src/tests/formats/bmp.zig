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

test "[BMP] writing: 1x1 (V3, BI_BITFIELDS, BI_BITCOUNT_6)" {
    try common.testWriteImage1x1Success(.BMP, "images/test-1x1.bmp");
}

test "[BMP] writing: 2x2 (V1, BI_RGB, BI_BITCOUNT_5) - padding" {
    try common.testWriteImage2x2Success(.BMP, "images/test-2x2.bmp");
}

test "[BMP] writing: 8x4 (V3, BI_BITFIELDS, BI_BITCOUNT_6)" {
    try common.testWriteImage8x4Success(.BMP, "images/test-8x4-bit-6.bmp", .Alpha);
}

test "[BMP] writing: 8x4 (V3, BI_BITFIELDS, BI_BITCOUNT_4)" {
    try common.testWriteImage8x4Success(.BMP, "images/test-8x4-bit-4.bmp", .Alpha);
}

test "[BMP] writing: 8x4 (V1, BI_RGB, BI_BITCOUNT_1)" {
    try common.testWriteImage8x4Success(.BMP, "images/test-8x4-rgb-1.bmp", .Mono);
}

test "[BMP] writing: 8x4 (V1, BI_RGB, BI_BITCOUNT_2)" {
    try common.testWriteImage8x4Success(.BMP, "images/test-8x4-rgb-2.bmp", .Default);
}

test "[BMP] writing: 8x4 (V1, BI_RGB, BI_BITCOUNT_2, negative-height)" {
    try common.testWriteImage8x4Success(.BMP, "images/test-8x4-rgb-2-nh.bmp", .Default);
}

test "[BMP] writing: 8x4 (V1, BI_RGB, BI_BITCOUNT_3)" {
    try common.testWriteImage8x4Success(.BMP, "images/test-8x4-rgb-3.bmp", .Default);
}

test "[BMP] writing: 8x4 (V1, BI_RGB, BI_BITCOUNT_4)" {
    try common.testWriteImage8x4Success(.BMP, "images/test-8x4-rgb-4.bmp", .Default);
}

test "[BMP] writing: 8x4 (V1, BI_RGB, BI_BITCOUNT_5)" {
    try common.testWriteImage8x4Success(.BMP, "images/test-8x4-rgb-5.bmp", .Default);
}

test "[BMP] writing: 8x4 (V1, BI_RGB, BI_BITCOUNT_6)" {
    try common.testWriteImage8x4Success(.BMP, "images/test-8x4-rgb-6.bmp", .Default);
}

test "[BMP] writing new RGBA128f image" {
    //const std = @import("std");
    //const zimg = @import("../../lib/zig-image.zig");
    //const Image = zimg.ImageCT(.rgba128f);
    //const RGBA128f = zimg.color.RGBA128f;
    //
    //const W = 64;
    //const H = 64;
    //
    //var image = try Image.init(std.testing.allocator, W, H);
    //defer image.deinit();
    //
    //var y: u32 = 0;
    //while (y < H) : (y += 1) {
    //    var x: u32 = 0;
    //    while (x < W) : (x += 1) {
    //        const r = @as(f32, @floatFromInt(x)) / W;
    //        const g = @as(f32, @floatFromInt(y)) / H;
    //        try image.storage.set(x + y * W, RGBA128f.init(r, g, 0.0, 1.0));
    //    }
    //}
    //
    //var file = try std.fs.cwd().createFile("generated.bmp", .{});
    //defer file.close();
    //
    //try image.write(.BMP, file.writer());
    return error.SkipZigTest;
}
