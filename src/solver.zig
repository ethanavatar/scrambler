const cubies = @import("cubies.zig");

const allMoves = .{
    { .face = .Right, .order = 1 }, { .face = .Right, .order = 2 }, { .face = .Right, .order = 3 },
    { .face = .Left,  .order = 1 }, { .face = .Left,  .order = 2 }, { .face = .Left,  .order = 3 },
    { .face = .Up,    .order = 1 }, { .face = .Up,    .order = 2 }, { .face = .Up,    .order = 3 },
    { .face = .Down,  .order = 1 }, { .face = .Down,  .order = 2 }, { .face = .Down,  .order = 3 },
    { .face = .Front, .order = 1 }, { .face = .Front, .order = 2 }, { .face = .Front, .order = 3 },
    { .face = .Back,  .order = 1 }, { .face = .Back,  .order = 2 }, { .face = .Back,  .order = 3 },
};


