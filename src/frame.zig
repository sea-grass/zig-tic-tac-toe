// frame.zig
// Author: sea-grass
// Date: Jan 8 2023
//
// Frame helps you draw text to the terminal, positionally, in a declarative way. It places each write in an ordered
// queue and then renders them all at once and returns a slice you can print to the terminal.
//
//
// When a Frame is initialized, it is provided the number of rows and cols the buffer should contain.
// Under the hood, it creates a buffer of size `rows*cols` to reuse whenever it is asked to write all chunks.
//
// Frame exposes SubFrames, which have an origin within the frame, expose a Writer, and keep track of write offsets.
// Each time a Writer's `write` is called, it makes a copy of the data and adds a Write to the WriteQueue.
//
// When a Frame is asked to "update" it clears its internal buffer and processes the writes, in row/col order, from the WriteQueue.
// Once a Write is processed, the memory for it and its data buffer is released. Each Write keeps track of the SubFrame's row/col
// and the offset from this point this write should begin. Knowing the offset separately allows us to perform line wrapping
// using the Frame's width. The queue is flushed during this process, which completes when the queue is empty.
//
// The WriteQueue, which the Frame uses to keep track of Writes, keeps each Write ordered based on their row/col. Our "drawing"
// style considers higher rows to be "closer" and lower rows to be "farther." We start with the highest row/col Write and lowest
// offset and work our way backwards. Each byte we change in the buffer is marked dirty. Dirty cells are never overwritten
// during an update. This means that we can short circuit the writes if all cells get marked dirty. I'm sure there are more
// clever optimizations waiting there.
//
// A Frame can be configured to fill empty spaces with a whitespace character. By default, it will uses spaces if there are still
// characters in the current row, otherwise will print a newline and skip rendering the unnecessary whitespace.
//
// Right now, out-of-bounds Writes are ignored, and writers may unknowingly attempt to print out of bounds without any
// warning. It is possible to detect this when a write is queued, so it's an optimization that can be added later.
//
// This Frame structure could be used to build a DoubleBufferFrame, which would manage two Frames internally, but this would
// only be helpful in practice in a multithreaded setting, and Frame definitely isn't threadsafe as it is.
//
// It might be useful to supply a SubFrame with a width to allow text wrapping to wrap around within the frame instead of all
// the way around. A change like this would make a Frame and SubFrame so similar, that it might not be useful to distinguish them.
// If it gets to this point, it might be better to consider a FrameList and a Frame (or even if the exact width/height isn't
// known ahead of time), where each Frame.Writer adds to its own write queue and when a FrameList is updated, it flushes
// all if its Frames's queues as it writes them to a dynamically allocated buffer. Each Frame could still be able to flush
// its own queue into its own buffer, allowing them to work independently of a FrameList.

const std = @import("std");
const io = std.io;
const math = std.math;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const PriorityQueue = std.PriorityQueue;

width: u64,
height: u64,
whitespace_char: u8 = default_whitespace_char,
allocator: Allocator,

current: ?[]u8 = null,
writes: WriteQueue,
subframe_ptrs: ArrayList(*SubFrame),
// buffer and dirty are initialized on-demand, when the first update
// occurs, and only get freed once the frame is destroyed.
buffer: ?[]u8 = null,
dirty: ?[]bool = null,

const default_whitespace_char = ' ';

const Frame = @This();
const Write = struct {
    row: u64,
    col: u64,
    offset: u64,
    data: []const u8,
};

const WriteQueue = PriorityQueue(*Write, WriteCompare, WriteCompare.compareReverse);

const WriteCompare = struct {
    fn compare(_: @This(), a: *Write, b: *Write) math.Order {
        if (a.row < b.row) return .lt;
        if (a.row == b.row) {
            if (a.col < b.col) return .lt;
            if (a.col == b.col) return .eq;
            return .gt;
        }
        return .gt;
    }

    fn compareReverse(self: @This(), a: *Write, b: *Write) math.Order {
        return switch (self.compare(a, b)) {
            .lt => .gt,
            .eq => .eq,
            .gt => .lt,
        };
    }
};

pub fn init(a: Allocator, width: u64, height: u64) Frame {
    return .{
        .allocator = a,
        .writes = WriteQueue.init(a, .{}),
        .subframe_ptrs = ArrayList(*SubFrame).init(a),
        .width = width,
        .height = height,
    };
}

pub fn deinit(frame: *Frame) void {
    // TODO: free current
    while (frame.writes.removeOrNull()) |write| {
        frame.allocator.free(write.data);
        frame.allocator.destroy(write);
    }
    frame.writes.deinit();

    for (frame.subframe_ptrs.items) |sf| {
        frame.allocator.destroy(sf);
    }
    frame.subframe_ptrs.deinit();

    if (frame.buffer) |_|
        frame.allocator.free(frame.buffer.?);
    if (frame.dirty) |_|
        frame.allocator.free(frame.dirty.?);
}

