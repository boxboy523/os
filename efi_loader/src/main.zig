const std = @import("std");
const uefi = std.os.uefi;

export fn efi_main(
    handle: uefi.Handle,
    system_table: *uefi.tables.SystemTable,
) uefi.Status {
    _ = handle;
    uefi.system_table = system_table;

    const con_out = uefi.system_table.con_out orelse return uefi.Status.device_error;

    _ = con_out.reset(false) catch {};

    _ = con_out.outputString(&[_:0]u16{ 'H', 'e', 'l', 'l', 'o', ',', ' ', 'w', 'o', 'r', 'l', 'd', '!', 0 }) catch {};

    while (true) {}

    return uefi.Status.success;
}
