const std = @import("std");
const utilities = @import("utilities.zig");
const facelets  = @import("facelets.zig");
const permutations = @import("permutations.zig");
const math = @import("math.zig");
const solver = @import("solver.zig");

pub const CubeMove = struct {
    face:  permutations.CubeFace,
    order: u8,

    pub fn inverse(move: CubeMove) CubeMove {
        const inverse_order: u8 = switch (move.order) {
            1 => 3, 2 => 2, 3 => 1,
            else => unreachable,
        };

        return .{
            .face = move.face,
            .order = inverse_order,
        };
    }

    pub fn format(
        self: CubeMove,
        writer: *std.Io.Writer,
    ) !void { 
        const label: u8 = switch (self.face) {
            .Right => 'R', .Left  => 'L',
            .Up    => 'U', .Down  => 'D',
            .Front => 'F', .Back  => 'B',
        };

        const order: u8 = switch (self.order) {
            1 => ' ', 2 => '2', 3 => '\'',
            else => unreachable,
        };

        try writer.print("{c}{c}", .{ label, order });
    }
};

pub const Edge = enum(u8) {
    UB, UR, UF, UL,
    LF, LB, RF, RB,
    DF, DR, DB, DL,
};

pub const Corner = enum(u8) {
    ULB, URB, UFR, ULF,
    DLF, DFR, DRB, DLB,
};

pub const CubieCube = struct {
    edgePermutations:   [12]Edge,
    cornerPermutations: [8]Corner,

    edgeOrientations:   [12]u8,
    cornerOrientations: [8]u8,

    pub const solved: CubieCube = .{
        .edgePermutations   = utilities.initAcending([12]Edge),
        .cornerPermutations = utilities.initAcending([8]Corner),

        .edgeOrientations   = @splat(0),
        .cornerOrientations = @splat(0),
    };

    fn parity(perm: []const u8) u64 {
        var inversions: u64 = 0;
        for (0..perm.len) |i| {
            for ((i + 1)..perm.len) |j| {
                if (perm[i] > perm[j]) {
                    inversions += 1;
                }
            }
        }
        return inversions % 2;
    }

    pub fn randomState() !CubieCube {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        var cube = CubieCube.solved;

        const rand = std.crypto.random;
        {
            const edge_pieces:   []const u8 = @ptrCast(&solved.edgePermutations);
            const corner_pieces: []const u8 = @ptrCast(&solved.cornerPermutations);

            const edge_rank = rand.intRangeAtMost(u64, 0, math.factorial(12));
            const edge_perm = try math.lexicographicUnrank(edge_pieces, edge_rank, allocator);

            for (edge_perm.items, 0..) |piece, i|
                cube.edgePermutations[i] = @enumFromInt(piece);

            const corner_rank = rand.intRangeAtMost(u64, 0, math.factorial(8));
            const corner_perm = try math.lexicographicUnrank(corner_pieces, corner_rank, allocator);

            for (corner_perm.items, 0..) |piece, i|
                cube.cornerPermutations[i] = @enumFromInt(piece);

            if (parity(corner_perm.items) != parity(edge_perm.items)) {
                const a = cube.edgePermutations[0];
                const b = cube.edgePermutations[1];

                cube.edgePermutations[0] = b;
                cube.edgePermutations[1] = a;
            }
        }

        {
            const edge_rank = rand.intRangeAtMost(u16, 0, 2048);
            const decoded_edges = try solver.decodeEdgeOrientation(edge_rank, allocator);
            cube.edgeOrientations = decoded_edges.edgeOrientations;

            const corner_rank = rand.intRangeAtMost(u16, 0, 2187);
            const decoded_corners = try solver.decodeCornerOrientation(corner_rank, allocator);
            cube.cornerOrientations = decoded_corners.cornerOrientations;
        }

        return cube;
    }

    pub fn initFromAlgorithmString(algorithm: []const u8) CubieCube {
        var cube = CubieCube.solved;
        cube.algorithmString(algorithm);
        return cube;
    }

    fn getTurnFromString(move: []const u8) CubeMove {
        var order: u8 = 1;

        if (move.len == 2) {
            if (std.ascii.isDigit(move[1])) {
                order = std.fmt.charToDigit(move[1], 10) catch unreachable;

            } else if (move[1] == '\'') {
                order = 3;

            } else {
                @panic("invalid move modifier");
            }
        }

        const face: permutations.CubeFace = switch (std.ascii.toUpper(move[0])) {
            'R' => .Right, 'L' => .Left,
            'F' => .Front, 'B' => .Back,
            'U' => .Up,    'D' => .Down,
            else => @panic("invalid move"),
        };

        return .{
            .face  = face,
            .order = order,
        };
    }

    pub fn algorithmString(self: *CubieCube, moves: []const u8) void {
        var sequence = std.mem.splitSequence(u8, moves, " ");
        while (sequence.next()) |move| {
            if (move.len == 0) continue;
            const cube_turn = getTurnFromString(move);
            //std.debug.print("move = {s}, turn = {?}\n", .{ move, cube_turn });
            self.turn(cube_turn);
        }
    }

    pub fn turn(self: *CubieCube, cubeTurn: CubeMove) void {
        for (0..cubeTurn.order) |_| {
            const permutation = switch (cubeTurn.face) {
                .Right => permutations.rMove, .Left  => permutations.lMove,
                .Up    => permutations.uMove, .Down  => permutations.dMove,
                .Front => permutations.fMove, .Back  => permutations.bMove,
            };

            self.permute(permutation);
        }
    }

    pub fn permute(self: *CubieCube, permutation: CubieCube) void {
        var newState: CubieCube = CubieCube.solved;
        for (0..12) |i| {
            const perm = @intFromEnum(permutation.edgePermutations[i]);
            newState.edgePermutations[i] = self.edgePermutations[perm];
            newState.edgeOrientations[i] = (self.edgeOrientations[perm] + permutation.edgeOrientations[i]) % 2;
        }

        for (0..8) |i| {
            const perm = @intFromEnum(permutation.cornerPermutations[i]);
            newState.cornerPermutations[i] = self.cornerPermutations[@intFromEnum(permutation.cornerPermutations[i])];
            newState.cornerOrientations[i] = (self.cornerOrientations[perm] + permutation.cornerOrientations[i]) % 3;
        }

        self.edgePermutations   = newState.edgePermutations;
        self.edgeOrientations   = newState.edgeOrientations;
        self.cornerPermutations = newState.cornerPermutations;
        self.cornerOrientations = newState.cornerOrientations;
    }

    pub fn format(
        self: CubieCube,
        writer: *std.Io.Writer,
    ) !void { 
        try writer.print("{f}", .{ facelets.FaceletCube.fromCubies(self) });
    }
};
