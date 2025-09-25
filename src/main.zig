const std = @import("std");
const permutations = @import("permutations.zig");

pub const checker = "R2 L2 F2 B2 U2 D2";
pub const tPerm   = "R U R' U' R' F R2 U' R' U' R U R' F'";

const solver = @import("solver.zig");

pub fn main() !void {
    var cube = permutations.solved;
    cube.algorithmString("B2 F2 L2 U2 B2 D2 F2 U2 L B2 D F' L' D U B' U F' L2 F'");

    solver.generateEdgeOrientationMovesTable();
    solver.generateCornerOrientationMovesTable();
    solver.generateSlicePermutationMovesTable();
    try solver.generatePhase1PruneTable();

    try solver.findSolution(cube);

    //std.debug.print("{}", .{ cube });
}
