const std = @import("std");
const solver = @import("solver.zig");
const cubies = @import("cubies.zig");
const allocators = @import("allocators.zig");
const Symmetry = @import("Symmetry.zig");

var file_allocator: allocators.FileAllocator = undefined;

const Self = @This();

phase1: struct { magic: u32, table: [108039]i8, reps: []usize, reps_map: std.AutoArrayHashMap(usize, usize) },
phase2: struct { magic: u32, table: [812851200]i8, reps: []usize, reps_map: std.AutoArrayHashMap(usize, usize) },

edgeOrientation:   struct { magic: u32, table: [2048][solver.allMoves.len]u16, },
edgePermutation:   struct { magic: u32, table: [40320][solver.allMoves.len]u16, },
cornerOrientation: struct { magic: u32, table: [2187][solver.allMoves.len]u16, },
cornerPermutation: struct { magic: u32, table: [40320][solver.allMoves.len]u16, },
slicePermutation:  struct { magic: u32, table: [495][solver.allMoves.len]u16, },

pub var tables: *Self = undefined;

pub var phase1_reps: []usize = undefined;
pub var phase1_reps_map: std.AutoArrayHashMap(usize, usize) = undefined;

fn generatePruneTable(
    expected_magic: u32,
    total_states: usize,
    magic: *u32, table: []i8, reps: *[]usize, reps_map: *std.AutoArrayHashMap(usize, usize),
    encode_function: *const fn (cube: solver.CoordinateCube) ?usize,
    decode_function: *const fn (index: usize) ?solver.CoordinateCube,
) !void {
    if (magic.* == expected_magic) return;
    @memset(table, -1);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    reps.* = try allocator.alloc(usize, total_states);
    reps_map.* = std.AutoArrayHashMap(usize, usize).init(allocator);

    for (0..total_states) |i| {
        const coordinate = decode_function(i) orelse unreachable;

        var best_index = total_states;
        var best_class: usize = 48;

        for (0..48) |class| {
            const symmetric_coordinate = coordinate.applySymmetry(Symmetry.symmetries[class]) catch unreachable;
            const index = encode_function(symmetric_coordinate) orelse unreachable;

            if (index < best_index or (index == best_index and class < best_class)) {
                best_index = index;
                best_class = class;
            }
        }

        reps.*[i] = best_index;
        if (!reps_map.contains(best_index)) {
            try reps_map.put(best_index, reps_map.count());
        }

        if (i % 10000 == 0) {
            std.debug.print("symmetries = {}/{} ({d:.4}%)\r", .{
                i,
                total_states,
                (@as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(total_states))) * 100,
            });
        }
    }

    std.debug.print("symmetries = {}/{} (100%)\n", .{ total_states, total_states });
    std.debug.print("reps_map: {}\n", .{ reps_map.count() });

    const solved_index = encode_function(solver.CoordinateCube.solved) orelse unreachable;
    table[solved_index] = 0;

    var depth:  usize = 0;
    var filled: usize = 1;

    while (filled < reps_map.count()): (depth += 1) {
        std.debug.print("depth = {}, filled = {}\r", .{ depth, filled });
        for (0..total_states) |i| {

            const rep = reps.*[i];
            const v = table[reps_map.get(rep) orelse unreachable];

            if (v != depth) continue;

            const coordinate = decode_function(rep) orelse unreachable;
        
            for (solver.allMoves, 0..) |_, move_index| {
                const next_coordinate = coordinate.move(move_index); 

                if (encode_function(next_coordinate)) |next_index| {
                    const next_rep = reps.*[next_index];
                    const rep_index = reps_map.get(next_rep) orelse unreachable;

                    if (table[rep_index] == -1) {
                        table[rep_index] = @intCast(depth + 1);
                        filled += 1;
                    }
                }

            }
        }
        std.debug.print("depth = {}, filled = {}\r", .{ depth, filled });
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
    Symmetry.generate();

    const cwd = std.fs.cwd();
    const tables_directory = try cwd.makeOpenPath("tables", .{ .access_sub_paths = true });

    file_allocator = allocators.FileAllocator{ .dir = tables_directory, .file_name = "tables.bin" };
    const allocator = file_allocator.allocator();
    var self = try allocators.createUntouched(allocator, Self);
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

    //try generatePruneTable(
    //    std.mem.bytesToValue(u32, "P1PT"),
    //    4478976,
    //    &self.phase1.magic, &self.phase1.table, &self.phase1.reps, &self.phase1.reps_map,
    //    solver.encodeCoordinateToTableIndex, solver.decodeTableIndexToCoordinate,
    //);

    try generatePruneTable(
        std.mem.bytesToValue(u32, "P2PT"),
        812851200,
        &self.phase2.magic, &self.phase2.table, &self.phase2.reps, &self.phase2.reps_map,
        solver.encodePhase2CoordToIndex, solver.decodePhase2IndexToCoord,
    );

    @panic("");

    //return self;
}

pub fn freeAll(self: *Self) void {
    allocators.destroyUntouched(file_allocator.allocator(), self);
}
