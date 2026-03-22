const std = @import("std");
const types = @import("types.zig");
const VM = @import("vm.zig").VM;
const Context = @import("context.zig").WasmContext;
const utils = @import("utils.zig");

pub inline fn unreachableOp() anyerror!void {
    return error.Unreachable;
}

pub inline fn block_op(_: types.Block) anyerror!void {
    // Start of block, do nothing special for now
}

pub inline fn loop(_: types.Block) anyerror!void {
    // Start of loop, do nothing special for now
}

pub inline fn if_op(vm: *VM, block: types.Block) anyerror!void {
    const condition = try vm.popI32();
    if (condition == 0) {
        vm.pc = block.to_jump orelse return error.InvalidWasmFile;
    }
}

pub inline fn else_op(vm: *VM, block: types.Block) anyerror!void {
    vm.pc = block.to_jump orelse return error.InvalidWasmFile;
    vm.stack.length.val -= block.stack_offset;
}

pub inline fn end(vm: *VM, block: types.Block) anyerror!void {
    if (block.tag == .function) {
        if (try vm.exitFrame(block)) |return_addr| {
            vm.pc = return_addr;
        } else {
            vm.running = false;
        }
    } else {
        try vm.end(block);
    }
}

pub inline fn br(vm: *VM, block: types.Block) anyerror!void {
    vm.pc = block.to_jump orelse return error.InvalidWasmFile;
    vm.stack.length = vm.stack.length.sub(block.stack_offset);
}

pub inline fn brIf(vm: *VM, block: types.Block) anyerror!void {
    const condition = try vm.popI32();
    if (condition != 0) {
        vm.pc = block.to_jump orelse return error.InvalidWasmFile;
        vm.stack.length = vm.stack.length.sub(block.stack_offset);
    }
}

pub inline fn returnOp(vm: *VM, block: types.Block) anyerror!void {
    if (try vm.exitFrame(block)) |return_addr| {
        vm.pc = return_addr;
    } else {
        vm.running = false;
    }
}

pub inline fn call(vm: *VM, func_ref: types.FuncRef) anyerror!void {
    try vm.enterFrame(func_ref, vm.pc);
    vm.pc = 0; // Start of the called function's code
}

pub inline fn localGet(vm: *VM, idx: types.LocalIdx) anyerror!void {
    const value = try vm.getLocal(idx);
    try vm.stack.push(value);
}

pub inline fn localSet(vm: *VM, idx: types.LocalIdx) anyerror!void {
    const value = try vm.stack.pop();
    try vm.setLocal(idx, value);
}

pub inline fn globalGet(vm: *VM, idx: types.GlobalIdx) anyerror!void {
    const value = vm.globals[idx.val].value;
    try vm.stack.push(value);
}

pub inline fn globalSet(vm: *VM, idx: types.GlobalIdx) anyerror!void {
    const value = try vm.stack.pop();
    if (vm.globals[idx.val].mutable) {
        vm.globals[idx.val].value = value;
    } else {
        return error.GlobalImmutable;
    }
}

pub inline fn i32Load(vm: *VM, mem_arg: types.MemArg) anyerror!void {
    const addrValue: usize = @intCast(try vm.popI32());
    const addr: usize = addrValue + @as(usize, mem_arg.offset);
    if (addr > vm.memories[0].data.len - 4) {
        return error.MemoryOutOfBounds;
    }
    const value = std.mem.readInt(i32, vm.memories[0].data[addr..][0..4], .little);
    try vm.stack.push(.{ .i32 = value });
}

pub inline fn i32Store(vm: *VM, mem_arg: types.MemArg) anyerror!void {
    const value = try vm.popI32();
    const addrValue: usize = @intCast(try vm.popI32());
    const addr: usize = addrValue + @as(usize, mem_arg.offset);
    if (addr > vm.memories[0].data.len - 4) {
        return error.MemoryOutOfBounds;
    }
    std.mem.writeInt(i32, vm.memories[0].data[addr..][0..4], value, .little);
}

