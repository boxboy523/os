const std = @import("std");
const Stack = @import("stack.zig").Stack;
const Value = @import("types.zig").Value;

pub const VM = struct {
    value_stack: Stack,
    call_stack: Stack, // [arg0, arg1, ... ,  local0, local1, ... , saved_pc, saved_fp, ...]
    pc: usize, // program counter
    current_func_idx: usize,
    locals: []Value,
    allocator: std.heap.ArenaAllocator,

    pub fn init(allocator: std.mem.Allocator, v_cap: usize, c_cap: usize) !VM {
        const arena_allocator = std.heap.ArenaAllocator.init(allocator);
        const aa = arena_allocator.allocator();
        const value_stack = try Stack.init(&aa, v_cap, 0);
        const call_stack = try Stack.init(&aa, c_cap, 0);
        return VM{
            .value_stack = value_stack,
            .call_stack = call_stack,
            .pc = 0,
            .allocator = arena_allocator,
        };
    }

    pub fn get_local(self: *VM, index: usize) !Value {}

    pub fn deinit(self: *VM) void {
        self.allocator.deinit();
    }
};
