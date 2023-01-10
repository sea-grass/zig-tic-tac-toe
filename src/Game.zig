const std = @import("std");
const command = @import("command.zig");
const compare = @import("compare.zig");
const Frame = @import("Frame.zig");
const Move = @import("Move.zig");
const State = @import("state.zig").State;
const Symbol = @import("symbol.zig").Symbol;
const Allocator = std.mem.Allocator;
const allEqual = compare.allEqual;
const any = compare.any;
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
view_frame: Frame,

pub fn init(a: Allocator) !Game {
    const rows = 20;
    const cols = 40;
    var frame = Frame.init(a, cols, rows);
    frame.whitespace_char = 'v';
    return .{
        .allocator = a,
        .moves = ArrayList(Move).init(a),
        .view_frame = frame,
    };
}

pub fn deinit(self: *Game) void {
    self.moves.deinit();
    self.view_frame.deinit();
}

pub fn start(g: *Game, reader: anytype, writer: anytype) !void {
    try g.view(writer);
    while (!g.complete()) {
        try g.update(reader);
        try g.view(writer);
    }
}

fn view(g: *Game, writer: anytype) !void {
    var title = g.view_frame.sub_frame(0, 2).writer();
    try title.print("{c} Tic Tac Toe {c}", .{ Symbol.x.char(), Symbol.o.char() });

    var board = g.view_frame.sub_frame(1, 0).writer();
    try g.viewBoard(board);

    var moves = g.view_frame.sub_frame(10, 0).writer();
    try g.viewMoves(moves);

    try g.viewState(g.view_frame.sub_frame(9, 2).writer());

    try g.viewMessage(g.view_frame.sub_frame(11, 0).writer());
    if (!g.complete()) {
        try g.viewRemainingSpots(g.view_frame.sub_frame(12, 0).writer());
    }

    const frame = try g.view_frame.update();
    // TODO Frame frees its own at the end of its  lifetime
    defer g.view_frame.allocator.free(frame);

    try writer.print("\n{s}", .{frame});
    if (!g.complete()) try g.viewPrompt(writer);
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
            try writer.print("{c}, it's your turn.", .{g.state.symbol().char()});
        },
        .x_win, .o_win => {
            try writer.print("The game's over. {c} wins!", .{g.state.symbol().char()});
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
    try writer.print("{c} ", .{g.state.symbol().char()});
}

fn viewBoard(g: Game, writer: anytype) !void {
    for (g.board) |square, i| {
        if (square == .empty) {
            try writer.print(" {d} ", .{i});
        } else try writer.print(" {s} ", .{square});
        if ((i + 1) % 3 == 0) {
            try writer.print("\n", .{});
        }
    }
}

fn viewMoves(game: Game, writer: anytype) !void {
    if (game.moves.items.len == 0) return;

    try writer.print("Moves: ", .{});
    for (game.moves.items) |m| {
        try writer.print("{c}{d} ", .{ m.symbol.char(), m.spot });
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
