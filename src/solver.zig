const std = @import("std");

const math = @import("math.zig");
const algorithms = @import("algorithms.zig");
const cubies = @import("cubies.zig");
const permutations = @import("permutations.zig");

const MoveTables = @import("MoveTables.zig");
const PruneTables = @import("PruneTables.zig");

pub const allMoves = [_]cubies.CubeMove{
    .{ .face = .Right, .order = 1 }, .{ .face = .Right, .order = 2 }, .{ .face = .Right, .order = 3 },
    .{ .face = .Left,  .order = 1 }, .{ .face = .Left,  .order = 2 }, .{ .face = .Left,  .order = 3 },
    .{ .face = .Up,    .order = 1 }, .{ .face = .Up,    .order = 2 }, .{ .face = .Up,    .order = 3 },
    .{ .face = .Down,  .order = 1 }, .{ .face = .Down,  .order = 2 }, .{ .face = .Down,  .order = 3 },
    .{ .face = .Front, .order = 1 }, .{ .face = .Front, .order = 2 }, .{ .face = .Front, .order = 3 },
    .{ .face = .Back,  .order = 1 }, .{ .face = .Back,  .order = 2 }, .{ .face = .Back,  .order = 3 },
};

const g1Moves = [_]cubies.CubeMove{
    .{ .face = .Right, .order = 2 },
    .{ .face = .Left,  .order = 2 },
    .{ .face = .Up,    .order = 1 }, .{ .face = .Up,   .order = 2 }, .{ .face = .Up,   .order = 3 },
    .{ .face = .Down,  .order = 1 }, .{ .face = .Down, .order = 2 }, .{ .face = .Down, .order = 3 },
    .{ .face = .Front, .order = 2 },
    .{ .face = .Back,  .order = 2 },
};

pub fn encodeEdgeOrientation(cube: cubies.CubieCube) u16 {
    var flip: u16 = 0;
    var factor: u16 = 1;
    var sum: u16 = 0;

    for (0..11) |i| {
        flip += cube.edgeOrientations[i] * factor;
        sum += cube.edgeOrientations[i];
        factor *= 2;
    }

    const expected = (2 - (sum % 2)) % 2;
    if (cube.edgeOrientations[11] != expected) {
        std.debug.print("expected: {}, actual: {}\n", .{ expected, cube.edgeOrientations[11] });
        std.debug.assert(cube.edgeOrientations[11] == expected);
    }

    return flip;
}

pub fn decodeEdgeOrientation(coord: u16, _: std.mem.Allocator) !cubies.CubieCube {
    var current_coord = coord;
    var results: [12]u8 = undefined;
    var sum: usize = 0;

    for (0..11) |i| {
        const o: u8 = @intCast(current_coord & 1);
        results[i] = o;
        sum += o;
        current_coord /= 2;
    }

    results[11] = @intCast((2 - (sum % 2)) % 2);

    var cube = cubies.CubieCube.solved();
    cube.edgeOrientations = results;

    return cube;
}

test {
    const cube = cubies.CubieCube.initFromAlgorithmString(algorithms.mitch);

    const expectations = [12]u8{ 0, 1, 0, 1,   0, 0, 0, 0,   0, 0, 1, 1 };
    try std.testing.expectEqual(expectations, cube.edgeOrientations);
    try std.testing.expectEqual(expectations, decodeEdgeOrientation(encodeEdgeOrientation(cube)));
    try std.testing.expectEqual(0b10000001010, encodeEdgeOrientation(cube));
}

pub fn encodeCornerOrientation(cube: cubies.CubieCube) u16 {
    var twist: u16 = 0;
    var factor: u16 = 1;
    var sum: u16 = 0;

    for (0..7) |i| {
        twist += cube.cornerOrientations[i] * factor;
        sum += cube.cornerOrientations[i];
        factor *= 3;
    }

    std.debug.assert(cube.cornerOrientations[7] == (3 - (sum % 3)) % 3);
    return twist;
}

pub fn decodeCornerOrientation(twist: u16, _: std.mem.Allocator) !cubies.CubieCube {
    var coord = twist;
    var results: [8]u8 = undefined;
    var sum: usize = 0;

    for (0..7) |i| {
        const o: u8 = @intCast(coord % 3);
        results[i] = o;
        sum += o;
        coord /= 3;
    }

    results[7] = @intCast((3 - (sum % 3)) % 3);

    var cube = cubies.CubieCube.solved();
    cube.cornerOrientations = results;

    return cube;
}

