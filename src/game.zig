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

pub const Command = union(enum) { unknown, quit, play: u8 };
pub const GameError = error{
    InputError,
    ViewError,
};
const State = enum { x_turn, o_turn, x_win, o_win, tie, quit };
const Symbol = enum { empty, x, o };
const Message = enum { none, input_too_long, invalid_number, invalid_choice, spot_already_occupied, unknown_input_error };

pub const Adapter = struct {
    viewFn: fn (a: *Adapter, g: Game) GameError!void,
    getCommandFn: fn (a: *Adapter) GameError!Command,

    pub fn view(self: *Adapter, game: Game) !void {
        try self.viewFn(self, game);
    }

    pub fn getCommand(self: *Adapter) !Command {
        const command = try self.getCommandFn(self);
        return command;
    }
};

pub const Game = struct {
    id: u8 = 0,
    adapter: Adapter,
    state: State = State.x_turn,
    board: [9]Symbol = [_]Symbol{Symbol.empty} ** 9,
    message: Message = Message.none,

    pub fn init(a: Adapter) Game {
        return Game{ .id = 1, .adapter = a };
    }

    pub fn view(self: *Game) !void {
        try self.adapter.view(self.*);
    }

    pub fn update(self: *Game) !void {
        const command = try self.adapter.getCommand();

        switch (command) {
            .play => |spot| {
                if (spot > 8) {
                    self.message = Message.invalid_choice;
                    return;
                }

                switch (self.board[spot]) {
                    .empty => switch (self.state) {
                        .x_turn => {
                            self.board[spot] = Symbol.x;
                        },
                        .o_turn => {
                            self.board[spot] = Symbol.o;
                        },
                        else => {},
                    },
                    else => {
                        self.message = Message.spot_already_occupied;
                        return;
                    },
                }
            },
            .quit => {
                self.state = State.quit;
                return;
            },
            .unknown => {
                self.message = Message.invalid_choice;
                return;
            },
        }

        const state = nextState(self.*);

        self.state = state;
        self.message = Message.none;
    }

    pub fn complete(self: Game) bool {
        return switch (self.state) {
            State.x_win => true,
            State.o_win => true,
            State.tie => true,
            State.quit => true,
            else => false,
        };
    }
};

test "complete" {
    const x_turn_game = Game{ .state = State.x_turn };
    const o_turn_game = Game{ .state = State.o_turn };
    const x_win_game = Game{ .state = State.x_win };
    const o_win_game = Game{ .state = State.o_win };
    const tie_game = Game{ .state = State.tie };
    const quit_game = Game{ .state = State.quit };

    assert(!x_turn_game.complete());
    assert(!o_turn_game.complete());
    assert(x_win_game.complete());
    assert(o_win_game.complete());
    assert(tie_game.complete());
    assert(quit_game.complete());
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
            if (items[0] == Symbol.o) {
                return State.o_win;
            } else if (items[0] == Symbol.x) {
                return State.x_win;
            }
        }
    }

    // check for tie
    if (!any(Symbol, Symbol.empty, board[0..])) {
        return State.tie;
    }

    // Switch turns
    if (game.state == State.x_turn) {
        return State.o_turn;
    } else if (game.state == State.o_turn) {
        return State.x_turn;
    }

    return game.state;
}

test "nextState" {
    const x_turn_game = Game{ .state = State.x_turn };

    assert(nextState(x_turn_game) == State.o_turn);
}
