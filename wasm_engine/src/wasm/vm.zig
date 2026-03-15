const std = @import("std");
const Stack = @import("stack.zig").Stack;
const Value = @import("types.zig").Value;

pub const VM = struct {
<<<<<<< HEAD
    stack: Stack,
    pc: usize, // program counter
    allocator: std.heap.ArenaAllocator,
    running: bool,

    pub fn init(allocator: std.mem.Allocator, stack_cap: usize) !VM {
        var arena = std.heap.ArenaAllocator.init(allocator);
        const aa = arena.allocator();
        const stack = try Stack.init(aa, stack_cap, 0);
        return VM{
            .stack = stack,
            .pc = 0,
            .allocator = arena,
            .running = false,
        };
    }

    pub fn entry(self: *VM, func_idx: usize, args: []const Value) !void {
        self.stack.function_index = func_idx;
        for (args) |arg| {
            try self.stack.push(arg);
        }
        self.running = true;
    }
=======
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
>>>>>>> 336a68a41ad81c9d282961cac18d8ec18596c0d1

    pub fn deinit(self: *VM) void {
        self.allocator.deinit();
    }
};