test {
    const cube = cubies.CubieCube.initFromAlgorithmString(algorithms.mitch);

    const expectations = [8]u8{ 0, 2, 2, 1,   0, 1, 1, 2 };
    try std.testing.expectEqual(expectations, cube.cornerOrientations);
    try std.testing.expectEqual(expectations, decodeCornerOrientation(encodeCornerOrientation(cube))); 
    try std.testing.expectEqual(0b001111111111, encodeCornerOrientation(cube)); // TODO: Base 3 converter
}

pub fn encodeCoordinateToTableIndex(coordinate: CoordinateCube) ?usize {
    return coordinate.edgeOrientation + @as(usize, 2048) * coordinate.cornerOrientation;
}

pub fn decodeTableIndexToCoordinate(index: usize) ?CoordinateCube {
    return .{
        .edgeOrientation   = @intCast(@mod(index, 2048)),
        .cornerOrientation = @intCast(@divFloor(index, 2048)),
    };
}

test {
    for (0..2048 * 2187) |index| {
        try std.testing.expectEqual(
            index,
            encodeCoordinateToTableIndex(decodeTableIndexToCoordinate(index)),
        );
    }
}

pub const CoordinateCube = struct {
    edgeOrientation:   u16 = 0,
    edgePermutation:   u16 = 0,
    cornerOrientation: u16 = 0,
    cornerPermutation: u16 = 0,

    pub fn fromCubies(cubie_cube: cubies.CubieCube) CoordinateCube {
        return .{
            .edgeOrientation = encodeEdgeOrientation(cubie_cube),
            .edgePermutation = encodeEdgePermutation(cubie_cube),
            .cornerOrientation = encodeCornerOrientation(cubie_cube),
            .cornerPermutation = encodeCornerPermutation(cubie_cube),
        };
    }

    pub fn move(self: *const CoordinateCube, move_index: usize) CoordinateCube {
        return .{
            .edgeOrientation = MoveTables.edgeOrientation[self.edgeOrientation][move_index],
            .edgePermutation = MoveTables.edgePermutation[self.edgePermutation][move_index],
            .cornerOrientation = MoveTables.cornerOrientation[self.cornerOrientation][move_index],
            .cornerPermutation = MoveTables.cornerPermutation[self.cornerPermutation][move_index],
        };
    }
};

pub fn encodePhase2CoordToIndex(cube: CoordinateCube) ?usize {
    if ((cube.cornerPermutation > 40320) or (cube.edgePermutation > 40320)) {
        std.debug.print("Corner: {}, Edge: {}\n", .{ cube.cornerPermutation, cube.edgePermutation });
        unreachable;
    }

    const valid_edge_rank = cube.edgePermutation / 2;
    return cube.cornerPermutation * @as(usize, 20160) + valid_edge_rank;
}

pub fn decodePhase2IndexToCoord(index: usize) ?CoordinateCube {
    const corner_rank = index / 20160;
    const edge_rank = (index % 20160) * 2 + (corner_rank % 2);

    if ((corner_rank > 40320) or (edge_rank > 40320)) {
        std.debug.print("Corner: {}, Edge: {}\n", .{ corner_rank, edge_rank });
        return null;
    }

    return .{
        .cornerPermutation = @intCast(corner_rank),
        .edgePermutation   = @intCast(edge_rank),
    };
}

test {
    for (0..std.math.maxInt(u16)) |index| {
        try std.testing.expectEqual(
            index,
            encodePhase2CoordToIndex(decodePhase2IndexToCoord(index) orelse unreachable),
        );
    }
}

pub fn encodeCornerPermutation(cube: cubies.CubieCube) u16 {
    var elements: [8]u8 = undefined;
    for (cube.cornerPermutations, 0..8) |piece, i| {
        elements[i] = @intFromEnum(piece);
    }

    const rank = math.lexicographicRank(&elements);
    if (rank > 40320) {
        std.debug.print("Corner rank: {} (max = {})\n", .{ rank, 40320 });
        unreachable;
    }

    return @intCast(rank);
}

pub fn decodeCornerPermutation(rank: u16, allocator: std.mem.Allocator) !cubies.CubieCube {
    const pieces = [_]cubies.Corner{
        .ULB, .URB, .UFR, .ULF,
        .DLF, .DFR, .DRB, .DLB,
    };

    var elements: [pieces.len]u8 = undefined;
    for (pieces, 0..8) |piece, i| {
        elements[i] = @intFromEnum(piece);
    }

    const perm = try math.lexicographicUnrank(&elements, rank, allocator);
    var cube = cubies.CubieCube.solved();

    for (perm.items, 0..) |cubie, i| {
        cube.cornerPermutations[i] = @enumFromInt(cubie);
    }

    return cube;
}

