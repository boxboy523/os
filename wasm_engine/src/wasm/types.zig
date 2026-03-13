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
