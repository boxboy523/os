const utils = @import("utils.zig");

pub const WasmModule = struct {
    raw_data: []const u8,
    type_section: ?Section,
    import_section: ?Section,
    function_section: ?Section,
    table_section: ?Section,
    memory_section: ?Section,
    global_section: ?Section,
    export_section: ?Section,
    start_section: ?Section,
    element_section: ?Section,
    code_section: ?Section,
    data_section: ?Section,
    data_count_section: ?Section,
    tag_section: ?Section,

    pub fn empty() WasmModule {
        return .{
            .raw_data = &[_]u8{},
            .type_section = null,
            .import_section = null,
            .function_section = null,
            .table_section = null,
            .memory_section = null,
            .global_section = null,
            .export_section = null,
            .start_section = null,
            .element_section = null,
            .code_section = null,
            .data_section = null,
            .data_count_section = null,
            .tag_section = null,
        };
    }
};

pub const Section = struct {
    id: u8,
    data: []const u8,

    pub fn stream(self: Section) utils.byteStream {
        return utils.byteStream{ .data = self.data };
    }
};
