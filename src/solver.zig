const std = @import("std");

const math = @import("math.zig");
const algorithms = @import("algorithms.zig");
const cubies = @import("cubies.zig");
const permutations = @import("permutations.zig");

const Tables = @import("Tables.zig");

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

//test {
//    const cube = cubies.CubieCube.initFromAlgorithmString(algorithms.mitch);
//
//    const expectations = [12]u8{ 0, 1, 0, 1,   0, 0, 0, 0,   0, 0, 1, 1 };
//    try std.testing.expectEqual(expectations, cube.edgeOrientations);
//    try std.testing.expectEqual(expectations, decodeEdgeOrientation(encodeEdgeOrientation(cube)));
//    try std.testing.expectEqual(0b10000001010, encodeEdgeOrientation(cube));
//}

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

//test {
//    const cube = cubies.CubieCube.initFromAlgorithmString(algorithms.mitch);
//
//    const expectations = [8]u8{ 0, 2, 2, 1,   0, 1, 1, 2 };
//    try std.testing.expectEqual(expectations, cube.cornerOrientations);
//    try std.testing.expectEqual(expectations, decodeCornerOrientation(encodeCornerOrientation(cube))); 
//    try std.testing.expectEqual(0b001111111111, encodeCornerOrientation(cube)); // TODO: Base 3 converter
//}

pub fn encodeCoordinateToTableIndex(coordinate: CoordinateCube) ?usize {
    return coordinate.edgeOrientation + @as(usize, 2048) * coordinate.cornerOrientation;
}

pub fn decodeTableIndexToCoordinate(index: usize) ?CoordinateCube {
    return .{
        .edgeOrientation   = @intCast(@mod(index, 2048)),
        .cornerOrientation = @intCast(@divFloor(index, 2048)),
    };
}

//test {
//    for (0..2048 * 2187) |index| {
//        try std.testing.expectEqual(
//            index,
//            encodeCoordinateToTableIndex(decodeTableIndexToCoordinate(index)),
//        );
//    }
//}

pub const CoordinateCube = struct {
    edgeOrientation:   u16 = 0,
    edgePermutation:   u16 = 0,
    cornerOrientation: u16 = 0,
    cornerPermutation: u16 = 0,
    slicePermutation:  u16 = 0,

    pub fn solved() CoordinateCube {
        return CoordinateCube.fromCubies(cubies.CubieCube.solved());
    }

    pub fn fromCubies(cubie_cube: cubies.CubieCube) CoordinateCube {
        return .{
            .edgeOrientation   = encodeEdgeOrientation(cubie_cube),
            .edgePermutation   = encodeEdgePermutation(cubie_cube),
            .cornerOrientation = encodeCornerOrientation(cubie_cube),
            .cornerPermutation = encodeCornerPermutation(cubie_cube),
            .slicePermutation  = encodeSlicePermutation(cubie_cube),
        };
    }

    pub fn move(self: *const CoordinateCube, move_index: usize) CoordinateCube {
        return .{
            .edgeOrientation   = Tables.edgeOrientation[self.edgeOrientation][move_index],
            .edgePermutation   = Tables.edgePermutation[self.edgePermutation][move_index],
            .cornerOrientation = Tables.cornerOrientation[self.cornerOrientation][move_index],
            .cornerPermutation = Tables.cornerPermutation[self.cornerPermutation][move_index],
            .slicePermutation  = Tables.slicePermutation[self.slicePermutation][move_index],
        };
    }

    pub fn isG1(self: *const CoordinateCube) bool {
        const solved_cube = CoordinateCube.solved();
        return self.edgeOrientation == solved_cube.edgeOrientation
            and self.cornerOrientation == solved_cube.cornerOrientation
            and self.slicePermutation == solved_cube.slicePermutation;
    }

    pub fn isSolved(self: *const CoordinateCube) bool {
        const solved_cube = CoordinateCube.solved();
        return self.isG1()
            and self.edgePermutation == solved_cube.edgePermutation
            and self.cornerPermutation == solved_cube.cornerPermutation;
    }
};

test {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    try Tables.generateAll(arena.allocator());

    var cube = CoordinateCube.solved();
    try std.testing.expectEqual(true, cube.isG1());

    cube = cube.move(0);
    try std.testing.expectEqual(false, cube.isG1());
}

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

const combinations: [13][13]u64 = ret: {
    var result: [13][13]u64 = std.mem.zeroes([13][13]u64);

    for (0..12 + 1) |i| {
        result[i][0] = 1;
        for (1..i + 1) |j| {
            result[i][j] = result[i - 1][j - 1] + result[i - 1][j];
        }
    }

    break :ret result;
};

pub fn encodeSlicePermutation(cube: cubies.CubieCube) u16 {
    var combo: [4]u8 = undefined;
    for ([_]cubies.Edge{ .LF, .LB, .RF, .RB, }, 0..) |slice_edge, i| {
        combo[i] = @intFromEnum(cube.edgePermutations[@intFromEnum(slice_edge)]);
    }

    std.mem.sort(u8, &combo, {}, comptime std.sort.desc(u8));

    var rank: u16 = 0;
    rank += @intCast(combinations[combo[0]][4]);
    rank += @intCast(combinations[combo[1]][3]);
    rank += @intCast(combinations[combo[2]][2]);
    rank += @intCast(combinations[combo[3]][1]);

    return rank;
}

