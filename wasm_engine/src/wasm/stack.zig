const std = @import("std");
const types = @import("types.zig");
const context = @import("context.zig");

pub const STACK_AVAILABLE = 1;
pub const STACK_FIXED = 2;
pub const STACK_REVERSED = 4;
pub const OVERLAP_RESERVED = 64;

pub fn Stack(comptime T: type) type {
    return struct {
        allocator: ?std.mem.Allocator,
        data: []T,
        length: types.StackIdx = .{ .val = 0 },
        capacity: usize,
        initial_capacity: usize,
        flag: u8, // 2^0: is_available, 2^1: is_fixed, 2^2: is_reversed

        pub fn initFixed(buffer: []T, flag: u8) Stack(T) {
            const flag_with_availability = flag | STACK_AVAILABLE | STACK_FIXED;
            return Stack(T){
                .allocator = null,
                .data = buffer,
                .flag = flag_with_availability,
                .capacity = buffer.len,
                .initial_capacity = buffer.len,
            };
        }

        pub fn init(allocator: std.mem.Allocator, capacity: usize, flag: u8) !Stack(T) {
            const data = try allocator.alloc(T, capacity);
            const flag_with_availability = flag | STACK_AVAILABLE;
            return Stack(T){
                .allocator = allocator,
                .data = data,
                .flag = flag_with_availability,
                .capacity = capacity,
                .initial_capacity = capacity,
            };
        }

        pub fn push(self: *Stack(T), value: T) !void {
            if (self.data.len == 0) {
                return error.StackOverflow;
            }
            if (self.length.val >= self.capacity) {
                try self.resize(self.capacity * 2);
            }
            if (self.flag & STACK_REVERSED != 0) {
                self.data[self.capacity - 1 - self.length.val] = value;
            } else {
                self.data[self.length.val] = value;
            }
            self.length.val += 1;
        }

        pub fn pushSlice(self: *Stack(T), values: []T) !void {
            if (self.data.len < values.len) {
                return error.StackOverflow;
            }
            while (self.length.val + values.len > self.capacity) {
                try self.resize(self.capacity * 2);
            }
            if (self.flag & STACK_REVERSED != 0) {
                for (0..values.len) |i| {
                    self.data[self.capacity - 1 - self.length.val - i] = values[values.len - 1 - i];
                }
            } else {
                std.mem.copyForwards(T, self.data[self.length.val..], values);
            }
            self.length.val += values.len;
        }

        pub fn pop(self: *Stack(T)) !T {
            if (self.data.len == 0 or self.length.val == 0) {
                return error.StackUnderflow;
            }
            self.length.val -= 1;
            const value = if (self.flag & STACK_REVERSED != 0)
                self.data[self.capacity - self.length.val - 1]
            else
                self.data[self.length.val];
            if (self.flag & STACK_FIXED == 0 and
                self.length.val < self.capacity / 4 and
                self.capacity >= self.initial_capacity * 2)
            {
                try self.resize(self.capacity / 2);
            }
            return value;
        }

        pub fn head(self: *Stack(T)) !T {
            if (self.data.len == 0 or self.length.val == 0) {
                return error.StackUnderflow;
            }
            return if (self.flag & STACK_REVERSED != 0)
                self.data[self.capacity - self.length.val]
            else
                self.data[self.length.val - 1];
        }

        pub fn get(self: *Stack(T), index: types.StackIdx) !T {
            if (index.val >= self.length.val) {
                return error.StackIndexOutOfBounds;
            }
            return if (self.flag & STACK_REVERSED != 0)
                self.data[self.capacity - self.length.val + index.val]
            else
                self.data[index.val];
        }

        pub fn getPtr(self: *Stack(T), index: types.StackIdx) !*T {
            if (index.val >= self.length.val) {
                std.debug.print("Attempted to access stack index {d} but length is {d}\n", .{ index.val, self.length.val });
                return error.StackIndexOutOfBounds;
            }
            return if (self.flag & STACK_REVERSED != 0)
                &self.data[self.capacity - self.length.val + index.val]
            else
                &self.data[index.val];
        }

        pub fn set(self: *Stack(T), index: types.StackIdx, value: T) !void {
            if (index.val >= self.length.val) {
                return error.StackIndexOutOfBounds;
            }
            if (self.flag & STACK_REVERSED != 0) {
                self.data[self.capacity - self.length.val + index.val] = value;
            } else {
                self.data[index.val] = value;
            }
        }

        pub fn move(self: *Stack(T), target: []T) !void {
            if (self.flag & STACK_FIXED == 0) {
                return error.StackNotFixed;
            }
            if (target.len < self.length.val) {
                return error.TargetBufferTooSmall;
            }
            if (self.flag & STACK_REVERSED != 0) {
                for (0..self.length.val) |i| {
                    target[i] = self.data[self.capacity - self.length.val + i];
                }
            } else {
                std.mem.copyForwards(T, target, self.data[0..self.length.val]);
            }
            self.capacity = target.len;
        }

        fn resize(self: *Stack(T), new_capacity: usize) !void {
            if (self.flag & STACK_FIXED != 0) {
                return error.StackIsFixed;
            }
            const new_data = try (self.allocator orelse {
                return error.Unreachable;
            }).realloc(self.data, new_capacity);
            self.capacity = new_capacity;
            self.data = new_data;
        }

        pub fn clear(self: *Stack(T)) void {
            self.length.val = 0;
        }

        pub fn deinit(self: *Stack(T)) void {
            if (self.allocator) |allocator| {
                allocator.free(self.data);
            }
            self.data = &[_]T{};
            self.flag = 0; // reset flags
        }
    };
}
