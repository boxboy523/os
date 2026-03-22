const std = @import("std");
const types = @import("../types.zig");
const utils = @import("../utils.zig");
const WasmContext = @import("../context.zig").WasmContext;
const Stack = @import("../stack.zig").Stack;

pub const LocalEntry = struct {
    count: u64,
    value_type: types.ValueType,
};

pub const BlockTemp = struct {
    tag: types.BlockTag,
    stack_size: usize,
    start_pc: usize,
    type: types.BlockType,
    br_else_patches: std.ArrayList(usize),
};

pub const CodeBody = struct {
    func_index: types.FuncIdx,
    locals: []LocalEntry,
    raw_code: []const u8,
    code: []const types.Opcode,

    pub fn parse(stream: *utils.byteStream, idx: types.FuncIdx, allocator: std.mem.Allocator) !CodeBody {
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
            .func_index = idx,
            .locals = locals,
            .raw_code = body_stream.data,
            .code = &[_]types.Opcode{},
        };
    }

    pub fn rawToCode(self: *CodeBody, context: WasmContext, allocator: std.mem.Allocator) !void {
        var code_stream = utils.byteStream{ .data = self.raw_code };
        var opcode_list: std.ArrayList(types.Opcode) = .empty;
        defer opcode_list.deinit(allocator);
        var stack_size: usize = 0;
        var block_temp_stack = try Stack(BlockTemp).init(allocator, 16, 0);
        defer {
            for (block_temp_stack.data) |*block_temp| {
                block_temp.br_else_patches.deinit(allocator);
            }
        }
        try block_temp_stack.push(.{
            .tag = .function,
            .stack_size = 0,
            .start_pc = 0,
            .type = .empty,
            .br_else_patches = .empty,
        });
        while (code_stream.data.len > 0) {
            const byte = try code_stream.readByte();
            std.debug.print("Parsing opcode byte: 0x{x} Stack Size: {d}\n", .{ byte, stack_size });
            const opcode_tag: types.OpcodeTag = @enumFromInt(byte);
            switch (opcode_tag) {
                inline .block, .loop, .if_op => |t| {
                    const block_type = try types.BlockType.fromRaw(&code_stream, &context);
                    if (t == .if_op) {
                        stack_size -= 1;
                    }
                    const block = types.Block{
                        .tag = switch (t) {
                            .block => .block,
                            .loop => .loop,
                            .if_op => .if_blk,
                            else => unreachable,
                        },
                        .stack_offset = block_type.paramCount(), // block parameters are already on the stack when the block starts
                        .type = block_type,
                    };
                    try block_temp_stack.push(.{
                        .tag = block.tag,
                        .stack_size = stack_size - block_type.paramCount(), // remember the stack size at the start of the block (after popping parameters)
                        .start_pc = opcode_list.items.len,
                        .type = block_type,
                        .br_else_patches = .empty,
                    });
                    try opcode_list.append(allocator, @unionInit(types.Opcode, @tagName(t), block));
                },
                inline .else_op => {
                    const block_temp = try block_temp_stack.getPtr(block_temp_stack.length.sub(1));
                    if (block_temp.tag != .if_blk) {
                        return error.InvalidWasmFile; // else without matching if
                    }
                    const start_opcode = &opcode_list.items[block_temp.start_pc];
                    switch (start_opcode.*) {
                        .if_op => |*if_opcode| {
                            if_opcode.to_jump = opcode_list.items.len + 1;
                        },
                        else => {
                            unreachable;
                        },
                    }
                    try block_temp.br_else_patches.append(allocator, opcode_list.items.len);
                    try opcode_list.append(allocator, .{
                        .else_op = .{
                            .tag = .else_blk,
                            .stack_offset = stack_size - block_temp.stack_size - block_temp.type.resultCount(), // same with end
                            .type = block_temp.type,
                        },
                    });
                    stack_size = block_temp.stack_size + block_temp.type.paramCount(); // reset stack size
                },
                inline .br, .br_if => |t| {
                    const label_index = try code_stream.readLEB128();
                    const block_temp = try block_temp_stack.getPtr(block_temp_stack.length.sub(1 + label_index));
                    if (block_temp.tag != .loop) {
                        try block_temp.br_else_patches.append(allocator, opcode_list.items.len);
                    }
                    switch (t) {
                        .br => {},
                        .br_if => {
                            stack_size -= 1;
                        }, // br_if will consume the condition value
                        else => {},
                    }
                    const presulved_count = if (block_temp.tag == .loop)
                        block_temp.type.paramCount()
                    else
                        block_temp.type.resultCount();
                    std.debug.print("stack size: {d}, block: {any}\n presolved count: {d}\n", .{ stack_size, block_temp, presulved_count });
                    const to_jump: ?usize = if (block_temp.tag == .loop)
                        block_temp.start_pc
                    else
                        null; // Will be set later when the block is closed
                    const block = types.Block{
                        .tag = block_temp.tag,
                        .stack_offset = stack_size - block_temp.stack_size - presulved_count, // the stack offset after popping values for the branch
                        .to_jump = to_jump,
                        .type = block_temp.type,
                    };
                    try opcode_list.append(allocator, @unionInit(types.Opcode, @tagName(t), block));
                },
                inline .end => {
                    var block_temp = try block_temp_stack.pop();
                    defer block_temp.br_else_patches.deinit(allocator);
                    if (block_temp.tag == .function) {
                        break; // function end, we are done
                    }
                    const start_opcode = &opcode_list.items[block_temp.start_pc];
                    const current_pc = opcode_list.items.len;
                    switch (start_opcode.*) {
                        .if_op => |*b| {
                            b.to_jump = b.to_jump orelse (current_pc + 1);
                        },
                        else => {},
                    }
                    for (block_temp.br_else_patches.items) |patch_index| {
                        const opcode_ptr = &opcode_list.items[patch_index];
                        switch (opcode_ptr.*) {
                            .br, .br_if, .else_op => |*b| {
                                b.to_jump = current_pc + 1;
                            },
                            else => {
                                unreachable; // Only br and br_if should be patched
                            },
                        }
                    }
                    const block_to_push = types.Block{
                        .tag = block_temp.tag,
                        .stack_offset = stack_size - block_temp.stack_size - block_temp.type.resultCount(), // the stack offset after popping values for the block result
                        .type = block_temp.type,
                    };
                    stack_size -= block_to_push.stack_offset; // pop values for the block result
                    try opcode_list.append(allocator, .{ .end = block_to_push });
                },
                inline .return_op => {
                    const func_type = try context.getTypePtr(self.func_index);
                    try opcode_list.append(allocator, .{
                        .return_op = .{
                            .tag = .function,
                            .stack_offset = @intCast(stack_size),
                            .type = .{ .multi = func_type },
                        },
                    });
                    stack_size -= func_type.results.len; // return will pop all result values
                },
                inline .call => {
                    const func_index = types.FuncIdx{ .val = try code_stream.readLEB128() };
                    const func_ref = types.FuncRef{
                        .func_idx = func_index,
                        .func_type = try context.getTypePtr(func_index),
                        .code_body = &context.code_bodies[func_index.val],
                    };
                    try opcode_list.append(allocator, .{ .call = func_ref });
                    stack_size += func_ref.func_type.results.len;
                    stack_size -= func_ref.func_type.params.len;
                },
                inline .local_get, .local_set, .global_get, .global_set => |t| {
                    const index = try code_stream.readLEB128();
                    try opcode_list.append(allocator, @unionInit(types.Opcode, @tagName(t), .{ .val = index }));
                    switch (t) {
                        .local_get, .global_get => {
                            stack_size += 1;
                        }, // get operation produces a value
                        .local_set, .global_set => {
                            stack_size -= 1;
                        }, // set operation consumes a value
                        else => {},
                    }
                },
                inline .i32_load, .i32_store => |t| {
                    const alignment = try code_stream.readLEB128();
                    const offset = try code_stream.readLEB128();
                    try opcode_list.append(allocator, @unionInit(types.Opcode, @tagName(t), .{ .alignment = alignment, .offset = offset }));
                    switch (t) {
                        .i32_load => {}, // load produces a value
                        .i32_store => {
                            stack_size -= 2;
                        }, // store consumes an address and a value
                        else => {},
                    }
                },
                inline .i32_const => {
                    const value = try code_stream.readLEB128();
                    try opcode_list.append(allocator, .{ .i32_const = @intCast(value) });
                    stack_size += 1;
                },
                inline .i32_eqz, .i32_eq, .i32_ne, .i32_lt_s, .i32_lt_u, .i32_gt_s, .i32_gt_u, .i32_le_s, .i32_le_u, .i32_ge_s, .i32_ge_u, .i32_add, .i32_sub, .i32_and, .i32_or, .i32_xor => |t| {
                    try opcode_list.append(allocator, @unionInit(types.Opcode, @tagName(t), {}));
                    switch (t) {
                        .i32_eqz => {},
                        else => {
                            stack_size -= 1;
                        },
                    }
                },
                inline else => |t| {
                    try opcode_list.append(allocator, @unionInit(types.Opcode, @tagName(t), {}));
                },
            }
        }
        self.code = try opcode_list.toOwnedSlice(allocator);
        block_temp_stack.deinit();
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

    pub fn deinit(self: CodeBody, allocator: std.mem.Allocator) void {
        allocator.free(self.locals);
        allocator.free(self.code);
    }
};
