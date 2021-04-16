const std = @import("std");
const fmt = std.fmt;
const Writer = std.fs.File.Writer;
const Reader = std.fs.File.Reader;
const game = @import("game.zig");
const Game = game.Game;
const Message = game.Message;
const Command = game.Command;
const Adapter = game.Adapter;
const GameError = game.GameError;

pub const ReplAdapter = struct {
    const Self = @This();

    adapter: Adapter,
    writer: Writer,
    reader: Reader,

    pub fn init(reader: Reader, writer: Writer) Self {
        return Self{ .adapter = Adapter{ .viewFn = view, .getCommandFn = getCommand }, .reader = reader, .writer = writer };
    }

    pub fn view(a: *Adapter, g: Game) GameError!void {
        // TODO: Fix the errors from `fieldParentPtr` dereferencing
        //const self = @fieldParentPtr(Self, "adapter", a);
        //const writer = self.writer;
        const writer = std.io.getStdOut().writer();

        print(g, writer) catch return GameError.ViewError;
    }

    pub fn getCommand(a: *Adapter) GameError!Command {
        // TODO: Fix the errors from `fieldParentPtr` dereferencing
        //const self = @fieldParentPtr(Self, "adapter", a);
        //const reader = self.reader;
        const reader = std.io.getStdIn().reader();

        const line = readLine(reader) catch |err| switch (err) {
            error.InputTooLong => {
                return Command.unknown;
            },
            else => {
                return Command.unknown;
            },
        };

        const guess = fmt.parseUnsigned(u8, line, 10) catch return Command.unknown;

        return Command{ .play = guess };
    }
};

fn print(g: Game, writer: Writer) !void {
    try writer.print("Tic Tac Toe\n===========\n", .{});
    try viewBoard(g, writer);
    try viewState(g, writer);
    try viewMessage(g, writer);
}

fn viewBoard(g: Game, writer: Writer) callconv(.Inline) !void {
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

fn viewState(g: Game, writer: Writer) callconv(.Inline) !void {
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

fn viewMessage(g: Game, writer: Writer) callconv(.Inline) !void {
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

fn readLine(reader: Reader) ![]const u8 {
    var line_buf: [20]u8 = undefined;

    const amt = try reader.read(&line_buf);
    if (amt == line_buf.len) {
        return error.InputTooLong;
    }
    const line = std.mem.trimRight(u8, line_buf[0..amt], "\r\n");

    return line;
}
