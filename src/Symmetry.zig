const std = @import("std");
const cubies = @import("cubies.zig");

pub const SymmetryKind = enum(u8) {
    URF3,
    F2,
    U4,
    LR2,
};

pub const URF3: cubies.CubieCube = .{
    .edgePermutations   = [12]cubies.Edge{ .LF, .UF, .RF, .DF, .DR, .DL, .UR, .UL, .RB, .UB, .LB, .DB },
    .cornerPermutations = [8]cubies.Corner{ .DLF, .ULF, .UFR, .DFR, .DRB, .URB, .ULB, .DLB },

    .edgeOrientations   = [12]u8{ 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1 },
    .cornerOrientations = [8]u8{ 2, 1, 2, 1, 2, 1, 2, 1 },
};

pub const F2: cubies.CubieCube = .{
    .edgePermutations   = [12]cubies.Edge{ .DB, .DL, .DF, .DR, .RF, .RB, .LF, .LB, .UF, .UL, .UB, .UR },
    .cornerPermutations = [8]cubies.Corner{ .DRB, .DLB, .DLF, .DFR, .UFR, .ULF, .ULB, .URB },

    .edgeOrientations   = [12]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    .cornerOrientations = [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
};

pub const U4: cubies.CubieCube = .{
    .edgePermutations   = [12]cubies.Edge{ .UL, .UB, .UR, .UF, .RF, .LF, .RB, .LB, .DR, .DB, .DL, .DF },
    .cornerPermutations = [8]cubies.Corner{ .ULF, .ULB, .URB, .UFR, .DFR, .DRB, .DLB, .DLF },

    .edgeOrientations   = [12]u8{ 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0 },
    .cornerOrientations = [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
};

pub const LR2: cubies.CubieCube = .{
    .edgePermutations   = [12]cubies.Edge{ .UB, .UL, .UF, .UR, .RF, .RB, .LF, .LB, .DF, .DL, .DB, .DR },
    .cornerPermutations = [8]cubies.Corner{ .URB, .ULB, .ULF, .UFR, .DFR, .DLF, .DLB, .DRB },

    .edgeOrientations   = [12]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
    .cornerOrientations = [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
};

pub var symmetries: [48]cubies.CubieCube = undefined;

pub fn generate() void {
    var cube = cubies.CubieCube.solved;

    // URF33
    for (0..3) |urf_3| {

        // F2
        for (0..2) |f_2| {

            // U4
            for (0..4) |u_4| {

                // LR2
                for (0..2) |lr_2| {
                    const i = 16 * urf_3 + 8 * f_2 + 2 * u_4 + lr_2;

                    symmetries[i] = .{
                        .edgePermutations   = cube.edgePermutations,
                        .cornerPermutations = cube.cornerPermutations,

                        .edgeOrientations   = cube.edgeOrientations,
                        .cornerOrientations = cube.cornerOrientations,
                    };
                    cube.permute(LR2);
                }

                cube.permute(U4);
            }

            cube.permute(F2);
        }
        
        cube.permute(URF3);
    }
}

