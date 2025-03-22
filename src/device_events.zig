//! Event-based interface for device input events.

const std = @import("std");
const Thread = std.Thread;
const Mutex = std.Thread.Mutex;
const Allocator = std.mem.Allocator;
const time = std.time;

const Keycode = @import("keymap.zig").Keycode;
const MousePosition = @import("mouse_state.zig").MousePosition;
const MouseButton = @import("mouse_state.zig").MouseButton;
const DeviceState = @import("device_state.zig").DeviceState;

/// Function type for keyboard event callbacks
pub const KeyCallback = *const fn(key: Keycode) void;

/// Function type for mouse move event callbacks
pub const MouseMoveCallback = *const fn(position: *const MousePosition) void;

/// Function type for mouse button event callbacks
pub const MouseButtonCallback = *const fn(button: MouseButton, state: bool) void;

/// A callback guard that keeps the callback registered as long as it exists
pub const CallbackGuard = struct {
    id: usize,
    callback_type: CallbackType,
    events_handler: *DeviceEventsHandler,

    pub fn deinit(self: *CallbackGuard) void {
        self.events_handler.deregisterCallback(self.callback_type, self.id);
    }
};

/// Types of callbacks that can be registered
const CallbackType = enum {
    KeyDown,
    KeyUp,
    MouseMove,
    MouseButtonDown,
    MouseButtonUp,
};

/// Storage for a single callback
const CallbackEntry = struct {
    id: usize,
    active: bool,
};

// Type definitions for callbacks
const KeyEntryCallback = struct { entry: CallbackEntry, callback: KeyCallback };
const MouseMoveEntryCallback = struct { entry: CallbackEntry, callback: MouseMoveCallback };
const MouseButtonEntryCallback = struct { entry: CallbackEntry, callback: MouseButtonCallback };

/// Storage for keyboard callbacks
const KeyboardCallbacks = struct {
    key_down: std.ArrayList(KeyEntryCallback),
    key_up: std.ArrayList(KeyEntryCallback),
    
    pub fn init(allocator: Allocator) KeyboardCallbacks {
        return .{
            .key_down = std.ArrayList(KeyEntryCallback).init(allocator),
            .key_up = std.ArrayList(KeyEntryCallback).init(allocator),
        };
    }
    
    pub fn deinit(self: *KeyboardCallbacks) void {
        self.key_down.deinit();
        self.key_up.deinit();
    }
};

/// Storage for mouse callbacks
const MouseCallbacks = struct {
    move: std.ArrayList(MouseMoveEntryCallback),
    button_down: std.ArrayList(MouseButtonEntryCallback),
    button_up: std.ArrayList(MouseButtonEntryCallback),
    
    pub fn init(allocator: Allocator) MouseCallbacks {
        return .{
            .move = std.ArrayList(MouseMoveEntryCallback).init(allocator),
            .button_down = std.ArrayList(MouseButtonEntryCallback).init(allocator),
            .button_up = std.ArrayList(MouseButtonEntryCallback).init(allocator),
        };
    }
    
    pub fn deinit(self: *MouseCallbacks) void {
        self.move.deinit();
        self.button_down.deinit();
        self.button_up.deinit();
    }
};

