const std = @import("std");
const VM = @import("vm.zig").VM;
const Context = @import("context.zig").WasmContext;
const utils = @import("utils.zig");
const Opcode = @import("types.zig").Opcode;
const Inst = @import("instructions.zig");
const Value = @import("types.zig").Value;
const Module = @import("raw_data.zig").WasmModule;
const parser = @import("parser.zig");

pub const Process = struct {
    vm: VM,
    context: Context,

    pub fn entryRun(self: *Process, func_idx: usize, args: []const Value) anyerror!void {
        try self.vm.entry(func_idx, args);
        try self.vm.stack.enterFrame(&self.context, func_idx, 0);
        while (self.vm.running) {
            try self.step();
        }
    }

    fn step(self: *Process) anyerror!void {
        const code = self.context.code_bodies[self.vm.stack.function_index].code;
        if (self.vm.pc >= code.len) {
            return error.EndOfFunction;
        }

        const opcode: Opcode = std.meta.intToEnum(Opcode, code[self.vm.pc]) catch {
            std.debug.panic("Invalid opcode: 0x{x}", .{code[self.vm.pc]});
        };
        const debug_pc = self.vm.pc;
        self.vm.pc += 1; // Move past the opcode byte
        try executeOpcode(&self.vm, &self.context, opcode);

        std.debug.print("[PC: {d}] Stack Depth: {d} Opcode: {s} Function: {d} | Top: ", .{ debug_pc, self.vm.stack.call_stack.length, @tagName(opcode), self.vm.stack.function_index });
        if (self.vm.stack.call_stack.length > 0) {
            const top = try self.vm.stack.call_stack.head();
            std.debug.print("{any}\n", .{top});
        } else {
            std.debug.print("Empty\n", .{});
        }
    }

    pub fn deinit(self: *Process) void {
        self.vm.deinit();
        self.context.deinit();
    }
};

pub fn executeOpcode(vm: *VM, context: *Context, opcode: Opcode) anyerror!void {
    switch (opcode) {
        .Unreachable => try Inst.unreachableOp(vm, context), // unreachable
        .Nop => try Inst.nop(vm, context), // nop
        .End => try Inst.end(vm, context), // end
        .Call => try Inst.call(vm, context), // call
        .Return => try Inst.returnOp(vm, context), // return
        .LocalGet => try Inst.localGet(vm, context), // local
        .LocalSet => try Inst.localSet(vm, context), // local
        .GlobalGet => try Inst.globalGet(vm, context), // global
        .GlobalSet => try Inst.globalSet(vm, context), // global
        .I32Load => try Inst.i32Load(vm, context), // i32.load
        .I32Store => try Inst.i32Store(vm, context), // i32.store
        .I32Add => try Inst.i32Add(vm, context), // i32.add
        .I32Sub => try Inst.i32Sub(vm, context), // i32.sub
        .I32Const => try Inst.i32Const(vm, context), // i32.const
        //else => try Inst.unsupportedOpcode(vm, context),
    }
}

pub fn setup(allocator: std.mem.Allocator, buffer: []const u8) !Process {
    const module = try parser.buildWasmModule(buffer);
    const context = try Context.init(module, allocator);
    errdefer context.deinit();
    const vm = try VM.init(allocator, context, 1024);
    errdefer vm.deinit();
    return .{
        .vm = vm,
        .context = context,
    };
}
