const std = @import("std");
const device_query = @import("zig_device_query_lib");
const DeviceState = device_query.DeviceState;
const Keycode = device_query.Keycode;
const MouseState = device_query.MouseState;
const DeviceEventsHandler = device_query.DeviceEventsHandler;
const time = std.time;

// Global variable for callback usage
var g_should_exit = false;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.debug.print("WARNING: Memory leak detected\n", .{});
    }

    // Clear screen and show menu
    clearScreen();
    printMenu();

    // Read user selection
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    var buf: [2]u8 = undefined;
    
    var selected_option: ?u8 = null;
    while (selected_option == null) {
        try stdout.print("Choose an option (1-4): ", .{});
        if (stdin.readUntilDelimiterOrEof(buf[0..], '\n') catch null) |choice| {
            if (choice.len == 1) {
                switch (choice[0]) {
                    '1'...'4' => selected_option = choice[0] - '0',
                    else => try stdout.print("Invalid option, please try again.\n", .{}),
                }
            } else {
                try stdout.print("Invalid option, please try again.\n", .{});
            }
        }
    }

    clearScreen();
    switch (selected_option.?) {
        1 => try runMousePositionTracker(allocator),
        2 => try runKeyboardStateMonitor(allocator),
        3 => try runEventBasedMonitor(allocator),
        4 => try runVisualInputDisplay(allocator),
        else => unreachable,
    }
}

fn printMenu() void {
    std.debug.print("=== Zig Device Query Test ===\n\n", .{});
    std.debug.print("1. Mouse Position Tracker\n", .{});
    std.debug.print("2. Keyboard State Monitor\n", .{});
    std.debug.print("3. Event-Based Input Monitor\n", .{});
    std.debug.print("4. Visual Input Display\n", .{});
    std.debug.print("\nPress ESC to exit any test.\n\n", .{});
}

fn clearScreen() void {
    std.debug.print("\x1B[2J\x1B[H", .{}); // ANSI escape codes to clear screen and move cursor to home
}

fn moveCursor(row: usize, col: usize) void {
    std.debug.print("\x1B[{};{}H", .{ row, col });
}

fn printBoxChar(ch: u8) void {
    std.debug.print("{c}", .{ch});
}

// Test 1: Continuous monitor of mouse position
fn runMousePositionTracker(allocator: std.mem.Allocator) !void {
    var device_state = try DeviceState.init(allocator);
    defer device_state.deinit();

    std.debug.print("=== Mouse Position Tracker ===\n\n", .{});
    std.debug.print("Continuously tracking mouse position and button state.\n", .{});
    std.debug.print("Press ESC key to exit.\n\n", .{});

    while (true) {
        // Get mouse state
        var mouse = try device_state.getMouse();
        defer mouse.deinit();
        
        // Get keyboard state to check for ESC
        const keys = try device_state.getKeys();
        defer allocator.free(keys);
        
        // Check for ESC key to exit
        for (keys) |key| {
            if (key == Keycode.Escape) {
                std.debug.print("\nExiting mouse tracker...\n", .{});
                return;
            }
        }
        
        // Clear previous line and print current position
        std.debug.print("\rMouse: ({:4}, {:4}) | Buttons: ", .{ mouse.coords.x, mouse.coords.y });
        
        // Print button states
        var any_pressed = false;
        for (1..6) |i| {
            if (i < mouse.button_pressed.len and mouse.button_pressed[i]) {
                std.debug.print("{}:{s} ", .{ i, "down" });
                any_pressed = true;
            }
        }
        
        if (!any_pressed) {
            std.debug.print("none     ", .{});
        }
        
        std.debug.print("    ", .{}); // Extra spaces to clear any previous longer output
        
        // Small sleep to avoid burning CPU
        time.sleep(20 * time.ns_per_ms);
    }
}

