const std = @import("std");
const utilities = @import("utilities.zig");
const model = @import("cube_model.zig");

const lib = @import("kociemba_two_phase_lib");

const PhaseOneScore = struct {
    cornerOrientationScore: u16,
    edgeOrientationScore:   u16,
};


fn phaseOneScore() PhaseOneScore {

}

pub fn main() !void {
    var cube: model.CubeState = .{ };

    const sexy   = "R U R' U'";
    const sledge = "R' F R F'";
    const sexySledge = utilities.join_strings(" ", .{ sexy, sledge });
    _ = sexySledge;

    const tPerm = "R U R' U' R' F R2 U' R' U' R U R' F'";
    cube.algorithm_string(tPerm);

    std.debug.print("{}", .{ cube });
}
