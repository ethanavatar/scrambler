
pub fn initAcending(comptime T: type) T {
    const T_Info = @typeInfo(T);
    const T_Child_Info = @typeInfo(T_Info.array.child);

    var v: [T_Info.array.len]T_Info.array.child = undefined;

    inline for (0..T_Info.array.len) |i| {
        if (T_Child_Info == .@"enum") {
            v[i] = @enumFromInt(i);

        } else {
            v[i] = i;
        }
    }

    return v;
}

pub fn join_strings(comptime sep: []const u8, comptime args: anytype) []const u8 {
    const args_T = @TypeOf(args);
    const args_T_info = @typeInfo(args_T);

    if (args_T_info != .@"struct") {
        @compileError("expected tuple or struct, found " ++ @typeName(args_T));
    }

    const args_len = args_T_info.@"struct".fields.len;
    const fields: [args_len][]const u8 = args;
    if (fields.len == 0) {
        return "";
    }

    comptime var res: []const u8 = fields[0];
    inline for (fields[1..]) |fld| {
        res = res ++ sep ++ fld;
    }

    return res;
}

