const ansi = @import("ansi.zig");

// TODO: IMPROVE: the struture and this iteration could/should be optimized for performance - but: who cares...
const Mapping = struct {
    const Entry = struct {
        char: []const u8,
        value: f32,
    };

    entries: []const Entry,

    pub fn find(self: @This(), value: f32) []const u8 {
        var min_idx: usize = 0;
        var min_diff: f32 = 1.0;
        for (self.entries, 0..) |entry, i| {
            const diff = @max(entry.value, value) - @min(entry.value, value);
            if (diff < min_diff) {
                min_idx = i;
                min_diff = diff;
            }
        }
        return self.entries[min_idx].char;
    }
};

pub const DEFAULT: Mapping = .{ .entries = &[_]Mapping.Entry{
    .{ .char = " ", .value = 0.000000 },
    .{ .char = ansi.CHAR_LIGHT_SHADE, .value = 0.250000 },
    .{ .char = ansi.CHAR_MEDIUM_SHADE, .value = 0.500000 },
    .{ .char = ansi.CHAR_DARK_SHADE, .value = 0.750000 },
    .{ .char = ansi.CHAR_BLOCK_FULL, .value = 1.000000 },
} };

// https://github.com/Uki99/img2ascii/blob/master/source/img2ascii/src/includes/mappings.hpp
pub const ASCII: Mapping = .{ .entries = &[_]Mapping.Entry{
    .{ .char = " ", .value = 0.000000 },
    .{ .char = ".", .value = 0.133333 },
    .{ .char = "-", .value = 0.155556 },
    .{ .char = ",", .value = 0.177778 },
    .{ .char = ":", .value = 0.266667 },
    .{ .char = "+", .value = 0.311111 },
    .{ .char = "~", .value = 0.333333 },
    .{ .char = ";", .value = 0.355556 },
    .{ .char = "(", .value = 0.400000 },
    .{ .char = "%", .value = 0.444444 },
    .{ .char = "x", .value = 0.488889 },
    .{ .char = "1", .value = 0.511111 },
    .{ .char = "*", .value = 0.533333 },
    .{ .char = "n", .value = 0.555556 },
    .{ .char = "T", .value = 0.577778 },
    .{ .char = "3", .value = 0.600000 },
    .{ .char = "J", .value = 0.622222 },
    .{ .char = "5", .value = 0.644444 },
    .{ .char = "$", .value = 0.666667 },
    .{ .char = "S", .value = 0.688889 },
    .{ .char = "4", .value = 0.711111 },
    .{ .char = "F", .value = 0.733333 },
    .{ .char = "G", .value = 0.755556 },
    .{ .char = "E", .value = 0.777778 },
    .{ .char = "8", .value = 0.800000 },
    .{ .char = "D", .value = 0.844444 },
    .{ .char = "@", .value = 0.888889 },
    .{ .char = "B", .value = 0.911111 },
    .{ .char = "#", .value = 0.933333 },
    .{ .char = "0", .value = 1.000000 },
} };
