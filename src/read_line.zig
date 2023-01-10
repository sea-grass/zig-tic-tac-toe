const std = @import("std");
const trimRight = std.mem.trimRight;

pub fn readLine(reader: anytype) ![]const u8 {
    var buf: [20]u8 = undefined;

    errdefer reader.skipUntilDelimiterOrEof('\n') catch {};
    if (try reader.readUntilDelimiterOrEof(&buf, '\n')) |input| {
        return trimRight(u8, input, "\r");
    }

    return error.NoInput;
}
