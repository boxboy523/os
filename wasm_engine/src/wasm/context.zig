const std = @import("std");

const raw_data = @import("raw_data.zig");
const types = @import("types.zig");
const utils = @import("utils.zig");
const parser = @import("parser.zig");
const Process = @import("runner.zig").Process;
const VM = @import("vm.zig").VM;
const runner = @import("runner.zig");

pub const WasmContext = struct {
    module: raw_data.WasmModule,
    function_types: []FunctionType,
    imports: []ImportEntry,
    function_table: []u32,
    memories: []MemoryEntry,
    globals: []Global,
    exports: []ExportEntry,
    code_bodies: []CodeBody,
    arena: ?std.heap.ArenaAllocator,

    pub fn empty() WasmContext {
        return .{
            .module = raw_data.WasmModule.empty(),
            .function_types = &[_]FunctionType{},
            .imports = &[_]ImportEntry{},
            .function_table = &[_]u32{},
            .memories = &[_]MemoryEntry{},
            .globals = &[_]Global{},
            .exports = &[_]ExportEntry{},
            .code_bodies = &[_]CodeBody{},
            .arena = null,
        };
    }

    pub fn init(module: raw_data.WasmModule, allocator: std.mem.Allocator) !WasmContext {
        var context = WasmContext{
            .module = module,
            .function_types = &[_]FunctionType{},
            .imports = &[_]ImportEntry{},
            .function_table = &[_]u32{},
            .memories = &[_]MemoryEntry{},
            .globals = &[_]Global{},
            .exports = &[_]ExportEntry{},
            .code_bodies = &[_]CodeBody{},
            .arena = null,
        };
        var arena = std.heap.ArenaAllocator.init(allocator);
        const arena_allocator = arena.allocator();
        errdefer context.deinit();
        if (module.type_section) |section| {
            context.function_types = try parser.parseTypeSection(section, arena_allocator);
        }
        if (module.import_section) |section| {
            context.imports = try parser.parseImportSection(section, arena_allocator);
        }
        if (module.function_section) |section| {
            context.function_table = try parser.parseFunctionSection(section, arena_allocator);
        }
        if (module.memory_section) |section| {
            context.memories = try parser.parseMemorySection(section, arena_allocator);
        }
        if (module.global_section) |section| {
            context.globals = try parser.parseGlobalSection(section, arena_allocator);
        }
        if (module.export_section) |section| {
            context.exports = try parser.parseExportSection(section, arena_allocator);
        }
        if (module.code_section) |section| {
            context.code_bodies = try parser.parseCodeSection(section, arena_allocator);
        }
        if (context.function_table.len != context.code_bodies.len) {
            return error.InvalidWasmFile; // Function count mismatch
        }
        context.arena = arena;
        return context;
    }

    pub fn print(self: WasmContext) void {
        std.debug.print("WasmContext:\n", .{});
        std.debug.print("  Function Types:\n", .{});
        for (self.function_types) |func_type| {
            std.debug.print("    - ", .{});
            func_type.print();
            std.debug.print("\n", .{});
        }
        std.debug.print("  Function Table:\n", .{});
        for (self.function_table) |func_index| {
            std.debug.print("    - {d}\n", .{func_index});
        }
        std.debug.print("  Imports:\n", .{});
        for (self.imports) |import| {
            std.debug.print("    - ", .{});
            import.print();
            std.debug.print("\n", .{});
        }
        std.debug.print("  Globals:\n", .{});
        for (self.globals) |global| {
            std.debug.print("    - ", .{});
            global.print();
            std.debug.print("\n", .{});
        }
        std.debug.print("  Exports:\n", .{});
        for (self.exports) |exp| {
            std.debug.print("    - ", .{});
            exp.print();
            std.debug.print("\n", .{});
        }
        std.debug.print("  Code Bodies:\n", .{});
        for (self.code_bodies) |code_body| {
            std.debug.print("    - ", .{});
            code_body.print();
            std.debug.print("\n", .{});
        }
    }

    pub fn deinit(self: WasmContext) void {
        if (self.arena) |arena| {
            arena.deinit();
        } else {
            std.debug.print("Warning: WasmContext deinit called without an arena allocator\n", .{});
        }
    }
};

