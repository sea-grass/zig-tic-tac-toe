const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;
const debug = std.debug;
const assert = debug.assert;
const assertEqual = debug.assertEqual;
const Writer = std.fs.File.Writer;
const Reader = std.fs.File.Reader;
const util = @import("util.zig");
const allEqual = util.allEqual;
const any = util.any;

const Symbol = extern enum { Empty, X, O };
const Message = extern enum { None, Input_Too_Long, Invalid_Number, Invalid_Choice, Spot_Already_Occupied };
const Game = extern struct { id: u8 = 0, state: State = State.X_Turn, board: [9]Symbol = [_]Symbol{Symbol.Empty} ** 9, message: Message = Message.None };
const State = extern enum { X_Turn, O_Turn, X_Win, O_Win, Tie };

pub fn create() Game {
    return Game{ .id = 1 };
}

pub fn copy(game: Game) Game {
    return Game{ .id = game.id, .state = game.state, .board = game.board, .message = game.message };
}

test "copy" {
    const initial = Game{ .id = 9, .state = State.X_Win, .message = Message.None };
    const duplicate = copy(initial);

    assert(initial.id == duplicate.id);
    assert(initial.state == duplicate.state);
}

pub fn view(game: Game, writer: Writer) !void {
    try writer.print("Tic Tac Toe\n===========\n", .{});
    try viewBoard(game, writer);
    try viewState(game, writer);
    try viewMessage(game, writer);
}

fn viewBoard(game: Game, writer: Writer) !void {
    const game_board = game.board;

    for (game_board) |square, i| {
        if (i % 3 == 0) {
            try writer.print("-------------\n", .{});
        }
        try writer.print("|", .{});

        if (square == Symbol.Empty) {
            try writer.print(" {} ", .{i});
        } else if (square == Symbol.X) {
            try writer.print(" X ", .{});
        } else if (square == Symbol.O) {
            try writer.print(" O ", .{});
        }

        if (i % 3 == 2) {
            try writer.print("|\n", .{});
        }
    }
    // print bottom border
    try writer.print("-------------\n", .{});
}

fn viewState(game: Game, writer: Writer) !void {
    const state = game.state;
    if (state == State.X_Turn) {
        try writer.print("X, it's your turn.\n", .{});
    } else if (state == State.O_Turn) {
        try writer.print("O, it's your turn.\n", .{});
    } else if (state == State.X_Win) {
        try writer.print("The game's over. X wins!\n", .{});
    } else if (state == State.O_Win) {
        try writer.print("The game's over. O wins!\n", .{});
    } else if (state == State.Tie) {
        try writer.print("The game's over. It's a tie!\n", .{});
    }
}

fn viewMessage(game: Game, writer: Writer) !void {
    const message = game.message;
    if (message == Message.Input_Too_Long) {
        try writer.print("! Input too long. Please try again.\n", .{});
    } else if (message == Message.Invalid_Number) {
        try writer.print("! Input was not a valid number. Please try again.\n", .{});
    } else if (message == Message.Invalid_Choice) {
        try writer.print("! Input was not a valid choice. Please try again.\n", .{});
    } else if (message == Message.Spot_Already_Occupied) {
        try writer.print("! The selected spot has already been occupied. Please try again.\n", .{});
    }
}

pub fn complete(game: Game) bool {
    return switch (game.state) {
        State.X_Win => true,
        State.O_Win => true,
        State.Tie => true,
        else => false,
    };
}

test "complete" {
    const x_turn_game = Game{ .state = State.X_Turn };
    const o_turn_game = Game{ .state = State.O_Turn };
    const x_win_game = Game{ .state = State.X_Win };
    const o_win_game = Game{ .state = State.O_Win };
    const tie_game = Game{ .state = State.Tie };

    assert(complete(x_turn_game) == false);
    assert(complete(o_turn_game) == false);
    assert(complete(x_win_game) == true);
    assert(complete(o_win_game) == true);
    assert(complete(tie_game) == true);
}

pub fn update(game: Game, reader: Reader) !Game {
    var g = copy(game);

    var line_buf: [20]u8 = undefined;

    const amt = try reader.read(&line_buf);
    if (amt == line_buf.len) {
        g.message = Message.Input_Too_Long;
        return g;
    }
    const line = std.mem.trimRight(u8, line_buf[0..amt], "\r\n");

    const guess = fmt.parseUnsigned(u8, line, 10) catch {
        g.message = Message.Invalid_Number;
        return g;
    };

    if (guess < 0 or guess > 8) {
        g.message = Message.Invalid_Choice;
        return g;
    }

    if (g.board[guess] != Symbol.Empty) {
        g.message = Message.Spot_Already_Occupied;
        return g;
    }

    if (g.state == State.X_Turn) {
        g.board[guess] = Symbol.X;
    } else if (g.state == State.O_Turn) {
        g.board[guess] = Symbol.O;
    }

    const state = nextState(g);

    g.state = state;
    g.message = Message.None;

    return g;
}

const checks: [8][3]u8 = [8][3]u8{
    [3]u8{ 0, 1, 2 },
    [3]u8{ 3, 4, 5 },
    [3]u8{ 6, 7, 8 },
    [3]u8{ 0, 3, 6 },
    [3]u8{ 1, 4, 7 },
    [3]u8{ 2, 5, 8 },
    [3]u8{ 0, 4, 8 },
    [3]u8{ 2, 4, 6 },
};

fn nextState(game: Game) State {
    const board = game.board;
    // check for wins
    for (checks) |check| {
        const items = [3]Symbol{ board[check[0]], board[check[1]], board[check[2]] };
        if (items[0] != Symbol.Empty and allEqual(Symbol, items[0..])) {
            if (items[0] == Symbol.O) {
                return State.O_Win;
            } else if (items[0] == Symbol.X) {
                return State.X_Win;
            }
        }
    }

    // check for tie
    if (!any(Symbol, Symbol.Empty, board[0..])) {
        return State.Tie;
    }

    // Switch turns
    if (game.state == State.X_Turn) {
        return State.O_Turn;
    } else if (game.state == State.O_Turn) {
        return State.X_Turn;
    }

    return game.state;
}

test "nextState" {
    const x_turn_game = Game{ .state = State.X_Turn };

    assert(nextState(x_turn_game) == State.O_Turn);
}
