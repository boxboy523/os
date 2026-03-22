const std = @import("std");
const utils = @import("utils.zig");
const Context = @import("context.zig").WasmContext;
const context = @import("context.zig");
const code = @import("context/code.zig");

pub const WasmError = error{
    InvalidLEB128,
    InvalidSection,
    InvalidWasmFile,
    InvalidTypeSection,
    UnsupportedVersion,
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

pub const ExternalKind = enum(u8) {
    Function = 0x00,
    Table = 0x01,
    Memory = 0x02,
    Global = 0x03,
    Tag = 0x04,
};

pub const Limits = struct {
    min: u64,
    max: ?u64,
};

pub const Value = union(enum) {
    i32: i32,
    i64: i64,
    f32: f32,
    f64: f64,
    meta: u64, // call_stack metadata, such as function index or local index

    pub fn print(self: Value) void {
        switch (self) {
            .i32 => std.debug.print("i32: {}", .{self.i32}),
            .i64 => std.debug.print("i64: {}", .{self.i64}),
            .f32 => std.debug.print("f32: {}", .{self.f32}),
            .f64 => std.debug.print("f64: {}", .{self.f64}),
            .meta => std.debug.print("meta: {}", .{self.meta}),
        }
    }
};

pub const TypeIdx = struct { val: usize };
pub const FuncIdx = struct { val: usize };
pub const CodeIdx = struct { val: usize };
pub const StackIdx = struct {
    val: usize,
    pub fn add(self: StackIdx, offset: usize) StackIdx {
        return StackIdx{ .val = self.val + offset };
    }
    pub fn sub(self: StackIdx, offset: usize) StackIdx {
        return StackIdx{ .val = self.val - offset };
    }
};
pub const LocalIdx = struct { val: usize };
pub const GlobalIdx = struct { val: usize };

pub const OpcodeTag = enum(u8) {
    unreachable_op = 0x00,
    nop = 0x01,
    block = 0x02,
    loop = 0x03,
    if_op = 0x04,
    else_op = 0x05,
    end = 0x0B,
    br = 0x0C,
    br_if = 0x0D,
    return_op = 0x0F,
    call = 0x10,
    local_get = 0x20,
    local_set = 0x21,
    global_get = 0x23,
    global_set = 0x24,
    i32_load = 0x28,
    i32_store = 0x36,
    i32_const = 0x41,
    i32_eqz = 0x45,
    i32_eq = 0x46,
    i32_ne = 0x47,
    i32_lt_s = 0x48,
    i32_lt_u = 0x49,
    i32_gt_s = 0x4A,
    i32_gt_u = 0x4B,
    i32_le_s = 0x4C,
    i32_le_u = 0x4D,
    i32_ge_s = 0x4E,
    i32_ge_u = 0x4F,
    i32_add = 0x6A,
    i32_sub = 0x6B,
};

pub const MemArg = struct {
    alignment: usize,
    offset: usize,
};

pub const BlockType = union(enum) {
    empty,
    single: ValueType,
    multi: *const context.FuncType,

    pub fn fromRaw(stream: *utils.byteStream, ctx: *const Context) !BlockType {
        const data = try stream.readSLEB128();
        var block_type: BlockType = undefined;
        if (data < 0) {
            const u_data: u64 = @bitCast(data);
            const byte: u8 = @intCast(u_data & 0x7F);
            switch (byte) {
                0x40 => block_type = BlockType{ .empty = {} },
                0x7F, 0x7E, 0x7D, 0x7C, 0x7B, 0x70, 0x6F => block_type = BlockType{ .single = @enumFromInt(byte) },
                else => return error.InvalidBlockType,
            }
        } else {
            block_type = BlockType{ .multi = try ctx.getTypePtr(.{ .val = @intCast(data) }) };
        }
        return block_type;
    }

    pub fn resultCount(self: BlockType) usize {
        return switch (self) {
            .empty => 0,
            .single => 1,
            .multi => self.multi.results.len,
        };
    }

    pub fn paramCount(self: BlockType) usize {
        return switch (self) {
            .multi => self.multi.params.len,
            else => 0,
        };
    }
};

pub const FuncRef = struct {
    func_idx: FuncIdx,
    func_type: *const context.FuncType,
    code_body: *const code.CodeBody,
};

pub const Opcode = union(OpcodeTag) {
    unreachable_op,
    nop,
    block: Block,
    loop: Block,
    if_op: Block,
    else_op: Block,
    end: Block,
    br: Block,
    br_if: Block,
    return_op: Block,
    call: FuncRef,
    local_get: LocalIdx,
    local_set: LocalIdx,
    global_get: GlobalIdx,
    global_set: GlobalIdx,
    i32_load: MemArg,
    i32_store: MemArg,
    i32_const: i32,
    i32_eqz,
    i32_eq,
    i32_ne,
    i32_lt_s,
    i32_lt_u,
    i32_gt_s,
    i32_gt_u,
    i32_le_s,
    i32_le_u,
    i32_ge_s,
    i32_ge_u,
    i32_add,
    i32_sub,
};

pub const BlockTag = enum(u8) {
    block = 0x02,
    loop = 0x03,
    if_blk = 0x04,
    else_blk = 0x05,
    function = 0x00,
};

pub const Block = struct {
    tag: BlockTag,
    stack_offset: usize, // how many values should be popped from the stack when exiting this block (if function, excludes parameters, metadata)
    to_jump: ?usize = null,
    type: BlockType,
    pub fn print(self: Block) void {
        std.debug.print("Block {{ type: {s}, stack_ptr: {d}}}", .{ @tagName(self.block_type), self.stack_ptr });
    }
};
