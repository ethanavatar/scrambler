const cubies    = @import("cubies.zig");
const utilities = @import("utilities.zig");

pub const CubeFace = enum(u8) {
    Right, Left,
    Front, Back,
    Up,    Down,
};

pub fn changeEdge(cube: *cubies.CubieCube, position: cubies.Edge, newPiece: cubies.Edge, newOrientation: u8) void {
    cube.edgePermutations[@intFromEnum(position)] = newPiece;
    cube.edgeOrientations[@intFromEnum(position)] = newOrientation;
}

fn changeCorner(cube: *cubies.CubieCube, position: cubies.Corner, newPiece: cubies.Corner, newOrientation: u8) void {
    cube.cornerPermutations[@intFromEnum(position)] = newPiece;
    cube.cornerOrientations[@intFromEnum(position)] = newOrientation;
}

pub const rMove: cubies.CubieCube = ret: {
    var c = cubies.CubieCube.solved();

    changeEdge(&c, .UR, .RF, 1);
    changeEdge(&c, .RB, .UR, 1);
    changeEdge(&c, .DR, .RB, 1);
    changeEdge(&c, .RF, .DR, 1);

    changeCorner(&c, .URB, .UFR, 2);
    changeCorner(&c, .DRB, .URB, 1);
    changeCorner(&c, .DFR, .DRB, 2);
    changeCorner(&c, .UFR, .DFR, 1);

    break :ret c;
};

pub const lMove: cubies.CubieCube = ret: {
    var c = cubies.CubieCube.solved();

    changeEdge(&c, .UL, .LB, 1);
    changeEdge(&c, .LF, .UL, 1);
    changeEdge(&c, .DL, .LF, 1);
    changeEdge(&c, .LB, .DL, 1);

    changeCorner(&c, .ULB, .DLB, 1);
    changeCorner(&c, .ULF, .ULB, 2);
    changeCorner(&c, .DLF, .ULF, 1);
    changeCorner(&c, .DLB, .DLF, 2);

    break :ret c;
};

pub const uMove: cubies.CubieCube = ret: {
    var c = cubies.CubieCube.solved();

    changeEdge(&c, .UB, .UL, 0);
    changeEdge(&c, .UR, .UB, 0);
    changeEdge(&c, .UF, .UR, 0);
    changeEdge(&c, .UL, .UF, 0);

    changeCorner(&c, .ULB, .ULF, 0);
    changeCorner(&c, .URB, .ULB, 0);
    changeCorner(&c, .UFR, .URB, 0);
    changeCorner(&c, .ULF, .UFR, 0);

    break :ret c;
};

pub const dMove: cubies.CubieCube = ret: {
    var c = cubies.CubieCube.solved();

    changeEdge(&c, .DF, .DL, 0);
    changeEdge(&c, .DR, .DF, 0);
    changeEdge(&c, .DB, .DR, 0);
    changeEdge(&c, .DL, .DB, 0);

    changeCorner(&c, .DLF, .DLB, 0);
    changeCorner(&c, .DFR, .DLF, 0);
    changeCorner(&c, .DRB, .DFR, 0);
    changeCorner(&c, .DLB, .DRB, 0);

    break :ret c;
};

pub const fMove: cubies.CubieCube = ret: {
    var c = cubies.CubieCube.solved();

    changeEdge(&c, .UF, .LF, 0);
    changeEdge(&c, .RF, .UF, 0);
    changeEdge(&c, .DF, .RF, 0);
    changeEdge(&c, .LF, .DF, 0);

    changeCorner(&c, .ULF, .DLF, 1);
    changeCorner(&c, .UFR, .ULF, 2);
    changeCorner(&c, .DFR, .UFR, 1);
    changeCorner(&c, .DLF, .DFR, 2);

    break :ret c;
};

pub const bMove: cubies.CubieCube = ret: {
    var c = cubies.CubieCube.solved();

    changeEdge(&c, .UB, .RB, 0);
    changeEdge(&c, .LB, .UB, 0);
    changeEdge(&c, .DB, .LB, 0);
    changeEdge(&c, .RB, .DB, 0);

    changeCorner(&c, .ULB, .URB, 2);
    changeCorner(&c, .DLB, .ULB, 1);
    changeCorner(&c, .DRB, .DLB, 2);
    changeCorner(&c, .URB, .DRB, 1);

    break :ret c;
};
