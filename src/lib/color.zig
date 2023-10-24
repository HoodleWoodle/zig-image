const std = @import("std");

pub const RGBA128f = RGBA(f32);
pub const RGBA32 = RGBA(u8);
pub const RGBA64 = RGBA(u16);

pub fn RGBA(comptime T: type) type {
    return packed struct {
        a: T,
        b: T,
        g: T,
        r: T,

        pub usingnamespace RGBAFunctionality(@This(), T, T, T, T);
    };
}

pub const BGRA32 = BGRA(u8);

pub fn BGRA(comptime T: type) type {
    return packed struct {
        a: T,
        r: T,
        g: T,
        b: T,

        pub usingnamespace RGBAFunctionality(@This(), T, T, T, T);
    };
}

pub const ARGB32 = ARGB(u8, u8);
pub const ARGB4444 = ARGB(u4, u4);
pub const ARGB1555 = ARGB(u1, u5);
pub const A2R10G10B10 = ARGB(u2, u10);

pub fn ARGB(comptime A: type, comptime T: type) type {
    return packed struct {
        b: T,
        g: T,
        r: T,
        a: A,

        pub usingnamespace RGBAFunctionality(@This(), T, T, T, A);
    };
}

pub const ABGR32 = ABGR(u8, u8);
pub const A2B10G10R10 = ABGR(u2, u10);

pub fn ABGR(comptime A: type, comptime T: type) type {
    return packed struct {
        r: T,
        g: T,
        b: T,
        a: A,

        pub usingnamespace RGBAFunctionality(@This(), T, T, T, A);
    };
}

pub const RGB24 = RGB(u8, u8, u8);
pub const RGB48 = RGB(u16, u16, u16);
pub const RGB565 = RGB(u5, u6, u5);
pub const RGB555 = RGB(u5, u5, u5);

pub fn RGB(comptime R: type, comptime G: type, comptime B: type) type {
    return packed struct {
        b: B,
        g: G,
        r: R,

        pub usingnamespace RGBFunctionality(@This(), R, G, B);
    };
}

pub const BGR24 = BGR(u8);

pub fn BGR(comptime T: type) type {
    return packed struct {
        r: T,
        g: T,
        b: T,

        pub usingnamespace RGBFunctionality(@This(), T, T, T);
    };
}

pub const Grayscale1 = Grayscale(u1);
pub const Grayscale2 = Grayscale(u2);
pub const Grayscale4 = Grayscale(u4);
pub const Grayscale8 = Grayscale(u8);
pub const Grayscale16 = Grayscale(u16);

pub fn Grayscale(comptime T: type) type {
    return packed struct {
        const Self = @This();

        v: T, // v for value

        pub fn init(v: T) Self {
            return Self{ .v = v };
        }

        pub fn eql(self: Self, other: Self) bool {
            return isEqual(T, self.v, other.v);
        }

        pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;

            try writer.print("{s}{{ .v = 0x{x} }}", .{
                @typeName(Self), self.v,
            });
        }

        pub fn from(comptime From: type, value: From) Self {
            if (comptime isGrayscale(From)) {
                const v = fromGrayscale(T, From, value);
                return Self.init(v);
            } else {
                const v = fromAvgRGB(T, From, value);
                return Self.init(v);
            }
        }

        pub fn isConversionLossy(comptime From: type) bool {
            comptime {
                if (isGrayscale(From)) {
                    if (isConversionLossyFromGrayscale(T, From)) return true;
                } else {
                    if (isConversionLossyFromR(T, From)) return true;
                    if (isConversionLossyFromG(T, From)) return true;
                    if (isConversionLossyFromB(T, From)) return true;
                    if (isConversionLossyFromA(T, From)) return true;
                }
                return false;
            }
        }
    };
}

