//! Device state querying implementation.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Keycode = @import("keymap.zig").Keycode;
const MouseState = @import("mouse_state.zig").MouseState;

const builtin = @import("builtin");
const os_tag = builtin.os.tag;

/// DeviceState provides functions to query the state of input devices.
pub const DeviceState = switch (os_tag) {
    .linux => LinuxDeviceState,
    .windows => WindowsDeviceState,
    .macos => MacOSDeviceState,
    else => UnsupportedDeviceState,
};

/// Implementation of DeviceState for Linux using X11
const LinuxDeviceState = struct {
    allocator: Allocator,
    display: ?*x11.c.Display, // X11 Display pointer - using concrete type
    root_window: c_ulong, // Root window ID

    const x11 = struct {
        const c = @cImport({
            @cInclude("X11/Xlib.h");
        });

        // X11 button masks
        const Button1Mask = c.Button1Mask;
        const Button2Mask = c.Button2Mask;
        const Button3Mask = c.Button3Mask;
        const Button4Mask = c.Button4Mask;
        const Button5Mask = c.Button5Mask;

        // Functions needed for initialization and cleanup
        pub const XOpenDisplay = c.XOpenDisplay;
        pub const XDefaultRootWindow = c.XDefaultRootWindow;
        pub const XCloseDisplay = c.XCloseDisplay;
        
        // Functions for querying device state
        pub const XQueryKeymap = c.XQueryKeymap;
        pub const XQueryPointer = c.XQueryPointer;
        pub const XDisplayKeycodes = c.XDisplayKeycodes;
        pub const XGetKeyboardMapping = c.XGetKeyboardMapping;
        pub const XFree = c.XFree;
    };

    /// Initialize a new DeviceState for Linux
    pub fn init(allocator: Allocator) !LinuxDeviceState {
        std.debug.print("LinuxDeviceState.init() called\n", .{});
        
        // Try an extremely cautious approach
        std.debug.print("Initializing X11 connection\n", .{});
        
        // Try using an explicit display value
        const display_str = ":1";
        std.debug.print("Trying to connect to display: {s}\n", .{display_str});
        
        // Attempt to open the X display with an explicit display name
        const display = blk: {
            // Create a null-terminated C string for the display name
            var buffer: [64]u8 = undefined;
            const len = @min(display_str.len, buffer.len - 1);
            @memcpy(buffer[0..len], display_str[0..len]);
            buffer[len] = 0; // Null terminate
            
            std.debug.print("Calling XOpenDisplay with explicit display\n", .{});
            
            break :blk x11.XOpenDisplay(&buffer) orelse {
                std.debug.print("XOpenDisplay failed with explicit display\n", .{});
                std.debug.print("Trying with null display parameter\n", .{});
                
                // Try with null as fallback
                const null_display = x11.XOpenDisplay(null) orelse {
                    std.debug.print("XOpenDisplay(null) also failed\n", .{});
                    return error.FailedToOpenDisplay;
                };
                
                break :blk null_display;
            };
        };
        
        std.debug.print("XOpenDisplay succeeded: {*}\n", .{display});
        
        // Use the concrete type for X11 display
        const root_window = x11.XDefaultRootWindow(display);
        std.debug.print("Root window: {}\n", .{root_window});
        
        return LinuxDeviceState{
            .allocator = allocator,
            .display = display,
            .root_window = root_window,
        };
    }

    /// Free allocated resources
    pub fn deinit(self: *LinuxDeviceState) void {
        if (self.display) |display| {
            _ = x11.XCloseDisplay(display);
            self.display = null;
        }
    }

    /// Query for the current mouse position and button state
    pub fn getMouse(self: *LinuxDeviceState) !MouseState {
        var root_return: c_ulong = undefined;
        var child_return: c_ulong = undefined;
        var root_x: c_int = undefined;
        var root_y: c_int = undefined;
        var win_x: c_int = undefined;
        var win_y: c_int = undefined;
        var mask_return: c_uint = undefined;
        
        std.debug.print("LinuxDeviceState.getMouse() called, self={*}\n", .{self});
        
        if (self.display) |display| {
            std.debug.print("Display pointer: {*}, root_window: {}\n", .{display, self.root_window});
            
            const result = x11.XQueryPointer(
                display,
                self.root_window,
                &root_return,
                &child_return,
                &root_x,
                &root_y,
                &win_x,
                &win_y,
                &mask_return
            );
            
            if (result == 0) {
                std.debug.print("XQueryPointer failed\n", .{});
                return error.QueryPointerFailed;
            }
            
            std.debug.print("XQueryPointer succeeded, coords=({}, {})\n", .{win_x, win_y});
            
            var mouse = try MouseState.init(self.allocator);
            mouse.setCoords(win_x, win_y);
            
            // Check button states
            try mouse.setButtonState(1, (mask_return & x11.Button1Mask) != 0);
            try mouse.setButtonState(2, (mask_return & x11.Button2Mask) != 0);
            try mouse.setButtonState(3, (mask_return & x11.Button3Mask) != 0);
            try mouse.setButtonState(4, (mask_return & x11.Button4Mask) != 0);
            try mouse.setButtonState(5, (mask_return & x11.Button5Mask) != 0);
            
            return mouse;
        }
        
        std.debug.print("Display is null!\n", .{});
        return error.DisplayNotInitialized;
    }

    /// Map X11 keycode to our Keycode enum
    fn mapX11KeycodeToKeycode(keycode: u8) ?Keycode {
        // This is a simplified mapping, a more comprehensive one would be needed
        // for a production implementation
        return switch (keycode) {
            10 => Keycode.Key1, // Assuming X11 keycode 10 maps to '1'
            11 => Keycode.Key2,
            12 => Keycode.Key3,
            13 => Keycode.Key4,
            14 => Keycode.Key5,
            15 => Keycode.Key6,
            16 => Keycode.Key7,
            17 => Keycode.Key8,
            18 => Keycode.Key9,
            19 => Keycode.Key0,
            38 => Keycode.A,
            39 => Keycode.B,
            40 => Keycode.C,
            41 => Keycode.D,
            42 => Keycode.E,
            43 => Keycode.F,
            44 => Keycode.G,
            45 => Keycode.H,
            46 => Keycode.I,
            47 => Keycode.J,
            48 => Keycode.K,
            49 => Keycode.L,
            50 => Keycode.M,
            51 => Keycode.N,
            52 => Keycode.O,
            53 => Keycode.P,
            54 => Keycode.Q,
            55 => Keycode.R,
            56 => Keycode.S,
            57 => Keycode.T,
            58 => Keycode.U,
            59 => Keycode.V,
            60 => Keycode.W,
            61 => Keycode.X,
            62 => Keycode.Y,
            63 => Keycode.Z,
            // Function keys
            67 => Keycode.F1,
            68 => Keycode.F2,
            69 => Keycode.F3,
            70 => Keycode.F4,
            71 => Keycode.F5,
            72 => Keycode.F6,
            73 => Keycode.F7,
            74 => Keycode.F8,
            75 => Keycode.F9,
            76 => Keycode.F10,
            95 => Keycode.F11,
            96 => Keycode.F12,
            // Special keys
            9 => Keycode.Escape,
            65 => Keycode.Space,
            37 => Keycode.LControl,
            105 => Keycode.RControl,
            112 => Keycode.LShift, // Changed from 50 which conflicts with M
            117 => Keycode.RShift, // Changed from 62 which conflicts with Y
            64 => Keycode.LAlt,
            108 => Keycode.RAlt,
            36 => Keycode.Enter,
            98 => Keycode.Up,
            104 => Keycode.Down,
            100 => Keycode.Left,
            102 => Keycode.Right,
            22 => Keycode.Backspace,
            66 => Keycode.CapsLock,
            23 => Keycode.Tab,
            // Add more mappings as needed
            else => null,
        };
    }

    /// Query for all keys that are currently pressed down
    pub fn getKeys(self: *LinuxDeviceState) ![]Keycode {
        var keymap: [32]u8 = undefined;
        var keys = std.ArrayList(Keycode).init(self.allocator);
        errdefer keys.deinit();
        
        if (self.display) |display| {
            _ = x11.XQueryKeymap(display, &keymap);
            
            // Scan through the keymap to find pressed keys
            for (keymap, 0..) |byte, i| {
                var bit: u8 = 1;
                while (bit != 0) : (bit <<= 1) {
                    if ((byte & bit) != 0) {
                        const x11_keycode: u8 = @intCast(i * 8 + @ctz(bit));
                        if (mapX11KeycodeToKeycode(x11_keycode)) |keycode| {
                            try keys.append(keycode);
                        }
                    }
                }
            }
            
            return keys.toOwnedSlice();
        }
        
        return error.DisplayNotInitialized;
    }
};

