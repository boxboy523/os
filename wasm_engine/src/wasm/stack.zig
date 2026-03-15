const std = @import("std");
const Value = @import("types.zig").Value;
const Context = @import("context.zig").WasmContext;

pub const STACK_AVAILABLE = 1;
pub const STACK_FIXED = 2;

pub const Stack = struct {
    allocator: ?std.mem.Allocator,
    data: []Value, // [arg0, arg1, ... ,  local0, local1, ... , saved_func_idx, saved_pc, saved_fp, ...]
    length: usize,
    frame_base: usize,
    function_index: usize,
    capacity: usize,
    initial_capacity: usize,
    flag: u8, // 2^0: is_available, 2^1: is_fixed,

    pub fn initFixed(buffer: []Value, flag: u8) Stack {
        const flag_with_availability = flag | STACK_AVAILABLE | STACK_FIXED;
        return Stack{
            .allocator = null,
            .data = buffer,
            .flag = flag_with_availability,
            .length = 0,
            .capacity = buffer.len,
            .initial_capacity = buffer.len,
        };
    }

    pub fn init(allocator: std.mem.Allocator, capacity: usize, flag: u8) !Stack {
        const data = try allocator.alloc(Value, capacity);
        const flag_with_availability = flag | STACK_AVAILABLE;
        return Stack{
            .allocator = allocator,
            .data = data,
            .flag = flag_with_availability,
            .length = 0,
            .frame_base = 0,
            .function_index = 0,
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
        if (value != .i32) {
            try self.push(value);
            return error.TypeMismatch;
        }
        return value.i32;
    }

    pub fn popI64(self: *Stack) !i64 {
        const value = try self.pop();
        if (value != .i64) {
            try self.push(value);
            return error.TypeMismatch;
        }
        return value.i64;
    }

    pub fn popF32(self: *Stack) !f32 {
        const value = try self.pop();
        if (value != .f32) {
            try self.push(value);
            return error.TypeMismatch;
        }
        return value.f32;
    }

    pub fn popF64(self: *Stack) !f64 {
        const value = try self.pop();
        if (value != .f64) {
            try self.push(value);
            return error.TypeMismatch;
        }
        return value.f64;
    }

    pub fn resize(self: *Stack, new_capacity: usize) !void {
        if (self.flag & STACK_FIXED != 0) {
            return error.StackIsFixed;
        }
        const new_data = try (self.allocator orelse {
            return error.Unreachable;
        }).realloc(self.data, new_capacity);
        self.capacity = new_capacity;
        self.data = new_data;
    }

    pub fn getLocal(self: *Stack, index: usize) !Value {
        const local_index = self.frame_base + index;
        if (local_index >= self.length) {
            return error.InvalidLocalIndex;
        }
        return self.data[local_index];
    }

    pub fn setLocal(self: *Stack, index: usize, value: Value) !void {
        const local_index = self.frame_base + index;
        if (local_index >= self.length) {
            return error.InvalidLocalIndex;
        }
        self.data[local_index] = value;
    }

    pub fn enterFrame(self: *Stack, context: *const Context, func_idx: usize, ret: u64) !void {
        const num_args = context.function_types[func_idx].params.len;
        var num_locals: usize = 0;
        for (context.code_bodies[func_idx].locals) |local| {
            num_locals += @intCast(local.count);
        }
        const new_frame_base = self.length - num_args;
        const extra_needed = num_locals + 3; // locals + saved_func_idx + saved_pc + saved_fp
        if (self.length + extra_needed > self.capacity) {
            try self.resize(self.capacity * 2);
        }

        for (0..num_locals) |i| {
            self.data[self.length + i] = Value{ .i32 = 0 };
        }
        self.data[self.length + num_locals] = Value{ .i64 = @intCast(self.function_index) };
        self.data[self.length + num_locals + 1] = Value{ .i64 = @intCast(ret) };
        self.data[self.length + num_locals + 2] = Value{ .i64 = @intCast(self.frame_base) };
        self.length += extra_needed;
        self.frame_base = new_frame_base;
        self.function_index = func_idx;
    }

    pub fn exitFrame(self: *Stack) !?usize {
        if (self.frame_base == 0) {
            self.length = 0;
            self.frame_base = 0;
            return null;
        }
        const saved_fp = self.data[self.length - 1].i64;
        const saved_pc = self.data[self.length - 2].i64;
        const saved_func_idx = self.data[self.length - 3].i64;
        self.length = self.frame_base;
        self.frame_base = @intCast(saved_fp);
        self.function_index = @intCast(saved_func_idx);
        if (self.flag & STACK_FIXED == 0 and
            self.length < self.capacity / 4 and
            self.capacity >= self.initial_capacity * 2)
        {
            try self.resize(self.capacity / 2);
        }
        return @intCast(saved_pc);
    }

    pub fn free(self: *Stack) void {
        self.allocator.free(self.data);
        self.data = &[_]Value{};
        self.flag = 0; // reset flags
    }
};

test "Stack: 기본 push 및 pop 테스트" {
    const allocator = std.testing.allocator;
    var stack = try Stack.init(allocator, 4, 0);
    defer stack.free();

    // i32 push/pop
    try stack.push(Value{ .i32 = 42 });
    const val1 = try stack.pop();
    try std.testing.expectEqual(@as(i32, 42), val1.i32);

    // f64 push/pop
    try stack.push(Value{ .f64 = 3.14 });
    const val2 = try stack.pop();
    try std.testing.expectEqual(@as(f64, 3.14), val2.f64);
}

test "Stack: 편의 함수(popI32 등) 및 타입 체크 테스트" {
    const allocator = std.testing.allocator;
    var stack = try Stack.init(allocator, 4, 0);
    defer stack.free();

    try stack.push(Value{ .i32 = 100 });
    try stack.push(Value{ .f32 = 2.5 });

    // 타입 미스매치 테스트
    _ = stack.popI64() catch |err| {
        try std.testing.expectEqual(error.TypeMismatch, err);
    };

    // 정상 팝
    const f_val = try stack.popF32();
    try std.testing.expectEqual(@as(f32, 2.5), f_val);

    const i_val = try stack.popI32();
    try std.testing.expectEqual(@as(i32, 100), i_val);
}

test "Stack: 동적 확장(Resize) 테스트" {
    const allocator = std.testing.allocator;
    // 초기 용량 2로 설정
    var stack = try Stack.init(allocator, 2, 0);
    defer stack.free();

    try stack.push(Value{ .i32 = 1 });
    try stack.push(Value{ .i32 = 2 });

    // 용량 초과 시점 (2 -> 4로 확장되어야 함)
    try stack.push(Value{ .i32 = 3 });
    try std.testing.expectEqual(@as(usize, 4), stack.capacity);
    try std.testing.expectEqual(@as(usize, 3), stack.length);
}

test "Stack: 고정 크기(STACK_FIXED) 모드 테스트" {
    const allocator = std.testing.allocator;
    // STACK_FIXED 플래그 설정
    var stack = try Stack.init(allocator, 2, STACK_FIXED);
    defer stack.free();

    try stack.push(Value{ .i32 = 1 });
    try stack.push(Value{ .i32 = 2 });

    // 고정 크기이므로 확장을 시도하면 에러가 발생해야 함
    const result = stack.push(Value{ .i32 = 3 });
    try std.testing.expectError(error.StackIsFixed, result);
}

test "Stack: Underflow 테스트" {
    const allocator = std.testing.allocator;
    var stack = try Stack.init(allocator, 4, 0);
    defer stack.free();

    const result = stack.pop();
    try std.testing.expectError(error.StackUnderflow, result);
}
