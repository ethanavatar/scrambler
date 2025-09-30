const std = @import("std");


const win32 = @cImport({
    @cDefine("WIN32_LEAN_AND_MEAN", "1");
    @cInclude("Windows.h");
});

dir: std.fs.Dir,
count: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),
created_new_file: bool = true,

const Self = @This();

/// Metadata stored at the end of each allocation.
const Metadata = extern struct {
    file_index: u32,
    mmap_size: usize align(4),
};

/// Returns the aligned size with enough space for `size` and `Metadata` at the end.
inline fn alignedFileSize(size: usize) usize {
    return std.mem.alignForward(usize, size + @sizeOf(Metadata), std.heap.pageSize());
}

pub inline fn allocator(self: *Self) std.mem.Allocator {
    return .{
        .ptr = self,
        .vtable = &.{
            .alloc = alloc,
            .resize = resize,
            .remap = remap,
            .free = free,
        },
    };
}

fn alloc(
    ctx: *anyopaque,
    requested_size: usize,
    _: std.mem.Alignment,
    return_address: usize,
) ?[*]u8 {
    _ = return_address;
    const self: *Self = @ptrCast(@alignCast(ctx));

    const file_aligned_size = alignedFileSize(requested_size);
    const file_index = self.count.fetchAdd(1, .monotonic);

    var file_name_buf: [255]u8 = undefined;
    const file_name = std.fmt.bufPrint(&file_name_buf, "bin_{d}", .{ file_index }) catch unreachable;

    var file_exists = true;

    self.dir.access(file_name, .{ }) catch |e| switch (e) {
        error.FileNotFound => file_exists = false,
        else => return null,
    };

    const file = if (file_exists)
        self.dir.openFile(file_name, .{ .mode = .read_write }) catch return null
    else
        self.dir.createFile(file_name, .{ .read = true }) catch return null;

    self.created_new_file = !file_exists;

    defer file.close();

    const stat = file.stat() catch return null;

    if (stat.size < file_aligned_size) {
        file.setEndPos(file_aligned_size) catch {
            return null;
        };
    }

    //const full_alloc = std.posix.mmap(
    //    null,
    //    file_aligned_size,
    //    std.posix.PROT.READ | std.posix.PROT.WRITE,
    //    std.posix.MAP{ .TYPE = .SHARED },
    //    file.handle,
    //    0,
    //) catch {
    //    return null;
    //};

    const fm = win32.CreateFileMapping(
        file.handle,
        null,
        win32.PAGE_READWRITE,
        @intCast((file_aligned_size >> 32) & @as(u32, 0xFFFFFFFF)),
        @intCast(file_aligned_size & @as(u32, 0xFFFFFFFF)),
        null
    );
    defer _ = win32.CloseHandle(fm);

    const full_alloc: []u8 = @as([*]u8, @ptrCast(win32.MapViewOfFile(
        fm,
        win32.FILE_MAP_ALL_ACCESS,
        0, 0,
        file_aligned_size
    ) orelse unreachable))[0..file_aligned_size];

    //const full_alloc: []u8 = win32.MapViewOfFile(
    //    fm,
    //    win32.FILE_MAP_READ | win32.FILE_MAP_WRITE,
    //    @intCast(file_aligned_size & @as(u32, 0xFFFFFFFF)),
    //    @intCast((file_aligned_size >> 32) & @as(u32, 0xFFFFFFFF)),
    //    file_aligned_size
    //) orelse unreachable;

    std.debug.assert(requested_size <= file_aligned_size - @sizeOf(Metadata)); // sanity check
    const metadata_start = file_aligned_size - @sizeOf(Metadata);
    std.mem.bytesAsValue(Metadata, full_alloc[metadata_start..][0..@sizeOf(Metadata)]).* = .{
        .file_index = file_index,
        .mmap_size = file_aligned_size,
    };
    return full_alloc.ptr;
}

/// Resizes the allocation within the bounds of the mmap'd address space if possible.
fn resize(
    ctx: *anyopaque,
    buf: []u8,
    _: std.mem.Alignment,
    requested_size: usize,
    return_address: usize,
) bool {
    _ = return_address;
    const self: *Self = @ptrCast(@alignCast(ctx));

    const old_file_aligned_size = alignedFileSize(buf.len);
    const new_file_aligned_size = alignedFileSize(requested_size);

    if (new_file_aligned_size == old_file_aligned_size) {
        return true;
    }

    const buf_ptr: [*]align(std.heap.pageSize()) u8 = @alignCast(buf.ptr);
    const old_metadata_start = old_file_aligned_size - @sizeOf(Metadata);
    const metadata: Metadata = @bitCast(blk: {
        // you might think this block can be replaced with:
        //      buf_ptr[old_metadata_start..][0..@sizeOf(Metadata)].*
        // but no, that causes bus errors. it's not the same!
        var metadata_bytes: [@sizeOf(Metadata)]u8 = undefined;
        @memcpy(&metadata_bytes, buf_ptr[old_metadata_start..][0..@sizeOf(Metadata)]);
        break :blk metadata_bytes;
    });

    if (new_file_aligned_size > metadata.mmap_size) {
        return false;
    }

    var file_name_buf: [255]u8 = undefined;
    const file_name = std.fmt.bufPrint(&file_name_buf, "bin_{d}", .{ metadata.file_index }) catch unreachable;

    const file = self.dir.openFile(file_name, .{ .mode = .read_write }) catch {
        return false;
    };
    defer file.close();

    file.setEndPos(new_file_aligned_size) catch return false;

    std.debug.assert(requested_size <= new_file_aligned_size - @sizeOf(Metadata));
    const new_metadata_start = new_file_aligned_size - @sizeOf(Metadata);
    std.mem.bytesAsValue(
        Metadata,
        buf_ptr[new_metadata_start..][0..@sizeOf(Metadata)],
    ).* = metadata;

    return true;
}

fn remap(
    context: *anyopaque,
    memory: []u8,
    alignment: std.mem.Alignment,
    new_len: usize,
    return_address: usize,
) ?[*]u8 {
    return if (resize(
        context,
        memory,
        alignment,
        new_len,
        return_address,
    )) memory.ptr else null;
}

/// unmaps the memory and deletes the associated file.
fn free(
    ctx: *anyopaque,
    buf: []u8,
    _: std.mem.Alignment,
    return_address: usize,
) void {
    _ = return_address;
    _ = ctx;
    //const self: *Self = @ptrCast(@alignCast(ctx));
    std.debug.assert(buf.len != 0); // should be ensured by the allocator interface

    //const file_aligned_size = alignedFileSize(buf.len);

    const buf_ptr: [*]align(std.heap.pageSize()) u8 = @alignCast(buf.ptr);
    //const metadata_start = file_aligned_size - @sizeOf(Metadata);
    //const metadata: Metadata = @bitCast(buf_ptr[metadata_start..][0..@sizeOf(Metadata)].*);

    //var file_name_buf: [255]u8 = undefined;
    //const file_name = std.fmt.bufPrint(&file_name_buf, "bin_{d}", .{ metadata.file_index }) catch unreachable;

    //std.posix.munmap(buf_ptr[0..metadata.mmap_size]);
    _ = win32.FlushViewOfFile(buf_ptr, 0);
    _ = win32.UnmapViewOfFile(buf_ptr);

    //self.dir.deleteFile(file_name) catch { };
}
