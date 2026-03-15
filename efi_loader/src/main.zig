const std = @import("std");
const uefi = std.os.uefi;

fn print(
    con_out: *uefi.protocol.SimpleTextOutput,
    str: []const u8,
) void {
    var buf: [256]u16 = undefined;
    var i: usize = 0;
    for (str) |c| {
        if (i >= buf.len - 1) break;
        buf[i] = @as(u16, c);
        i += 1;
    }
    buf[i] = 0; // Null-terminate the string
    _ = con_out.outputString(&buf[0 .. i + 1]) catch {};
}

fn memory_map(boot_services: *uefi.protocol.BootServices) void {}

pub fn main() uefi.Status {
    const st = uefi.system_table;
    const boot_services = st.boot_services orelse return .device_error;
    const con_out = st.con_out orelse return .device_error;

    _ = con_out.reset(false) catch {};

    while (true) {}

    return .success;
}
