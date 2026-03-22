const types = @import("types.zig");

pub const OffsetResult = struct {
    offset: usize,
    value: u64,
};

pub const OffsetSResult = struct {
    offset: usize,
    value: i64,
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

pub fn decodeSLEB128(data: []const u8) !OffsetSResult {
    var result: i64 = 0;
    var shift: u6 = 0;
    var index: usize = 0;

    if (data.len == 0) {
        return error.UnexpectedEndOfData;
    }
    for (data, 0..) |byte, idx| {
        if (idx >= 10) {
            return error.InvalidLEB128; // LEB128 should not exceed 10 bytes for i64
        }
        const value = byte & 0x7F;
        result |= @as(i64, value) << shift;
        if (byte & 0x80 == 0) {
            index = idx + 1; // Return the number of bytes read
            if (shift < 63 and (byte & 0x40) != 0) {
                result |= @as(i64, -1) << shift; // Sign extend if negative
            }
            break;
        }
        shift += 7;
    }
    return OffsetSResult{
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

    pub fn head(self: *byteStream) !u8 {
        if (self.data.len == 0) {
            return error.UnexpectedEndOfData;
        }
        return self.data[0];
    }

    pub fn readLEB128(self: *byteStream) !u64 {
        const result = try decodeLEB128(self.data);
        self.data = self.data[result.offset..];
        return result.value;
    }

    pub fn readSLEB128(self: *byteStream) !i64 {
        const result = try decodeSLEB128(self.data);
        self.data = self.data[result.offset..];
        return result.value;
    }

    pub fn offsetLEB128(self: *byteStream) !OffsetResult {
        const result = try decodeLEB128(self.data);
        self.data = self.data[result.offset..];
        return result;
    }

    pub fn offsetSLEB128(self: *byteStream) !OffsetSResult {
        const result = try decodeSLEB128(self.data);
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

    pub fn skip(self: *byteStream, length: usize) !void {
        if (self.data.len < length) {
            return error.UnexpectedEndOfData;
        }
        self.data = self.data[length..];
    }
};
