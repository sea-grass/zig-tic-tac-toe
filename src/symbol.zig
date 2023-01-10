const std = @import("std");

pub const Symbol = enum {
    empty,
    x,
    o,

    const Self = @This();

    pub inline fn char(symbol: Self) u8 {
        return switch (symbol) {
            .empty => ' ',
            .x => 'x',
            .o => 'o',
        };
    }

    pub inline fn unicode_char(symbol: Self) u16 {
        return switch (symbol) {
            .empty => ' ',
            .x => '\u{2613}',
            .o => '\u{25EF}',
            //.x => '\u{2665}',
            //.o => '\u{2680}',
        };
    }

    pub fn format(symbol: Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("{c}", .{symbol.char()});
    }
};