pub const FunctionType = struct {
    params: []const types.ValueType,
    results: []const types.ValueType,

    pub fn parse(stream: *utils.byteStream, allocator: std.mem.Allocator) !FunctionType {
        const magic_byte = try stream.readByte();
        if (magic_byte != 0x60) {
            return error.InvalidTypeSection;
        }
        const param_count = try stream.readLEB128();
        const params_raw = try stream.slice(@as(usize, param_count));
        const result_count = try stream.readLEB128();
        const results_raw = try stream.slice(@as(usize, result_count));
        const params = try allocator.alloc(types.ValueType, param_count);
        for (params, 0..) |*param, index| {
            const param_byte = params_raw[index];
            const param_type: types.ValueType = @enumFromInt(param_byte);
            param.* = param_type;
        }
        const results = try allocator.alloc(types.ValueType, result_count);
        for (results, 0..) |*result, index| {
            const result_byte = results_raw[index];
            const result_type: types.ValueType = @enumFromInt(result_byte);
            result.* = result_type;
        }
        return .{
            .params = params,
            .results = results,
        };
    }

    pub fn print(self: FunctionType) void {
        std.debug.print("FunctionType(params: [", .{});
        for (self.params, 0..) |param, index| {
            if (index > 0) {
                std.debug.print(", ", .{});
            }
            std.debug.print("{s}", .{@tagName(param)});
        }
        std.debug.print("], results: [", .{});
        for (self.results, 0..) |result, index| {
            if (index > 0) {
                std.debug.print(", ", .{});
            }
            std.debug.print("{s}", .{@tagName(result)});
        }
        std.debug.print("])", .{});
    }

    pub fn free(self: FunctionType, allocator: std.mem.Allocator) void {
        allocator.free(self.params);
        allocator.free(self.results);
    }
};

pub const ImportEntry = struct {
    module: []const u8,
    name: []const u8,
    kind: types.ExternalKind,
    type_index: ?u64,
    element_type: ?types.ValueType,
    limits: ?types.Limits,
    global_content_type: ?types.ValueType,
    global_mutability: ?bool,

    pub fn parse(stream: *utils.byteStream) !ImportEntry {
        const module_len = try stream.readLEB128();
        const module = try stream.slice(@as(usize, module_len));
        const name_len = try stream.readLEB128();
        const name = try stream.slice(@as(usize, name_len));
        const kind_raw = try stream.readByte();
        const kind: types.ExternalKind = @enumFromInt(kind_raw);
        var ret = ImportEntry{
            .module = module,
            .name = name,
            .kind = kind,
            .type_index = null,
            .element_type = null,
            .limits = null,
            .global_content_type = null,
            .global_mutability = null,
        };
        switch (kind) {
            .Function => {
                ret.type_index = try stream.readLEB128();
            },
            .Table => {
                const element_type_raw = try stream.readByte();
                const element_type: types.ValueType = @enumFromInt(element_type_raw);
                const limits_flags = try stream.readByte();
                const has_max = (limits_flags & 0x01) != 0;
                const min = try stream.readLEB128();
                var max: ?u64 = null;
                if (has_max) {
                    max = try stream.readLEB128();
                }
                ret.element_type = element_type;
                ret.limits = .{ .min = min, .max = max };
            },
            .Memory => {
                const limits_flags = try stream.readByte();
                const has_max = (limits_flags & 0x01) != 0;
                const min = try stream.readLEB128();
                var max: ?u64 = null;
                if (has_max) {
                    max = try stream.readLEB128();
                }
                ret.limits = .{ .min = min, .max = max };
            },
            .Global => {
                const content_type_raw = try stream.readByte();
                const content_type: types.ValueType = @enumFromInt(content_type_raw);
                const mutability = try stream.readByte();
                if (mutability != 0 and mutability != 1) {
                    return error.InvalidWasmFile;
                }
                ret.global_content_type = content_type;
                ret.global_mutability = mutability == 1;
            },
            .Tag => {
                ret.type_index = try stream.readLEB128();
            },
        }
        return ret;
    }

    pub fn print(self: ImportEntry) void {
        std.debug.print("ImportEntry(module: \"{s}\", name: \"{s}\", kind: {s}", .{
            self.module,
            self.name,
            @tagName(self.kind),
        });
        switch (self.kind) {
            .Function => {
                std.debug.print(", type_index: {d}", .{self.type_index.?});
            },
            .Table => {
                std.debug.print(", element_type: {s}, limits: {{ min: {d}, max: {d} }}", .{
                    @tagName(self.element_type.?),
                    self.limits.?.min,
                    self.limits.?.max orelse 0,
                });
            },
            .Memory => {
                std.debug.print(", limits: {{ min: {d}, max: {d} }}", .{
                    self.limits.?.min,
                    self.limits.?.max orelse 0,
                });
            },
            .Global => {
                std.debug.print(", content_type: {s}, mutability: {s}", .{
                    @tagName(self.global_content_type.?),
                    if (self.global_mutability.?) "var" else "const",
                });
            },
            .Tag => {
                std.debug.print(", type_index: {d}", .{self.type_index.?});
            },
        }
        std.debug.print(")", .{});
    }
};

