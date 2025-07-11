const std = @import("std");

pub const CubeFace = enum(u8) {
    Right, Left,
    Front, Back,
    Up,    Down,
};

pub const CubeMove = struct {
    face:  CubeFace,
    order: enum(u8) { Single = 1, Double = 2, Prime = 3 } = .Single,
};

fn initStickers() [24]u8 {
    var stickers: [24]u8 = @splat(0);
    for (0..24) |i| {
        stickers[i] = i;
    }
    return stickers;
}

pub const CubeState = struct {
    edges:   [24]u8 = initStickers(),
    corners: [24]u8 = initStickers(),

    pub fn algorithm(self: *CubeState, moves: []CubeMove) void {
        for (moves) |move| {
            self.turn(move);
        }
    }

    pub fn algorithm_string(self: *CubeState, moves: []const u8) void {
        var sequence = std.mem.splitSequence(u8, moves, " ");
        while (sequence.next()) |move| {
            var order: u8 = 1;

            if (move.len == 2) {
                order = if (move[1] == '2') 2
                    else if (move[1] == '\'') 3
                    else @panic("invalid move modifier");
            }

            const face: CubeFace = switch (std.ascii.toUpper(move[0])) {
                'R' => .Right, 'L' => .Left,
                'F' => .Front, 'B' => .Back,
                'U' => .Up,    'D' => .Down,
                else => @panic("invalid move"),
            };

            self.turn(.{
                .face = face,
                .order = @enumFromInt(order)
            });
        }
    }

    pub fn turn(self: *CubeState, move: CubeMove) void {
        for (0..@intFromEnum(move.order)) |_| {
            switch (move.face) {
                .Right => {
                    cycleStickers(&self.edges,   &[_]u8{ 1,  19, 21, 9  });
                    cycleStickers(&self.edges,   &[_]u8{ 12, 13, 14, 15 });
                    cycleStickers(&self.corners, &[_]u8{ 1,  19, 21, 9  });
                    cycleStickers(&self.corners, &[_]u8{ 12, 13, 14, 15 });
                    cycleStickers(&self.corners, &[_]u8{ 2,  16, 22, 10 });
                },
                .Left => {
                    cycleStickers(&self.edges,   &[_]u8{ 3,  11, 23, 17 });
                    cycleStickers(&self.edges,   &[_]u8{ 4,  5,  6,  7  });
                    cycleStickers(&self.corners, &[_]u8{ 0,  8,  20, 18 });
                    cycleStickers(&self.corners, &[_]u8{ 3,  11, 23, 17 });
                    cycleStickers(&self.corners, &[_]u8{ 4,  5,  6,  7  });
                },
                .Front => {
                    cycleStickers(&self.edges,   &[_]u8{ 2,  15, 20, 5  });
                    cycleStickers(&self.edges,   &[_]u8{ 8,  9,  10, 11 });
                    cycleStickers(&self.corners, &[_]u8{ 2,  15, 20, 5  });
                    cycleStickers(&self.corners, &[_]u8{ 3,  12, 21, 6  });
                    cycleStickers(&self.corners, &[_]u8{ 8,  9,  10, 11 });
                },
                .Back => {
                    cycleStickers(&self.edges,   &[_]u8{ 0,  7,  22, 13 });
                    cycleStickers(&self.edges,   &[_]u8{ 16, 17, 18, 19 });
                    cycleStickers(&self.corners, &[_]u8{ 0,  7,  22, 13 });
                    cycleStickers(&self.corners, &[_]u8{ 1,  4,  23, 14 });
                    cycleStickers(&self.corners, &[_]u8{ 16, 17, 18, 19 });
                },
                .Up => {
                    cycleStickers(&self.edges,   &[_]u8{ 0,  1,  2, 3 });
                    cycleStickers(&self.edges,   &[_]u8{ 4, 16, 12, 8 });
                    cycleStickers(&self.corners, &[_]u8{ 0, 1,  2,  3 });
                    cycleStickers(&self.corners, &[_]u8{ 4, 16, 12, 8 });
                    cycleStickers(&self.corners, &[_]u8{ 5, 17, 13, 9 });
                },
                .Down => {
                    cycleStickers(&self.edges,   &[_]u8{ 6,  18, 14, 10 });
                    cycleStickers(&self.edges,   &[_]u8{ 20, 21, 22, 23 });
                    cycleStickers(&self.corners, &[_]u8{ 6,  18, 14, 10 });
                    cycleStickers(&self.corners, &[_]u8{ 7, 19, 15, 11 });
                    cycleStickers(&self.corners, &[_]u8{ 20, 21, 22, 23 });
                },
            }
        }
    }

    fn cycleStickers(stickers: *[24]u8, cycle: []const u8) void {
        const bufferSticker = cycle[0];
        for (cycle[1..]) |sticker| {
            swapStickers(stickers, bufferSticker, sticker);
        }
    }

    fn swapStickers(stickers: *[24]u8, a: usize, b: usize) void {
        stickers[a] ^= stickers[b];
        stickers[b] ^= stickers[a];
        stickers[a] ^= stickers[b];
    }

    fn ansi(colorIndex: usize) []const u8 {
        if (false) {}
        else if (colorIndex == 0) { return "\x1b[0;30;48;2;255;255;255m  \x1b[0m"; } // white
        else if (colorIndex == 1) { return "\x1b[0;30;48;2;255;125;0m  \x1b[0m"; }  // orange
        else if (colorIndex == 2) { return "\x1b[0;30;48;2;0;255;0m  \x1b[0m"; }    // green
        else if (colorIndex == 3) { return "\x1b[0;30;48;2;255;0;0m  \x1b[0m"; }    // red
        else if (colorIndex == 4) { return "\x1b[0;30;48;2;0;0;255m  \x1b[0m"; }    // blue
        else if (colorIndex == 5) { return "\x1b[0;30;48;2;255;255;0m  \x1b[0m"; }  // yellow
        else unreachable;
    }

    fn color(stickers: [24]u8, i: usize) []const u8 {
        const colorIndex = (stickers[i] - (stickers[i] % 4)) / 4;
        //std.debug.print("{d} = {s} ({d})\n", .{ i, ansi(colorIndex), colorIndex });
        return ansi(colorIndex);
    }

    pub fn format(
        self: CubeState,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {

        var c: [24][]const u8 = undefined;
        var e: [24][]const u8 = undefined;

        for (0..24) |i| {
            c[i] = color(self.corners, i);
            e[i] = color(self.edges,   i);
        }

        try writer.print("{s: ^6} {s}{s}{s}\n", .{ "", c[0], e[0],   c[1] });
        try writer.print("{s: ^6} {s}{s}{s}\n", .{ "", e[3], ansi(0), e[1] });
        try writer.print("{s: ^6} {s}{s}{s}\n", .{ "", c[3], e[2],   c[2] });

        const f = "{s}{s}{s} {s}{s}{s} {s}{s}{s} {s}{s}{s}\n";

        try writer.print(f, .{ c[4],  e[4],    c[5],   c[8],  e[8],    c[9],   c[12], e[12],   c[13],   c[16], e[16],   c[17] });
        try writer.print(f, .{ e[7],  ansi(1), e[5],   e[11], ansi(2), e[9],   e[15], ansi(3), e[13],   e[19], ansi(4), e[17], });
        try writer.print(f, .{ c[7],  e[6],    c[6],   c[11], e[10],   c[10],  c[15], e[14],   c[14],   c[19], e[18],   c[18], });

        try writer.print("{s: ^6} {s}{s}{s}\n", .{ "", c[20], e[20],   c[21] });
        try writer.print("{s: ^6} {s}{s}{s}\n", .{ "", e[23], ansi(5), e[21] });
        try writer.print("{s: ^6} {s}{s}{s}\n", .{ "", c[23], e[22],   c[22] });
    }
};
