const std = @import("std");
const types = @import("types.zig");
const utils = @import("utils.zig");

pub fn validateHeader(data: []const u8) !void {
    if (data.len < 8) {
        return error.InvalidHeader;
    }
    const magic = data[0..4];
    const version = data[4..8];
    if (!std.mem.eql(u8, magic, &[_]u8{ 0x00, 0x61, 0x73, 0x6D })) {
        return error.InvalidHeader;
    }
    if (!std.mem.eql(u8, version, &[_]u8{ 0x01, 0x00, 0x00, 0x00 })) {
        return error.UnsupportedVersion;
    }
}

pub fn buildWasmModule(data: []const u8) !types.WasmModule {
    var module = types.WasmModule{
        .raw_data = data,
        .type_section = null,
        .import_section = null,
        .function_section = null,
        .table_section = null,
        .memory_section = null,
        .global_section = null,
        .export_section = null,
        .start_section = null,
        .element_section = null,
        .code_section = null,
        .data_section = null,
        .data_count_section = null,
        .tag_section = null,
    };

    var offset: usize = 8; // Skip magic and version
    var last_section: u8 = 0;
    while (offset < data.len) {
        const section_id = data[offset];
        offset += 1;
        const offset_res = try utils.decodeLEB128(data[offset..]);
        offset += offset_res.offset;
        const section_data = try utils.safeSlice(data, offset, @as(usize, offset_res.value));
        offset += offset_res.value;
        if (offset > data.len) {
            return error.UnexpectedEndOfData;
        }
        if (section_id == 0) { // skip custom section_id
            continue;
        } else if (section_id <= last_section) {
            return error.InvalidSection;
        }
        last_section = section_id;
        const section = types.Section{
            .id = section_id,
            .data = section_data,
        };
        switch (section_id) {
            1 => module.type_section = section,
            2 => module.import_section = section,
            3 => module.function_section = section,
            4 => module.table_section = section,
            5 => module.memory_section = section,
            6 => module.global_section = section,
            7 => module.export_section = section,
            8 => module.start_section = section,
            9 => module.element_section = section,
            10 => module.code_section = section,
            11 => module.data_section = section,
            12 => module.data_count_section = section,
            13 => module.tag_section = section,
            else => return error.InvalidSection,
        }
    }
    return module;
}
