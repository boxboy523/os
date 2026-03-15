const VM = @import("vm.zig").VM;
const Context = @import("context.zig").WasmContext;
const utils = @import("utils.zig");

inline fn I32Const(vm: *VM, context: *const Context) anyerror!void {
    const code = context.code_bodies[vm.current_function_idx].code;
    const value = try utils.decodeLEB128(code, vm.pc);
    vm.pc += value.len;
    try vm.value_stack.push(.I32(value.value));
}

inline fn I32Add(vm: *VM, _: *const Context) anyerror!void {
    const b = try vm.value_stack.popI32();
    const a = try vm.value_stack.popI32();
    try vm.value_stack.push(.I32(a + b));
}

inline fn localGet(vm: *VM, context: *const Context) anyerror!void {
    const code = context.code_bodies[vm.current_function_idx].code;
    const index = try utils.decodeLEB128(code, vm.pc);
    vm.pc += index.len;

    try vm.value_stack.push(context.locals[index.value]);
}

inline fn unsupportedOpcode(_: *VM, _: *const Context) anyerror!void {
    return error.UnsupportedOpcode;
}