/// Handler for device events with callback registration
pub const DeviceEventsHandler = struct {
    allocator: Allocator,
    device_state: *DeviceState,
    keyboard_callbacks: KeyboardCallbacks,
    mouse_callbacks: MouseCallbacks,
    
    keyboard_thread: ?Thread,
    mouse_thread: ?Thread,
    
    running: bool,
    mutex: Mutex,
    sleep_duration: u64, // in nanoseconds
    next_callback_id: usize,
    
    /// Initialize a new DeviceEventsHandler with the given polling interval
    pub fn init(allocator: Allocator, polling_interval_ns: u64) !*DeviceEventsHandler {
        const self = try allocator.create(DeviceEventsHandler);
        errdefer allocator.destroy(self);
        
        // Create the device state pointer
        const device_state_ptr = try allocator.create(DeviceState);
        errdefer allocator.destroy(device_state_ptr);
        
        // Initialize the device state
        device_state_ptr.* = try DeviceState.init(allocator);
        errdefer device_state_ptr.deinit();
        
        // Debug print to verify device state initialization
        std.debug.print("Device state initialized successfully\n", .{});
        
        self.* = .{
            .allocator = allocator,
            .device_state = device_state_ptr,
            .keyboard_callbacks = KeyboardCallbacks.init(allocator),
            .mouse_callbacks = MouseCallbacks.init(allocator),
            .keyboard_thread = null,
            .mouse_thread = null,
            .running = false,
            .mutex = .{},
            .sleep_duration = polling_interval_ns,
            .next_callback_id = 1,
        };
        
        try self.startEventLoop();
        
        return self;
    }
    
    /// Free all resources
    pub fn deinit(self: *DeviceEventsHandler) void {
        self.stopEventLoop();
        
        self.keyboard_callbacks.deinit();
        self.mouse_callbacks.deinit();
        
        self.device_state.deinit();
        self.allocator.destroy(self.device_state);
        self.allocator.destroy(self);
    }
    
    /// Start the event loop threads
    fn startEventLoop(self: *DeviceEventsHandler) !void {
        if (self.running) return;
        
        self.running = true;
        
        self.keyboard_thread = try Thread.spawn(.{}, keyboardThreadFn, .{self});
        self.mouse_thread = try Thread.spawn(.{}, mouseThreadFn, .{self});
    }
    
    /// Stop the event loop threads
    fn stopEventLoop(self: *DeviceEventsHandler) void {
        if (!self.running) return;
        
        self.running = false;
        
        if (self.keyboard_thread) |thread| {
            thread.join();
            self.keyboard_thread = null;
        }
        
        if (self.mouse_thread) |thread| {
            thread.join();
            self.mouse_thread = null;
        }
    }
    
    /// Register a callback for key down events
    pub fn onKeyDown(self: *DeviceEventsHandler, callback: KeyCallback) !*CallbackGuard {
        const id = self.getNextCallbackId();
        
        const entry = CallbackEntry{ .id = id, .active = true };
        
        self.mutex.lock();
        defer self.mutex.unlock();
        
        try self.keyboard_callbacks.key_down.append(.{ .entry = entry, .callback = callback });
        
        const guard = try self.allocator.create(CallbackGuard);
        guard.* = .{
            .id = id,
            .callback_type = .KeyDown,
            .events_handler = self,
        };
        
        return guard;
    }
    
    /// Register a callback for key up events
    pub fn onKeyUp(self: *DeviceEventsHandler, callback: KeyCallback) !*CallbackGuard {
        const id = self.getNextCallbackId();
        
        const entry = CallbackEntry{ .id = id, .active = true };
        
        self.mutex.lock();
        defer self.mutex.unlock();
        
        try self.keyboard_callbacks.key_up.append(.{ .entry = entry, .callback = callback });
        
        const guard = try self.allocator.create(CallbackGuard);
        guard.* = .{
            .id = id,
            .callback_type = .KeyUp,
            .events_handler = self,
        };
        
        return guard;
    }
    
    /// Register a callback for mouse move events
    pub fn onMouseMove(self: *DeviceEventsHandler, callback: MouseMoveCallback) !*CallbackGuard {
        const id = self.getNextCallbackId();
        
        const entry = CallbackEntry{ .id = id, .active = true };
        
        self.mutex.lock();
        defer self.mutex.unlock();
        
        try self.mouse_callbacks.move.append(.{ .entry = entry, .callback = callback });
        
        const guard = try self.allocator.create(CallbackGuard);
        guard.* = .{
            .id = id,
            .callback_type = .MouseMove,
            .events_handler = self,
        };
        
        return guard;
    }
    
    /// Register a callback for mouse button down events
    pub fn onMouseButtonDown(self: *DeviceEventsHandler, callback: MouseButtonCallback) !*CallbackGuard {
        const id = self.getNextCallbackId();
        
        const entry = CallbackEntry{ .id = id, .active = true };
        
        self.mutex.lock();
        defer self.mutex.unlock();
        
        try self.mouse_callbacks.button_down.append(.{ .entry = entry, .callback = callback });
        
        const guard = try self.allocator.create(CallbackGuard);
        guard.* = .{
            .id = id,
            .callback_type = .MouseButtonDown,
            .events_handler = self,
        };
        
        return guard;
    }
    
    /// Register a callback for mouse button up events
    pub fn onMouseButtonUp(self: *DeviceEventsHandler, callback: MouseButtonCallback) !*CallbackGuard {
        const id = self.getNextCallbackId();
        
        const entry = CallbackEntry{ .id = id, .active = true };
        
        self.mutex.lock();
        defer self.mutex.unlock();
        
        try self.mouse_callbacks.button_up.append(.{ .entry = entry, .callback = callback });
        
        const guard = try self.allocator.create(CallbackGuard);
        guard.* = .{
            .id = id,
            .callback_type = .MouseButtonUp,
            .events_handler = self,
        };
        
        return guard;
    }
    
    /// Deregister a callback
    fn deregisterCallback(self: *DeviceEventsHandler, callback_type: CallbackType, id: usize) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        switch (callback_type) {
            .KeyDown => {
                for (self.keyboard_callbacks.key_down.items) |*item| {
                    if (item.entry.id == id) {
                        item.entry.active = false;
                        break;
                    }
                }
            },
            .KeyUp => {
                for (self.keyboard_callbacks.key_up.items) |*item| {
                    if (item.entry.id == id) {
                        item.entry.active = false;
                        break;
                    }
                }
            },
            .MouseMove => {
                for (self.mouse_callbacks.move.items) |*item| {
                    if (item.entry.id == id) {
                        item.entry.active = false;
                        break;
                    }
                }
            },
            .MouseButtonDown => {
                for (self.mouse_callbacks.button_down.items) |*item| {
                    if (item.entry.id == id) {
                        item.entry.active = false;
                        break;
                    }
                }
            },
            .MouseButtonUp => {
                for (self.mouse_callbacks.button_up.items) |*item| {
                    if (item.entry.id == id) {
                        item.entry.active = false;
                        break;
                    }
                }
            },
        }
    }
    
    /// Get the next unique callback ID
    fn getNextCallbackId(self: *DeviceEventsHandler) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        const id = self.next_callback_id;
        self.next_callback_id += 1;
        return id;
    }
};

