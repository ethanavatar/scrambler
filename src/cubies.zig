const std = @import("std");
const utilities = @import("utilities.zig");
const facelets  = @import("facelets.zig");
const moves     = @import("moves.zig");

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
    edgePermutations:   [12]Edge  = utilities.initAcending([12]Edge),
    cornerPermutations: [8]Corner = utilities.initAcending([8]Corner),

    edgeOrientations:   [12]u8 = @splat(0),
    cornerOrientations: [8]u8  = @splat(0),

    pub fn move(self: *CubieCube, face: moves.CubeFace, order: u8) void {
        for (0..order) |_| {
            const permutation = switch (face) {
                .Right => moves.rMove,
                .Left  => moves.lMove,
                .Up    => moves.uMove,
                .Down  => moves.dMove,
                .Front => moves.fMove,
                .Back  => moves.bMove,
            };

            var newState: CubieCube = moves.solved; 

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
