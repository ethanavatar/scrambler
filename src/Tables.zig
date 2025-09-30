const std = @import("std");
const solver = @import("solver.zig");
const cubies = @import("cubies.zig");
const allocators = @import("allocators.zig");

var file_allocator: allocators.FileAllocator = undefined;

pub var phase1: []i8 = undefined;
pub var phase2: []i8 = undefined;

pub var edgeOrientation:   [][solver.allMoves.len]u16 = undefined;
pub var edgePermutation:   [][solver.allMoves.len]u16 = undefined;
pub var cornerOrientation: [][solver.allMoves.len]u16 = undefined;
pub var cornerPermutation: [][solver.allMoves.len]u16 = undefined;
pub var slicePermutation:  [][solver.allMoves.len]u16 = undefined;

fn generatePruneTable(
    total_entries: usize,
    encode_function: *const fn (cube: solver.CoordinateCube) ?usize,
    decode_function: *const fn (index: usize) ?solver.CoordinateCube,
) ![]i8 {
    var table = try allocators.allocUntouched(file_allocator.allocator(), i8, total_entries);
    if (!file_allocator.created_new_file) {
        return table;
    }

    @memset(table, -1);

    const solved_index = encode_function(solver.CoordinateCube.solved()) orelse unreachable;
    table[solved_index] = 0;

    var depth:  usize = 0;
    var filled: usize = 1;

    while (filled < total_entries): (depth += 1) {
        std.debug.print("depth = {}, filled = {}\r", .{ depth, filled });
        for (0..total_entries) |i| {

            const v = table[i];
            if (v != depth) continue;

            const coordinate = decode_function(i) orelse unreachable;
        
            for (solver.allMoves, 0..) |_, move_index| {
                const next_coordinate = coordinate.move(move_index); 

                if (encode_function(next_coordinate)) |next_index| {
                    if (table[next_index] == -1) {
                        table[next_index] = @intCast(depth + 1);
                        filled += 1;
                    }
                }

            }

        }
    }

    std.debug.print("\n", .{ });
    return table;
}

fn generateMoveTable(
    total_entries: usize,
    encode_function: *const fn (cube: cubies.CubieCube) u16,
    decode_function: *const fn (coord: u16, arena: std.mem.Allocator) anyerror!cubies.CubieCube,
) ![][solver.allMoves.len]u16 {
    var table = try allocators.allocUntouched(file_allocator.allocator(), [solver.allMoves.len]u16, total_entries);
    if (!file_allocator.created_new_file) {
        return table;
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    for (0..total_entries) |coord| {
        defer _ = arena.reset(.retain_capacity);

        var cube = try decode_function(@intCast(coord), arena.allocator());
        for (solver.allMoves, 0..) |move, move_index| {
            cube.turn(move);
            defer cube.turn(move.inverse());

            table[coord][move_index] = encode_function(cube);
        }
    }

    return table;
}

pub fn generateAll() !void {
    // TODO: Assert that none of the tables have -1 in them

    const cwd = std.fs.cwd();
    const tables_directory = try cwd.makeOpenPath("tables", .{ .access_sub_paths = true });

    file_allocator = allocators.FileAllocator{ .dir = tables_directory };

    edgeOrientation = try generateMoveTable(
        2048,
        solver.encodeEdgeOrientation, solver.decodeEdgeOrientation,
    );

    edgePermutation = try generateMoveTable(
        40320,
        solver.encodeEdgePermutation, solver.decodeEdgePermutation,
    );

    cornerOrientation = try generateMoveTable(
        2187,
        solver.encodeCornerOrientation, solver.decodeCornerOrientation,
    );

    cornerPermutation = try generateMoveTable(
        40320,
        solver.encodeCornerPermutation, solver.decodeCornerPermutation,
    );

    slicePermutation = try generateMoveTable(
        495,
        solver.encodeSlicePermutation, solver.decodeSlicePermutation,
    );

    phase1 = try generatePruneTable(
        4478976,
        solver.encodeCoordinateToTableIndex, solver.decodeTableIndexToCoordinate,
    );

    phase2 = try generatePruneTable(
        812851200,
        solver.encodePhase2CoordToIndex, solver.decodePhase2IndexToCoord,
    );
}

pub fn freeAll() void {
    allocators.freeUntouched(file_allocator.allocator(), phase1);
    allocators.freeUntouched(file_allocator.allocator(), phase2);
    allocators.freeUntouched(file_allocator.allocator(), edgeOrientation);
    allocators.freeUntouched(file_allocator.allocator(), edgePermutation);
    allocators.freeUntouched(file_allocator.allocator(), cornerOrientation);
    allocators.freeUntouched(file_allocator.allocator(), cornerPermutation);
    allocators.freeUntouched(file_allocator.allocator(), slicePermutation);
}
