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
};

pub const Section = struct {
    id: u8,
    data: []const u8,

    pub fn stream(self: Section) utils.byteStream {
        return utils.byteStream{ .data = self.data };
    }
};
