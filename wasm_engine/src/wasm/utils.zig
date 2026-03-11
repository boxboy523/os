const types = @import("types.zig");

pub fn decodeLEB128(bytes: []const u8) !types.OffsetResult(u64) {
    var result: u64 = 0;
    var shift: u6 = 0;
    var offset: usize = undefined;

    for (bytes, 0..) |byte, index| {
        if (index >= 10) {
            return error.InvalidLEB128; // LEB128 should not exceed 10 bytes for u64
        }
        const value = byte & 0x7F;
        result |= @as(u64, value) << shift;
        if (byte & 0x80 == 0) {
            offset = index + 1; // Return the number of bytes read
            break;
        }
        shift += 7;
    }
    return .{
        .value = result,
        .offset = offset,
    };
}

pub fn safeSlice(data: []const u8, offset: usize, length: usize) ![]const u8 {
    if (offset > data.len || (length > data.len - offset)) {
        return error.OutOfBounds;
    }
    return data[offset .. offset + length];
}
