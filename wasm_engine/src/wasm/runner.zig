const std = @import("std");
const VM = @import("vm.zig").VM;
const Context = @import("context.zig").WasmContext;
const utils = @import("utils.zig");
const types = @import("types.zig");
const inst = @import("instructions.zig");
const Module = @import("raw_data.zig").WasmModule;
const parser = @import("parser.zig");

pub const Process = struct {
    vm: VM,
    context: Context,

    pub fn entryRun(self: *Process, func_idx: types.FuncIdx, args: []const types.Value) anyerror!void {
        try self.vm.entry(func_idx, args);
        const func_ref = try self.context.getFuncRef(func_idx);
        try self.vm.enterFrame(func_ref, 0);
        while (self.vm.running) {
            try self.step();
        }
        std.debug.print("Program Finished. Top of stack: {any}\n", .{self.vm.stack.data[0..10]});
    }

    fn step(self: *Process) anyerror!void {
        const code = self.context.code_bodies[self.vm.func_index.val].code;
        //std.debug.print("Code: {any} index: {d}\n", .{ code, self.vm.func_index.val });
        if (self.vm.pc >= code.len) {
            std.debug.print("End of function reached at PC: {d}\n", .{self.vm.pc});
            return error.EndOfFunction;
        }
        const debug_pc = self.vm.pc;
        const opcode = code[self.vm.pc];
        self.vm.pc += 1; // Move past the opcode byte
        try executeOpcode(&self.vm, opcode);

        std.debug.print("[PC: {d}] Stack Depth: {d} Opcode: {s} Function: {d} | Top: ", .{ debug_pc, self.vm.stack.length.val, @tagName(opcode), self.vm.func_index.val });
        if (self.vm.stack.length.val > 0) {
            const top = try self.vm.stack.head();
            std.debug.print("{any}", .{top});
        } else {
            std.debug.print("Empty", .{});
        }
        std.debug.print("\n", .{});
    }

    pub fn deinit(self: *Process) void {
        self.vm.deinit();
        self.context.deinit();
    }
};

pub fn executeOpcode(vm: *VM, opcode: types.Opcode) anyerror!void {
    switch (opcode) {
        .unreachable_op => try inst.unreachableOp(), // unreachable
        .nop => {}, // nop
        .block => |b| try inst.block_op(b), // block
        .loop => |b| try inst.loop(b), // loop
        .if_op => |b| try inst.if_op(vm, b), // if
        .else_op => |b| try inst.else_op(vm, b), // else
        .end => |b| try inst.end(vm, b),
        .br => |b| try inst.br(vm, b), // br
        .br_if => |b| try inst.brIf(vm, b), // br_if
        .return_op => |b| try inst.returnOp(vm, b), // return
        .call => |func_ref| try inst.call(vm, func_ref), // call
        .local_get => |idx| try inst.localGet(vm, idx), // local
        .local_set => |idx| try inst.localSet(vm, idx), // local
        .global_get => |idx| try inst.globalGet(vm, idx), // global
        .global_set => |idx| try inst.globalSet(vm, idx), // global
        .i32_load => |mem_arg| try inst.i32Load(vm, mem_arg), // i32.load
        .i32_store => |mem_arg| try inst.i32Store(vm, mem_arg), // i32.store
        .i32_const => |value| try inst.i32Const(vm, value), // i32.const
        .i32_eqz => try inst.i32Eqz(vm), // i32.eqz
        .i32_eq => try inst.i32Eq(vm), // i32.eq
        .i32_ne => try inst.i32Ne(vm), // i32.ne
        .i32_lt_s => try inst.i32LtS(vm), // i32.lt
        .i32_lt_u => try inst.i32LtU(vm), // i32.lt_u
        .i32_gt_s => try inst.i32GtS(vm), // i32.gt
        .i32_gt_u => try inst.i32GtU(vm), // i32.gt_u
        .i32_le_s => try inst.i32LeS(vm), // i32.le
        .i32_le_u => try inst.i32LeU(vm), // i32.le
        .i32_ge_s => try inst.i32GeS(vm), // i32.ge
        .i32_ge_u => try inst.i32GeU(vm), // i32.
        .i32_add => try inst.i32Add(vm), // i32.add
        .i32_sub => try inst.i32Sub(vm), // i32.sub
        .i32_and => try inst.i32And(vm), // i32.and
        .i32_or => try inst.i32Or(vm), // i32.or
        .i32_xor => try inst.i32Xor(vm), // i32.xor
        //else => try inst.unsupportedOpcode(vm, context),
    }
}

pub fn setup(allocator: std.mem.Allocator, buffer: []const u8) !Process {
    const module = try parser.buildWasmModule(buffer);
    const context = try Context.init(module, allocator);
    errdefer context.deinit();
    std.debug.print("Module loaded with {d} functions, {d} globals, {d} memories\n", .{ context.func_table.len, context.globals.len, context.memories.len });
    const vm = try VM.init(allocator, context, 128);
    errdefer vm.deinit();
    return .{
        .vm = vm,
        .context = context,
    };
}