/// The keyboard thread function
fn keyboardThreadFn(events_handler: *DeviceEventsHandler) void {
    std.debug.print("Keyboard thread started\n", .{});
    
    var prev_keys = std.ArrayList(Keycode).init(events_handler.allocator);
    defer prev_keys.deinit();
    
    while (events_handler.running) {
        // Get current keys
        const current_keys = events_handler.device_state.getKeys() catch |err| {
            std.debug.print("Error getting keys: {}\n", .{err});
            time.sleep(events_handler.sleep_duration);
            continue;
        };
        defer events_handler.allocator.free(current_keys);
        
        // Check for key down events (keys in current but not in prev)
        events_handler.mutex.lock();
        for (current_keys) |key| {
            var found = false;
            for (prev_keys.items) |prev_key| {
                if (key == prev_key) {
                    found = true;
                    break;
                }
            }
            
            if (!found) {
                // Key down event
                for (events_handler.keyboard_callbacks.key_down.items) |item| {
                    if (item.entry.active) {
                        item.callback(key);
                    }
                }
            }
        }
        
        // Check for key up events (keys in prev but not in current)
        for (prev_keys.items) |prev_key| {
            var found = false;
            for (current_keys) |key| {
                if (key == prev_key) {
                    found = true;
                    break;
                }
            }
            
            if (!found) {
                // Key up event
                for (events_handler.keyboard_callbacks.key_up.items) |item| {
                    if (item.entry.active) {
                        item.callback(prev_key);
                    }
                }
            }
        }
        events_handler.mutex.unlock();
        
        // Update previous keys
        prev_keys.clearRetainingCapacity();
        for (current_keys) |key| {
            prev_keys.append(key) catch {};
        }
        
        time.sleep(events_handler.sleep_duration);
    }
    
    std.debug.print("Keyboard thread exited\n", .{});
}

/// The mouse thread function
fn mouseThreadFn(events_handler: *DeviceEventsHandler) void {
    std.debug.print("Mouse thread started\n", .{});
    
    std.debug.print("Device state pointer: {*}\n", .{events_handler.device_state});
    
    var prev_mouse = events_handler.device_state.getMouse() catch |err| {
        std.debug.print("Error getting initial mouse state: {}\n", .{err});
        return;
    };
    defer prev_mouse.deinit();
    
    std.debug.print("Initial mouse state acquired successfully\n", .{});
    
    while (events_handler.running) {
        var current_mouse = events_handler.device_state.getMouse() catch |err| {
            std.debug.print("Error getting current mouse state: {}\n", .{err});
            time.sleep(events_handler.sleep_duration);
            continue;
        };
        
        events_handler.mutex.lock();
        
        // Check for mouse move events
        if (current_mouse.coords.x != prev_mouse.coords.x or current_mouse.coords.y != prev_mouse.coords.y) {
            for (events_handler.mouse_callbacks.move.items) |item| {
                if (item.entry.active) {
                    item.callback(&current_mouse.coords);
                }
            }
        }
        
        // Check for mouse button events
        const max_button = @max(current_mouse.button_pressed.len, prev_mouse.button_pressed.len);
        var button: usize = 1; // Skip index 0 since buttons are 1-indexed
        while (button < max_button) : (button += 1) {
            const prev_pressed = if (button < prev_mouse.button_pressed.len) prev_mouse.button_pressed[button] else false;
            const curr_pressed = if (button < current_mouse.button_pressed.len) current_mouse.button_pressed[button] else false;
            
            if (!prev_pressed and curr_pressed) {
                // Button down event
                for (events_handler.mouse_callbacks.button_down.items) |item| {
                    if (item.entry.active) {
                        item.callback(button, true);
                    }
                }
            } else if (prev_pressed and !curr_pressed) {
                // Button up event
                for (events_handler.mouse_callbacks.button_up.items) |item| {
                    if (item.entry.active) {
                        item.callback(button, false);
                    }
                }
            }
        }
        
        events_handler.mutex.unlock();
        
        // Update previous mouse state
        prev_mouse.deinit();
        prev_mouse = current_mouse;
        
        time.sleep(events_handler.sleep_duration);
    }
    
    std.debug.print("Mouse thread exited\n", .{});
}

/// Clean up callback lists by removing inactive callbacks
fn cleanupCallbackLists(_: *DeviceEventsHandler) void {
    // Not implemented in this simplified version
}