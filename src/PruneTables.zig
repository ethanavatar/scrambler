const std = @import("std");
const solver = @import("solver.zig");

pub var phase1: []i8 = undefined;
pub var phase2: []i8 = undefined;

fn generate(
    total_entries: usize,
    encode_function: *const fn (cube: solver.CoordinateCube) ?usize,
    decode_function: *const fn (index: usize) ?solver.CoordinateCube,
    allocator: std.mem.Allocator
) ![]i8 {
    var table = try allocator.alloc(i8, total_entries);
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

fn writeToFile(
    file: std.fs.File,
    table: []i8
) ![]i8 {
    var line_buffer: [255]u8 = undefined;
    const file_writer = file.writer(&line_buffer);
    var writer = file_writer.interface;

    for (table) |depth| {
        try writer.print("{}\n", .{ depth });
    }

    return table;
}

fn readTableFromFile(
    total_entries: usize,
    file: std.fs.File,
    allocator: std.mem.Allocator
) ![]i8 {
    var table = try allocator.alloc(i8, total_entries);

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    const contents = try file.readToEndAlloc(arena.allocator(), std.math.pow(usize, 2, 30) * 2);

    var line_number: usize = 0;
    var lines = std.mem.splitSequence(u8, contents, "\n");
    while (lines.next()) |line|: (line_number += 1) {
        if (line.len == 0) continue;
        table[line_number] = try std.fmt.parseInt(i8, line, 10);
    }

    return table;
}

fn getTable(
    total_entries: usize,
    table_filename: []const u8,
    encode_function: *const fn (cube: solver.CoordinateCube) ?usize,
    decode_function: *const fn (index: usize) ?solver.CoordinateCube,
    allocator: std.mem.Allocator
) ![]i8 {

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
    // TODO: Assert that none of the tables have -1 in them

    phase1 = try getTable(
        4478976, "phase1Prune.txt",
        solver.encodeCoordinateToTableIndex, solver.decodeTableIndexToCoordinate,
        allocator,
    );

    phase2 = try getTable(
        812851200, "phase2Prune.txt",
        solver.encodePhase2CoordToIndex, solver.decodePhase2IndexToCoord,
        allocator,
    );
}