// Test 2: Keyboard state monitor
fn runKeyboardStateMonitor(allocator: std.mem.Allocator) !void {
    var device_state = try DeviceState.init(allocator);
    defer device_state.deinit();

    std.debug.print("=== Keyboard State Monitor ===\n\n", .{});
    std.debug.print("Press keys to see them detected. Press ESC to exit.\n\n", .{});

    // Initialize the display area
    for (0..20) |_| {
        std.debug.print("\n", .{});
    }

    while (true) {
        // Get keyboard state
        const keys = try device_state.getKeys();
        defer allocator.free(keys);
        
        // Move cursor back to start position
        moveCursor(4, 1);
        
        // Check for ESC key to exit
        var should_exit = false;
        for (keys) |key| {
            if (key == Keycode.Escape) {
                should_exit = true;
                break;
            }
        }
        
        if (should_exit) {
            moveCursor(22, 1);
            std.debug.print("\nExiting keyboard monitor...\n", .{});
            return;
        }
        
        // Print all pressed keys in a organized way
        std.debug.print("Keys currently pressed ({} keys):                 \n\n", .{keys.len});
        
        if (keys.len == 0) {
            std.debug.print("No keys pressed                                    \n", .{});
        } else {
            var line_pos: usize = 0;
            for (keys) |key| {
                const key_str = key.toString();
                std.debug.print("{s:<12}", .{key_str});
                
                line_pos += 1;
                if (line_pos >= 5) {
                    std.debug.print("\n", .{});
                    line_pos = 0;
                }
            }
            
            // Clear the rest of the display
            if (line_pos > 0) {
                std.debug.print("\n", .{});
            }
        }
        
        // Extra newlines to clear previous output
        for (0..10) |_| {
            std.debug.print("                                                  \n", .{});
        }
        
        // Small sleep to avoid burning CPU
        time.sleep(20 * time.ns_per_ms);
    }
}

// Test 3: Event-based input monitor
fn runEventBasedMonitor(allocator: std.mem.Allocator) !void {
    std.debug.print("=== Event-Based Input Monitor ===\n\n", .{});
    std.debug.print("This test uses callbacks to monitor input events.\n", .{});
    std.debug.print("Press keys, move the mouse, or click to see events.\n", .{});
    std.debug.print("Press ESC to exit.\n\n", .{});
    
    var events_handler = try DeviceEventsHandler.init(allocator, 10 * time.ns_per_ms);
    defer events_handler.deinit();
    
    // Reset global flag
    g_should_exit = false;
    
    // Keyboard callbacks
    const key_down_guard = try events_handler.onKeyDown(keyDownCallback);
    defer allocator.destroy(key_down_guard);
    
    const key_up_guard = try events_handler.onKeyUp(keyUpCallback);
    defer allocator.destroy(key_up_guard);
    
    // Mouse callbacks
    const mouse_move_guard = try events_handler.onMouseMove(mouseMoveCallback);
    defer allocator.destroy(mouse_move_guard);
    
    const mouse_button_down_guard = try events_handler.onMouseButtonDown(mouseButtonCallback);
    defer allocator.destroy(mouse_button_down_guard);
    
    const mouse_button_up_guard = try events_handler.onMouseButtonUp(mouseButtonCallback);
    defer allocator.destroy(mouse_button_up_guard);
    
    // Keep running until ESC key is pressed (will set g_should_exit to true)
    while (!g_should_exit) {
        time.sleep(100 * time.ns_per_ms);
    }
    
    std.debug.print("\nExiting event-based monitor...\n", .{});
}

// Test 4: Visual representation of input
fn runVisualInputDisplay(allocator: std.mem.Allocator) !void {
    var device_state = try DeviceState.init(allocator);
    defer device_state.deinit();

    clearScreen();
    std.debug.print("=== Visual Input Display ===\n\n", .{});
    std.debug.print("This test shows a visual representation of keyboard and mouse input.\n", .{});
    std.debug.print("Press ESC to exit.\n\n", .{});
    
    // Draw keyboard outline
    const keyboard_row1 = "ESC F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12";
    const keyboard_row2 = "` 1 2 3 4 5 6 7 8 9 0 - = BKSP";
    const keyboard_row3 = "TAB Q W E R T Y U I O P [ ] \\";
    const keyboard_row4 = "CAPS A S D F G H J K L ; ' ENTER";
    const keyboard_row5 = "SHIFT Z X C V B N M , . / SHIFT";
    const keyboard_row6 = "CTRL ALT SPACE ALT CTRL";
    
    // Draw empty keyboard initially
    moveCursor(5, 5);
    std.debug.print("{s}\n", .{keyboard_row1});
    moveCursor(6, 5);
    std.debug.print("{s}\n", .{keyboard_row2});
    moveCursor(7, 5);
    std.debug.print("{s}\n", .{keyboard_row3});
    moveCursor(8, 5);
    std.debug.print("{s}\n", .{keyboard_row4});
    moveCursor(9, 5);
    std.debug.print("{s}\n", .{keyboard_row5});
    moveCursor(10, 5);
    std.debug.print("{s}\n", .{keyboard_row6});
    
    // Draw mouse area
    moveCursor(12, 5);
    std.debug.print("Mouse:\n", .{});
    moveCursor(13, 5);
    std.debug.print("┌───────┐\n", .{});
    moveCursor(14, 5);
    std.debug.print("│       │\n", .{});
    moveCursor(15, 5);
    std.debug.print("│   X   │  Left button: [ ]\n", .{});
    moveCursor(16, 5);
    std.debug.print("│       │  Right button: [ ]\n", .{});
    moveCursor(17, 5);
    std.debug.print("└───────┘  Middle button: [ ]\n", .{});
    moveCursor(18, 5);
    std.debug.print("Position: (    ,    )\n", .{});
    
    while (true) {
        // Get keyboard state
        const keys = try device_state.getKeys();
        defer allocator.free(keys);
        
        // Check for ESC key to exit
        for (keys) |key| {
            if (key == Keycode.Escape) {
                moveCursor(20, 1);
                std.debug.print("\nExiting visual display...\n", .{});
                return;
            }
        }
        
        // Get mouse state
        var mouse = try device_state.getMouse();
        defer mouse.deinit();
        
        // Highlight pressed keys
        highlightKeyboard(keys);
        
        // Update mouse display
        updateMouseDisplay(&mouse);
        
        // Small sleep to avoid burning CPU
        time.sleep(20 * time.ns_per_ms);
    }
}

