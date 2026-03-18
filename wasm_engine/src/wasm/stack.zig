const std = @import("std");
const Value = @import("types.zig").Value;
const Context = @import("context.zig").WasmContext;
const Block = @import("types.zig").Block;

pub const STACK_AVAILABLE = 1;
pub const STACK_FIXED = 2;
pub const STACK_REVERSED = 4;

pub fn Stack(comptime T: type) type {
    return struct {
        allocator: ?std.mem.Allocator,
        data: []T,
        length: usize,
        capacity: usize,
        initial_capacity: usize,
        flag: u8, // 2^0: is_available, 2^1: is_fixed, 2^2: is_reversed

        pub fn initFixed(buffer: []T, flag: u8) Stack(T) {
            const flag_with_availability = flag | STACK_AVAILABLE | STACK_FIXED;
            return Stack(T){
                .allocator = null,
                .data = buffer,
                .flag = flag_with_availability,
                .length = 0,
                .capacity = buffer.len,
                .initial_capacity = buffer.len,
            };
        }

        pub fn init(allocator: std.mem.Allocator, capacity: usize, flag: u8) !Stack(T) {
            const data = try allocator.alloc(T, capacity);
            const flag_with_availability = flag | STACK_AVAILABLE;
            return Stack(T){
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

        pub fn push(self: *Stack(T), value: T) !void {
            if (self.data.len == 0) {
                return error.StackOverflow;
            }
            if (self.length >= self.capacity) {
                try self.resize(self.capacity * 2);
            }
            if (self.flag & STACK_REVERSED != 0) {
                self.data[self.capacity - 1 - self.length] = value;
            } else {
                self.data[self.length] = value;
            }
            self.length += 1;
        }

        pub fn pushSlice(self: *Stack(T), values: []T) !void {
            if (self.data.len < values.len) {
                return error.StackOverflow;
            }
            while (self.length + values.len > self.capacity) {
                try self.resize(self.capacity * 2);
            }
            if (self.flag & STACK_REVERSED != 0) {
                for (0..values.len) |i| {
                    self.data[self.capacity - 1 - self.length - i] = values[values.len - 1 - i];
                }
            } else {
                std.mem.copyForwards(T, self.data[self.length..], values);
            }
            self.length += values.len;
        }

        pub fn pop(self: *Stack(T)) !T {
            if (self.data.len == 0 or self.length == 0) {
                return error.StackUnderflow;
            }
            self.length -= 1;
            const value = if (self.flag & STACK_REVERSED != 0)
                self.data[self.capacity - self.length - 1]
            else
                self.data[self.length];
            if (self.flag & STACK_FIXED == 0 and
                self.length < self.capacity / 4 and
                self.capacity >= self.initial_capacity * 2)
            {
                try self.resize(self.capacity / 2);
            }
            return value;
        }

        pub fn head(self: *Stack(T)) !T {
            if (self.data.len == 0 or self.length == 0) {
                return error.StackUnderflow;
            }
            return if (self.flag & STACK_REVERSED != 0)
                self.data[self.capacity - self.length]
            else
                self.data[self.length - 1];
        }

        pub fn get(self: *Stack(T), index: usize) !T {
            if (index >= self.length) {
                return error.StackIndexOutOfBounds;
            }
            return if (self.flag & STACK_REVERSED != 0)
                self.data[self.capacity - self.length + index]
            else
                self.data[index];
        }

        pub fn set(self: *Stack(T), index: usize, value: T) !void {
            if (index >= self.length) {
                return error.StackIndexOutOfBounds;
            }
            if (self.flag & STACK_REVERSED != 0) {
                self.data[self.capacity - self.length + index] = value;
            } else {
                self.data[index] = value;
            }
        }

        pub fn move(self: *Stack(T), target: []T) !void {
            if (self.flag & STACK_FIXED == 0) {
                return error.StackNotFixed;
            }
            if (target.len < self.length) {
                return error.TargetBufferTooSmall;
            }
            if (self.flag & STACK_REVERSED != 0) {
                for (0..self.length) |i| {
                    target[i] = self.data[self.capacity - self.length + i];
                }
            } else {
                std.mem.copyForwards(T, target, self.data[0..self.length]);
            }
            self.capacity = target.len;
        }

        pub fn resize(self: *Stack(T), new_capacity: usize) !void {
            if (self.flag & STACK_FIXED != 0) {
                return error.StackIsFixed;
            }
            const new_data = try (self.allocator orelse {
                return error.Unreachable;
            }).realloc(self.data, new_capacity);
            self.capacity = new_capacity;
            self.data = new_data;
        }

        pub fn clear(self: *Stack(T)) void {
            self.length = 0;
        }

        pub fn free(self: *Stack(T)) void {
            self.allocator.free(self.data);
            self.data = &[_]Value{};
            self.flag = 0; // reset flags
        }
    };
}
pub const StackSpace = struct {
    allocator: std.mem.Allocator,
    call_stack: Stack(Value),
    control_stack: Stack(Block),
    data: []u8,
    frame_base: usize,
    function_index: usize,

    pub fn init(allocator: std.mem.Allocator, capacity: usize, flag: u8) !StackSpace {
        const align_bytes = @max(@alignOf(Value), @alignOf(Block));
        const alignment = comptime std.mem.Alignment.fromByteUnits(align_bytes);
        const data_space = try allocator.alignedAlloc(u8, alignment, capacity * align_bytes);
        const stack_slice = std.mem.bytesAsSlice(Value, data_space);
        const block_slice = std.mem.bytesAsSlice(Block, data_space);
        return .{
            .allocator = allocator,
            .call_stack = Stack(Value).initFixed(stack_slice, flag),
            .control_stack = Stack(Block).initFixed(block_slice, flag | STACK_REVERSED),
            .data = data_space,
            .frame_base = 0,
            .function_index = 0,
        };
    }

    pub fn pop(self: *StackSpace) !Value {
        return try self.call_stack.pop();
    }

    pub fn popI32(self: *StackSpace) !i32 {
        const value = try self.call_stack.pop();
        if (value != .i32) {
            try self.push(value);
            return error.TypeMismatch;
        }
        return value.i32;
    }

    pub fn popI64(self: *StackSpace) !i64 {
        const value = try self.call_stack.pop();
        if (value != .i64) {
            try self.push(value);
            return error.TypeMismatch;
        }
        return value.i64;
    }

    pub fn popF32(self: *StackSpace) !f32 {
        const value = try self.call_stack.pop();
        if (value != .f32) {
            try self.push(value);
            return error.TypeMismatch;
        }
        return value.f32;
    }

    pub fn popF64(self: *StackSpace) !f64 {
        const value = try self.call_stack.pop();
        if (value != .f64) {
            try self.push(value);
            return error.TypeMismatch;
        }
        return value.f64;
    }

    pub fn push(self: *StackSpace, value: Value) !void {
        try self.check_overlap(@sizeOf(Value));
        try self.call_stack.push(value);
    }

    pub fn getLocal(self: *StackSpace, index: usize) !Value {
        const local_index = self.frame_base + index;
        return try self.call_stack.get(local_index);
    }

    pub fn setLocal(self: *StackSpace, index: usize, value: Value) !void {
        const local_index = self.frame_base + index;
        return try self.call_stack.set(local_index, value);
    }

    pub fn enterFrame(self: *StackSpace, context: *const Context, func_idx: usize, ret: u64) !void {
        const func_type_idx: usize = @intCast(context.function_table[func_idx]);
        const num_args = context.function_types[func_type_idx].params.len;
        var num_locals: usize = 0;
        for (context.code_bodies[func_idx].locals) |local| {
            num_locals += @intCast(local.count);
        }
        const new_frame_base = self.call_stack.length - num_args;

        try self.check_overlap(@sizeOf(Value) * (num_locals + 3));

        for (0..num_locals) |_| {
            try self.call_stack.push(Value{ .i64 = 0 });
        }
        try self.call_stack.push(Value{ .i64 = @intCast(self.function_index) });
        try self.call_stack.push(Value{ .i64 = @intCast(ret) });
        try self.call_stack.push(Value{ .i64 = @intCast(self.frame_base) });
        self.frame_base = new_frame_base;
        self.function_index = func_idx;
    }

    pub fn exitFrame(self: *StackSpace) !?usize {
        if (self.frame_base == 0) {
            self.clear_callstack();
            return null;
        }
        const saved_fp = (try self.call_stack.pop()).i64;
        const saved_pc = (try self.call_stack.pop()).i64;
        const saved_func_idx = (try self.call_stack.pop()).i64;
        self.call_stack.length = self.frame_base;
        self.frame_base = @intCast(saved_fp);
        self.function_index = @intCast(saved_func_idx);
        return @intCast(saved_pc);
    }

    pub fn clear_callstack(self: *StackSpace) void {
        self.call_stack.clear();
        self.frame_base = 0;
        self.function_index = 0;
    }

    pub fn clear(self: *StackSpace) void {
        self.clear_callstack();
        self.control_stack.clear();
    }

    pub fn block_enter(self: *StackSpace, block: Block) !void {
        try self.check_overlap(@sizeOf(Block));
        try self.control_stack.push(block);
    }

    pub fn branch(self: *StackSpace, label_idx: usize) !usize {
        if (label_idx >= self.control_stack.length) {
            return error.InvalidLabelIndex;
        }
        self.control_stack.length -= label_idx;
        const target_block = try self.control_stack.pop();
        if (target_block.result_count > 0) {
            const result_src = self.call_stack.length - target_block.result_count;
            const result_dst = target_block.stack_ptr;
            std.mem.copyForwards(
                Value,
                self.call_stack.data[result_dst .. result_dst + target_block.result_count],
                self.call_stack.data[result_src .. result_src + target_block.result_count],
            );
        }
        self.call_stack.length = target_block.stack_ptr + target_block.result_count;
        switch (target_block.block_type) {
            .Block => {
                return target_block.pc_end + 1;
            },
            .Loop => {
                return target_block.pc_start;
            },
            .If => {
                return target_block.pc_end + 1;
            },
            else => return error.InvalidBlockType,
        }
    }

    pub fn end(self: *StackSpace) !void {
        const target_block = try self.control_stack.pop();
        if (target_block.result_count > 0) {
            const result_src = self.call_stack.length - target_block.result_count;
            const result_dst = target_block.stack_ptr;
            std.mem.copyForwards(
                Value,
                self.call_stack.data[result_dst .. result_dst + target_block.result_count],
                self.call_stack.data[result_src .. result_src + target_block.result_count],
            );
        }
        self.call_stack.length = target_block.stack_ptr + target_block.result_count;
    }

    fn check_overlap(self: *StackSpace, dist: usize) !void {
        const call_stack_top = self.call_stack.length * @sizeOf(Value);
        const control_stack_top = self.data.len - self.control_stack.length * @sizeOf(Block);
        if (call_stack_top + dist > control_stack_top) {
            const alignment = comptime std.mem.Alignment.fromByteUnits(@max(@alignOf(Value), @alignOf(Block)));
            const new_data = try self.allocator.alignedAlloc(u8, alignment, self.data.len * 2);
            const stack_slice = std.mem.bytesAsSlice(Value, new_data);
            const block_slice = std.mem.bytesAsSlice(Block, new_data);
            try self.call_stack.move(stack_slice);
            try self.control_stack.move(block_slice);
            self.allocator.free(self.data);
            self.data = new_data;
        }
    }

    pub fn free(self: *StackSpace) void {
        self.allocator.free(self.data);
    }
};
