const utils = @import("utils.zig");

pub const Section = struct {
    id: u8,
    data: []const u8,
};

pub const WasmError = error{
    InvalidLEB128,
    InvalidSection,
    InvalidWasmFile,
    InvalidTypeSection,
    UnsupportedVersion,
};

pub const WasmModule = struct {
    raw_data: []const u8,
    type_section: ?Section,
    import_section: ?Section,
    function_section: ?Section,
    table_section: ?Section,
    memory_section: ?Section,
    global_section: ?Section,
    export_section: ?Section,
    start_section: ?Section,
    element_section: ?Section,
    code_section: ?Section,
    data_section: ?Section,
    data_count_section: ?Section,
    tag_section: ?Section,
};

pub const ValueType = enum(u8) {
    i32 = 0x7F,
    i64 = 0x7E,
    f32 = 0x7D,
    f64 = 0x7C,
    v128 = 0x7B,
    funcref = 0x70,
    externref = 0x6F,
    _,
};

pub fn OffsetResult(comptime T: type) type {
    return struct {
        value: T,
        offset: usize,
    };
}

pub const FunctionType = struct {
    params: []const u8,
    results: []const u8,

    pub fn parse(data: []const u8) !OffsetResult(FunctionType) {
        var offset: usize = 0;
        if (data.len == 0 || (data[offset] != 0x60)) {
            return error.InvalidTypeSection;
        }
        offset += 1; // skip 0x60
        const count_res1 = try utils.decodeLEB128(data[offset..]);
        const param_count = count_res1.value;
        offset += count_res1.offset;
        const params = try utils.safeSlice(data, offset, @as(usize, param_count));
        offset += param_count;
        const count_res2 = try utils.decodeLEB128(data[offset..]);
        const result_count = count_res2.value;
        offset += count_res2.offset;
        const results = try utils.safeSlice(data, offset, @as(usize, result_count));
        offset += result_count;
        return .{
            .value = FunctionType{
                .params = params,
                .results = results,
            },
            .offset = offset,
        };
    }

    pub fn getParamType(self: FunctionType, index: usize) ?ValueType {
        if (index >= self.params.len) return null;
        return @as(ValueType, self.params[index]);
    }

    pub fn getResultType(self: FunctionType, index: usize) ?ValueType {
        if (index >= self.results.len) return null;
        return @as(ValueType, self.results[index]);
    }
};
