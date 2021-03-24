/// main.zig
/// Tic Tac Toe
/// A simple tic tac toe CLI game.
const std = @import("std");
const game = @import("game.zig");
const create = game.create;
const view = game.view;
const update = game.update;
const complete = game.complete;

pub fn main() anyerror!void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    var g = create();

    try view(g, stdout);
    while (!complete(g)) {
        g = try update(g, stdin);
        try view(g, stdout);
    }
}
