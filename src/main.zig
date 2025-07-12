const std = @import("std");
const utilities = @import("utilities.zig");
const model = @import("cubies.zig");
const moves = @import("moves.zig");

pub fn main() !void {
    var cube: model.CubieCube = moves.solved;
    cube.move(.Right, 2);
    cube.move(.Left,  2);
    cube.move(.Front, 2);
    cube.move(.Back,  2);
    cube.move(.Up,    2);
    cube.move(.Down,  2);

    std.debug.print("{}", .{ cube });
}
