const std = @import("std");
const util = @import("util.zig");

const allEqual = util.allEqual;
const any = util.any;
const readLine = util.readLine;

pub const Command = union(enum) { unknown, quit, play: u8 };
pub const GameError = error{
    InputError,
    ViewError,
};
const State = enum {
    x_turn,
    o_turn,
    x_win,
    o_win,
    tie,
    quit,

    pub fn isGameOver(state: State) bool {
        return switch (state) {
            .x_win => true,
            .o_win => true,
            .tie => true,
            .quit => true,
            else => false,
        };
    }
};
const Symbol = enum { empty, x, o };
const ViewMessage = enum { none, input_too_long, invalid_number, invalid_choice, spot_already_occupied, unknown_input_error };

pub const Game = struct {
    id: u8 = 0,
    state: State = State.x_turn,
    board: [9]Symbol = [_]Symbol{Symbol.empty} ** 9,
    message: ViewMessage = .none,

    pub fn init(_: std.mem.Allocator) !Game {
        return .{};
    }

    pub fn deinit(_: *Game) void {}

    pub fn start(g: *Game, reader: anytype, writer: anytype) !void {
        try g.view(writer);
        while (!g.complete()) {
            try g.update(reader);
            try g.view(writer);
        }
    }

    fn view(g: Game, writer: anytype) !void {
        try writer.print("Tic Tac Toe\n===========\n", .{});
        try viewBoard(g, writer);
        try viewState(g, writer);
        try viewMessage(g, writer);
    }

    pub fn complete(g: Game) bool {
        return g.state.isGameOver();
    }

    pub fn update(g: *Game, reader: anytype) !void {
        const command = try g.getCommand(reader);

        switch (command) {
            .play => |spot| {
                if (spot > 8) {
                    g.message = .invalid_choice;
                    return;
                }

                switch (g.board[spot]) {
                    .empty => switch (g.state) {
                        .x_turn => {
                            g.board[spot] = Symbol.x;
                        },
                        .o_turn => {
                            g.board[spot] = Symbol.o;
                        },
                        else => {},
                    },
                    else => {
                        g.message = .spot_already_occupied;
                        return;
                    },
                }
            },
            .quit => {
                g.state = State.quit;
                return;
            },
            .unknown => {
                g.message = .invalid_choice;
                return;
            },
        }

        const state = nextState(g.*);

        g.state = state;
        g.message = .none;
    }

    fn viewBoard(g: Game, writer: anytype) !void {
        for (g.board) |square, i| {
            if (i % 3 == 0) {
                try writer.print("-------------\n", .{});
            }
            try writer.print("|", .{});

            switch (square) {
                .empty => {
                    try writer.print(" {} ", .{i});
                },
                .x => {
                    try writer.print(" X ", .{});
                },
                .o => {
                    try writer.print(" O ", .{});
                },
            }

            if (i % 3 == 2) {
                try writer.print("|\n", .{});
            }
        }
        // print bottom border
        try writer.print("-------------\n", .{});
    }

    fn viewState(g: Game, writer: anytype) !void {
        switch (g.state) {
            .x_turn => {
                try writer.print("X, it's your turn.\n", .{});
            },
            .o_turn => {
                try writer.print("O, it's your turn.\n", .{});
            },
            .x_win => {
                try writer.print("The game's over. X wins!\n", .{});
            },
            .o_win => {
                try writer.print("The game's over. O wins!\n", .{});
            },
            .tie => {
                try writer.print("The game's over. It's a tie!\n", .{});
            },
            else => {},
        }
    }

    fn viewMessage(g: Game, writer: anytype) !void {
        switch (g.message) {
            .none => {
                try writer.print("\n", .{});
            },
            .input_too_long => {
                try writer.print("! Input too long. Please try again.\n", .{});
            },
            .invalid_number => {
                try writer.print("! Input was not a valid number. Please try again.\n", .{});
            },
            .invalid_choice => {
                try writer.print("! Input was not a valid choice. Please try again.\n", .{});
            },
            .spot_already_occupied => {
                try writer.print("! The selected spot has already been occupied. Please try again.\n", .{});
            },
            .unknown_input_error => {
                try writer.print("! Unknown input error. Please try again.\n", .{});
            },
        }
    }

    fn getCommand(_: Game, reader: anytype) GameError!Command {
        const line = readLine(reader) catch |err| switch (err) {
            else => {
                return Command.unknown;
            },
        };

        if (std.mem.eql(u8, line, "q") or std.mem.eql(u8, line, "Q")) return .quit;

        const guess = std.fmt.parseUnsigned(u8, line, 10) catch return Command.unknown;

        return Command{ .play = guess };
    }
};

test "complete" {
    const x_turn_game = Game{ .state = State.x_turn };
    const o_turn_game = Game{ .state = State.o_turn };
    const x_win_game = Game{ .state = State.x_win };
    const o_win_game = Game{ .state = State.o_win };
    const tie_game = Game{ .state = State.tie };
    const quit_game = Game{ .state = State.quit };

    try std.testing.expect(!x_turn_game.complete());
    try std.testing.expect(!o_turn_game.complete());
    try std.testing.expect(x_win_game.complete());
    try std.testing.expect(o_win_game.complete());
    try std.testing.expect(tie_game.complete());
    try std.testing.expect(quit_game.complete());
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
        if (items[0] != Symbol.empty and allEqual(Symbol, items[0..])) {
            return if (items[0] == Symbol.o) .o_win else .x_win;
        }
    }

    // check for tie
    if (!any(Symbol, Symbol.empty, board[0..])) {
        return State.tie;
    }

    // Switch turns
    return switch (game.state) {
        .x_turn => .o_turn,
        .o_turn => .x_turn,
        else => game.state,
    };
}

test "nextState" {
    const x_turn_game = Game{ .state = State.x_turn };

    try std.testing.expect(nextState(x_turn_game) == State.o_turn);
}