pub fn RGBAFunctionality(comptime Self: type, comptime R: type, comptime G: type, comptime B: type, comptime A: type) type {
    return struct {
        pub fn init(r: R, g: G, b: B, a: A) Self {
            return Self{ .r = r, .g = g, .b = b, .a = a };
        }

        pub fn eql(self: Self, other: Self) bool {
            return isEqual(R, self.r, other.r) and isEqual(G, self.g, other.g) and isEqual(B, self.b, other.b) and isEqual(A, self.a, other.a);
        }

        pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;

            try writer.print("{s}{{ .r = " ++ spec(R) ++ ", .g = " ++ spec(G) ++ ", .b = " ++ spec(B) ++ ", .a = " ++ spec(A) ++ " }}", .{
                @typeName(Self), self.r, self.g, self.b, self.a,
            });
        }

        pub fn from(comptime From: type, value: From) Self {
            if (comptime isGrayscale(From)) {
                const r = fromGrayscale(R, From, value);
                const g = fromGrayscale(G, From, value);
                const b = fromGrayscale(B, From, value);
                const a = defaultAlpha(A);
                return Self.init(r, g, b, a);
            } else {
                const r = fromR(R, From, value);
                const g = fromG(G, From, value);
                const b = fromB(B, From, value);
                const a = fromA(A, From, value);
                return Self.init(r, g, b, a);
            }
        }

        pub fn isConversionLossy(comptime From: type) bool {
            comptime {
                if (isGrayscale(From)) {
                    if (isConversionLossyFromGrayscale(R, From)) return true;
                    if (isConversionLossyFromGrayscale(G, From)) return true;
                    if (isConversionLossyFromGrayscale(B, From)) return true;
                    if (isConversionLossyFromGrayscale(A, From)) return true;
                } else {
                    if (isConversionLossyFromR(R, From)) return true;
                    if (isConversionLossyFromG(G, From)) return true;
                    if (isConversionLossyFromB(B, From)) return true;
                    if (isConversionLossyFromA(A, From)) return true;
                }
                return false;
            }
        }
    };
}

pub fn RGBFunctionality(comptime Self: type, comptime R: type, comptime G: type, comptime B: type) type {
    return struct {
        pub fn init(r: R, g: G, b: B) Self {
            return Self{ .r = r, .g = g, .b = b };
        }

        pub fn eql(self: Self, other: Self) bool {
            return isEqual(R, self.r, other.r) and isEqual(G, self.g, other.g) and isEqual(B, self.b, other.b);
        }

        pub fn format(self: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;

            try writer.print("{s}{{ .r = " ++ spec(R) ++ ", .g = " ++ spec(G) ++ ", .b = " ++ spec(B) ++ " }}", .{
                @typeName(Self), self.r, self.g, self.b,
            });
        }

        pub fn from(comptime From: type, value: From) Self {
            if (comptime isGrayscale(From)) {
                const r = fromGrayscale(R, From, value);
                const g = fromGrayscale(G, From, value);
                const b = fromGrayscale(B, From, value);
                return Self.init(r, g, b);
            } else {
                const r = fromR(R, From, value);
                const g = fromG(G, From, value);
                const b = fromB(B, From, value);
                return Self.init(r, g, b);
            }
        }

        pub fn isConversionLossy(comptime From: type) bool {
            comptime {
                if (isGrayscale(From)) {
                    if (isConversionLossyFromGrayscale(R, From)) return true;
                    if (isConversionLossyFromGrayscale(G, From)) return true;
                    if (isConversionLossyFromGrayscale(B, From)) return true;
                } else {
                    if (isConversionLossyFromR(R, From)) return true;
                    if (isConversionLossyFromG(G, From)) return true;
                    if (isConversionLossyFromB(B, From)) return true;
                }
                return false;
            }
        }
    };
}

fn TypeOfChannel(comptime Container: type, comptime channel: []const u8) type {
    return loop: for (@typeInfo(Container).Struct.fields) |field| {
        if (std.mem.eql(u8, field.name, channel))
            break :loop field.type;
    } else {
        @compileError("Unsupported color container: '" ++ @typeName(Container) ++ "' for channel '" ++ channel ++ "'");
    };
}

fn isConversionLossyFromGrayscale(comptime To: type, comptime Container: type) bool {
    return isChannelConversionLossy(To, Container, "v");
}

fn isConversionLossyFromR(comptime To: type, comptime Container: type) bool {
    return isChannelConversionLossy(To, Container, "r");
}

fn isConversionLossyFromG(comptime To: type, comptime Container: type) bool {
    return isChannelConversionLossy(To, Container, "g");
}

fn isConversionLossyFromB(comptime To: type, comptime Container: type) bool {
    return isChannelConversionLossy(To, Container, "b");
}

fn isConversionLossyFromA(comptime To: type, comptime Container: type) bool {
    return if (comptime hasAlpha(Container)) isChannelConversionLossy(To, Container, "a") else false;
}

