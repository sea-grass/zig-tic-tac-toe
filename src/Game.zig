const std = @import("std");
const util = @import("util.zig");
const command = @import("command.zig");
const Move = @import("Move.zig");
const State = @import("state.zig").State;
const Symbol = @import("symbol.zig").Symbol;
const Allocator = std.mem.Allocator;
const allEqual = util.allEqual;
const any = util.any;
const ArrayList = std.ArrayList;
const Command = command.Command;

const Game = @This();

const Error = error{
    InputError,
    ViewError,
};

state: State = .x_turn,
allocator: Allocator,
board: [9]Symbol = [_]Symbol{Symbol.empty} ** 9,
message: ViewMessage = .none,
moves: ArrayList(Move),

pub fn init(a: Allocator) !Game {
    return .{
        .allocator = a,
        .moves = ArrayList(Move).init(a),
    };
}

pub fn deinit(self: *Game) void {
    self.moves.deinit();
}

pub fn start(g: *Game, reader: anytype, writer: anytype) !void {
    try g.view(writer);
    while (!g.complete()) {
        try g.update(reader);
        try g.view(writer);
    }
}

fn view(g: Game, writer: anytype) !void {
    try writer.print("\n{u} Tic Tac Toe {u}\n\n", .{ Symbol.x.unicode_char(), Symbol.o.unicode_char() });
    try g.viewBoard(writer);
    try g.viewMoves(writer);
    try g.viewState(writer);
    try g.viewMessage(writer);
    if (!g.complete()) {
        try g.viewRemainingSpots(writer);
        try g.viewPrompt(writer);
    }
}

fn complete(g: Game) bool {
    return g.state.isGameOver();
}

fn update(g: *Game, reader: anytype) !void {
    const c = command.get(reader) catch |err| switch (err) {
        else => .unknown,
    };

    const should_update_state = update: {
        switch (c) {
            .play => |spot| {
                if (g.board[spot] != .empty) {
                    g.message = .spot_already_occupied;
                    return;
                }

                if (g.state == .x_turn or g.state == .o_turn) {
                    const symbol = g.state.symbol();
                    try g.moves.append(.{ .spot = spot, .symbol = symbol });
                    g.board[spot] = symbol;
                    break :update true;
                }

                break :update false;
            },
            .quit => {
                g.state = .quit;
                break :update false;
            },
            .unknown => {
                g.message = .invalid_choice;
                break :update false;
            },
        }
    };

    if (should_update_state) {
        g.message = .none;

        g.state = state: {
            const board = g.board;
            for (win_checks) |check| {
                const items = [3]Symbol{ board[check[0]], board[check[1]], board[check[2]] };
                if (items[0] != .empty and allEqual(Symbol, items[0..])) {
                    break :state if (items[0] == .o) .o_win else .x_win;
                }
            }

            // check for tie
            if (!any(Symbol, .empty, board[0..])) {
                break :state .tie;
            }

            // Switch turns
            break :state switch (g.state) {
                .x_turn => .o_turn,
                .o_turn => .x_turn,
                else => g.state,
            };
        };
    }
}

const win_checks = [8][3]u8{
    [3]u8{ 0, 1, 2 },
    [3]u8{ 3, 4, 5 },
    [3]u8{ 6, 7, 8 },
    [3]u8{ 0, 3, 6 },
    [3]u8{ 1, 4, 7 },
    [3]u8{ 2, 5, 8 },
    [3]u8{ 0, 4, 8 },
    [3]u8{ 2, 4, 6 },
};

fn viewState(g: Game, writer: anytype) !void {
    switch (g.state) {
        .x_turn, .o_turn => {
            try writer.print("{u}, it's your turn.", .{g.state.symbol().unicode_char()});
        },
        .x_win, .o_win => {
            try writer.print("The game's over. {u} wins!", .{g.state.symbol().unicode_char()});
        },
        .tie => {
            try writer.print("The game's over. It's a tie!", .{});
        },
        else => {},
    }
    try writer.print("\n", .{});
}

const ViewMessage = enum {
    none,
    input_too_long,
    invalid_number,
    invalid_choice,
    spot_already_occupied,
    unknown_input_error,
};

fn viewMessage(g: Game, writer: anytype) !void {
    switch (g.message) {
        .none => {},
        .input_too_long => {
            try writer.print("! Input too long. Please try again.", .{});
        },
        .invalid_number => {
            try writer.print("! Input was not a valid number. Please try again.", .{});
        },
        .invalid_choice => {
            try writer.print("! Input was not a valid choice. Please try again.", .{});
        },
        .spot_already_occupied => {
            try writer.print("! The selected spot has already been occupied. Please try again.", .{});
        },
        else => {
            try writer.print("! Encountered error: {any}.", .{g.message});
        },
    }
    try writer.print("\n", .{});
}

fn viewRemainingSpots(g: Game, writer: anytype) !void {
    if (g.complete()) return;
    try writer.print("Remaining spots: ", .{});
    for (g.board) |spot, i| {
        if (spot == .empty) try writer.print("{d} ", .{i});
    }
    try writer.print("\n", .{});
}

fn viewPrompt(g: Game, writer: anytype) !void {
    try writer.print("{u} ", .{g.state.symbol().unicode_char()});
}

fn viewBoard(g: Game, writer: anytype) !void {
    for (g.board) |square, i| {
        if (i % 3 == 0) {
            try writer.print("\n", .{});
        }

        try writer.print(" ", .{});

        if (square == .empty) {
            try writer.print(" {d} ", .{i});
        } else try writer.print(" {s} ", .{square});

        if (i % 3 == 2) {
            try writer.print(" \n", .{});
        }
    }
    // print bottom border
    try writer.print("\n", .{});
}

fn viewMoves(game: Game, writer: anytype) !void {
    if (game.moves.items.len == 0) return;

    try writer.print("Moves: ", .{});
    for (game.moves.items) |m| {
        try writer.print("{u}{d} ", .{ m.symbol.unicode_char(), m.spot });
    }
    try writer.print("\n", .{});
}

test "complete" {
    const x_turn_game = Game{ .state = .x_turn };
    try std.testing.expect(!x_turn_game.complete());

    const o_turn_game = Game{ .state = .o_turn };
    try std.testing.expect(!o_turn_game.complete());

    const x_win_game = Game{ .state = .x_win };
    try std.testing.expect(x_win_game.complete());

    const o_win_game = Game{ .state = .o_win };
    try std.testing.expect(o_win_game.complete());

    const tie_game = Game{ .state = .tie };
    try std.testing.expect(tie_game.complete());

    const quit_game = Game{ .state = .quit };
    try std.testing.expect(quit_game.complete());
}

test {
    std.testing.refAllDecls(@This());
}
