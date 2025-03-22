//! A library for querying keyboard and mouse state without requiring an active window.
//! This is a Zig port of the Rust `device_query` crate.

const std = @import("std");
const testing = std.testing;

pub const keymap = @import("keymap.zig");
pub const device_state = @import("device_state.zig");
pub const mouse_state = @import("mouse_state.zig");
pub const device_events = @import("device_events.zig");

pub const Keycode = keymap.Keycode;
pub const MouseState = mouse_state.MouseState;
pub const MousePosition = mouse_state.MousePosition;
pub const MouseButton = mouse_state.MouseButton;
pub const DeviceState = device_state.DeviceState;
pub const DeviceEventsHandler = device_events.DeviceEventsHandler;

test "basic library imports" {
    _ = keymap;
    _ = device_state;
    _ = mouse_state;
    _ = device_events;
}