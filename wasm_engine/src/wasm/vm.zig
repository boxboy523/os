const std = @import("std");
const Stack = @import("stack.zig").Stack;
const types = @import("types.zig");
const Global = @import("context.zig").Global;
const Context = @import("context.zig").WasmContext;
pub const Memory = struct {
    arena: std.heap.ArenaAllocator,
    data: []u8,
    max_pages: ?u64,
    page_count: usize,
    is_64bit: bool,

    pub fn init(allocator: std.mem.Allocator, limits: types.Limits, is_64bit: bool) !Memory {
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
    stack: Stack(types.Value),
    pc: usize, // program counter
    allocator: std.heap.ArenaAllocator,
    frame_base: types.StackIdx = .{ .val = 0 },
    func_index: types.FuncIdx = .{ .val = 0 },
    globals: []Global,
    memories: []Memory,
    running: bool,

    pub fn init(allocator: std.mem.Allocator, context: Context, stack_cap: usize) !VM {
        var arena = std.heap.ArenaAllocator.init(allocator);
        const aa = arena.allocator();
        const stack = try Stack(types.Value).init(aa, stack_cap, 0);
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

    pub fn entry(self: *VM, func_idx: types.FuncIdx, args: []const types.Value) !void {
        self.reset();
        self.func_index = func_idx;
        for (args) |arg| {
            try self.stack.push(arg);
        }
        self.running = true;
    }

    pub fn popI32(self: *VM) !i32 {
        const value = try self.stack.pop();
        if (value != .i32) {
            try self.stack.push(value);
            return error.TypeMismatch;
        }
        return value.i32;
    }

    pub fn popI64(self: *VM) !i64 {
        const value = try self.stack.pop();
        if (value != .i64) {
            try self.stack.push(value);
            return error.TypeMismatch;
        }
        return value.i64;
    }

    pub fn popF32(self: *VM) !f32 {
        const value = try self.call_stack.pop();
        if (value != .f32) {
            try self.stack.push(value);
            return error.TypeMismatch;
        }
        return value.f32;
    }

    pub fn popF64(self: *VM) !f64 {
        const value = try self.call_stack.pop();
        if (value != .f64) {
            try self.stack.push(value);
            return error.TypeMismatch;
        }
        return value.f64;
    }

    pub fn getLocal(self: *VM, index: types.LocalIdx) !types.Value {
        const local_index = self.frame_base.add(index.val);
        return try self.stack.get(local_index);
    }

    pub fn setLocal(self: *VM, index: types.LocalIdx, value: types.Value) !void {
        const local_index = self.frame_base.add(index.val);
        return try self.stack.set(local_index, value);
    }

    pub fn enterFrame(self: *VM, func_ref: types.FuncRef, ret: u64) !void {
        const num_args = func_ref.func_type.params.len;
        var num_locals: usize = 0;
        for (func_ref.code_body.locals) |local| {
            num_locals += @intCast(local.count);
        }
        const new_frame_base = self.stack.length.sub(num_args);

        for (0..num_locals) |_| {
            try self.stack.push(types.Value{ .i64 = 0 });
        }
        try self.stack.push(types.Value{ .meta = @intCast(self.func_index.val) });
        try self.stack.push(types.Value{ .meta = @intCast(ret) });
        try self.stack.push(types.Value{ .meta = @intCast(self.frame_base.val) });
        self.frame_base = new_frame_base;
        self.func_index = func_ref.func_idx;
    }

    pub fn exitFrame(self: *VM, block: types.Block) !?usize {
        if (block.tag != .function) {
            return error.InvalidWasmFile;
        }
        const result_count = block.type.resultCount();
        const result_src = self.stack.length.val - result_count;
        self.stack.length.val -= block.stack_offset;
        if (self.frame_base.val == 0) {
            std.mem.copyForwards(
                types.Value,
                self.stack.data[0..result_count],
                self.stack.data[result_src .. result_src + result_count],
            );
            @memset(self.stack.data[result_count .. result_src + result_count], types.Value{ .i64 = 0 });
            return null;
        }
        const saved_fp = (try self.stack.pop()).meta;
        const saved_pc = (try self.stack.pop()).meta;
        const saved_func_idx = (try self.stack.pop()).meta;
        self.stack.length = self.frame_base.add(result_count);
        std.mem.copyForwards(
            types.Value,
            self.stack.data[self.frame_base.val .. self.frame_base.val + result_count],
            self.stack.data[result_src .. result_src + result_count],
        );
        self.frame_base = .{ .val = @intCast(saved_fp) };
        self.func_index = .{ .val = @intCast(saved_func_idx) };
        return @intCast(saved_pc);
    }

    pub fn end(self: *VM, block: types.Block) !void {
        const result_count = block.type.resultCount();
        const result_src = self.stack.length.val - result_count;
        self.stack.length.val = self.stack.length.val - block.stack_offset;
        std.mem.copyForwards(
            types.Value,
            self.stack.data[self.stack.length.val .. self.stack.length.val + result_count],
            self.stack.data[result_src .. result_src + result_count],
        );
        self.stack.length.val += result_count;
    }

    pub fn reset(self: *VM) void {
        self.stack.clear();
        self.pc = 0;
        self.frame_base = .{ .val = 0 };
        self.func_index = .{ .val = 0 };
        self.running = false;
    }

    pub fn deinit(self: *VM) void {
        for (self.memories) |*mem| {
            mem.deinit();
        }
        self.allocator.deinit();
    }
};
