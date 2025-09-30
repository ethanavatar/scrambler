const std = @import("std");


const win32 = @cImport({
    @cDefine("WIN32_LEAN_AND_MEAN", "1");
    @cInclude("Windows.h");
});

dir: std.fs.Dir,
file_name: []const u8,

offset: usize = 0,

const Self = @This();

inline fn alignedFileSize(size: usize) usize {
    return std.mem.alignForward(usize, size, std.heap.pageSize());
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

    var file_exists = true;

    self.dir.access(self.file_name, .{ }) catch |e| switch (e) {
        error.FileNotFound => file_exists = false,
        else => return null,
    };

    const file = if (file_exists)
        self.dir.openFile(self.file_name, .{ .mode = .read_write }) catch return null
    else
        self.dir.createFile(self.file_name, .{ .read = true }) catch return null;

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

    const full_alloc: []align(std.heap.pageSize()) u8 = @alignCast(@as([*]u8, @ptrCast(win32.MapViewOfFile(
        fm,
        win32.FILE_MAP_ALL_ACCESS,
        @intCast((self.offset >> 32) & @as(u32, 0xFFFFFFFF)),
        @intCast(self.offset & @as(u32, 0xFFFFFFFF)),
        file_aligned_size
    ) orelse unreachable))[0..file_aligned_size]);

    self.offset += full_alloc.len;

    //const full_alloc: []u8 = win32.MapViewOfFile(
    //    fm,
    //    win32.FILE_MAP_READ | win32.FILE_MAP_WRITE,
    //    @intCast(file_aligned_size & @as(u32, 0xFFFFFFFF)),
    //    @intCast((file_aligned_size >> 32) & @as(u32, 0xFFFFFFFF)),
    //    file_aligned_size
    //) orelse unreachable;

    return full_alloc.ptr;
}

/// Resizes the allocation within the bounds of the mmap'd address space if possible.
fn resize(
    _: *anyopaque,
    _: []u8,
    _: std.mem.Alignment,
    _: usize,
    _: usize,
) bool {

    // TODO: https://ziglang.org/documentation/master/std/#src/std/heap/PageAllocator.zig
    return false;
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
    const buf_ptr: [*]align(std.heap.pageSize()) u8 = @alignCast(buf.ptr);

    //std.posix.munmap(buf_ptr[0..metadata.mmap_size]);
    _ = win32.FlushViewOfFile(buf_ptr, 0);
    _ = win32.UnmapViewOfFile(buf_ptr);
}
