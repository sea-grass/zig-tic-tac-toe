/// main.zig
/// Tic Tac Toe
/// A simple tic tac toe CLI game.
const std = @import("std");
const Game = @import("game.zig").Game;

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    var g = try Game.init(allocator);
    defer g.deinit();

    try g.start(stdin, stdout);
}

test {
    _ = @import("game.zig");
    _ = @import("util.zig");
}
