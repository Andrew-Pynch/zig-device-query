# Zig Device Query

A Zig library for querying mouse and keyboard state without requiring an active window. This is a Zig port of the Rust [device_query](https://github.com/ostrosco/device_query) crate.

## Features

- Cross-platform support (Linux implemented, Windows and macOS stubs ready for implementation)
- Query mouse position and button state
- Query keyboard state (which keys are pressed)
- Event-based callbacks for:
  - Key presses and releases
  - Mouse movement
  - Mouse button presses and releases

## Dependencies

### Linux

On Linux, the X11 development libraries are required:

```bash
# Ubuntu/Debian
sudo apt install libx11-dev

# Fedora/RHEL/CentOS
sudo dnf install xorg-x11-server-devel
```

## Usage

### Adding to your project

Add the dependency to your `build.zig.zon`:

```zig
.dependencies = .{
    .zig_device_query = .{
        .url = "https://github.com/Andrew-Pynch/zig-device-query/archive/refs/tags/v0.1.0.tar.gz",
        .hash = "<hash>",
    },
},
```

And in your `build.zig`:

```zig
const device_query_dep = b.dependency("zig_device_query", .{
    .target = target,
    .optimize = optimize,
});

// Add module to your executable
exe.addModule("zig_device_query", device_query_dep.module("zig_device_query_lib"));

// Link required system libraries
if (target.result.os.tag == .linux) {
    exe.linkSystemLibrary("X11");
} else if (target.result.os.tag == .windows) {
    exe.linkSystemLibrary("user32");
}
```

### Query-based approach

```zig
const std = @import("std");
const device_query = @import("zig_device_query");
const DeviceState = device_query.DeviceState;
const Keycode = device_query.Keycode;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Create a device state
    var device_state = try DeviceState.init(allocator);
    defer device_state.deinit();

    // Get mouse state
    var mouse = try device_state.getMouse();
    defer mouse.deinit();

    std.debug.print("Mouse position: ({}, {})\n", .{mouse.coords.x, mouse.coords.y});

    // Check if a specific button is pressed
    if (mouse.isButtonPressed(1)) {
        std.debug.print("Left mouse button is pressed\n", .{});
    }

    // Get keyboard state
    const keys = try device_state.getKeys();
    defer allocator.free(keys);

    // Check if a specific key is pressed
    for (keys) |key| {
        if (key == Keycode.A) {
            std.debug.print("A key is pressed\n", .{});
        }
    }
}
```

### Event-based approach

```zig
const std = @import("std");
const device_query = @import("zig_device_query");
const DeviceEventsHandler = device_query.DeviceEventsHandler;
const time = std.time;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    // Create an event handler with a 10ms polling interval
    var events_handler = try DeviceEventsHandler.init(allocator, 10 * time.ns_per_ms);
    defer events_handler.deinit();

    // Register callback for key presses
    const key_guard = try events_handler.onKeyDown(keyCallback);
    defer allocator.destroy(key_guard);

    // Register callback for mouse movement
    const mouse_guard = try events_handler.onMouseMove(mouseMoveCallback);
    defer allocator.destroy(mouse_guard);

    // Keep the program running to receive events
    std.debug.print("Press keys or move the mouse...\n", .{});
    time.sleep(10 * time.ns_per_s);
}

fn keyCallback(key: device_query.Keycode) void {
    std.debug.print("Key pressed: {s}\n", .{key.toString()});
}

fn mouseMoveCallback(position: *const device_query.MousePosition) void {
    std.debug.print("Mouse moved to: ({}, {})\n", .{position.x, position.y});
}
```

## License

MIT License (same as the original Rust crate)

## Acknowledgments

This is a port of the Rust [device_query](https://github.com/ostrosco/device_query) crate by Shane Osbourne (ostrosco).
