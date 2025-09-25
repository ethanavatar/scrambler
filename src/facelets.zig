const std = @import("std");
const cubies = @import("cubies.zig");

const ansiBlack = "\x1b[0;39;48;2;0;0;0m";
const ansiReset = "\x1b[0m";

const ansi: [6][]const u8 = .{
    "\x1b[0;30;48;2;255;255;255m  " ++ ansiReset, // white
    "\x1b[0;30;48;2;255;125;0m  "   ++ ansiReset, // orange
    "\x1b[0;30;48;2;0;255;0m  "     ++ ansiReset, // green
    "\x1b[0;30;48;2;255;0;0m  "     ++ ansiReset, // red
    "\x1b[0;30;48;2;0;0;255m  "     ++ ansiReset, // blue
    "\x1b[0;30;48;2;255;255;0m  "   ++ ansiReset, // yellow
};

const Color = enum(u8) {
    White, Orange,
    Green, Red,
    Blue,  Yellow,

    pub fn format(
        self: Color,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void { 
        try writer.print("{s}", .{ ansi[@intFromEnum(self)] });
    }
};

pub const FaceletCube = struct {
    edgeColors:   [24]Color,
    cornerColors: [24]Color,

    pub fn fromCubies(cubieCube: cubies.CubieCube) FaceletCube {
        var cube: FaceletCube = undefined;

        for (edgeFacelets, 0..) |edge, i| {
            const piece = @intFromEnum(edge.piece);
            const actualPiece = @intFromEnum(cubieCube.edgePermutations[piece]);
            const actualOrientation = cubieCube.edgeOrientations[piece];
            const actualFace = (actualOrientation + edge.face) % 2;

            const color = edgeColors[actualPiece][actualFace];
            cube.edgeColors[i] = color;
        }

        for (cornerFacelets, 0..) |corner, i| {
            const piece = @intFromEnum(corner.piece);
            const actualPiece = @intFromEnum(cubieCube.cornerPermutations[piece]);
            const actualOrientation = cubieCube.cornerOrientations[piece];
            const actualFace = (actualOrientation + corner.face) % 3;

            const color = cornerColors[actualPiece][actualFace];
            cube.cornerColors[i] = color;
        }

        return cube;
    }

    pub fn format(
        self: FaceletCube,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void { 
        const ec: [24]Color = self.edgeColors;
        const cc: [24]Color = self.cornerColors;

        //try writer.print("{s}\n", .{ ansiBlack });

        try writer.print("{s: ^6} {s}{s}{s}\n", .{ "", cc[0], ec[0],   cc[1] });
        try writer.print("{s: ^6} {s}{s}{s}\n", .{ "", ec[3], ansi[0], ec[1] });
        try writer.print("{s: ^6} {s}{s}{s}\n", .{ "", cc[3], ec[2],   cc[2] });

        const f = "{s}{s}{s} {s}{s}{s} {s}{s}{s} {s}{s}{s}\n";

        try writer.print(f, .{ cc[4], ec[4],   cc[5],  cc[8],  ec[8],   cc[9],   cc[12], ec[12],  cc[13],  cc[16], ec[16],  cc[17] });
        try writer.print(f, .{ ec[7], ansi[1], ec[5],  ec[11], ansi[2], ec[9],   ec[15], ansi[3], ec[13],  ec[19], ansi[4], ec[17] });
        try writer.print(f, .{ cc[7], ec[6],   cc[6],  cc[11], ec[10],  cc[10],  cc[15], ec[14],  cc[14],  cc[19], ec[18],  cc[18] });

        try writer.print("{s: ^6} {s}{s}{s}\n", .{ "", cc[20], ec[20],   cc[21] });
        try writer.print("{s: ^6} {s}{s}{s}\n", .{ "", ec[23], ansi[5],  ec[21] });
        try writer.print("{s: ^6} {s}{s}{s}\n", .{ "", cc[23], ec[22],   cc[22] });

        //try writer.print("\n{s}", .{ ansiReset });
    }

};

const edgeColors: [12][2]Color = .{
    .{ .White, .Blue   },
    .{ .White, .Red    },
    .{ .White, .Green  },
    .{ .White, .Orange },

    .{ .Orange, .Green },
    .{ .Orange, .Blue  },
    .{ .Red,    .Green },
    .{ .Red,    .Blue  },

    .{ .Yellow, .Green  },
    .{ .Yellow, .Red    },
    .{ .Yellow, .Blue   },
    .{ .Yellow, .Orange },
};

const cornerColors: [8][3]Color = .{
    .{ .White, .Orange, .Blue   },
    .{ .White, .Blue,   .Red    },
    .{ .White, .Red,    .Green  },
    .{ .White, .Green,  .Orange },

    .{ .Yellow, .Orange, .Green   },
    .{ .Yellow, .Green,  .Red     },
    .{ .Yellow, .Red,    .Blue    },
    .{ .Yellow, .Blue,   .Orange  },
};

const EdgeFacelet   = struct { piece: cubies.Edge, face: u8 };
const CornerFacelet = struct { piece: cubies.Corner, face: u8 };

const edgeFacelets: [24]EdgeFacelet = .{
    .{ .piece = .UB, .face = 0 }, 
    .{ .piece = .UR, .face = 0 },
    .{ .piece = .UF, .face = 0 },
    .{ .piece = .UL, .face = 0 },

    .{ .piece = .UL, .face = 1 },
    .{ .piece = .LF, .face = 0 },
    .{ .piece = .DL, .face = 1 },
    .{ .piece = .LB, .face = 0 },

    .{ .piece = .UF, .face = 1 },
    .{ .piece = .RF, .face = 1 },
    .{ .piece = .DF, .face = 1 },
    .{ .piece = .LF, .face = 1 },

    .{ .piece = .UR, .face = 1 },
    .{ .piece = .RB, .face = 0 },
    .{ .piece = .DR, .face = 1 },
    .{ .piece = .RF, .face = 0 },

    .{ .piece = .UB, .face = 1 },
    .{ .piece = .LB, .face = 1 },
    .{ .piece = .DB, .face = 1 },
    .{ .piece = .RB, .face = 1 },

    .{ .piece = .DF, .face = 0 },
    .{ .piece = .DR, .face = 0 },
    .{ .piece = .DB, .face = 0 },
    .{ .piece = .DL, .face = 0 },
};

const cornerFacelets: [24]CornerFacelet = .{
    .{ .piece = .ULB, .face = 0 }, 
    .{ .piece = .URB, .face = 0 },
    .{ .piece = .UFR, .face = 0 },
    .{ .piece = .ULF, .face = 0 },

    .{ .piece = .ULB, .face = 1 },
    .{ .piece = .ULF, .face = 2 },
    .{ .piece = .DLF, .face = 1 },
    .{ .piece = .DLB, .face = 2 },

    .{ .piece = .ULF, .face = 1 },
    .{ .piece = .UFR, .face = 2 },
    .{ .piece = .DFR, .face = 1 },
    .{ .piece = .DLF, .face = 2 },

    .{ .piece = .UFR, .face = 1 },
    .{ .piece = .URB, .face = 2 },
    .{ .piece = .DRB, .face = 1 },
    .{ .piece = .DFR, .face = 2 },

    .{ .piece = .URB, .face = 1 },
    .{ .piece = .ULB, .face = 2 },
    .{ .piece = .DLB, .face = 1 },
    .{ .piece = .DRB, .face = 2 },

    .{ .piece = .DLF, .face = 0 },
    .{ .piece = .DFR, .face = 0 },
    .{ .piece = .DRB, .face = 0 },
    .{ .piece = .DLB, .face = 0 },
};