pub fn sub_frame(frame: *Frame, row: u64, col: u64) *SubFrame {
    var ptr = frame.allocator.create(SubFrame) catch unreachable;
    frame.subframe_ptrs.append(ptr) catch unreachable;

    ptr.* = .{
        .frame = frame,
        .row = row,
        .col = col,
    };

    return ptr;
}

pub fn update(frame: *Frame) ![]const u8 {
    // TODO: Join buffer and dirty in a simple struct
    // just can't think of naming atm. SingleWriteBuffer?
    // OverwriteForbiddenBuffer?
    if (frame.buffer == null and frame.dirty == null) {
        const len = frame.width * frame.height;
        frame.buffer = try frame.allocator.alloc(u8, len);
        frame.dirty = try frame.allocator.alloc(bool, len);
    }

    var buf = frame.buffer.?;
    // fill with spaces to avoid unknown data
    std.mem.set(u8, buf, frame.whitespace_char);

    var dirty = frame.dirty.?;
    std.mem.set(bool, dirty, false);

    var list = ArrayList(u8).init(frame.allocator);
    defer list.deinit();

    // Write to fixed size buffer
    writes: while (frame.writes.removeOrNull()) |write| {
        defer {
            frame.allocator.free(write.data);
            frame.allocator.destroy(write);
        }

        var start_index: usize = frame.width * write.row + write.col + write.offset;
        var index: usize = start_index;

        var curr: []const u8 = write.data[0..];
        while (curr.len > 0) {
            if (index >= buf.len) continue :writes;
            switch (curr[0]) {
                '\n' => {
                    if (!dirty[index]) {
                        buf[index] = 0;
                        dirty[index] = true;
                    }
                    // todo: index should be negative offset by the current col
                    index += frame.width;
                },
                else => |c| {
                    if (!dirty[index]) {
                        buf[index] = 0;
                        dirty[index] = true;
                    }
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

    // TODO free previous current
    frame.current = try list.toOwnedSlice();
    return frame.current.?;
}

const SubFrame = struct {
    row: u64,
    col: u64,
    offset: u64 = 0,
    frame: *Frame,

    pub const WriteError = error{ CouldNotCopyBytes, CouldNotWrite };
    pub const Writer = io.Writer(*SubFrame, WriteError, write);

    pub fn writer(self: *SubFrame) Writer {
        return .{ .context = self };
    }

    fn write(self: *SubFrame, bytes: []const u8) WriteError!usize {
        var data = ArrayList(u8).init(self.frame.allocator);
        defer data.deinit();

        data.appendSlice(bytes) catch return WriteError.CouldNotCopyBytes;

        var ptr = self.frame.allocator.create(Write) catch return WriteError.CouldNotCopyBytes;
        errdefer self.frame.allocator.destroy(ptr);

        ptr.* = .{
            .row = self.row,
            .col = self.col,
            .offset = self.offset,
            .data = data.toOwnedSlice() catch return WriteError.CouldNotCopyBytes,
        };

        self.frame.writes.add(ptr) catch return WriteError.CouldNotWrite;

        self.offset += bytes.len;

        return bytes.len;
    }
};

test {
    const rows = 5;
    const cols = 15;
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
        try smiley.print(" :(", .{});

        var numbers = frame.sub_frame(4, 0).writer();
        const nums = .{ 1, 2, 3, 4 };
        inline for (nums) |num| {
            try numbers.print("{d}, ", .{num});
        }

        var numbers2 = frame.sub_frame(5, 17).writer();
        try numbers2.print("1, ", .{});
    }

    const data = try frame.update();
    defer std.testing.allocator.free(data);
    std.debug.print("\ndata\n{s}\n", .{data});
}

test "write without update" {
    const a = std.testing.allocator;
    var f = Frame.init(a, 1, 2);
    defer f.deinit();

    try f.sub_frame(0, 0).writer().print("19", .{});

    // We don't need to make any assertions.
    // The testing allocator will alert us if we leak memory.
}

test "overwrite" {
    const a = std.testing.allocator;
    var f = Frame.init(a, 2, 2);
    defer f.deinit();

    try f.sub_frame(1, 0).writer().print("19", .{});
    try f.sub_frame(1, 0).writer().print("hf", .{});
    try f.sub_frame(0, 0).writer().print("gl\ngg", .{});

    const data = try f.update();
    defer std.testing.allocator.free(data);

    std.debug.print("\ndata\n{s}\n", .{data});
    try std.testing.expect(std.mem.eql(u8, data, "gl\nhf\n"));
}
