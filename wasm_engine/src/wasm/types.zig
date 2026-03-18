const std = @import("std");
const utils = @import("utils.zig");
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

    pub fn print(self: Value) void {
        switch (self) {
            .i32 => std.debug.print("i32: {}", .{self.i32}),
            .i64 => std.debug.print("i64: {}", .{self.i64}),
            .f32 => std.debug.print("f32: {}", .{self.f32}),
            .f64 => std.debug.print("f64: {}", .{self.f64}),
        }
    }
};

pub const Opcode = enum(u8) {
    Unreachable = 0x00,
    Nop = 0x01,
    End = 0x0B,
    Return = 0x0F,
    Call = 0x10,
    LocalGet = 0x20,
    LocalSet = 0x21,
    GlobalGet = 0x23,
    GlobalSet = 0x24,
    I32Load = 0x28,
    I32Store = 0x36,
    I32Const = 0x41,
    I32Add = 0x6A,
    I32Sub = 0x6B,
};

pub const BlockType = enum(u8) {
    Block = 0x02,
    Loop = 0x03,
    If = 0x04,
    Function = 0x00,
};

pub const Block = struct {
    block_type: BlockType align(8),
    stack_ptr: usize,
    start_pc: usize,
    end_pc: usize,
    result_count: usize,
    _padding: [24]u8,
};

comptime {
    if (@sizeOf(Block) != 64) {
        @compileError("Block struct must be exactly 64 bytes for efficient copying");
    }
}
