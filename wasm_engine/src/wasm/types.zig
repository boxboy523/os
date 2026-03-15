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

<<<<<<< HEAD
pub const Value = union(enum) {
=======
const Value = union(enum) {
>>>>>>> 336a68a41ad81c9d282961cac18d8ec18596c0d1
    i32: i32,
    i64: i64,
    f32: f32,
    f64: f64,
};

<<<<<<< HEAD
pub const Opcode = enum(u8) {
    Unreachable = 0x00,
    Nop = 0x01,
    End = 0x0B,
    Call = 0x10,
=======
const Opcode = enum(u8) {
    Unreachable = 0x00,
    Nop = 0x01,
    End = 0x0B,
>>>>>>> 336a68a41ad81c9d282961cac18d8ec18596c0d1
    LocalGet = 0x20,
    I32Const = 0x41,
    I32Add = 0x6A,
};
