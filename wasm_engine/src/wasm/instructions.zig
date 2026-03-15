<<<<<<< HEAD
const Value = @import("types.zig").Value;
=======
>>>>>>> 336a68a41ad81c9d282961cac18d8ec18596c0d1
const VM = @import("vm.zig").VM;
const Context = @import("context.zig").WasmContext;
const utils = @import("utils.zig");

<<<<<<< HEAD
pub inline fn i32Const(vm: *VM, context: *const Context) anyerror!void {
    const code = context.code_bodies[vm.stack.function_index].code;
    const value = try utils.decodeLEB128(code[vm.pc..]);
    vm.pc += value.offset;
    try vm.stack.push(.{ .i32 = @intCast(value.value) });
}

pub inline fn i32Add(vm: *VM, _: *const Context) anyerror!void {
    const b = try vm.stack.popI32();
    const a = try vm.stack.popI32();
    try vm.stack.push(.{ .i32 = @intCast(a + b) });
}

pub inline fn localGet(vm: *VM, context: *const Context) anyerror!void {
    const code = context.code_bodies[vm.stack.function_index].code;
    const index = try utils.decodeLEB128(code[vm.pc..]);
    vm.pc += index.offset;
    const value = try vm.stack.getLocal(index.value);
    try vm.stack.push(value);
}

pub inline fn unsupportedOpcode(_: *VM, _: *const Context) anyerror!void {
    return error.UnsupportedOpcode;
}

pub inline fn nop(_: *VM, _: *const Context) anyerror!void {
    // No operation, just return
}

pub inline fn call(vm: *VM, context: *const Context) anyerror!void {
    const code = context.code_bodies[vm.stack.function_index].code;
    const func_idx = try utils.decodeLEB128(code[vm.pc..]);
    vm.pc += func_idx.offset;
    try vm.stack.enterFrame(context, @intCast(func_idx.value), vm.pc);
    vm.pc = 0; // Start of the called function's code
}

pub inline fn end(vm: *VM, context: *const Context) anyerror!void {
    const func_type = context.function_types[vm.stack.function_index];
    const return_count = func_type.results.len;
    var results_buf: [8]Value = undefined;
    const results = if (return_count <= 8)
        results_buf[0..return_count]
    else
        try vm.allocator.allocator().alloc(Value, return_count);
    defer if (return_count > 8) vm.allocator.allocator().free(results);
    for (0..return_count) |i| {
        results[return_count - 1 - i] = try vm.stack.pop();
    }
    if (try vm.stack.exitFrame()) |return_addr| {
        vm.pc = return_addr;
    } else {
        vm.running = false;
    }
    for (results) |result| {
        try vm.stack.push(result);
    }
}
=======
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
>>>>>>> 336a68a41ad81c9d282961cac18d8ec18596c0d1
