const std = @import("std");

pub const STACK_AVAILABLE = 1;
pub const STACK_FIXED = 2;

const Value = union(enum) {
    i32: i32,
    i64: i64,
    f32: f32,
    f64: f64,
};

pub const Stack = struct {
    allocator: std.mem.Allocator,
    data: []Value,
    length: usize,
    capacity: usize,
    initial_capacity: usize,
    flag: u8, // 2^0: is_available, 2^1: is_fixed,
    pub fn init(allocator: std.mem.Allocator, capacity: usize, flag: u8) !Stack {
        const data = try allocator.alloc(Value, capacity);
        const flag_with_availability = flag | STACK_AVAILABLE;
        return Stack{
            .allocator = allocator,
            .data = data,
            .flag = flag_with_availability,
            .length = 0,
            .capacity = capacity,
            .initial_capacity = capacity,
        };
    }

    pub fn push(self: *Stack, value: Value) !void {
        if (self.data.len == 0) {
            return error.StackOverflow;
        }
        if (self.length >= self.capacity) {
            try self.resize(self.capacity * 2);
        }
        self.data[self.length] = value;
        self.length += 1;
    }

    pub fn pop(self: *Stack) !Value {
        if (self.data.len == 0 or self.length == 0) {
            return error.StackUnderflow;
        }
        self.length -= 1;
        const value = self.data[self.length];
        if (self.flag & STACK_FIXED == 0 and
            self.length < self.capacity / 4 and
            self.capacity >= self.initial_capacity * 2)
        {
            try self.resize(self.capacity / 2);
        }
        return value;
    }

    pub fn popI32(self: *Stack) !i32 {
        const value = try self.pop();
        if (value.tag != .i32) {
            return error.TypeMismatch;
        }
        return value.i32;
    }

    pub fn popI64(self: *Stack) !i64 {
        const value = try self.pop();
        if (value.tag != .i64) {
            return error.TypeMismatch;
        }
        return value.i64;
    }

    pub fn popF32(self: *Stack) !f32 {
        const value = try self.pop();
        if (value.tag != .f32) {
            return error.TypeMismatch;
        }
        return value.f32;
    }

    pub fn popF64(self: *Stack) !f64 {
        const value = try self.pop();
        if (value.tag != .f64) {
            return error.TypeMismatch;
        }
        return value.f64;
    }

    pub fn resize(self: *Stack, new_capacity: usize) !void {
        if (self.flag & STACK_FIXED != 0) {
            return error.StackIsFixed;
        }
        const new_data = try self.allocator.realloc(self.data, new_capacity);
        self.capacity = new_capacity;
        self.data = new_data;
    }

    pub fn free(self: *Stack) void {
        self.allocator.free(self.data);
        self.data = &[_]Value{};
        self.flag = 0; // reset flags
    }
};
