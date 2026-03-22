const std = @import("std");
const types = @import("types.zig");
const utils = @import("utils.zig");
const context = @import("context.zig");
const code = @import("context/code.zig");
const raw_data = @import("raw_data.zig");
const VM = @import("vm.zig").VM;

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

pub fn buildWasmModule(data: []const u8) !raw_data.WasmModule {
    var module = raw_data.WasmModule{
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

    var stream = utils.byteStream{ .data = data[8..] };
    var last_section: u8 = 0;
    while (stream.data.len > 0) {
        const section_id = try stream.readByte();
        const section_size = try stream.readLEB128();
        const section_data = try stream.slice(@as(usize, section_size));
        if (section_id == 0) { // skip custom section_id
            continue;
        } else if (section_id <= last_section) {
            return error.InvalidSection;
        }
        last_section = section_id;
        const section = raw_data.Section{
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

pub fn parseFunctionSection(section: raw_data.Section, allocator: std.mem.Allocator) ![]types.TypeIdx {
    var stream = section.stream();
    const count = try stream.readLEB128();
    const func_table = try allocator.alloc(types.TypeIdx, count);
    for (func_table) |*entry| {
        const index = try stream.readLEB128();
        entry.val = index;
    }
    return func_table;
}

pub fn parseTypeSection(section: raw_data.Section, allocator: std.mem.Allocator) ![]context.FuncType {
    var stream = section.stream();
    const type_count = try stream.readLEB128();
    const func_types = try allocator.alloc(context.FuncType, type_count);
    for (func_types) |*func_type| {
        func_type.* = try context.FuncType.parse(&stream, allocator);
    }
    return func_types;
}

pub fn parseImportSection(section: raw_data.Section, allocator: std.mem.Allocator) ![]context.ImportEntry {
    var stream = section.stream();
    const import_count = try stream.readLEB128();
    const imports = try allocator.alloc(context.ImportEntry, import_count);
    for (imports) |*import| {
        import.* = try context.ImportEntry.parse(&stream);
    }
    return imports;
}

pub fn parseExportSection(section: raw_data.Section, allocator: std.mem.Allocator) ![]context.ExportEntry {
    var stream = section.stream();
    const export_count = try stream.readLEB128();
    const exports = try allocator.alloc(context.ExportEntry, export_count);
    for (exports) |*exp| {
        exp.* = try context.ExportEntry.parse(&stream);
    }
    return exports;
}

pub fn parseCodeSection(section: raw_data.Section, allocator: std.mem.Allocator) ![]code.CodeBody {
    var stream = section.stream();
    const code_count = try stream.readLEB128();
    const code_bodies = try allocator.alloc(code.CodeBody, code_count);
    for (code_bodies, 0..) |*body, idx| {
        body.* = try code.CodeBody.parse(&stream, .{ .val = idx }, allocator);
    }
    return code_bodies;
}

pub fn parseMemorySection(section: raw_data.Section, allocator: std.mem.Allocator) ![]context.MemoryEntry {
    var stream = section.stream();
    const memory_count = try stream.readLEB128();
    const memories = try allocator.alloc(context.MemoryEntry, memory_count);
    for (memories) |*memory| {
        memory.* = try context.MemoryEntry.parse(&stream);
    }
    return memories;
}

pub fn parseGlobalSection(section: raw_data.Section, allocator: std.mem.Allocator) ![]context.Global {
    var stream = section.stream();
    const global_count = try stream.readLEB128();
    const globals = try allocator.alloc(context.Global, global_count);
    for (globals, 0..) |*global, i| {
        global.* = try context.Global.parse(&stream, globals[0..i], allocator);
    }
    return globals;
}
