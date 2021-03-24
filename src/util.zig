const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;

pub fn allEqual(comptime T: type, items: []const T) bool {
    // empty arrays technically don't have _different_ items
    if (items.len < 1) {
        return true;
    }

    const first = items[0];
    for (items[1..]) |item| {
        if (item != first) {
            return false;
        }
    }
    return true;
}

test "allEqual" {
    const different_items = [_]u8{ 1, 2 };
    const same_items = [_]u8{ 1, 1, 1 };
    const empty_items = [_]u8{};
    const single_items = [_]u8{1};

    assert(!allEqual(u8, different_items[0..]));
    assert(allEqual(u8, same_items[0..]));
    assert(allEqual(u8, empty_items[0..]));
    assert(allEqual(u8, single_items[0..]));
}
