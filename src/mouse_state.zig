//! Definition for mouse coordinates and button states.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Mouse position type (x, y)
pub const MousePosition = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) MousePosition {
        return .{ .x = x, .y = y };
    }
};

/// Mouse button identifier
pub const MouseButton = usize;

/// A structure containing the current mouse coordinates and the
/// state of each mouse button that we can query.
/// Button numbers are 1-based, so index 0 is unused.
pub const MouseState = struct {
    /// Current mouse coordinates in pixels
    coords: MousePosition,
    /// State of each mouse button (index 0 is unused)
    button_pressed: []bool,
    allocator: Allocator,

    /// Initialize a new MouseState
    pub fn init(allocator: Allocator) !MouseState {
        // Support up to 5 mouse buttons by default
        const buttons = try allocator.alloc(bool, 6);
        std.mem.set(bool, buttons, false);
        
        return MouseState{
            .coords = MousePosition.init(0, 0),
            .button_pressed = buttons,
            .allocator = allocator,
        };
    }

    /// Free the allocated resources
    pub fn deinit(self: *MouseState) void {
        self.allocator.free(self.button_pressed);
    }

    /// Get the state of a specific mouse button (1-indexed)
    pub fn isButtonPressed(self: MouseState, button: MouseButton) bool {
        if (button >= self.button_pressed.len) return false;
        return self.button_pressed[button];
    }

    /// Set the state of a specific mouse button (1-indexed)
    pub fn setButtonState(self: *MouseState, button: MouseButton, pressed: bool) !void {
        if (button >= self.button_pressed.len) {
            // Resize the array if needed
            const new_size = button + 1;
            const new_buttons = try self.allocator.realloc(self.button_pressed, new_size);
            self.button_pressed = new_buttons;
            
            // Initialize the new elements to false
            for (self.button_pressed[self.button_pressed.len..new_size]) |*b| {
                b.* = false;
            }
        }
        self.button_pressed[button] = pressed;
    }

    /// Set the mouse coordinates
    pub fn setCoords(self: *MouseState, x: i32, y: i32) void {
        self.coords = MousePosition.init(x, y);
    }
};

test "mouse state" {
    const allocator = std.testing.allocator;
    var mouse = try MouseState.init(allocator);
    defer mouse.deinit();

    // Test initial state
    try std.testing.expectEqual(@as(i32, 0), mouse.coords.x);
    try std.testing.expectEqual(@as(i32, 0), mouse.coords.y);
    try std.testing.expect(!mouse.isButtonPressed(1));

    // Test setting coordinates
    mouse.setCoords(100, 200);
    try std.testing.expectEqual(@as(i32, 100), mouse.coords.x);
    try std.testing.expectEqual(@as(i32, 200), mouse.coords.y);

    // Test button state
    try mouse.setButtonState(1, true);
    try std.testing.expect(mouse.isButtonPressed(1));
    try std.testing.expect(!mouse.isButtonPressed(2));

    // Test large button number
    try mouse.setButtonState(10, true);
    try std.testing.expect(mouse.isButtonPressed(10));
}