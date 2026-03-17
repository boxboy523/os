const std = @import("std");
const Value = @import("types.zig").Value;
const VM = @import("vm.zig").VM;
const Context = @import("context.zig").WasmContext;
const utils = @import("utils.zig");

pub inline fn unreachableOp(_: *VM, _: *const Context) anyerror!void {
    return error.Unreachable;
}

pub inline fn nop(_: *VM, _: *const Context) anyerror!void {
    // No operation, just return
}

pub inline fn end(vm: *VM, context: *const Context) anyerror!void {
    const func_type_idx: usize = @intCast(context.function_table[vm.stack.function_index]);
    const func_type = context.function_types[func_type_idx];
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

pub inline fn returnOp(vm: *VM, context: *const Context) anyerror!void {
    vm.pc = context.code_bodies[vm.stack.function_index].code.len - 1; // Force end of function
}

pub inline fn call(vm: *VM, context: *const Context) anyerror!void {
    const code = context.code_bodies[vm.stack.function_index].code;
    const func_idx = try utils.decodeLEB128(code[vm.pc..]);
    vm.pc += func_idx.offset;
    try vm.stack.enterFrame(context, @intCast(func_idx.value), vm.pc);
    vm.pc = 0; // Start of the called function's code
}

pub inline fn localGet(vm: *VM, context: *const Context) anyerror!void {
    const code = context.code_bodies[vm.stack.function_index].code;
    const index = try utils.decodeLEB128(code[vm.pc..]);
    vm.pc += index.offset;
    const value = try vm.stack.getLocal(index.value);
    try vm.stack.push(value);
}

pub inline fn localSet(vm: *VM, context: *const Context) anyerror!void {
    const code = context.code_bodies[vm.stack.function_index].code;
    const index = try utils.decodeLEB128(code[vm.pc..]);
    vm.pc += index.offset;
    const value = try vm.stack.pop();
    try vm.stack.setLocal(index.value, value);
}

pub inline fn globalGet(vm: *VM, context: *const Context) anyerror!void {
    const code = context.code_bodies[vm.stack.function_index].code;
    const index = try utils.decodeLEB128(code[vm.pc..]);
    vm.pc += index.offset;
    const value = vm.globals[index.value].value;
    try vm.stack.push(value);
}

pub inline fn globalSet(vm: *VM, context: *const Context) anyerror!void {
    const code = context.code_bodies[vm.stack.function_index].code;
    const index = try utils.decodeLEB128(code[vm.pc..]);
    vm.pc += index.offset;
    const value = try vm.stack.pop();
    if (vm.globals[index.value].mutable) {
        vm.globals[index.value].value = value;
    } else {
        return error.GlobalImmutable;
    }
}

pub inline fn i32Load(vm: *VM, context: *const Context) anyerror!void {
    const code = context.code_bodies[vm.stack.function_index].code;
    const alignment = try utils.decodeLEB128(code[vm.pc..]);
    vm.pc += alignment.offset;
    const offset = try utils.decodeLEB128(code[vm.pc..]);
    vm.pc += offset.offset;
    const addrValue: usize = @intCast(try vm.stack.popI32());
    const addr: usize = addrValue + @as(usize, offset.value);
    if (addr > vm.memories[0].data.len - 4) {
        return error.MemoryOutOfBounds;
    }
    const value = std.mem.readInt(i32, vm.memories[0].data[addr..][0..4], .little);
    try vm.stack.push(.{ .i32 = value });
}

pub inline fn i32Store(vm: *VM, context: *const Context) anyerror!void {
    const code = context.code_bodies[vm.stack.function_index].code;
    const alignment = try utils.decodeLEB128(code[vm.pc..]);
    vm.pc += alignment.offset;
    const offset = try utils.decodeLEB128(code[vm.pc..]);
    vm.pc += offset.offset;
    const value = try vm.stack.popI32();
    const addrValue: usize = @intCast(try vm.stack.popI32());
    const addr: usize = addrValue + @as(usize, offset.value);
    if (addr > vm.memories[0].data.len - 4) {
        return error.MemoryOutOfBounds;
    }
    std.mem.writeInt(i32, vm.memories[0].data[addr..][0..4], value, .little);
}

pub inline fn i32Add(vm: *VM, _: *const Context) anyerror!void {
    const b = try vm.stack.popI32();
    const a = try vm.stack.popI32();
    try vm.stack.push(.{ .i32 = @intCast(a + b) });
}

pub inline fn i32Sub(vm: *VM, _: *const Context) anyerror!void {
    const b = try vm.stack.popI32();
    const a = try vm.stack.popI32();
    try vm.stack.push(.{ .i32 = @intCast(a - b) });
}

pub inline fn i32Const(vm: *VM, context: *const Context) anyerror!void {
    const code = context.code_bodies[vm.stack.function_index].code;
    const value = try utils.decodeLEB128(code[vm.pc..]);
    vm.pc += value.offset;
    try vm.stack.push(.{ .i32 = @intCast(value.value) });
}

pub inline fn unsupportedOpcode(_: *VM, _: *const Context) anyerror!void {
    return error.UnsupportedOpcode;
}