pub fn decodeSlicePermutation(rank: u16, allocator: std.mem.Allocator) !cubies.CubieCube {
    var combo = std.array_list.Managed(u8).init(allocator);
    defer combo.deinit();

    var current_n: usize = 12;
    var current_k: usize = 4;
    var current_rank = rank;

    while (current_k > 0): (current_k -= 1) {
        var i = current_n - 1;
        while (combinations[i][current_k] > current_rank): (i -= 1) {}

        try combo.append(@intCast(i));
        current_rank -= @intCast(combinations[i][current_k]);
        current_n = i;
    }

    std.mem.sort(u8, combo.items, {}, comptime std.sort.asc(u8));

    var cube = cubies.CubieCube.solved();

    for (combo.items, [_]cubies.Edge{ .LF, .LB, .RF, .RB, }) |destination, source| {
        permutations.changeEdge(&cube, @enumFromInt(destination), source, 0);
        permutations.changeEdge(&cube, source, @enumFromInt(destination), 0);
    }

    return cube;
}

test {
    var cube = cubies.CubieCube.solved(); 
    std.debug.print("{}\n", .{ cube });

    var rank = encodeSlicePermutation(cube);
    std.debug.print("{}\n", .{ rank });

    var new_cube = try decodeSlicePermutation(rank, std.testing.allocator);
    std.debug.print("{}\n", .{ new_cube });

    try std.testing.expectEqual(
        rank,
        encodeSlicePermutation(new_cube)
    );

    permutations.changeEdge(&cube, .RF, .RB, 0);
    permutations.changeEdge(&cube, .RB, .RF, 0);
    std.debug.print("{}\n", .{ cube });

    rank = encodeSlicePermutation(cube);
    std.debug.print("{}\n", .{ rank });

    new_cube = try decodeSlicePermutation(rank, std.testing.allocator);
    std.debug.print("{}\n", .{ new_cube });

    try std.testing.expectEqual(
        rank,
        encodeSlicePermutation(new_cube)
    );
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

const max_depth: usize = 99;

var max_solutions: usize = 0;

pub fn findSolutions(
    c: cubies.CubieCube, solutions_count: usize,
    allocator: std.mem.Allocator,
) !std.array_list.Managed([]cubies.CubeMove) {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    max_solutions = solutions_count;

    var cube = c;

    var solutions = std.array_list.Managed([]cubies.CubeMove).init(allocator);

    const start_time = std.time.timestamp();

    for (0..max_depth) |depth| {
        var moves = std.array_list.Managed(cubies.CubeMove).init(arena.allocator());
        defer moves.deinit();

        try firstPhaseSearch(&cube, depth, &moves, &solutions, start_time);

        if (solutions.items.len >= max_solutions) {
            break;
        }
    }

    return solutions;
}

fn firstPhaseSearch(
    cube: *cubies.CubieCube, depth: usize, moves: *std.array_list.Managed(cubies.CubeMove),
    solutions: *std.array_list.Managed([]cubies.CubeMove),
    start_time: i64
) !void {
    const coord_cube = CoordinateCube.fromCubies(cube.*);

    if (depth == 0) {
        if (moves.items.len > 0) {
            const previous_move = moves.getLast();
            const was_side_move = previous_move.face == .Right
                or previous_move.face == .Left
                or previous_move.face == .Front
                or previous_move.face == .Back;

            const was_quarter_turn = previous_move.order == 1 or previous_move.order == 3;

            if (coord_cube.isG1() and was_side_move and was_quarter_turn) {
                const g1_time = std.time.timestamp();
                //std.debug.print("G1 ({} seconds since start)\n", .{ g1_time - start_time });

                try secondPhaseStart(cube, depth, moves, solutions, g1_time);
            }
        }

    } else if (depth > 0) {
        const index = encodeCoordinateToTableIndex(coord_cube) orelse unreachable;
        const prune_depth = Tables.phase1[index];

        if (prune_depth <= depth) {
            for (allMoves) |move| {
                try moves.append(move);
                defer _ = moves.pop();

                cube.turn(move);
                defer cube.turn(move.inverse());

                try firstPhaseSearch(cube, depth - 1, moves, solutions, start_time);

                if (solutions.items.len >= max_solutions) {
                    break;
                }
            }
        }
    }
}

fn secondPhaseStart(
    cube: *cubies.CubieCube, current_depth: usize, moves: *std.array_list.Managed(cubies.CubeMove),
    solutions: *std.array_list.Managed([]cubies.CubeMove),
    g1_time: i64
) !void {
    for (0..max_depth - current_depth) |depth| {
        secondPhaseSearch(cube, depth, moves, solutions, g1_time);
        if (solutions.items.len >= max_solutions) {
            break;
        }
    }
}

fn secondPhaseSearch(
    cube: *cubies.CubieCube, depth: usize, moves: *std.array_list.Managed(cubies.CubeMove),
    solutions: *std.array_list.Managed([]cubies.CubeMove),
    g1_time: i64
) void {
    const coord_cube = CoordinateCube.fromCubies(cube.*);

    if (depth == 0) {
        if (isSolved(cube.*)) {
            //std.debug.print("G2 ({} seconds since G1)\n", .{ std.time.timestamp() - g1_time });
            const allocator = solutions.allocator;

            // If I used an unmanaged arraylist, I could use toOwnedSlice(Allocator)
            const solution = allocator.alloc(cubies.CubeMove, moves.items.len) catch unreachable;
            std.mem.copyForwards(cubies.CubeMove, solution, moves.items);

            solutions.append(solution) catch unreachable;
        }

    } else if (depth > 0) {
        const index = encodePhase2CoordToIndex(coord_cube) orelse unreachable;
        const prune_depth = Tables.phase2[index];

        if (prune_depth <= depth) {
            for (g1Moves) |move| {

                moves.append(move) catch unreachable;
                defer _ = moves.pop();

                cube.turn(move);
                defer cube.turn(move.inverse());

                secondPhaseSearch(cube, depth - 1, moves, solutions, g1_time);

                if (solutions.items.len >= max_solutions) {
                    break;
                }
            }
        }
    }
}

