# River Window Management Protocol

Zinex relies on custom Wayland protocols to orchestrate layout and rendering configurations. The primary protocol is `river-window-management-v1`.

This document explains the key interfaces, double-buffered state updates, lifecycle events, and error codes defined by the protocol.

---

## Double-Buffered State updates

In Wayland, window management state changes can trigger screen flickering or stutter if applied piece-by-piece. The `river-window-management-v1` protocol resolves this by implementing a **double-buffered state architecture**.

1.  The compositor updates its internal representation of windows and outputs, but does not display it yet.
2.  The compositor enters a **Manage Sequence** or a **Render Sequence** and notifies the window manager client (Zinex).
3.  Zinex makes multiple requests (e.g. proposes dimensions or updates node positions). These requests are staged (buffered) on the compositor side.
4.  Once Zinex sends `manage_finish` or `render_finish`, the compositor commits the staged state changes atomically in the next hardware frame.

This ensures frame-perfect visual transitions.

---

## Core Interfaces

### 1. `river_window_manager_v1`
The global manager interface. Only one window management client may be active at any given time.
*   **Events**:
    *   `unavailable`: Sent as the first event if another window manager is already running.
    *   `manage_start`: Begins a manage sequence.
    *   `render_start`: Begins a render sequence.
    *   `output`: Announced when a new output is added to the compositor.
    *   `window`: Announced when a new client window is created.
    *   `seat`: Announced when a seat is created (representing inputs).
*   **Requests**:
    *   `manage_finish`: Commits and ends a manage sequence.
    *   `render_finish`: Commits and ends a render sequence.
    *   `manage_dirty`: Forcefully requests the compositor to start a manage sequence (e.g. if the window manager initiates internal state changes).

### 2. `river_window_v1`
Represents an individual client window (comparable to an `xdg_toplevel`).
*   **Events**:
    *   `dimensions`: Sent by the compositor when the client window confirms its new width and height.
    *   `title` / `app_id`: Notifies the window manager of updates to title string and application ID class.
    *   `closed`: Notifies that the window is being destroyed.
*   **Requests**:
    *   `propose_dimensions`: Suggests a new width and height for the window.
    *   `set_tiled`: Sets which edges of the window are adjacent to screen edges or other tiled windows.
    *   `get_node`: Acquires a rendering node handle (`river_node_v1`) to control positions.

### 3. `river_node_v1`
Represents a node in the compositor's rendering tree. It governs the geometry positioning and stacking (Z-order) of a window.
*   **Requests**:
    *   `set_position`: Sets absolute coordinates $(x, y)$ in logical desktop space.
    *   `place_top` / `place_bottom`: Places the node at the top or bottom of the render stack.
    *   `place_above` / `place_below`: Re-orders the node relative to another specific node.

### 4. `river_output_v1`
Represents a logical output screen.
*   **Events**:
    *   `position`: Global logical offset coordinates.
    *   `dimensions`: Logical width and height.
    *   `removed`: Notifies that the output is offline (e.g. unplugged/disabled).

### 5. `river_seat_v1`
Represents input focus control.
*   **Requests**:
    *   `focus_window`: Instructs the compositor to transfer keyboard focus to a given `river_window_v1`.

---

## Protocol Errors

The compositor enforces strict sequence rules. If Zinex violates them, the compositor throws a protocol error and immediately terminates the Wayland connection:

*   **`sequence_order` (value 0)**:
    *   *Cause*: The client sent a request associated with window-management state (like `propose_dimensions`) outside a Manage Sequence, or sent a request associated with rendering state (like `set_position`) outside a Manage/Render Sequence. Or, it called `manage_finish`/`render_finish` in the wrong order.
*   **`role` (value 1)**:
    *   *Cause*: The client attempted to assign a role to a surface that already has one.
*   **`unresponsive` (value 2)**:
    *   *Cause*: The window manager client took too long to complete a manage/render sequence.

---

## Other Bundled River Protocols

In the `protocol/` directory, several other River-specific protocols are scanned and compiled for potential future features:

1.  **`river-input-management-v1`**:
    Allows a manager client to configure keyboard layouts, mouse acceleration, scroll factors, and pointer behavior.
2.  **`river-layer-shell-v1`**:
    An extension of the standard Wayland layer-shell protocol. Enables rendering status bars, panels, background wallpapers, and notifications at specific layer depths.
3.  **`river-libinput-config-v1`**:
    Exposes raw libinput configurations (touchpad tap-to-click, natural scrolling, middle-button emulation).
4.  **`river-xkb-bindings-v1` & `river-xkb-config-v1`**:
    Handles keybinding configurations and layout maps directly, letting the window manager configure global compositor hotkeys dynamically.