fn isChannelConversionLossy(comptime To: type, comptime Container: type, comptime channel: []const u8) bool {
    const From = TypeOfChannel(Container, channel);

    const type_info_from = @typeInfo(From);
    const type_info_to = @typeInfo(To);

    if (type_info_from == .Int and type_info_to == .Int)
        return type_info_from.Int.bits > type_info_to.Int.bits;

    if (type_info_from == .Int and type_info_to == .Float)
        return false; // TODO: IMPROVE: this is not correct: precision ? (u512 -> f16)

    if (type_info_from == .Float and type_info_to == .Int)
        return true; // TODO: IMPROVE: this is not correct: precision ? (f16 -> u512)

    if (type_info_from == .Float and type_info_to == .Float)
        return type_info_from.Float.bits > type_info_to.Float.bits;

    @compileError("Unsupported color channels: '" ++ @typeName(From) ++ "' ro '" ++ @typeName(To) ++ "'");
}

fn spec(comptime T: type) []const u8 {
    return if (@typeInfo(T) == .Float) "{d:.3}" else "0x{x}";
}

fn isEqual(comptime T: type, a: T, b: T) bool {
    return if (@typeInfo(T) == .Float) std.math.approxEqAbs(T, a, b, std.math.floatEps(T)) else a == b;
}

fn defaultAlpha(comptime To: type) To {
    const type_info = @typeInfo(To);
    if (type_info == .Int)
        return std.math.maxInt(To);
    if (type_info == .Float)
        return 1.0;

    @compileError("Unsupported color channel: '" ++ @typeName(To) ++ "'");
}

fn isGrayscale(comptime Container: type) bool {
    return @hasField(Container, "v");
}

fn fromGrayscale(comptime T: type, comptime Container: type, container: Container) T {
    return fromChannel(T, Container, container, "v");
}

fn fromR(comptime R: type, comptime Container: type, container: Container) R {
    return fromChannel(R, Container, container, "r");
}

fn fromG(comptime G: type, comptime Container: type, container: Container) G {
    return fromChannel(G, Container, container, "g");
}

fn fromB(comptime B: type, comptime Container: type, container: Container) B {
    return fromChannel(B, Container, container, "b");
}

fn hasAlpha(comptime Container: type) bool {
    return @hasField(Container, "a");
}

fn fromA(comptime A: type, comptime Container: type, container: Container) A {
    return if (comptime hasAlpha(Container)) fromChannel(A, Container, container, "a") else defaultAlpha(A);
}

fn fromAvgRGB(comptime To: type, comptime Container: type, container: Container) To {
    const r = fromChannel(To, Container, container, "r");
    const g = fromChannel(To, Container, container, "g");
    const b = fromChannel(To, Container, container, "b");

    const type_info = @typeInfo(To);
    if (type_info == .Int) {
        const sum = @as(f64, @floatFromInt(@as(u64, r) + @as(u64, g) + @as(u64, b)));
        return @as(To, @intFromFloat(std.math.round(sum / (@as(f64, std.math.maxInt(To)) * 3))));
    }
    if (type_info == .Float)
        return (r + g + b) / 3.0;
}

fn fromChannel(comptime To: type, comptime Container: type, container: Container, comptime channel: []const u8) To {
    const From = TypeOfChannel(Container, channel);
    const from = @field(container, channel);

    const type_info_from = @typeInfo(From);
    const type_info_to = @typeInfo(To);

    if (type_info_from == .Int and type_info_to == .Int) {
        const bits_from = type_info_from.Int.bits;
        const bits_to = type_info_to.Int.bits;
        if (bits_from < bits_to) {
            const cast = std.math.cast(To, from).?;
            comptime var bits_to_fill = bits_to;
            var result: To = 0;
            inline while (bits_to_fill >= bits_from) {
                bits_to_fill -= bits_from;
                result |= std.math.shl(To, cast, bits_to_fill);
            }
            result |= std.math.shr(To, cast, bits_from - bits_to_fill);
            return result;
        }
        if (bits_from > bits_to)
            return std.math.cast(To, std.math.shr(From, from, bits_from - bits_to)).?;
        if (bits_from == bits_to)
            return std.math.cast(To, from).?;
    }

    if (type_info_from == .Int and type_info_to == .Float)
        return @as(To, @floatFromInt(from)) / @as(To, @floatFromInt(std.math.maxInt(From)));

    if (type_info_from == .Float and type_info_to == .Int)
        return @as(To, @intFromFloat(std.math.round(from * @as(From, @floatFromInt(std.math.maxInt(To))))));

    if (type_info_from == .Float and type_info_to == .Float)
        return std.math.lossyCast(To, from);

    @compileError("Unsupported color container: '" ++ @typeName(Container) ++ "'");
}
