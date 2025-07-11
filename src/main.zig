const std = @import("std");
const utilities = @import("utilities.zig");
const model = @import("cube_model.zig");

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
