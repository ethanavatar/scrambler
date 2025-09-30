const std = @import("std");
pub const FileAllocator = @import("allocators/FileAllocator.zig");

pub fn allocUntouched(self: std.mem.Allocator, comptime T: type, n: usize) std.mem.Allocator.Error![]T {
    return allocAdvancedWithRetAddr(self, T, null, n, @returnAddress());
}

pub fn createUntouched(a: std.mem.Allocator, comptime T: type) std.mem.Allocator.Error!*T {
    if (@sizeOf(T) == 0) {
        const ptr = comptime std.mem.alignBackward(usize, std.math.maxInt(usize), @alignOf(T));
        return @ptrFromInt(ptr);
    }
    const ptr: *T = @ptrCast(try allocBytesWithAlignment(a, .of(T), @sizeOf(T), @returnAddress()));
    return ptr;
}

pub inline fn allocAdvancedWithRetAddr(
    self: std.mem.Allocator,
    comptime T: type,
    /// null means naturally aligned
    comptime alignment: ?std.mem.Alignment,
    n: usize,
    return_address: usize,
) std.mem.Allocator.Error![]align(if (alignment) |a| a.toByteUnits() else @alignOf(T)) T {
    const a = comptime (alignment orelse std.mem.Alignment.of(T));
    const ptr: [*]align(a.toByteUnits()) T = @ptrCast(try allocWithSizeAndAlignment(
        self, @sizeOf(T), a, n, return_address
    ));
    return ptr[0..n];
}

fn allocWithSizeAndAlignment(
    self: std.mem.Allocator,
    comptime size: usize,
    comptime alignment: std.mem.Alignment,
    n: usize,
    return_address: usize,
) std.mem.Allocator.Error![*]align(alignment.toByteUnits()) u8 {
    const byte_count = std.math.mul(usize, size, n) catch return std.mem.Allocator.Error.OutOfMemory;
    return allocBytesWithAlignment(self, alignment, byte_count, return_address);
}

fn allocBytesWithAlignment(
    self: std.mem.Allocator,
    comptime alignment: std.mem.Alignment,
    byte_count: usize,
    return_address: usize,
) std.mem.Allocator.Error![*]align(alignment.toByteUnits()) u8 {
    if (byte_count == 0) {
        const ptr = comptime alignment.backward(std.math.maxInt(usize));
        return @as([*]align(alignment.toByteUnits()) u8, @ptrFromInt(ptr));
    }

    const byte_ptr = self.rawAlloc(byte_count, alignment, return_address) orelse
        return std.mem.Allocator.Error.OutOfMemory;

    return @alignCast(byte_ptr);
}

pub fn freeUntouched(self: std.mem.Allocator, memory: anytype) void {
    const Slice = @typeInfo(@TypeOf(memory)).pointer;
    const bytes = std.mem.sliceAsBytes(memory);
    const bytes_len = bytes.len + if (Slice.sentinel() != null) @sizeOf(Slice.child) else 0;
    if (bytes_len == 0) return;
    const non_const_ptr = @constCast(bytes.ptr);
    self.rawFree(non_const_ptr[0..bytes_len], .fromByteUnits(Slice.alignment), @returnAddress());
}

pub fn destroyUntouched(self: std.mem.Allocator, ptr: anytype) void {
    const info = @typeInfo(@TypeOf(ptr)).pointer;
    if (info.size != .one) @compileError("ptr must be a single item pointer");
    const T = info.child;
    if (@sizeOf(T) == 0) return;
    const non_const_ptr = @as([*]u8, @ptrCast(@constCast(ptr)));
    self.rawFree(non_const_ptr[0..@sizeOf(T)], .fromByteUnits(info.alignment), @returnAddress());
}
