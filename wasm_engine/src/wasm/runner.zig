const std = @import("std");
const VM = @import("vm.zig").VM;
const Context = @import("context.zig").WasmContext;
const utils = @import("utils.zig");
const Opcode = @import("types.zig").Opcode;
const Inst = @import("instructions.zig");
const Value = @import("types.zig").Value;

pub const Process = struct {
    vm: VM,
    context: Context,

    pub fn entryRun(self: *Process, func_idx: usize, args: []const Value) anyerror!void {
        try self.vm.entry(func_idx, args);
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
            std.debug.panic("Invalid opcode: {d}", .{code[self.vm.pc]});
        };
        const debug_pc = self.vm.pc;
        self.vm.pc += 1; // Move past the opcode byte
        switch (opcode) {
            .I32Const => try Inst.i32Const(&self.vm, &self.context), // i32.const
            .I32Add => try Inst.i32Add(&self.vm, &self.context), // i32.add
            .LocalGet => try Inst.localGet(&self.vm, &self.context), // local
            .Nop => try Inst.nop(&self.vm, &self.context), // nop
            .End => try Inst.end(&self.vm, &self.context), // end
            .Call => try Inst.call(&self.vm, &self.context), // call
            else => try Inst.unsupportedOpcode(&self.vm, &self.context),
        }

        std.debug.print("[PC: {d}] Stack Depth: {d} Opcode: {s} | Top: ", .{ debug_pc, self.vm.stack.length, @tagName(opcode) });
        if (self.vm.stack.length > 0) {
            const top = self.vm.stack.data[self.vm.stack.length - 1];
            std.debug.print("{any}\n", .{top});
        } else {
            std.debug.print("Empty\n", .{});
        }
    }
};

pub fn setup(allocator: std.mem.Allocator, context: Context) !Process {
    return .{
        .vm = try VM.init(allocator, 1024),
        .context = context,
    };
}
