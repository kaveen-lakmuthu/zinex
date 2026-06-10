# Zinex

Zinex is a custom, Zig-based tiling window manager for the **River** Wayland compositor. It uses the `river-window-management-v1` protocol to manage layouts and tiles clients externally.

## Features

- **Master-Stack Layout**: Supports an intuitive master-stack layout structure.
- **Dynamic Resizing**: Seamlessly updates coordinates and dimension proposal on output size changes.
- **Modern Zig (0.16.0)**: Built using the latest Zig standard library patterns.
- **Pure Wayland Interface**: Communicates directly via generated Wayland bindings.

## Requirements

- **Zig 0.16.0**
- **River compositor** (v0.4.0 or newer for external layout manager support)
- **libwayland-client**

## Building

To build the executable:

```bash
zig build -Doptimize=ReleaseFast
```

The compiled binary will be placed at `zig-out/bin/zinex`.

## Usage

Configure River to delegate its tiling layout generation to Zinex by running:

```bash
riverctl layout-generator /path/to/zinex/zig-out/bin/zinex
```

Alternatively, you can add this line to your `~/.config/river/init` startup configuration file.
