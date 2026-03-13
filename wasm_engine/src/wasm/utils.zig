const types = @import("types.zig");

pub const OffsetResult = struct {
    offset: usize,
    value: u64,
};

pub fn decodeLEB128(data: []const u8) !OffsetResult {
    var result: u64 = 0;
    var shift: u6 = 0;
    var index: usize = 0;

    if (data.len == 0) {
        return error.UnexpectedEndOfData;
    }
    for (data, 0..) |byte, idx| {
        if (idx >= 10) {
            return error.InvalidLEB128; // LEB128 should not exceed 10 bytes for u64
        }
        const value = byte & 0x7F;
        result |= @as(u64, value) << shift;
        if (byte & 0x80 == 0) {
            index = idx + 1; // Return the number of bytes read
            break;
        }
        shift += 7;
    }
    return OffsetResult{
        .offset = index,
        .value = result,
    };
}

pub const byteStream = struct {
    data: []const u8,

    pub fn readByte(self: *byteStream) !u8 {
        if (self.data.len == 0) {
            return error.UnexpectedEndOfData;
        }
        const byte = self.data[0];
        self.data = self.data[1..];
        return byte;
    }

    pub fn readLEB128(self: *byteStream) !u64 {
        const result = try decodeLEB128(self.data);
        self.data = self.data[result.offset..];
        return result.value;
    }

    pub fn offsetLEB128(self: *byteStream) !OffsetResult {
        const result = try decodeLEB128(self.data);
        self.data = self.data[result.offset..];
        return result;
    }

    pub fn slice(self: *byteStream, length: usize) ![]const u8 {
        if (self.data.len < length) {
            return error.UnexpectedEndOfData;
        }
        const rtn = self.data[0..length];
        self.data = self.data[length..];
        return rtn;
    }
};