/// Implementation for Windows
const WindowsDeviceState = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) !WindowsDeviceState {
        return WindowsDeviceState{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *WindowsDeviceState) void {
        _ = self;
    }

    pub fn getMouse(self: *WindowsDeviceState) !MouseState {
        _ = self;
        @compileError("Windows implementation not yet available");
    }

    pub fn getKeys(self: *WindowsDeviceState) ![]Keycode {
        _ = self;
        @compileError("Windows implementation not yet available");
    }
};

/// Implementation for macOS
const MacOSDeviceState = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) !MacOSDeviceState {
        return MacOSDeviceState{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MacOSDeviceState) void {
        _ = self;
    }

    pub fn getMouse(self: *MacOSDeviceState) !MouseState {
        _ = self;
        @compileError("macOS implementation not yet available");
    }

    pub fn getKeys(self: *MacOSDeviceState) ![]Keycode {
        _ = self;
        @compileError("macOS implementation not yet available");
    }
};

/// For unsupported platforms
const UnsupportedDeviceState = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) !UnsupportedDeviceState {
        return UnsupportedDeviceState{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *UnsupportedDeviceState) void {
        _ = self;
    }

    pub fn getMouse(self: *UnsupportedDeviceState) !MouseState {
        _ = self;
        @compileError("Unsupported platform");
    }

    pub fn getKeys(self: *UnsupportedDeviceState) ![]Keycode {
        _ = self;
        @compileError("Unsupported platform");
    }
};