fn highlightKeyboard(keys: []const Keycode) void {
    // Simple highlight of some common keys (just as demonstration)
    // In a real implementation, you'd want to map all keys to positions

    // Format for positioning and color:
    // Position cursor at (row, col) and set color based on whether key is pressed
    const highlight_start = "\x1B[7m"; // Inverse video (highlight)
    const highlight_end = "\x1B[0m";   // Reset formatting
    
    // Check for specific keys and highlight them
    const key_positions = [_]struct { key: Keycode, row: usize, col: usize, label: []const u8 }{
        .{ .key = Keycode.Escape, .row = 5, .col = 5, .label = "ESC" },
        .{ .key = Keycode.A, .row = 8, .col = 11, .label = "A" },
        .{ .key = Keycode.S, .row = 8, .col = 13, .label = "S" },
        .{ .key = Keycode.D, .row = 8, .col = 15, .label = "D" },
        .{ .key = Keycode.F, .row = 8, .col = 17, .label = "F" },
        .{ .key = Keycode.Space, .row = 10, .col = 15, .label = "SPACE" },
        .{ .key = Keycode.Enter, .row = 8, .col = 35, .label = "ENTER" },
        .{ .key = Keycode.LShift, .row = 9, .col = 5, .label = "SHIFT" },
        .{ .key = Keycode.LControl, .row = 10, .col = 5, .label = "CTRL" },
    };
    
    for (key_positions) |pos| {
        var is_pressed = false;
        for (keys) |key| {
            if (key == pos.key) {
                is_pressed = true;
                break;
            }
        }
        
        moveCursor(pos.row, pos.col);
        if (is_pressed) {
            std.debug.print("{s}{s}{s}", .{ highlight_start, pos.label, highlight_end });
        } else {
            std.debug.print("{s}", .{pos.label});
        }
    }
}

fn updateMouseDisplay(mouse: *const MouseState) void {
    // Update mouse position
    moveCursor(18, 15);
    std.debug.print("{:4},{:4}", .{ mouse.coords.x, mouse.coords.y });
    
    // Update mouse button states
    const highlight_start = "\x1B[7m"; // Inverse video (highlight)
    const highlight_end = "\x1B[0m";   // Reset formatting
    
    // Left button
    moveCursor(15, 29);
    if (mouse.isButtonPressed(1)) {
        std.debug.print("[{s}X{s}]", .{ highlight_start, highlight_end });
    } else {
        std.debug.print("[ ]", .{});
    }
    
    // Right button
    moveCursor(16, 30);
    if (mouse.isButtonPressed(3)) {
        std.debug.print("[{s}X{s}]", .{ highlight_start, highlight_end });
    } else {
        std.debug.print("[ ]", .{});
    }
    
    // Middle button
    moveCursor(17, 32);
    if (mouse.isButtonPressed(2)) {
        std.debug.print("[{s}X{s}]", .{ highlight_start, highlight_end });
    } else {
        std.debug.print("[ ]", .{});
    }
}

// Callback functions for event-based monitor
fn keyDownCallback(key: Keycode) void {
    std.debug.print("Key down: {s}          \n", .{key.toString()});
    
    if (key == Keycode.Escape) {
        g_should_exit = true;
    }
}

fn keyUpCallback(key: Keycode) void {
    std.debug.print("Key up  : {s}          \n", .{key.toString()});
}

fn mouseMoveCallback(position: *const device_query.MousePosition) void {
    // Only print some positions to avoid flooding the terminal
    if (@rem(position.x, 100) == 0 or @rem(position.y, 100) == 0) {
        std.debug.print("Mouse moved: ({:4}, {:4})          \n", .{position.x, position.y});
    }
}

fn mouseButtonCallback(button: device_query.MouseButton, pressed: bool) void {
    std.debug.print("Mouse button {}: {s}          \n", 
        .{button, if (pressed) "pressed" else "released"});
}