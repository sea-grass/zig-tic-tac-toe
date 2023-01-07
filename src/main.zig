/// main.zig
/// Tic Tac Toe
/// A simple tic tac toe CLI game.
const std = @import("std");
const Game = @import("Game.zig");

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    var g = try Game.init(allocator);
    defer g.deinit();

    try g.start(stdin, stdout);
}

test {
    _ = @import("Game.zig");
    _ = @import("util.zig");
}