pub inline fn i32Const(vm: *VM, value: i32) anyerror!void {
    try vm.stack.push(.{ .i32 = value });
}

pub inline fn i32Eqz(vm: *VM) anyerror!void {
    const value = try vm.popI32();
    try vm.stack.push(.{ .i32 = if (value == 0) 1 else 0 });
}

pub inline fn i32Eq(vm: *VM) anyerror!void {
    const b = try vm.popI32();
    const a = try vm.popI32();
    try vm.stack.push(.{ .i32 = if (a == b) 1 else 0 });
}

pub inline fn i32Ne(vm: *VM) anyerror!void {
    const b = try vm.popI32();
    const a = try vm.popI32();
    try vm.stack.push(.{ .i32 = if (a != b) 1 else 0 });
}

pub inline fn i32LtS(vm: *VM) anyerror!void {
    const b = try vm.popI32();
    const a = try vm.popI32();
    try vm.stack.push(.{ .i32 = if (a < b) 1 else 0 });
}

pub inline fn i32LtU(vm: *VM) anyerror!void {
    const b: u32 = @intCast(try vm.popI32());
    const a: u32 = @intCast(try vm.popI32());
    try vm.stack.push(.{ .i32 = if (a < b) 1 else 0 });
}

pub inline fn i32GtS(vm: *VM) anyerror!void {
    const b = try vm.popI32();
    const a = try vm.popI32();
    try vm.stack.push(.{ .i32 = if (a > b) 1 else 0 });
}

pub inline fn i32GtU(vm: *VM) anyerror!void {
    const b: u32 = @intCast(try vm.popI32());
    const a: u32 = @intCast(try vm.popI32());
    try vm.stack.push(.{ .i32 = if (a > b) 1 else 0 });
}

pub inline fn i32LeS(vm: *VM) anyerror!void {
    const b = try vm.popI32();
    const a = try vm.popI32();
    try vm.stack.push(.{ .i32 = if (a <= b) 1 else 0 });
}

pub inline fn i32LeU(vm: *VM) anyerror!void {
    const b: u32 = @intCast(try vm.popI32());
    const a: u32 = @intCast(try vm.popI32());
    try vm.stack.push(.{ .i32 = if (a <= b) 1 else 0 });
}

pub inline fn i32GeS(vm: *VM) anyerror!void {
    const b = try vm.popI32();
    const a = try vm.popI32();
    try vm.stack.push(.{ .i32 = if (a >= b) 1 else 0 });
}

pub inline fn i32GeU(vm: *VM) anyerror!void {
    const b: u32 = @intCast(try vm.popI32());
    const a: u32 = @intCast(try vm.popI32());
    try vm.stack.push(.{ .i32 = if (a >= b) 1 else 0 });
}

pub inline fn i32Add(vm: *VM) anyerror!void {
    const b = try vm.popI32();
    const a = try vm.popI32();
    try vm.stack.push(.{ .i32 = @intCast(a + b) });
}

pub inline fn i32Sub(vm: *VM) anyerror!void {
    const b = try vm.popI32();
    const a = try vm.popI32();
    try vm.stack.push(.{ .i32 = @intCast(a - b) });
}

pub inline fn i32And(vm: *VM) anyerror!void {
    const b = try vm.popI32();
    const a = try vm.popI32();
    try vm.stack.push(.{ .i32 = a & b });
}

pub inline fn i32Or(vm: *VM) anyerror!void {
    const b = try vm.popI32();
    const a = try vm.popI32();
    try vm.stack.push(.{ .i32 = a | b });
}

pub inline fn i32Xor(vm: *VM) anyerror!void {
    const b = try vm.popI32();
    const a = try vm.popI32();
    try vm.stack.push(.{ .i32 = a ^ b });
}

pub inline fn unsupportedOpcode(_: *VM, _: *const Context) anyerror!void {
    return error.UnsupportedOpcode;
}
