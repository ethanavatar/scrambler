const std = @import("std");

const cubies = @import("cubies.zig");
const permutations = @import("permutations.zig");

const allMoves = [_]cubies.CubeMove{
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

fn binomialCoefficient(n: u64, k_in: u64) error{InvalidK}!u64 {
    if (n == 0)    return 0;
    if (k_in == 0) return 1;
    if (k_in > n)  return 0;

    const k = if (k_in < n - k_in) k_in else n - k_in;

    var result: u64 = 1;
    for (1..k + 1) |i| {
        result *= (n - i + 1);
        result /= i;
    }

    return result;
}

test {
    _ = binomialCoefficient(1, 2) catch |err| {
        try std.testing.expect(err == error.InvalidK);
    };
    try std.testing.expect(try binomialCoefficient(1, 0) == 1);
    try std.testing.expect(try binomialCoefficient(1, 1) == 1);
    try std.testing.expect(try binomialCoefficient(2, 0) == 1);
    try std.testing.expect(try binomialCoefficient(2, 1) == 2);
    try std.testing.expect(try binomialCoefficient(2, 2) == 1);
    try std.testing.expect(try binomialCoefficient(2, 2) == 1);
    try std.testing.expect(try binomialCoefficient(3, 0) == 1);
    try std.testing.expect(try binomialCoefficient(3, 1) == 3);
    try std.testing.expect(try binomialCoefficient(3, 3) == 1);
}

fn factorial(n: u64) u64 {
    var result: u64 = 1;

    for (1..n + 1) |i| {
        result *= i;
    }

    return result;
}

test {
    try std.testing.expectEqual(factorial(0), 1);
    try std.testing.expectEqual(factorial(1), 1);
    try std.testing.expectEqual(factorial(2), 2);
    try std.testing.expectEqual(factorial(3), 6);
    try std.testing.expectEqual(factorial(4), 24);
    try std.testing.expectEqual(factorial(5), 120);
}

fn lexicographicRank(permutation: []u8) u64 {
    const n = permutation.len;
    var rank: u64 = 0;

    for (0..n) |i| {
        var smaller_count: u64 = 0;
        for ((i + 1)..n) |j| {
            if (permutation[j] < permutation[i]) {
                smaller_count += 1;
            }
        }

        rank += smaller_count * factorial(n - i - 1);
    }

    return rank;
}

fn lexicographicUnrank(e: []const u8, r: u64, allocator: std.mem.Allocator) !std.ArrayList(u8) {
    const n = e.len;

    var elements = std.ArrayList(u8).init(allocator);
    defer elements.deinit();
    try elements.appendSlice(e);

    var permutation = std.ArrayList(u8).init(allocator);
    var rank = r;
    
    for (0..n) |i| {
        const f = factorial(n - i - 1);
        const index = rank / f;
        rank = rank % f;

        try permutation.append(elements.items[index]);

        for (index..elements.items.len - 1) |j| {
            elements.items[j] = elements.items[j + 1];
        }

        _ = elements.pop();
    }
    
    return permutation;
}

test {
    const elements = [_]u8{ 0, 1, 2, 3, 4, 5 };

    for (0..factorial(elements.len)) |rank| {
        const permutation = try lexicographicUnrank(&elements, rank, std.testing.allocator);
        defer permutation.deinit();

        //std.debug.print("rank: {}, permutation: {any}\n", .{ rank, permutation.items });
        try std.testing.expectEqual(rank, lexicographicRank(permutation.items));
    }
}

const Phase1Coordinate = struct {
    edgeOrientation:   u16,
    cornerOrientation: u16,
    slicePermutation:  u16,
};

fn encodeEdgeOrientation(cube: cubies.CubieCube) u16 {
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

fn decodeEdgeOrientation(coord: u16) [12]u8 {
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
    return results;
}

const mitch = "D2 L2 F2 D U2 R2 U' R' F2 L' U F2 R B' L2 D' B2 L2 R2";

test {
    var cube = permutations.solved;
    cube.algorithmString(mitch);

    const expectations = [12]u8{ 0, 1, 0, 1,   0, 0, 0, 0,   0, 0, 1, 1 };
    try std.testing.expectEqual(expectations, cube.edgeOrientations);
    try std.testing.expectEqual(expectations, decodeEdgeOrientation(encodeEdgeOrientation(cube)));
    try std.testing.expectEqual(0b10000001010, encodeEdgeOrientation(cube));
}

fn encodeCornerOrientation(cube: cubies.CubieCube) u16 {
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

fn decodeCornerOrientation(twist: u16) [8]u8 {
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
    return results;
}

test {
    var cube = permutations.solved;
    cube.algorithmString(mitch);

    const expectations = [8]u8{ 0, 2, 2, 1,   0, 1, 1, 2 };
    try std.testing.expectEqual(expectations, cube.cornerOrientations);
    try std.testing.expectEqual(expectations, decodeCornerOrientation(encodeCornerOrientation(cube))); 
    try std.testing.expectEqual(0b001111111111, encodeCornerOrientation(cube)); // TODO: Base 3 converter
}

fn isSliceEdge(edge: cubies.Edge) bool {
    return switch (edge) {
        .RF, .LF, .RB, .LB => true,
        else => false,
    };
}

test {
    try std.testing.expectEqual(true, isSliceEdge(.RF));
    try std.testing.expectEqual(true, isSliceEdge(.LF));
    try std.testing.expectEqual(true, isSliceEdge(.RB));
    try std.testing.expectEqual(true, isSliceEdge(.LB));

    try std.testing.expectEqual(false, isSliceEdge(.UB));
    try std.testing.expectEqual(false, isSliceEdge(.DF));
}

fn encodeSlicePermutation(cube: cubies.CubieCube) u16 {
    var slice_permutation: u16 = 0;

    var count: u32 = 4;
    
    var i: isize = 11;
    while (i >= 0): (i -= 1) {
        const edge = cube.edgePermutations[@intCast(i)];
        if (isSliceEdge(edge)) {
            count -= 1;
        } else {
            slice_permutation += @intCast(binomialCoefficient(@intCast(i), count) catch unreachable);
        }

        if (count == 0) break;
    }

    //for (cube.edgePermutations, 0..) |edge, edge_index| {
    //    std.debug.print("i: {}, k: {}\n", .{ i, count });
    //    switch (edge) {
    //        .RF, .LF, .RB, .LB => { count -= 1; },
    //        else => { slice_permutation += @intCast(binomialCoefficient(edge_index, count) catch unreachable); },
    //    }

    //    if (count == 0) break;
    //}

    return slice_permutation;
}

fn decodeSlicePermutation(slice_coord: u16) [4]cubies.Edge {
    var slices: [4]cubies.Edge = undefined;
    var slices_index: usize = 0;

    var coord = slice_coord;

    var k: u32 = 4;

    var i: isize = 11;
    while (i >= 0): (i -= 1) {
        const choice = binomialCoefficient(@intCast(i), k) catch unreachable;
        if (coord >= choice) {
            slices[slices_index] = @enumFromInt(i);
            slices_index += 1;

            coord -= @intCast(choice);

            k -= 1;
            if (k == 0) break;
        }
    }

    //for (0..12) |i| {
    //    if (k == 0) break;

    //    const choice = binomialCoefficient(i,k) catch unreachable;
    //    if (coord >= choice) {
    //        slices[slices_index] = @intCast(i);
    //        slices_index += 1;

    //        coord -= @intCast(choice);
    //        k -= 1;
    //    }
    //}

    return slices;
}

//test {
//    var cube = permutations.solved;
//    cube.algorithmString(mitch);
//
//    //const expectations = [4]cubies.Edge{ .UB, .DL, .LF, .LB };
//    try std.testing.expectEqual(269, encodeSlicePermutation(cube));
//    try std.testing.expectEqual(269, encodeSlicePermutation(decodeSlicePermutation(encodeSlicePermutation(cube))));
//}

fn cubiesToPhase1Coordinate(cube: cubies.CubieCube) Phase1Coordinate {
    return .{
        .edgeOrientation   = encodeEdgeOrientation(cube),
        .cornerOrientation = encodeCornerOrientation(cube),
        .slicePermutation  = encodeSlicePermutation(cube),
    };
}

var edgeOrientationMoves: [2048][allMoves.len]u16 = std.mem.zeroes([2048][allMoves.len]u16);

pub fn generateEdgeOrientationMovesTable() !void {
    for (0..2048) |flip_coord| {
        var cube = permutations.solved; 

        cube.edgeOrientations = decodeEdgeOrientation(@intCast(flip_coord));
        std.debug.assert(cubiesToPhase1Coordinate(cube).edgeOrientation == flip_coord);

        for (allMoves, 0..) |move, move_index| {
            const before = cube;

            cube.turn(move);
            edgeOrientationMoves[flip_coord][move_index] = encodeEdgeOrientation(cube);
            cube.turn(move.inverse());

            try std.testing.expectEqual(before.edgePermutations,   cube.edgePermutations);
            try std.testing.expectEqual(before.cornerPermutations, cube.cornerPermutations);
            try std.testing.expectEqual(before.edgeOrientations,   cube.edgeOrientations);
            try std.testing.expectEqual(before.cornerOrientations, cube.cornerOrientations);
        }
    }
}

var cornerOrientationMoves: [2187][allMoves.len]u16 = std.mem.zeroes([2187][allMoves.len]u16);

pub fn generateCornerOrientationMovesTable() !void {
    for (0..2187) |twist_coord| {
        var cube = permutations.solved; 

        cube.cornerOrientations = decodeCornerOrientation(@intCast(twist_coord));
        std.debug.assert(cubiesToPhase1Coordinate(cube).cornerOrientation == twist_coord);

        for (allMoves, 0..) |move, move_index| {
            const before = cube;

            cube.turn(move);
            cornerOrientationMoves[twist_coord][move_index] = encodeCornerOrientation(cube);
            cube.turn(move.inverse());

            try std.testing.expectEqual(before.edgePermutations,   cube.edgePermutations);
            try std.testing.expectEqual(before.cornerPermutations, cube.cornerPermutations);
            try std.testing.expectEqual(before.edgeOrientations,   cube.edgeOrientations);
            try std.testing.expectEqual(before.cornerOrientations, cube.cornerOrientations);
        }
    }
}

var slicePermutationMoves: [495][allMoves.len]u16 = std.mem.zeroes([495][allMoves.len]u16);

pub fn generateSlicePermutationMovesTable() void {
    for (0..495) |slice_coord| {
        var cube = permutations.solved; 

        const slices = decodeSlicePermutation(@intCast(slice_coord));

        for (slices, [4]cubies.Edge{ .RF, .LF, .RB, .LB }) |destination, source| {
            // TODO Test new orientation
            permutations.changeEdge(&cube, destination, source, 0);
            permutations.changeEdge(&cube, source, destination, 0);
        }

        std.testing.expectEqual(encodeSlicePermutation(cube), slice_coord) catch unreachable;

        for (allMoves, 0..) |move, move_index| {
            cube.turn(move);
            slicePermutationMoves[slice_coord][move_index] = encodeSlicePermutation(cube);
            cube.turn(move.inverse());
        }
    }
}

fn encodeCoordinateToTableIndex(coordinate: Phase1Coordinate) usize {
    return coordinate.edgeOrientation + @as(usize, 2048) * coordinate.cornerOrientation;
}

fn decodeTableIndexToCoordinate(index: usize) Phase1Coordinate {
    return .{
        .edgeOrientation   = @intCast(@mod(index, 2048)),
        .cornerOrientation = @intCast(@divFloor(index, 2048)),
        .slicePermutation  = 0,
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

var phase1Prune: []i32 = undefined;

pub fn generatePhase1PruneTable() !void {
    const allocator = std.heap.page_allocator;
    phase1Prune = try allocator.alloc(i32, 4478976);
    @memset(phase1Prune, -1);

    const solved_index: usize = encodeCoordinateToTableIndex(.{
        .edgeOrientation   = 0,
        .cornerOrientation = 0,
        .slicePermutation  = 0, // unused
    });

    phase1Prune[solved_index] = 0;

    var depth:  usize = 0;
    var filled: usize = 1;

    while (filled < (2048 * 2187)): (depth += 1) {
        for (0..phase1Prune.len) |i| {
            const v = phase1Prune[i];
            if (v == depth) {
                const coordinate = decodeTableIndexToCoordinate(i);
            
                for (allMoves, 0..) |_, move_index| {
                    const next_coordinate: Phase1Coordinate = .{
                        .edgeOrientation   = edgeOrientationMoves[coordinate.edgeOrientation][move_index],
                        .cornerOrientation = cornerOrientationMoves[coordinate.cornerOrientation][move_index],
                        //.slicePermutation  = slicePermutationMoves[coordinate.slicePermutation][move_index],
                        .slicePermutation  = 0,
                    }; 

                    const next_index: usize = encodeCoordinateToTableIndex(next_coordinate);

                    if (phase1Prune[next_index] == -1) {
                        phase1Prune[next_index] = @intCast(depth + 1);
                        filled += 1;
                    }
                }
            }
        }
    }
}

//const Phase2Coordinate = struct {
//
//};
//
//var phase2Prune: []i32 = undefined;
//
//pub fn generatePhase2PruneTable() !void {
//    const allocator = std.heap.page_allocator;
//    phase2Prune = try allocator.alloc(i32, 4478976);
//    @memset(phase2Prune, -1);
//
//    const solved_index: usize = encodeCoordinateToTableIndex(.{
//        .edgeOrientation   = 0,
//        .cornerOrientation = 0,
//        .slicePermutation  = 0, // unused
//    });
//
//    phase1Prune[solved_index] = 0;
//
//    var depth:  usize = 0;
//    var filled: usize = 1;
//
//    while (filled < (2048 * 2187)): (depth += 1) {
//        for (0..phase1Prune.len) |i| {
//            const v = phase1Prune[i];
//            if (v == depth) {
//                const coordinate = decodeTableIndexToCoordinate(i);
//            
//                for (allMoves, 0..) |_, move_index| {
//                    const next_coordinate: Phase1Coordinate = .{
//                        .edgeOrientation   = edgeOrientationMoves[coordinate.edgeOrientation][move_index],
//                        .cornerOrientation = cornerOrientationMoves[coordinate.cornerOrientation][move_index],
//                        //.slicePermutation  = slicePermutationMoves[coordinate.slicePermutation][move_index],
//                        .slicePermutation  = 0,
//                    }; 
//
//                    const next_index: usize = encodeCoordinateToTableIndex(next_coordinate);
//
//                    if (phase1Prune[next_index] == -1) {
//                        phase1Prune[next_index] = @intCast(depth + 1);
//                        filled += 1;
//                    }
//                }
//            }
//        }
//    }
//}

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

test "R2 L2 F2 B2 is Domino" {
    var cube = permutations.solved;
    cube.algorithmString("R2 L2 F2 B2");
    try std.testing.expect(isDominoReduced(cube));
}

test {
    var cube = permutations.solved;
    cube.algorithmString("R L2 F2 B2");

    try std.testing.expect(isDominoReduced(cube) == false);
}

test {
    var cube = permutations.solved;
    cube.algorithmString("U' R2 U L2 D B2 D' F2");

    try std.testing.expect(isDominoReduced(cube));
}

test {
    var cube = permutations.solved;
    cube.algorithmString("U' R U L2 D B2 D' F2");

    try std.testing.expect(isDominoReduced(cube) == false);
}

const max_depth: usize = 15;

pub fn findSolution(cube: *cubies.CubieCube) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    for (0..max_depth) |depth| {
        var moves = std.ArrayList(cubies.CubeMove).init(arena.allocator());
        defer moves.deinit();

        std.debug.print("(depth: {d})\n", .{ depth });
        try firstPhaseSearch(cube, depth, &moves);
    }    
}

fn firstPhaseSearch(cube: *cubies.CubieCube, depth: usize, moves: *std.ArrayList(cubies.CubeMove)) !void {
    if (depth == 0) {
        if (moves.items.len > 0) {
            const previous_move = moves.getLast();
            const was_side_move = previous_move.face == .Right
                or previous_move.face == .Left
                or previous_move.face == .Front
                or previous_move.face == .Back;

            const was_quarter_turn = previous_move.order == 1 or previous_move.order == 3;

            if (isDominoReduced(cube.*) and was_side_move and was_quarter_turn) {
                // phase 2 start
                for (moves.items) |move| {
                    const label: u8 = switch (move.face) {
                        .Right => 'R', .Left  => 'L',
                        .Up    => 'U', .Down  => 'D',
                        .Front => 'F', .Back  => 'B',
                    };

                    const order: u8 = switch (move.order) {
                        1 => ' ', 2 => '2', 3 => '\'',
                        else => unreachable,
                    };

                    std.debug.print("{c}{c} ", .{ label, order });
                }

                std.debug.print("\n", .{ });
            }
        }

    } else if (depth > 0) {
        const p = cubiesToPhase1Coordinate(cube.*);
        const index = encodeCoordinateToTableIndex(p);

        const prune_depth = phase1Prune[index];
        //std.debug.print("(pruned depth: {})\n", .{ prune_depth });

        if (prune_depth <= depth) {
            for (allMoves) |move| {
                cube.turn(move);

                try moves.append(move);
                try firstPhaseSearch(cube, depth - 1, moves);
                _ = moves.pop();

                cube.turn(move.inverse());
            }
        }
    }
}


