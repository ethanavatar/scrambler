const std = @import("std");

const permutations = @import("permutations.zig");
const cubies = @import("cubies.zig");
const solver = @import("solver.zig");

const Tables = @import("Tables.zig");
const allocators = @import("allocators.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    try Tables.generateAll();
    defer Tables.freeAll();

    const scramble = "B2 F2 L2 U2 B2 D2 F2 U2 L B2 D F' L' D U B' U F' L2 F'";

    std.debug.print("Scramble: {s}\n", .{ scramble });
    var cube = cubies.CubieCube.initFromAlgorithmString(scramble);
    std.debug.print("{f}\n", .{ cube });

    const solutions = try solver.findSolutions(cube, 10, allocator);
    std.debug.print("Generated {} Solutions.\n", .{ solutions.items.len });

    for (solutions.items, 1..) |solution, i| {
        cube = cubies.CubieCube.initFromAlgorithmString(scramble);

        std.debug.print("Solution {}: ", .{ i });
        for (solution) |move| {
            std.debug.print("{f} ", .{ move });
            cube.turn(move);
        }
        std.debug.print("\n", .{ });

        //std.debug.print("{f}\n", .{ cube });
    }
}
