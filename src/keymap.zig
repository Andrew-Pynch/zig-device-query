//! Definitions for keyboard keys.

const std = @import("std");

/// A list of supported keys that can be queried from the OS.
pub const Keycode = enum {
    Key0,
    Key1,
    Key2,
    Key3,
    Key4,
    Key5,
    Key6,
    Key7,
    Key8,
    Key9,
    A,
    B,
    C,
    D,
    E,
    F,
    G,
    H,
    I,
    J,
    K,
    L,
    M,
    N,
    O,
    P,
    Q,
    R,
    S,
    T,
    U,
    V,
    W,
    X,
    Y,
    Z,
    F1,
    F2,
    F3,
    F4,
    F5,
    F6,
    F7,
    F8,
    F9,
    F10,
    F11,
    F12,
    F13,
    F14,
    F15,
    F16,
    F17,
    F18,
    F19,
    F20,
    Escape,
    Space,
    LControl,
    RControl,
    LShift,
    RShift,
    LAlt,
    RAlt,
    Command,
    RCommand,
    LOption,
    ROption,
    LMeta,
    RMeta,
    Enter,
    Up,
    Down,
    Left,
    Right,
    Backspace,
    CapsLock,
    Tab,
    Home,
    End,
    PageUp,
    PageDown,
    Insert,
    Delete,
    Numpad0,
    Numpad1,
    Numpad2,
    Numpad3,
    Numpad4,
    Numpad5,
    Numpad6,
    Numpad7,
    Numpad8,
    Numpad9,
    NumpadSubtract,
    NumpadAdd,
    NumpadDivide,
    NumpadMultiply,
    NumpadEquals,
    NumpadEnter,
    NumpadDecimal,
    // The following keys names represent the position of the key in a US keyboard
    Grave,
    Minus,
    Equal,
    LeftBracket,
    RightBracket,
    BackSlash,
    Semicolon,
    Apostrophe,
    Comma,
    Dot,
    Slash,

    /// Parse a string into a Keycode
    pub fn fromString(str: []const u8) ?Keycode {
        inline for (@typeInfo(Keycode).Enum.fields) |field| {
            if (std.mem.eql(u8, str, field.name)) {
                return @field(Keycode, field.name);
            }
        }
        return null;
    }

    /// Convert a Keycode to a string
    pub fn toString(self: Keycode) []const u8 {
        return @tagName(self);
    }
};

test "keycode fromString" {
    try std.testing.expectEqual(Keycode.A, Keycode.fromString("A").?);
    try std.testing.expectEqual(Keycode.Enter, Keycode.fromString("Enter").?);
    try std.testing.expectEqual(Keycode.F10, Keycode.fromString("F10").?);
    try std.testing.expect(Keycode.fromString("NonExistentKey") == null);
}

test "keycode toString" {
    try std.testing.expectEqualStrings("A", Keycode.A.toString());
    try std.testing.expectEqualStrings("Enter", Keycode.Enter.toString());
    try std.testing.expectEqualStrings("F10", Keycode.F10.toString());
}