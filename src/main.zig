const std = @import("std");
const permutations = @import("permutations.zig");

pub const checker = "R2 L2 F2 B2 U2 D2";
pub const tPerm   = "R U R' U' R' F R2 U' R' U' R U R' F'";

pub fn main() !void {
    var cube = permutations.solved;
    cube.algorithmString(tPerm);

    std.debug.print("{}", .{ cube });
}
