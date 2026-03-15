const std = @import("std");
const Stack = @import("stack.zig").Stack;
const Value = @import("types.zig").Value;

pub const VM = struct {
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

    pub fn deinit(self: *VM) void {
        self.allocator.deinit();
    }
};
