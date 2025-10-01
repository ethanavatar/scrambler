const std = @import("std");
const solver = @import("solver.zig");
const cubies = @import("cubies.zig");
const allocators = @import("allocators.zig");

var file_allocator: allocators.FileAllocator = undefined;

const Self = @This();

phase1: struct { magic: u32, table: [4478976]i8, },
phase2: struct { magic: u32, table: [812851200]i8, },

edgeOrientation:   struct { magic: u32, table: [2048][solver.allMoves.len]u16, },
edgePermutation:   struct { magic: u32, table: [40320][solver.allMoves.len]u16, },
cornerOrientation: struct { magic: u32, table: [2187][solver.allMoves.len]u16, },
cornerPermutation: struct { magic: u32, table: [40320][solver.allMoves.len]u16, },
slicePermutation:  struct { magic: u32, table: [495][solver.allMoves.len]u16, },

pub var tables: *Self = undefined;

fn generatePruneTable(
    expected_magic: u32,
    magic: *u32, table: []i8,
    encode_function: *const fn (cube: solver.CoordinateCube) ?usize,
    decode_function: *const fn (index: usize) ?solver.CoordinateCube,
) !void {
    if (magic.* == expected_magic) return;
    @memset(table, -1);

    const solved_index = encode_function(solver.CoordinateCube.solved) orelse unreachable;
    table[solved_index] = 0;

    var depth:  usize = 0;
    var filled: usize = 1;

    while (filled < table.len): (depth += 1) {
        std.debug.print("depth = {}, filled = {}\r", .{ depth, filled });
        for (0..table.len) |i| {

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
    magic.* = expected_magic;
}

fn generateMoveTable(
    expected_magic: u32,
    magic: *u32, table: [][solver.allMoves.len]u16,
    encode_function: *const fn (cube: cubies.CubieCube) u16,
    decode_function: *const fn (coord: u16, arena: std.mem.Allocator) anyerror!cubies.CubieCube,
) !void {
    if (magic.* == expected_magic) return;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    for (0..table.len) |coord| {
        defer _ = arena.reset(.retain_capacity);

        var cube = try decode_function(@intCast(coord), arena.allocator());
        for (solver.allMoves, 0..) |move, move_index| {
            cube.turn(move);
            defer cube.turn(move.inverse());

            table[coord][move_index] = encode_function(cube);
        }
    }

    magic.* = expected_magic;
}

pub fn generateAll() !*Self {
    const cwd = std.fs.cwd();
    const tables_directory = try cwd.makeOpenPath("tables", .{ .access_sub_paths = true });

    file_allocator = allocators.FileAllocator{ .dir = tables_directory, .file_name = "tables.bin" };
    var self = try allocators.createUntouched(file_allocator.allocator(), Self);
    tables = self;

    try generateMoveTable(
        std.mem.bytesToValue(u32, "EOMT"),
        &self.edgeOrientation.magic, &self.edgeOrientation.table,
        solver.encodeEdgeOrientation, solver.decodeEdgeOrientation,
    );

    try generateMoveTable(
        std.mem.bytesToValue(u32, "EPMT"),
        &self.edgePermutation.magic, &self.edgePermutation.table,
        solver.encodeEdgePermutation, solver.decodeEdgePermutation,
    );

    try generateMoveTable(
        std.mem.bytesToValue(u32, "COMT"),
        &self.cornerOrientation.magic, &self.cornerOrientation.table,
        solver.encodeCornerOrientation, solver.decodeCornerOrientation,
    );

    try generateMoveTable(
        std.mem.bytesToValue(u32, "CPMT"),
        &self.cornerPermutation.magic, &self.cornerPermutation.table,
        solver.encodeCornerPermutation, solver.decodeCornerPermutation,
    );

    try generateMoveTable(
        std.mem.bytesToValue(u32, "SPMT"),
        &self.slicePermutation.magic, &self.slicePermutation.table,
        solver.encodeSlicePermutation, solver.decodeSlicePermutation,
    );

    try generatePruneTable(
        std.mem.bytesToValue(u32, "P1PT"),
        &self.phase1.magic, &self.phase1.table,
        solver.encodeCoordinateToTableIndex, solver.decodeTableIndexToCoordinate,
    );

    try generatePruneTable(
        std.mem.bytesToValue(u32, "P2PT"),
        &self.phase2.magic, &self.phase2.table,
        solver.encodePhase2CoordToIndex, solver.decodePhase2IndexToCoord,
    );

    return self;
}

pub fn freeAll(self: *Self) void {
    allocators.destroyUntouched(file_allocator.allocator(), self);
}
