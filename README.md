# Zinex

Zinex is an external tiling layout generator for the **River** Wayland compositor. Written in Zig, Zinex connects directly to River using custom Wayland protocol interfaces, calculating window placements and managing client geometries dynamically in a frame-perfect manner.

Unlike traditional window managers that embed layout logic inside the core compositor, River delegates layout generation to external processes. Zinex acts as one of these processes, implementing layout algorithms and responding to display changes, window creations, and focus updates.

---

## Features

*   **Master-Stack Layout**: Features an intuitive, mathematically computed master-stack tiling structure.
*   **Double-Buffered Rendering**: Leverages River's custom window management protocol to execute double-buffered layout updates, preventing visual tearing and screen flickering.
*   **Pure Wayland & Type-Safe Bindings**: Communicates with the compositor via generated type-safe Zig interfaces parsed from XML protocol definitions.
*   **Dynamic Focus Handling**: Automatically manages input seats, directing input focus to newly spawned window clients.
*   **Optimized for modern Zig (0.16.0)**: Employs standard library patterns for robust memory management and execution efficiency.

---

## Quick Start

### Requirements
*   **Zig Compiler** `0.16.0`
*   **River Wayland Compositor** `0.4.0` or newer
*   **libwayland-client** libraries and headers

### Building
Compile Zinex using the Zig build tool:
```bash
zig build -Doptimize=ReleaseFast
```
The resulting binary is generated at `zig-out/bin/zinex`.

### Usage
Instruct River to use Zinex as its active layout generator:
```bash
riverctl layout-generator /path/to/zinex/zig-out/bin/zinex
```
You can also append this command to your `~/.config/river/init` configuration file to run Zinex automatically when starting River.

---

## Documentation

To learn more about how Zinex is designed and how to contribute, explore the following documentation files:

*   **[Architecture Guide](docs/ARCHITECTURE.md)**: A deep-dive into the structure of Zinex, core data types, sequence diagrams of the Manage/Render protocol loops, and master-stack math.
*   **[Development Guide](docs/DEVELOPMENT.md)**: Instructions on setting up requirements, understanding the code generation scanner in `build.zig`, running tests, and debugging with `WAYLAND_DEBUG`.
*   **[Protocol Reference](docs/PROTOCOL.md)**: Information about the `river-window-management-v1` interfaces (`manager`, `window`, `node`, `output`, `seat`), protocol ordering rules, and error handling.

---

## License

Zinex is open-source software licensed under the **[MIT License](LICENSE)**.

Copyright (c) 2026 Kaveen Lakmuthu.
