const std = @import("std");
const utilities = @import("utilities.zig");
const facelets  = @import("facelets.zig");
const permutations = @import("permutations.zig");

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

    pub fn solved() CubieCube {
        return .{
            .edgePermutations   = utilities.initAcending([12]Edge),
            .cornerPermutations = utilities.initAcending([8]Corner),

            .edgeOrientations   = @splat(0),
            .cornerOrientations = @splat(0),
        };
    }

    pub fn initFromAlgorithmString(algorithm: []const u8) CubieCube {
        var cube = CubieCube.solved();
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
            var newState: CubieCube = CubieCube.solved();
            const permutation = switch (cubeTurn.face) {
                .Right => permutations.rMove, .Left  => permutations.lMove,
                .Up    => permutations.uMove, .Down  => permutations.dMove,
                .Front => permutations.fMove, .Back  => permutations.bMove,
            };

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
    }

    pub fn format(
        self: CubieCube,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void { 
        try writer.print("{s}", .{ facelets.FaceletCube.fromCubies(self) });
    }
};
