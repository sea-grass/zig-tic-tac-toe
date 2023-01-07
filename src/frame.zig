const std = @import("std");
const io = std.io;
const math = std.math;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const PriorityQueue = std.PriorityQueue;

// Frame is a way to draw positionally to a terminal, in batch.
//
// Demo:
//
// ```
// const Frame = @import("frame.zig");
//
// // the number of columns we want the frame to cover
// const width = 3;
// // height will help us compute the size of our backing buffer
// const height = 3;
//
// var buf: [_]u8 = .{0} ** (width*height);
// var buf2: [_]u8 = .{0} ** (width*height);
//
// var frame: Frame = .{ .buf_a = &buf, .buf_b = &buf2 };
//
// {
//   var title = frame.subframe(0, 0).writer();
//   try title.print("abc", .{});
//
//   var footer = frame.subframe(2, 0).writer();
//   try footer.print("...", .{});
//
//   var smiley = frame.subframe(1, 1).writer();
//   try footer.print(":)", .{});
// }
//
//
// const data = frame.update();
// std.debug.print("{s}\n", .{ data });
// ```
//
// Internally, Frame uses a priority queue to keep track of writes, where `Write = struct { row: u8, col: u8, data: []const u8 }`.
// When a write enters the queue with the same row and col as an existing write, it will get applied to the frame later, meaning
// it will overwrite the contents of the previous write. All writes are queued up to be written in a batch when `frame.update()`
// is called. Once the frame is done with the writes, the priority queue is flushed.
//
// > In practice, this priority queue is actually processed _backwards_, since it assumes that whatever is written later should
// be displayed on top. Each time a character in the frame's buffer gets written, it is marked as "dirty." Now, when processing
// writes, the frame checks if this cell is dirty and only writes if it is not. This means that we can short circuit the writes
// if all cells get marked dirty. I'm sure there are more clever optimizations waiting there.
//
// `frame.update()` returns a slice to the current buffer, which is also available at frame.current. This slice is invalidated
// as soon as frame.update is called again.
//
// ```
// const height = 5;
// var frame = Frame.init(allocator, width, height);
// var data = frame.update();
// frame.subframe(2, 0).writer().print("Hello", .{});
// frame.subframe(0, 2).writer().print("world", .{});
// // this will print `height` newlines, effectively `height` empty lines.
// std.debug.print("{s}", .{ data });
// data = frame.update();
// // data looks like "  world\n\nHello\n" and will print:
// //   world
// //
// // Hello
// std.debug.print("{s}", .{ data });
// ```
//
// A frame can be instructed to fill empty spaces with a whitespace character. By default, it will uses spaces if there are still
// characters in the current row, otherwise will print a newline and skip rendering the unnecessary whitespace.

width: u32,
height: u32,
allocator: Allocator,
writes: WriteQueue,
whitespace_char: u8 = ' ',

const Frame = @This();
const Write = struct {
    row: u8,
    col: u8,
    data: []const u8,
};

const WriteQueue = PriorityQueue(Write, WriteCompare, WriteCompare.compareReverse);

const WriteCompare = struct {
    fn compare(_: @This(), a: Write, b: Write) math.Order {
        if (a.row < b.row) return .lt;
        if (a.row == b.row) {
            if (a.col < b.col) return .lt;
            if (a.col == b.col) return .eq;
            return .gt;
        }
        return .gt;
    }

    fn compareReverse(self: @This(), a: Write, b: Write) math.Order {
        return switch (self.compare(a, b)) {
            .lt => .gt,
            .gt => .lt,
            .eq => .eq,
        };
    }
};

pub fn init(a: Allocator, width: u8, height: u8) Frame {
    return .{
        .allocator = a,
        .writes = WriteQueue.init(a, .{}),
        .width = width,
        .height = height,
    };
}

pub fn deinit(frame: *Frame) void {
    frame.writes.deinit();
}

pub fn sub_frame(frame: *Frame, row: u8, col: u8) SubFrame {
    return .{
        .frame = frame,
        .row = row,
        .col = col,
    };
}

pub fn update(frame: *Frame) ![]const u8 {
    var buf: []u8 = try frame.allocator.alloc(u8, frame.width * frame.height);
    defer frame.allocator.free(buf);
    // fill with spaces to avoid unknown data
    std.mem.set(u8, buf, frame.whitespace_char);
    var list = ArrayList(u8).init(frame.allocator);
    defer list.deinit();

    // Write to fixed size buffer
    while (frame.writes.removeOrNull()) |write| {
        var start_index: usize = frame.width * write.row + write.col;
        var index: usize = start_index;
        std.debug.print("\nprocessing write({d}, {d}, {s})\n", .{ write.row, write.col, write.data });
        var curr: []const u8 = write.data[0..];
        while (curr.len > 0) {
            switch (curr[0]) {
                '\n' => {
                    buf[index] = 0;
                    // todo: index should be negative offset by the current col
                    index += frame.width;
                },
                else => |c| {
                    buf[index] = c;
                    index += 1;
                },
            }
            curr = curr[1..];
        }
    }

    // Read buffer into printable string
    {
        var row: usize = 0;

        row_it: while (row < frame.height) {
            var col: usize = 0;
            col_it: while (col < frame.width) {
                const i = frame.width * row + col;
                switch (buf[i]) {
                    0 => {
                        // marks end of line
                        try list.append('\n');
                        row += 1;
                        col = 0;
                        continue :row_it;
                    },
                    else => |c| {
                        try list.append(c);
                        col += 1;
                        continue :col_it;
                    },
                }
            }
            try list.append('\n');
            row += 1;
        }
    }
    return list.toOwnedSlice();
}

const SubFrame = struct {
    row: u8,
    col: u8,
    frame: *Frame,

    pub const WriteError = error{CouldNotWrite};
    pub const Writer = io.Writer(SubFrame, WriteError, write);

    pub fn writer(self: SubFrame) Writer {
        return .{ .context = self };
    }

    fn write(self: SubFrame, bytes: []const u8) WriteError!usize {
        self.frame.writes.add(.{
            .row = self.row,
            .col = self.col,
            .data = bytes,
        }) catch return WriteError.CouldNotWrite;
        return bytes.len;
    }
};

test {
    const rows = 10;
    const cols = 30;
    var frame = init(std.testing.allocator, cols, rows);
    frame.whitespace_char = '@';
    defer frame.deinit();

    {
        const title_str = "Tic Tac Toe";
        var title = frame.sub_frame(0, cols / 2 - title_str.len / 2).writer();
        try title.print("{s}", .{title_str});

        var footer = frame.sub_frame(2, 0).writer();
        try footer.print("...", .{});

        var smiley = frame.sub_frame(1, 1).writer();
        try smiley.print(":)", .{});
    }

    const data = try frame.update();
    defer std.testing.allocator.free(data);
    std.debug.print("\ndata\n{s}\n", .{data});
}
