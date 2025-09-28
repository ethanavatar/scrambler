const std = @import("std");
const solver = @import("solver.zig");
const cubies = @import("cubies.zig");

pub var edgeOrientation: [][solver.allMoves.len]u16 = undefined;
pub var edgePermutation: [][solver.allMoves.len]u16 = undefined;
pub var cornerOrientation: [][solver.allMoves.len]u16 = undefined;
pub var cornerPermutation: [][solver.allMoves.len]u16 = undefined;

fn generate(
    total_entries: usize,
    encode_function: *const fn (cube: cubies.CubieCube) u16,
    decode_function: *const fn (coord: u16, arena: std.mem.Allocator) anyerror!cubies.CubieCube,
    allocator: std.mem.Allocator
) ![][solver.allMoves.len]u16 {
    var move_table = try allocator.alloc([solver.allMoves.len]u16, total_entries);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    for (0..total_entries) |coord| {
        defer _ = arena.reset(.retain_capacity);
        var cube = try decode_function(@intCast(coord), arena.allocator());

        for (solver.allMoves, 0..) |move, move_index| {
            cube.turn(move);
            move_table[coord][move_index] = encode_function(cube);
            cube.turn(move.inverse());
        }
    }

    return move_table;
}

pub fn generateAll() !void {
    const allocator = std.heap.page_allocator;
    edgeOrientation = try generate(2048, solver.encodeEdgeOrientation, solver.decodeEdgeOrientation, allocator);
    edgePermutation = try generate(40320, solver.encodeEdgePermutation, solver.decodeEdgePermutation, allocator);
    cornerOrientation = try generate(2187, solver.encodeCornerOrientation, solver.decodeCornerOrientation, allocator);
    cornerPermutation = try generate(40320, solver.encodeCornerPermutation, solver.decodeCornerPermutation, allocator);
}