pub fn encodeEdgePermutation(cube: cubies.CubieCube) u16 {
    const options = [_]cubies.Edge{
        .UB, .UR, .UF, .UL,
        .DF, .DR, .DB, .DL,
    };

    var elements: [8]u8 = undefined;
    for (options, 0..8) |option, i| {
        elements[i] = @intFromEnum(cube.edgePermutations[@intFromEnum(option)]);
    }

    const rank = math.lexicographicRank(&elements);
    if (rank > 40320) {
        std.debug.print("Edge rank: {} (max = {})\n", .{ rank, 40320 });
        unreachable;
    }

    return @intCast(rank);
}

pub fn decodeEdgePermutation(rank: u16, allocator: std.mem.Allocator) !cubies.CubieCube {
    const slots = [_]cubies.Edge{
        .UB, .UR, .UF, .UL,
        .DF, .DR, .DB, .DL,
    };

    var elements: [8]u8 = undefined;

    for (slots, 0..8) |slot, i| {
        elements[i] = @intFromEnum(slot);
    }

    const perm = try math.lexicographicUnrank(&elements, rank, allocator);

    var cube = cubies.CubieCube.solved();
    for (slots, 0..8) |slot, i| {
        cube.edgePermutations[@intFromEnum(slot)] = @enumFromInt(perm.items[i]);
    }

    return cube;
}

fn isSolved(cube: cubies.CubieCube) bool {
    const reference = cubies.CubieCube.solved();
    var not_solved = false;
    for (cube.edgePermutations,   reference.edgePermutations)   |l, r| not_solved = not_solved or (l != r);
    for (cube.cornerPermutations, reference.cornerPermutations) |l, r| not_solved = not_solved or (l != r);
    for (cube.edgeOrientations,   reference.edgeOrientations)   |l, r| not_solved = not_solved or (l != r);
    for (cube.cornerOrientations, reference.cornerOrientations) |l, r| not_solved = not_solved or (l != r);
    return !not_solved;
}

test {
    const solved = cubies.CubieCube.solved(); 
    try std.testing.expectEqual(true, isSolved(solved));

    const not_solved = cubies.CubieCube.initFromAlgorithmString(algorithms.mitch); 
    try std.testing.expectEqual(false, isSolved(not_solved));
}

fn isDominoReduced(cube: cubies.CubieCube) bool {
    for (cube.edgePermutations, 0..) |edge, edge_index| {
        const slot: cubies.Edge = @enumFromInt(edge_index);
        if (edge == slot) {
            // Already solved
            continue;
        }

        var is_g1 = false;

        for (g1Moves) |move1| {
            var temp_cube: cubies.CubieCube = cube;
            temp_cube.turn(move1);

            if ((temp_cube.edgePermutations[edge_index] == slot) and (temp_cube.edgeOrientations[edge_index] == 0)) {
                // Now solved
                is_g1 = true;
                break;
            } else {
                for (g1Moves) |move2| {
                    temp_cube.turn(move2);

                    if ((temp_cube.edgePermutations[edge_index] == slot) and (temp_cube.edgeOrientations[edge_index] == 0)) {
                        // Now solved
                        is_g1 = true;
                        break;
                    }
                }
            }
        }

        if (!is_g1) {
            return false;
        }
    }

    for (cube.cornerPermutations, 0..) |corner, corner_index| {
        const slot: cubies.Corner = @enumFromInt(corner_index);
        if (corner == slot) {
            // Already solved
            continue;
        }

        var is_g1 = false;

        for (g1Moves) |move1| {
            var temp_cube: cubies.CubieCube = cube;
            temp_cube.turn(move1);

            if ((temp_cube.cornerPermutations[corner_index] == slot) and (temp_cube.cornerOrientations[corner_index] == 0)) {
                // Now solved
                is_g1 = true;
                break;
            } else {
                for (g1Moves) |move2| {
                    temp_cube.turn(move2);

                    if ((temp_cube.cornerPermutations[corner_index] == slot) and (temp_cube.cornerOrientations[corner_index] == 0)) {
                        // Now solved
                        is_g1 = true;
                        break;
                    }
                }
            }
        }

        if (!is_g1) {
            return false;
        }
    }

    return true;
}

