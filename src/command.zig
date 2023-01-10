const std = @import("std");
const readLine = @import("read_line.zig").readLine;

pub const Command = union(enum) { unknown, quit, play: u8 };
pub const Error = error{InputError};

pub fn get(reader: anytype) Error!Command {
    const line = readLine(reader) catch |err| switch (err) {
        else => {
            return .unknown;
        },
    };

    if (std.mem.eql(u8, line, "q") or std.mem.eql(u8, line, "Q")) return .quit;

    const guess = std.fmt.parseUnsigned(u8, line, 10) catch return .unknown;

    if (guess > 8) return Error.InputError;

    return .{ .play = guess };
}