pub const ExportEntry = struct {
    name: []const u8,
    kind: types.ExternalKind,
    index: u64,

    pub fn parse(stream: *utils.byteStream) !ExportEntry {
        const name_len = try stream.readLEB128();
        const name = try stream.slice(@as(usize, name_len));
        const kind_raw = try stream.readByte();
        const kind: types.ExternalKind = @enumFromInt(kind_raw);
        const index = try stream.readLEB128();
        return .{
            .name = name,
            .kind = kind,
            .index = index,
        };
    }

    pub fn print(self: ExportEntry) void {
        std.debug.print("ExportEntry(name: \"{s}\", kind: {s}, index: {d})", .{
            self.name,
            @tagName(self.kind),
            self.index,
        });
    }
};

pub const LocalEntry = struct {
    count: u64,
    value_type: types.ValueType,
};

pub const CodeBody = struct {
    locals: []LocalEntry,
    code: []const u8,

    pub fn parse(stream: *utils.byteStream, allocator: std.mem.Allocator) !CodeBody {
        const body_size = try stream.readLEB128();
        const body_data = try stream.slice(@as(usize, body_size));
        var body_stream = utils.byteStream{ .data = body_data };
        const local_count = try body_stream.readLEB128();
        const locals = try allocator.alloc(LocalEntry, local_count);
        for (locals) |*local| {
            local.* = .{
                .count = try body_stream.readLEB128(),
                .value_type = @enumFromInt(try body_stream.readByte()),
            };
        }
        return .{
            .locals = locals,
            .code = body_stream.data,
        };
    }

    pub fn print(self: CodeBody) void {
        std.debug.print("CodeBody(locals: [", .{});
        for (self.locals, 0..) |local, index| {
            if (index > 0) {
                std.debug.print(", ", .{});
            }
            std.debug.print("{{ count: {d}, type: {s} }}", .{
                local.count,
                @tagName(local.value_type),
            });
        }
        std.debug.print("], code: [{d} bytes])", .{self.code.len});
    }

    pub fn free(self: CodeBody, allocator: std.mem.Allocator) void {
        allocator.free(self.locals);
    }
};

pub const MemoryEntry = struct {
    limits: types.Limits,
    is_64bit: bool,

    pub fn parse(stream: *utils.byteStream) !MemoryEntry {
        const flags = try stream.readByte();
        const is_64bit = (flags & 0x04) != 0;
        const has_max = (flags & 0x01) != 0;
        const min = try stream.readLEB128();
        var max: ?u64 = null;
        if (has_max) {
            max = try stream.readLEB128();
        }
        return .{
            .limits = .{ .min = min, .max = max },
            .is_64bit = is_64bit,
        };
    }

    pub fn print(self: MemoryEntry) void {
        std.debug.print("MemoryEntry(limits: {{ min: {d}, max: {d} }}, is_64bit: {s})", .{
            self.limits.min,
            self.limits.max orelse 0,
            if (self.is_64bit) "true" else "false",
        });
    }
};

pub const Global = struct {
    content_type: types.ValueType,
    mutable: bool,
    value: types.Value,

    pub fn parse(stream: *utils.byteStream, temp_vm: *VM, globals: []Global) !Global {
        const content_type_raw = try stream.readByte();
        const content_type: types.ValueType = @enumFromInt(content_type_raw);
        const mutability = try stream.readByte();
        if (mutability != 0 and mutability != 1) {
            std.debug.print("Invalid mutability byte: {d}\n", .{mutability});
            return error.InvalidWasmFile;
        }
        var empty_ctx = WasmContext.empty();
        const data = stream.data;
        empty_ctx.globals = globals;
        var code_body = [_]CodeBody{
            .{
                .locals = &[_]LocalEntry{},
                .code = data,
            },
        };
        empty_ctx.code_bodies = code_body[0..];
        try temp_vm.entry(0, &[_]types.Value{});
        while (true) {
            const opcode = data[temp_vm.pc];
            temp_vm.pc += 1;
            if (opcode == 0x0B) { // end opcode
                break;
            }
            try runner.executeOpcode(temp_vm, &empty_ctx, @enumFromInt(opcode));
        }
        const value = try temp_vm.stack.pop();
        if (temp_vm.stack.call_stack.length != 0) return error.InvalidConstantExpression;
        try stream.skip(temp_vm.pc);
        return .{
            .content_type = content_type,
            .mutable = mutability == 1,
            .value = value,
        };
    }

    pub fn print(self: Global) void {
        std.debug.print("Global(content_type: {s}, mutable: {s}, value: ", .{
            @tagName(self.content_type),
            if (self.mutable) "var" else "const",
        });
        self.value.print();
        std.debug.print(")", .{});
    }
};
