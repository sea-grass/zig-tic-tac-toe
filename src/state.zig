const Symbol = @import("symbol.zig").Symbol;

pub const State = enum {
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

    pub fn symbol(state: State) Symbol {
        return switch (state) {
            .x_turn, .x_win => .x,
            .o_turn, .o_win => .o,
            else => .empty,
        };
    }
};
