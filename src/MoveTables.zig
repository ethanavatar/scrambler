const std = @import("std");
const solver = @import("solver.zig");
const cubies = @import("cubies.zig");

pub var edgeOrientation:   [][solver.allMoves.len]u16 = undefined;
pub var edgePermutation:   [][solver.allMoves.len]u16 = undefined;
pub var cornerOrientation: [][solver.allMoves.len]u16 = undefined;
pub var cornerPermutation: [][solver.allMoves.len]u16 = undefined;
pub var slicePermutation:  [][solver.allMoves.len]u16 = undefined;

fn generate(
    total_entries: usize,
    encode_function: *const fn (cube: cubies.CubieCube) u16,
    decode_function: *const fn (coord: u16, arena: std.mem.Allocator) anyerror!cubies.CubieCube,
    allocator: std.mem.Allocator
) ![][solver.allMoves.len]u16 {
    var move_table = try allocator.alloc([solver.allMoves.len]u16, total_entries);

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    for (0..total_entries) |coord| {
        defer _ = arena.reset(.retain_capacity);

        var cube = try decode_function(@intCast(coord), arena.allocator());
        for (solver.allMoves, 0..) |move, move_index| {
            cube.turn(move);
            defer cube.turn(move.inverse());

            move_table[coord][move_index] = encode_function(cube);
        }
    }

    return move_table;
}

fn writeToFile(
    file: std.fs.File,
    table: [][solver.allMoves.len]u16
) ![][solver.allMoves.len]u16 {

    var line_buffer: [255]u8 = undefined;
    const file_writer = file.writer(&line_buffer);
    var writer = file_writer.interface;

    for (table, 0..) |coords, coord| {
        for (table[coord], 0..) |_, move| {
            try writer.print("{},{},{}\n", .{ coord, move, coords[move] });
        }
    }

    return table;
}

fn readTableFromFile(
    total_entries: usize,
    file: std.fs.File,
    allocator: std.mem.Allocator
) ![][solver.allMoves.len]u16 {
    var move_table = try allocator.alloc([solver.allMoves.len]u16, total_entries);

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const contents = try file.readToEndAlloc(arena.allocator(), std.math.pow(usize, 2, 30));

    var lines = std.mem.splitSequence(u8, contents, "\n");
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var pairs = std.mem.splitSequence(u8, line, ",");
        const coord = try std.fmt.parseInt(u16, pairs.next() orelse unreachable, 10);
        const move  = try std.fmt.parseInt(u16, pairs.next() orelse unreachable, 10);
        const next_coord  = try std.fmt.parseInt(u16, pairs.next() orelse unreachable, 10);

        std.debug.assert(coord < total_entries);
        std.debug.assert(move < solver.allMoves.len);
        std.debug.assert(next_coord < total_entries);

        move_table[@intCast(coord)][@intCast(move)] = next_coord;
    }

    return move_table;
}

fn getTable(
    total_entries: usize,
    table_filename: []const u8,
    encode_function: *const fn (cube: cubies.CubieCube) u16,
    decode_function: *const fn (coord: u16, arena: std.mem.Allocator) anyerror!cubies.CubieCube,
    allocator: std.mem.Allocator
) ![][solver.allMoves.len]u16 {

    const cwd = std.fs.cwd();
    const tables_directory = try cwd.makeOpenPath("tables", .{ .access_sub_paths = true });

    var table_exists = true;

    tables_directory.access(table_filename, .{ }) catch |e| switch (e) {
        error.FileNotFound => table_exists = false,
        else => return e,
    };

    if (table_exists) {
        const file = try tables_directory.openFile(table_filename, .{ });
        defer file.close();

        std.debug.print("`{s}` already exists. Reading from file...\n", .{ table_filename });
        return try readTableFromFile(total_entries, file, allocator);

    } else {
        const table = try generate(total_entries, encode_function, decode_function, allocator);

        const file = try tables_directory.createFile(table_filename, .{ .exclusive = true });
        defer file.close();

        std.debug.print("Generating new table and writing to `{s}`...\n", .{ table_filename });
        return try writeToFile(file, table);
    }
}

pub fn generateAll(allocator: std.mem.Allocator) !void {
    edgeOrientation = try getTable(
        2048, "edgeOrientationMoves.txt",
        solver.encodeEdgeOrientation, solver.decodeEdgeOrientation,
        allocator
    );

    edgePermutation = try getTable(
        40320, "edgePermutationMoves.txt",
        solver.encodeEdgePermutation, solver.decodeEdgePermutation,
        allocator
    );

    cornerOrientation = try getTable(
        2187, "cornerOrientationMoves.txt",
        solver.encodeCornerOrientation, solver.decodeCornerOrientation,
        allocator
    );

    cornerPermutation = try getTable(
        40320, "cornerPermutationMoves.txt",
        solver.encodeCornerPermutation, solver.decodeCornerPermutation,
        allocator
    );

    slicePermutation = try getTable(
        495, "slicePermutationMoves.txt",
        solver.encodeSlicePermutation, solver.decodeSlicePermutation,
        allocator
    );
}
