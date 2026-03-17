const std = @import("std");
const Stack = @import("stack.zig").Stack;
const Limits = @import("types.zig").Limits;
const Value = @import("types.zig").Value;
const Global = @import("context.zig").Global;
const Context = @import("context.zig").WasmContext;

pub const Memory = struct {
    arena: std.heap.ArenaAllocator,
    data: []u8,
    max_pages: ?u64,
    page_count: usize,
    is_64bit: bool,

    pub fn init(allocator: std.mem.Allocator, limits: Limits, is_64bit: bool) !Memory {
        var arena = std.heap.ArenaAllocator.init(allocator);
        const page_size = 65536; // WebAssembly page size is always 64KiB
        const initial_size: usize = @intCast(limits.min * page_size);
        const aa = arena.allocator();
        const data = try aa.alloc(u8, initial_size);
        return Memory{
            .arena = arena,
            .data = data,
            .max_pages = limits.max,
            .page_count = limits.min,
            .is_64bit = is_64bit,
        };
    }

    pub fn grow(self: *Memory, additional_pages: u64) !void {
        const page_size = 65536; // WebAssembly page size is always 64KiB
        const new_size: usize = @intCast((self.page_count + additional_pages) * page_size);
        const aa = self.arena.allocator();
        if (self.max_pages) |max| {
            const max_size: usize = @intCast(max * page_size);
            if (new_size > max_size or
                (self.page_count + additional_pages) > std.math.maxInt(u32) and self.is_64bit == false)
            {
                return error.MemoryLimitExceeded;
            }
        }
        const new_data = try aa.realloc(self.data, new_size);
        aa.free(self.data);
        self.data = new_data;
        self.page_count += additional_pages;
    }

    pub fn deinit(self: *Memory) void {
        self.arena.deinit();
    }
};

pub const VM = struct {
    stack: Stack,
    pc: usize, // program counter
    allocator: std.heap.ArenaAllocator,
    globals: []Global,
    memories: []Memory,
    running: bool,

    pub fn init(allocator: std.mem.Allocator, context: Context, stack_cap: usize) !VM {
        var arena = std.heap.ArenaAllocator.init(allocator);
        const aa = arena.allocator();
        const stack = try Stack.init(aa, stack_cap, 0);
        const globals_copy = try aa.alloc(Global, context.globals.len);
        const memories = try aa.alloc(Memory, context.memories.len);
        for (context.memories, 0..) |mem, i| {
            memories[i] = try Memory.init(allocator, mem.limits, mem.is_64bit);
        }
        std.mem.copyForwards(Global, globals_copy, context.globals);
        return .{
            .stack = stack,
            .pc = 0,
            .allocator = arena,
            .globals = globals_copy,
            .memories = memories,
            .running = false,
        };
    }

    pub fn entry(self: *VM, func_idx: usize, args: []const Value) !void {
        self.reset();
        self.stack.function_index = func_idx;
        for (args) |arg| {
            try self.stack.push(arg);
        }
        self.running = true;
    }

    pub fn reset(self: *VM) void {
        self.stack.clear();
        self.pc = 0;
        self.running = false;
    }

    pub fn deinit(self: *VM) void {
        for (self.memories) |*mem| {
            mem.deinit();
        }
        self.allocator.deinit();
    }
};
