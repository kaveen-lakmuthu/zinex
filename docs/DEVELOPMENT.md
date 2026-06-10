# Zinex Development Guide

This guide describes how to set up your environment, build the project, run tests, and debug Zinex.

---

## Prerequisites

To build and run Zinex, you need the following dependencies installed on your system:

1.  **Zig Compiler**: Version `0.16.0`.
2.  **Wayland Libraries**: `libwayland-client` and its development headers (e.g., `libwayland-dev` on Debian/Ubuntu, `wayland-devel` on Fedora).
3.  **River Compositor**: Version `0.4.0` or newer (necessary to support external layout manager protocol bindings).

---

## Workspace Directory Structure

The project has the following directory structure:

| Path | Purpose |
| :--- | :--- |
| `src/main.zig` | The application entry point, Wayland event loop, and global state tracking. |
| `src/root.zig` | Common library functions, utilities, and tests. |
| `protocol/` | Custom XML protocols provided by River. |
| `docs/` | Architecture, protocol, and development guides. |
| `layout-engine/` | Placeholder for future decoupled layout engines. |
| `panels/` | Placeholder for future panel and status bar implementations. |

---

## Build Commands

Zinex uses the standard Zig build system.

### Build Zinex
To compile the window manager executable:
```bash
zig build
```
The compiled binary will be output to `zig-out/bin/zinex`.

### Build with Optimizations
To build a highly optimized release binary:
```bash
zig build -Doptimize=ReleaseFast
```

### Run Tests
To run all unit tests defined in the module:
```bash
zig build test
```

---

## Protocol Code Generation

Zinex utilizes [zig-wayland](https://codeberg.org/ifreund/zig-wayland) to generate type-safe Zig bindings directly from XML protocol definitions.

This code generation occurs dynamically at compile time in `build.zig`. The build script:
1. Instantiates a `Scanner` tool from the `wayland` dependency module.
2. Registers custom XML protocol specifications located under the `protocol/` folder:
   * `protocol/river-window-management-v1.xml`
   * `protocol/river-input-management-v1.xml`
   * `protocol/river-layer-shell-v1.xml`
   * `protocol/river-libinput-config-v1.xml`
   * `protocol/river-xkb-bindings-v1.xml`
   * `protocol/river-xkb-config-v1.xml`
3. Automatically generates the client-side stub files and bundles them into the `@import("wayland")` namespace.

---

## Running and Debugging

### Running Zinex
To run Zinex, you must start it from inside an active River session. Instruct River to delegate tiling layout management to your local binary:
```bash
riverctl layout-generator ./zig-out/bin/zinex
```

### Logging and Troubleshooting
Zinex utilizes the standard library logging namespace (`std.log`). By default, logs print directly to the standard error stream of the process:
* Look for layout event outputs such as `Layout manage: output=...` and `Layout render: output=...`.

### Debugging Wayland Protocols
To inspect every Wayland protocol message exchanged between River and Zinex in real-time, run the window manager with the environment variable `WAYLAND_DEBUG` set to `1`:
```bash
WAYLAND_DEBUG=1 ./zig-out/bin/zinex
```
This prints all protocol requests, events, object IDs, and parameters to standard error, which is highly useful for troubleshooting sequence timing issues or bad inputs.
