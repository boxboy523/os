const std = @import("std");
const parser = @import("wasm/parser.zig");
const context = @import("wasm/context.zig");
const runner = @import("wasm/runner.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <wasm-file>\n", .{args[0]});
        return;
    }

    const file_path = args[1];
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const buffer = try file.readToEndAlloc(allocator, 100 * 1024 * 1024);
    defer allocator.free(buffer);

    try parser.validateHeader(buffer);
    std.debug.print("Valid WASM header found!\n", .{});
    const wasm_module = try parser.buildWasmModule(buffer);
    const wasm_context = try context.WasmContext.new(wasm_module, allocator);
    defer wasm_context.free();
    wasm_context.print();
    std.debug.print("WASM module parsed successfully!\n", .{});
}