test {
    var cube = cubies.CubieCube.initFromAlgorithmString("R2 L2 F2 B2");
    try std.testing.expect(isDominoReduced(cube));

    cube = cubies.CubieCube.initFromAlgorithmString("R L2 F2 B2");
    try std.testing.expect(isDominoReduced(cube) == false);

    cube = cubies.CubieCube.initFromAlgorithmString("U' R2 U L2 D B2 D' F2");
    try std.testing.expect(isDominoReduced(cube));

    cube = cubies.CubieCube.initFromAlgorithmString("U' R U L2 D B2 D' F2");
    try std.testing.expect(isDominoReduced(cube) == false);
}

const max_depth: usize = 99;

var max_solutions: usize = 0;

pub fn findSolutions(
    c: cubies.CubieCube, solutions_count: usize,
    allocator: std.mem.Allocator,
) !std.ArrayList([]cubies.CubeMove) {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    max_solutions = solutions_count;

    var cube = c;

    var solutions = std.ArrayList([]cubies.CubeMove).init(allocator);

    for (0..max_depth) |depth| {
        var moves = std.ArrayList(cubies.CubeMove).init(arena.allocator());
        defer moves.deinit();

        try firstPhaseSearch(&cube, depth, &moves, &solutions);

        if (solutions.items.len >= max_solutions) {
            break;
        }
    }

    return solutions;
}

fn firstPhaseSearch(
    cube: *cubies.CubieCube, depth: usize, moves: *std.ArrayList(cubies.CubeMove),
    solutions: *std.ArrayList([]cubies.CubeMove)
) !void {
    if (depth == 0) {
        if (moves.items.len > 0) {
            const previous_move = moves.getLast();
            const was_side_move = previous_move.face == .Right
                or previous_move.face == .Left
                or previous_move.face == .Front
                or previous_move.face == .Back;

            const was_quarter_turn = previous_move.order == 1 or previous_move.order == 3;

            if (isDominoReduced(cube.*) and was_side_move and was_quarter_turn) {
                try secondPhaseStart(cube, depth, moves, solutions);
            }
        }

    } else if (depth > 0) {
        const p = CoordinateCube.fromCubies(cube.*);
        const index = encodeCoordinateToTableIndex(p) orelse unreachable;
        const prune_depth = PruneTables.phase1[index];

        if (prune_depth <= depth) {
            for (allMoves) |move| {
                cube.turn(move);
                defer cube.turn(move.inverse());

                try moves.append(move);
                defer _ = moves.pop();

                try firstPhaseSearch(cube, depth - 1, moves, solutions);

                if (solutions.items.len >= max_solutions) {
                    break;
                }
            }
        }
    }
}

fn secondPhaseStart(
    cube: *cubies.CubieCube, current_depth: usize, moves: *std.ArrayList(cubies.CubeMove),
    solutions: *std.ArrayList([]cubies.CubeMove)
) !void {
    for (0..max_depth - current_depth) |depth| {
        secondPhaseSearch(cube, depth, moves, solutions);
        if (solutions.items.len >= max_solutions) {
            break;
        }
    }
}

fn secondPhaseSearch(
    cube: *cubies.CubieCube, depth: usize, moves: *std.ArrayList(cubies.CubeMove),
    solutions: *std.ArrayList([]cubies.CubeMove)
) void {
    if (depth == 0) {
        if (moves.items.len > 0) {
            if (isSolved(cube.*)) {
                const allocator = solutions.allocator;

                // TODO: Use toOwnedSlice(Allocator) in zig 0.15
                const solution = allocator.alloc(cubies.CubeMove, moves.items.len) catch unreachable;
                std.mem.copyForwards(cubies.CubeMove, solution, moves.items);

                solutions.append(solution) catch unreachable;
            }
        }

    } else if (depth > 0) {
        const p = CoordinateCube.fromCubies(cube.*);
        const index = encodePhase2CoordToIndex(p) orelse unreachable;
        const prune_depth = PruneTables.phase2[index];

        if (prune_depth <= depth) {
            for (allMoves) |move| {
                cube.turn(move);
                defer cube.turn(move.inverse());

                moves.append(move) catch unreachable;
                defer _ = moves.pop();

                secondPhaseSearch(cube, depth - 1, moves, solutions);

                if (solutions.items.len >= max_solutions) {
                    break;
                }
            }
        }
    }
}

