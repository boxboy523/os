const std = @import("std");
const VM = @import("vm.zig").VM;
const Context = @import("context.zig").WasmContext;
const utils = @import("utils.zig");
const Opcode = @import("types.zig").Opcode;
const Inst = @import("instructions.zig");

pub const Process = struct {
    vm: VM,
    context: Context,

    fn step(self: *Process) anyerror!void {
        const code = self.context.code_bodies[self.vm.current_function_idx].code;
        if (self.vm.pc >= code.len) {
            return error.EndOfFunction;
        }
        const opcode: Opcode = std.meta.intToEnum(Opcode, code[self.vm.pc]) catch {
            std.debug.panic("Invalid opcode: {d}", .{code[self.vm.pc]});
        };
        self.vm.pc += 1; // Move past the opcode byte
        switch (opcode) {
            .I32Const => try Inst.I32Const(&self.vm, &self.context), // i32.const
            else => try Inst.unsupportedOpcode(&self.vm, &self.context),
        }
    }
};

pub fn setup(allocator: std.mem.Allocator, context: Context) !Process {
    return .{
        .vm = try VM.init(allocator, 1024, 1024),
        .context = context,
    };
}
