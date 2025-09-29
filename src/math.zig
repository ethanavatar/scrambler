const std = @import("std");

pub fn binomialCoefficient(n: u64, k_in: u64) u64 {
    if (n == 0)    return 0;
    //if (k_in == 0) return 1;
    if (k_in > n)  return 0;

    const k = if (k_in < n - k_in) k_in else n - k_in;

    var result: u64 = 1;
    for (1..k + 1) |i| {
        result *= (n - i + 1);
        result /= i;
    }

    return result;
}

fn factorial(n: u64) u64 {
    var result: u64 = 1;

    for (1..n + 1) |i| {
        result *= i;
    }

    return result;
}

test {
    try std.testing.expectEqual(factorial(0), 1);
    try std.testing.expectEqual(factorial(1), 1);
    try std.testing.expectEqual(factorial(2), 2);
    try std.testing.expectEqual(factorial(3), 6);
    try std.testing.expectEqual(factorial(4), 24);
    try std.testing.expectEqual(factorial(5), 120);
}

pub fn lexicographicRank(permutation: []const u8) u64 {
    const n = permutation.len;
    var rank: u64 = 0;

    for (0..n) |i| {
        var smaller_count: u64 = 0;
        for ((i + 1)..n) |j| {
            if (permutation[j] < permutation[i]) {
                smaller_count += 1;
            }
        }

        rank += smaller_count * factorial(n - i - 1);
    }

    return rank;
}

pub fn lexicographicUnrank(e: []const u8, r: u64, allocator: std.mem.Allocator) !std.ArrayList(u8) {
    const n = e.len;

    var elements = std.ArrayList(u8).init(allocator);
    defer elements.deinit();

    try elements.appendSlice(e);

    var permutation = std.ArrayList(u8).init(allocator);
    var rank = r;

    std.debug.print("rank = {}\n", .{ rank });
    
    for (0..n) |i| {
        const f = factorial(n - i - 1);
        const index = rank / f;
        rank = rank % f;

        try permutation.append(elements.items[index]);

        for (index..elements.items.len - 1) |j| {
            elements.items[j] = elements.items[j + 1];
        }

        _ = elements.pop();
    }
    
    return permutation;
}

test {
    const elements = [_]u8{ 0, 1, 2, 3, 4, 5 };

    for (0..factorial(elements.len)) |rank| {
        const permutation = try lexicographicUnrank(&elements, rank, std.testing.allocator);
        defer permutation.deinit();

        //std.debug.print("rank: {}, permutation: {any}\n", .{ rank, permutation.items });
        try std.testing.expectEqual(rank, lexicographicRank(permutation.items));
    }
}
