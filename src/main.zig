const std = @import("std");

const permutations = @import("permutations.zig");
const cubies = @import("cubies.zig");
const solver = @import("solver.zig");

const MoveTables = @import("MoveTables.zig");

pub fn main() !void {
    const solutions = [_][]const u8{
        "U2 D' R' U' F  L2 U  R2 F  L  U  L2 U' L2 B2 U2 R2 U' F2 D' F2 D",
        "U2 D' R' U' F  L2 U  R2 F  L  U' R2 D2 R2 U' R2 F2 D  L2 U' F2 D",
        "U2 D' R' U' F  L2 U  R2 F  L  U  L  L  U' L2 B2 U2 R2 U' F2 D' F2 D",
        "U2 D' R' U' F  L2 U  R2 F  L  U  L2 U  U2 L2 B2 U2 R2 U' F2 D' F2 D",
        "U2 D' R' U' F  L2 U  R2 F  L  U  L2 U2 U  L2 B2 U2 R2 U' F2 D' F2 D",
        "U2 D' R' U' F  L2 U  R2 F  L  U  L2 U' L  L  B2 U2 R2 U' F2 D' F2 D",
        "U2 D' R' U' F  L2 U  R2 F  L  U  L2 U' L2 U2 R2 D2 F2 D  L2 U' F2 D",
        "U2 D' R' U' F  L2 U  R2 F  L  U  L2 U' L2 B  B  U2 R2 U' F2 D' F2 D",
        "U2 D' R' U' F  L2 U  R2 F  L  U  L2 U' L2 B2 U  U  R2 U' F2 D' F2 D",
        "U2 D' R' U' F  L2 U  R2 F  L  U  L2 U' L2 B2 U2 R  R  U' F2 D' F2 D",
    };

    const scramble = "B2 F2 L2 U2 B2 D2 F2 U2 L B2 D F' L' D U B' U F' L2 F'";

    std.debug.print("Scramble: {s}\n", .{ scramble });

    var cube = cubies.CubieCube.initFromAlgorithmString(scramble);
    cube.algorithmString(scramble);

    std.debug.print("{}\n", .{ cube });

    for (solutions, 0..) |solution, i| {
        std.debug.print("Solution {}: {s}\n", .{ i, solution });
        cube = cubies.CubieCube.initFromAlgorithmString(scramble);
        cube.algorithmString(solution);
        std.debug.print("{}\n", .{ cube });
    }

    try MoveTables.generateAll();
    ////solver.generateSlicePermutationMovesTable();
    //try solver.generatePhase1PruneTable();
    //try solver.generatePhase2PruneTable();

    //try solver.findSolution(&cube);

    //std.debug.print("{}", .{ cube });
}
