const std = @import("std");

const permutations = @import("permutations.zig");
const cubies = @import("cubies.zig");
const solver = @import("solver.zig");

const Tables = @import("Tables.zig");
const allocators = @import("allocators.zig");

const clap = @import("clap");

const Parameters = enum(u8) {
    Command,
    Scramble_Count,
};

const params = [_]clap.Param(u8){
    .{
        .id = @intFromEnum(Parameters.Command),
        .takes_value = .one,
    },
    .{
        .id = @intFromEnum(Parameters.Scramble_Count),
        .names = .{ .short = 'c', .long = "count" },
        .takes_value = .one,
    },
};


pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var tables = try Tables.generateAll();
    defer tables.freeAll();

    const allocator = arena.allocator();
    
    var iter = try std.process.ArgIterator.initWithAllocator(allocator);
    defer iter.deinit();

    _ = iter.next();

    var diag = clap.Diagnostic{};
    var parser = clap.streaming.Clap(u8, std.process.ArgIterator){
        .params = &params, .iter = &iter, .diagnostic = &diag,
    };

    while (parser.next() catch |err| {
        try diag.reportToFile(.stderr(), err);
        return err;
    }) |arg| {
        switch (@as(Parameters, @enumFromInt(arg.param.id))) {
            Parameters.Command => {
                const command = arg.value.?;
                if (std.mem.eql(u8, command, "scramble")) try scrambleCommand(allocator, &parser, &diag)
                else std.debug.print("Unknown command: {s}", .{ command });
            },
            else => unreachable,
        }
    }
}


fn scrambleCommand(
    allocator: std.mem.Allocator,
    parser: *clap.streaming.Clap(u8, std.process.ArgIterator),
    diag: *clap.Diagnostic
) !void {
    while (parser.next() catch |err| {
        try diag.reportToFile(.stderr(), err);
        return err;
    }) |arg| {
        switch (@as(Parameters, @enumFromInt(arg.param.id))) {
            Parameters.Scramble_Count => {
                const count = try std.fmt.parseInt(u32, arg.value.?, 10);
                for (0..count) |_| {
                    try scrambleMain(allocator);
                }
            },
            else => unreachable,
        }
    }
}

fn scrambleMain(allocator: std.mem.Allocator) !void {
    const scramble = try cubies.CubieCube.randomState();
    const solutions = try solver.findSolutions(scramble, 1, allocator);
    const solution = solutions.items[0];

    var scrambled_cube = cubies.CubieCube.solved;

    std.debug.print("\n", .{ });

    var i = solution.moves.len;
    while (i > 0) {
        i -= 1;
        const move = solution.moves[i].inverse();
        std.debug.print("{f} ", .{ move });
        if (i == solution.phase1_end) {
            std.debug.print("\n", .{ });
        }
        scrambled_cube.turn(move);
    }

    std.debug.print("\n\n", .{ });
    std.debug.print("{f}\n", .{ scramble });

    std.debug.assert(std.mem.eql(cubies.Edge, &scramble.edgePermutations, &scrambled_cube.edgePermutations));
    std.debug.assert(std.mem.eql(cubies.Corner, &scramble.cornerPermutations, &scrambled_cube.cornerPermutations));
    std.debug.assert(std.mem.eql(u8, &scramble.edgeOrientations, &scrambled_cube.edgeOrientations));
    std.debug.assert(std.mem.eql(u8, &scramble.cornerOrientations, &scrambled_cube.cornerOrientations));
}
