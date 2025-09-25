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

fn binomialCoefficient(n: u64, k_in: u64) u64 {
    if (k_in > n) {
        return 0;
    }

    const k = if (k_in < n - k_in) k_in else n - k_in;

    var result: u64 = 1;
    for (1..k + 1) |i| {
        result *= (n - i + 1);
        result /= i;
    }

    return result;
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

test {
    
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

fn encodeSlicePermutation(cube: cubies.CubieCube) u16 {
    var slice_permutation: u16 = 0;

    var count: u32 = 4;
    for (cube.edgePermutations, 0..) |edge, edge_index| {
        switch (edge) {
            .RF, .LF, .RB, .LB => { count -= 1; },
            else => { slice_permutation += @intCast(binomialCoefficient(edge_index, count)); },
        }

        if (count == 0) break;
    }

    return slice_permutation;
}

fn cubiesToPhase1Coordinate(cube: cubies.CubieCube) Phase1Coordinate {
    return .{
        .edgeOrientation   = encodeEdgeOrientation(cube),
        .cornerOrientation = encodeCornerOrientation(cube),
        .slicePermutation  = encodeSlicePermutation(cube),
    };
}

var edgeOrientationMoves: [2048][allMoves.len]u16 = std.mem.zeroes([2048][allMoves.len]u16);

pub fn generateEdgeOrientationMovesTable() void {
    var cube = permutations.solved; 

    for (0..2048) |flip_coord| {
        cube.edgeOrientations = decodeEdgeOrientation(@intCast(flip_coord));

        for (allMoves, 0..) |move, move_index| {
            cube.turn(move);
            edgeOrientationMoves[flip_coord][move_index] = cubiesToPhase1Coordinate(cube).edgeOrientation;

            const inverse_order: u8 = switch (move.order) {
                1 => 3, 2 => 1, 3 => 1,
                else => unreachable,
            };

            const inverse_move: cubies.CubeMove = .{
                .face = move.face,
                .order = inverse_order,
            };

            cube.turn(inverse_move);
        }
    }
}

var cornerOrientationMoves: [2187][allMoves.len]u16 = std.mem.zeroes([2187][allMoves.len]u16);

pub fn generateCornerOrientationMovesTable() void {
    var cube = permutations.solved; 

    for (0..2187) |twist_coord| {

        {
            var coord = twist_coord;
            var sum: usize = 0;

            for (0..7) |i| {
                const o: u8 = @intCast(coord % 3);
                cube.cornerOrientations[i] = o;
                sum += o;
                coord /= 3;
            }

            cube.cornerOrientations[7] = @intCast((3 - (sum % 3)) % 3);

        }

        std.debug.assert(cubiesToPhase1Coordinate(cube).cornerOrientation == twist_coord);

        for (allMoves, 0..) |move, move_index| {
            cube.turn(move);

            const coord = cubiesToPhase1Coordinate(cube).cornerOrientation;
            cornerOrientationMoves[twist_coord][move_index] = coord;
            //std.debug.print("{}\n", .{ coord });

            const inverse_order: u8 = switch (move.order) {
                1 => 3, 2 => 1, 3 => 1,
                else => unreachable,
            };

            const inverse_move: cubies.CubeMove = .{
                .face = move.face,
                .order = inverse_order,
            };

            cube.turn(inverse_move);
        }
    }
}

var slicePermutationMoves: [495][allMoves.len]u16 = std.mem.zeroes([495][allMoves.len]u16);

pub fn generateSlicePermutationMovesTable() void {
    var cube = permutations.solved; 

    for (0..495) |slice_coord| {
        {
            var slices: [4]u8 = undefined;
            var slices_index: usize = 0;

            var coord = slice_coord;

            var k: u32 = 4;

            for (0..12) |i| {
                if (k == 0) break;

                const choice = binomialCoefficient(11 - i, k);
                if (coord >= choice) {
                    slices[slices_index] = @intCast(i);
                    slices_index += 1;

                    coord -= choice;
                    k -= 1;
                }
            }

            for (slices, [4]cubies.Edge{ .RF, .LF, .RB, .LB }) |destination, source| {
                permutations.changeEdge(&cube, @enumFromInt(destination), source, 0);
                permutations.changeEdge(&cube, source, @enumFromInt(destination), 0);
            }
        }

        for (allMoves, 0..) |move, move_index| {
            cube.turn(move);
            slicePermutationMoves[slice_coord][move_index] = encodeSlicePermutation(cube);

            const inverse_order: u8 = switch (move.order) {
                1 => 3, 2 => 1, 3 => 1,
                else => unreachable,
            };

            const inverse_move: cubies.CubeMove = .{
                .face = move.face,
                .order = inverse_order,
            };

            cube.turn(inverse_move);
        }
    }
}

var phase1Prune: [4478976]i32 = std.mem.zeroes([4478976]i32);

pub fn generatePhase1PruneTable() !void {
    @memset(&phase1Prune, -1);

    // index = flip + 2048 * twist
    //
    // flip  = index % 2048
    // twist = index // 2048
    
    const allocator = std.heap.page_allocator;

    var queue = std.ArrayList(i32).init(allocator);
    defer queue.deinit();

    for (0..495) |slice_state| {
        const coordinate: Phase1Coordinate = .{
            .edgeOrientation   = 0,
            .cornerOrientation = 0,
            .slicePermutation  = @intCast(slice_state),
        };

        const encoding: usize = coordinate.edgeOrientation + @as(usize, 2048) * coordinate.cornerOrientation;
        if (phase1Prune[encoding] == -1) {
            phase1Prune[encoding] = 0;
            try queue.append(@intCast(encoding));
        }
    }

    while (queue.items.len > 0) {
        const encoding = queue.pop() orelse unreachable;
        const depth = phase1Prune[@intCast(encoding)];

        for (allMoves, 0..) |_, move_index| {
            const coordinate: Phase1Coordinate = .{
                .edgeOrientation   = @intCast(@mod(encoding, 2048)),
                .cornerOrientation = @intCast(@divFloor(encoding, 2048)),
                .slicePermutation  = 0,
            };

            const next_coordinate: Phase1Coordinate = .{
                .edgeOrientation   = edgeOrientationMoves[coordinate.edgeOrientation][move_index],
                .cornerOrientation = cornerOrientationMoves[coordinate.cornerOrientation][move_index],
                .slicePermutation  = slicePermutationMoves[coordinate.slicePermutation][move_index],
            }; 

            const next_encoding: usize = next_coordinate.edgeOrientation + @as(usize, 2048) * next_coordinate.cornerOrientation;

            if (phase1Prune[next_encoding] == -1) {
                phase1Prune[next_encoding] = depth + 1;
                try queue.append(@intCast(next_encoding));
            }
        }
    }

    var count: usize = 0;
    var unexplored: usize = 0;
    for (0..phase1Prune.len) |i| {
        const distance = phase1Prune[i];
        if (distance != -1) {
            count += 1;
        } else {
            unexplored += 1;
        }
    }

    std.debug.print("count: {}, unexplored: {}\n", .{
        count,
        unexplored
    });
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

test "R2 L2 F2 B2 is Domino" {
    var cube = permutations.solved;
    cube.algorithmString("R2 L2 F2 B2");

    for (cube.edgeOrientations) |edge| {
        std.debug.print("{?}", .{ edge });
    }
    std.debug.print("\n", .{ });

    for (cube.cornerOrientations) |corner| {
        std.debug.print("{?}", .{ corner });
    }
    std.debug.print("\n", .{ });

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

const max_depth: usize = 0;

const CubeWithMoves = struct {
    cube:  cubies.CubieCube,
    moves: std.ArrayList(cubies.CubeMove),

    fn init(cube: cubies.CubieCube, gpa: std.mem.Allocator) CubeWithMoves {
        return .{ .cube = cube, .moves = std.ArrayList(cubies.CubeMove).init(gpa) };
    }

    fn clone(self: *CubeWithMoves) !CubeWithMoves {
        return .{ .cube = self.cube, .moves = try self.moves.clone() };
    }
};

pub fn findSolution(cube: cubies.CubieCube) !void {

    for (0..max_depth) |depth| {
        std.debug.print("(depth: {d})\n", .{ depth });
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();

        const allocator = arena.allocator();

        var state = CubeWithMoves.init(cube, allocator);

        try firstPhaseSearch(&state, depth);
    }    
}

fn firstPhaseSearch(state: *CubeWithMoves, depth: usize) !void {
    if (depth == 0) {
        if (state.moves.items.len > 0) {
            const previous_move = state.moves.getLast();
            const was_side_move = previous_move.face == .Right
                or previous_move.face == .Left
                or previous_move.face == .Front
                or previous_move.face == .Back;

            const was_quarter_turn = previous_move.order == 1 or previous_move.order == 3;

            if (isDominoReduced(state.cube) and was_side_move and was_quarter_turn) {
                // phase 2 start
                for (state.moves.items) |move| {
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
        const p = cubiesToPhase1Coordinate(state.cube);
        const encoding: usize = p.edgeOrientation + @as(usize, 2048) * p.cornerOrientation;

        const prune_depth = phase1Prune[encoding];
        std.debug.print("(pruned depth: {})\n", .{ prune_depth });

        if (prune_depth <= depth) {
            for (allMoves) |move| {
                var new_state = try state.clone();
                new_state.cube.turn(move);
                try new_state.moves.append(move);

                try firstPhaseSearch(&new_state, depth - 1);
            }
        }
    }
}


