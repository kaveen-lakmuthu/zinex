const std = @import("std");
const wl = @import("wayland").client.wl;
const river = @import("wayland").client.river;

const Zinex = struct {
    allocator: std.mem.Allocator,
    display: *wl.Display,
    registry: *wl.Registry,

    compositor: ?*wl.Compositor = null,
    river_wm: ?*river.WindowManagerV1 = null,

    outputs: std.ArrayList(*Output),
    windows: std.ArrayList(*Window),
    seats: std.ArrayList(*Seat),

    pub fn init(allocator: std.mem.Allocator, display: *wl.Display, registry: *wl.Registry) Zinex {
        return .{
            .allocator = allocator,
            .display = display,
            .registry = registry,
            .outputs = .empty,
            .windows = .empty,
            .seats = .empty,
        };
    }

    pub fn deinit(self: *Zinex) void {
        for (self.outputs.items) |o| {
            o.proxy.destroy();
            self.allocator.destroy(o);
        }
        self.outputs.deinit(self.allocator);

        for (self.windows.items) |w| {
            w.node.destroy();
            w.proxy.destroy();
            if (w.app_id) |app| self.allocator.free(app);
            if (w.title) |t| self.allocator.free(t);
            self.allocator.destroy(w);
        }
        self.windows.deinit(self.allocator);

        for (self.seats.items) |s| {
            s.proxy.destroy();
            self.allocator.destroy(s);
        }
        self.seats.deinit(self.allocator);
    }

    pub fn runLayoutManage(self: *Zinex) void {
        const wm = self.river_wm orelse return;

        if (self.outputs.items.len == 0 or self.windows.items.len == 0) {
            wm.manageFinish();
            return;
        }

        const output = self.outputs.items[0];
        const ow = output.width;
        const oh = output.height;
        const n = self.windows.items.len;

        std.log.info("Layout manage: output={}x{}, windows={}", .{ ow, oh, n });

        if (n == 1) {
            self.windows.items[0].proxy.proposeDimensions(ow, oh);
            self.windows.items[0].proxy.setTiled(.{});
        } else {
            // Master gets left half
            self.windows.items[0].proxy.proposeDimensions(@divTrunc(ow, 2), oh);
            self.windows.items[0].proxy.setTiled(.{ .right = true });

            // Stack gets right half
            const stack_h = @divTrunc(oh, @as(i32, @intCast(n - 1)));
            var i: usize = 1;
            while (i < n) : (i += 1) {
                self.windows.items[i].proxy.proposeDimensions(@divTrunc(ow, 2), stack_h);
                self.windows.items[i].proxy.setTiled(.{ .left = true });
            }
        }

        // Set focus to the newest window
        if (self.seats.items.len > 0) {
            const newest_win = self.windows.items[n - 1];
            self.seats.items[0].proxy.focusWindow(newest_win.proxy);
        }

        wm.manageFinish();
    }

    pub fn runLayoutRender(self: *Zinex) void {
        const wm = self.river_wm orelse return;

        if (self.outputs.items.len == 0 or self.windows.items.len == 0) {
            wm.renderFinish();
            return;
        }

        const output = self.outputs.items[0];
        const ox = output.x;
        const oy = output.y;
        const ow = output.width;
        const oh = output.height;
        const n = self.windows.items.len;

        std.log.info("Layout render: output=({}, {}) {}x{}, windows={}", .{ ox, oy, ow, oh, n });

        if (n == 1) {
            const win = self.windows.items[0];
            win.node.setPosition(ox, oy);
            win.node.placeTop();
        } else {
            // Master gets left half
            const master = self.windows.items[0];
            master.node.setPosition(ox, oy);
            master.node.placeTop();

            // Stack gets right half
            const stack_w = @divTrunc(ow, 2);
            const stack_h = @divTrunc(oh, @as(i32, @intCast(n - 1)));
            const stack_x = ox + stack_w;

            var i: usize = 1;
            while (i < n) : (i += 1) {
                const win = self.windows.items[i];
                const win_y = oy + @as(i32, @intCast(i - 1)) * stack_h;
                win.node.setPosition(stack_x, win_y);
                win.node.placeTop();
            }
        }

        wm.renderFinish();
    }

    const Output = struct {
        proxy: *river.OutputV1,
        name: u32,
        x: i32 = 0,
        y: i32 = 0,
        width: i32 = 0,
        height: i32 = 0,
    };

    const Window = struct {
        proxy: *river.WindowV1,
        node: *river.NodeV1,
        width: i32 = 0,
        height: i32 = 0,
        title: ?[]const u8 = null,
        app_id: ?[]const u8 = null,
    };

    const Seat = struct {
        proxy: *river.SeatV1,
        name: u32,
    };
};

fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, zinex: *Zinex) void {
    switch (event) {
        .global => |global| {
            const interface_name = std.mem.span(global.interface);
            if (std.mem.eql(u8, interface_name, "wl_compositor")) {
                zinex.compositor = registry.bind(global.name, wl.Compositor, 4) catch |err| {
                    std.log.err("Failed to bind wl_compositor: {}", .{err});
                    return;
                };
            } else if (std.mem.eql(u8, interface_name, "river_window_manager_v1")) {
                zinex.river_wm = registry.bind(global.name, river.WindowManagerV1, 4) catch |err| {
                    std.log.err("Failed to bind river_window_manager_v1: {}", .{err});
                    return;
                };
            }
        },
        .global_remove => {},
    }
}

fn outputListener(output_proxy: *river.OutputV1, event: river.OutputV1.Event, zinex: *Zinex) void {
    const output = for (zinex.outputs.items) |o| {
        if (o.proxy == output_proxy) break o;
    } else return;

    switch (event) {
        .position => |pos| {
            output.x = pos.x;
            output.y = pos.y;
            std.log.info("Output {}: position changed to ({}, {})", .{ output.name, pos.x, pos.y });
        },
        .dimensions => |dim| {
            output.width = dim.width;
            output.height = dim.height;
            std.log.info("Output {}: dimensions changed to {}x{}", .{ output.name, dim.width, dim.height });
        },
        .removed => {
            std.log.info("Output {} removed", .{ output.name });
            const idx = for (zinex.outputs.items, 0..) |o, i| {
                if (o == output) break i;
            } else return;
            _ = zinex.outputs.swapRemove(idx);
            output_proxy.destroy();
            zinex.allocator.destroy(output);
            if (zinex.river_wm) |wm| {
                wm.manageDirty();
            }
        },
        .wl_output => {},
    }
}

fn windowListener(window_proxy: *river.WindowV1, event: river.WindowV1.Event, zinex: *Zinex) void {
    const window = for (zinex.windows.items) |w| {
        if (w.proxy == window_proxy) break w;
    } else return;

    switch (event) {
        .dimensions => |dim| {
            window.width = dim.width;
            window.height = dim.height;
            std.log.info("Window {}: dimensions set to {}x{}", .{ window_proxy.getId(), dim.width, dim.height });
        },
        .app_id => |app| {
            if (window.app_id) |old| zinex.allocator.free(old);
            if (app.app_id) |str| {
                const dup = zinex.allocator.dupe(u8, std.mem.span(str)) catch @panic("OOM");
                window.app_id = dup;
                std.log.info("Window {}: app_id set to '{s}'", .{ window_proxy.getId(), dup });
            } else {
                window.app_id = null;
            }
        },
        .title => |t| {
            if (window.title) |old| zinex.allocator.free(old);
            if (t.title) |str| {
                const dup = zinex.allocator.dupe(u8, std.mem.span(str)) catch @panic("OOM");
                window.title = dup;
                std.log.info("Window {}: title set to '{s}'", .{ window_proxy.getId(), dup });
            } else {
                window.title = null;
            }
        },
        .closed => {
            std.log.info("Window {} closed", .{ window_proxy.getId() });
            const idx = for (zinex.windows.items, 0..) |w, i| {
                if (w == window) break i;
            } else return;
            _ = zinex.windows.swapRemove(idx);

            if (window.app_id) |app| zinex.allocator.free(app);
            if (window.title) |t| zinex.allocator.free(t);

            window.node.destroy();
            window.proxy.destroy();
            zinex.allocator.destroy(window);

            if (zinex.river_wm) |wm| {
                wm.manageDirty();
            }
        },
        else => {},
    }
}

fn wmListener(wm: *river.WindowManagerV1, event: river.WindowManagerV1.Event, zinex: *Zinex) void {
    _ = wm;
    switch (event) {
        .unavailable => {
            std.log.err("Window manager interface unavailable. Another window manager is likely running.", .{});
            std.process.exit(1);
        },
        .finished => {
            std.log.info("River window manager interface finished.", .{});
            std.process.exit(0);
        },
        .session_locked => {
            std.log.info("Session locked.", .{});
        },
        .session_unlocked => {
            std.log.info("Session unlocked.", .{});
        },
        .output => |args| {
            const output = zinex.allocator.create(Zinex.Output) catch |err| {
                std.log.err("Failed to allocate Output struct: {}", .{err});
                return;
            };
            output.* = .{
                .proxy = args.id,
                .name = args.id.getId(),
            };
            zinex.outputs.append(zinex.allocator, output) catch @panic("OOM");
            std.log.info("New output added: {}", .{output.name});

            args.id.setListener(*Zinex, outputListener, zinex);
        },
        .seat => |args| {
            const seat = zinex.allocator.create(Zinex.Seat) catch |err| {
                std.log.err("Failed to allocate Seat struct: {}", .{err});
                return;
            };
            seat.* = .{
                .proxy = args.id,
                .name = args.id.getId(),
            };
            zinex.seats.append(zinex.allocator, seat) catch @panic("OOM");
            std.log.info("New seat added: {}", .{seat.name});
        },
        .window => |args| {
            const node = args.id.getNode() catch |err| {
                std.log.err("Failed to get node for window: {}", .{err});
                return;
            };
            const window = zinex.allocator.create(Zinex.Window) catch |err| {
                std.log.err("Failed to allocate Window struct: {}", .{err});
                return;
            };
            window.* = .{
                .proxy = args.id,
                .node = node,
            };
            zinex.windows.append(zinex.allocator, window) catch @panic("OOM");
            std.log.info("New window created: id={}", .{args.id.getId()});

            args.id.setListener(*Zinex, windowListener, zinex);

            if (zinex.river_wm) |rwm| {
                rwm.manageDirty();
            }
        },
        .manage_start => {
            std.log.info("--- Manage Start ---", .{});
            zinex.runLayoutManage();
        },
        .render_start => {
            std.log.info("--- Render Start ---", .{});
            zinex.runLayoutRender();
        },
    }
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;

    const display = wl.Display.connect(null) catch |err| {
        std.log.err("Failed to connect to Wayland display. Are you running under a Wayland compositor? Error: {}", .{err});
        return err;
    };
    defer display.disconnect();

    const registry = try display.getRegistry();
    defer registry.destroy();

    var zinex = Zinex.init(gpa, display, registry);
    defer zinex.deinit();

    registry.setListener(*Zinex, registryListener, &zinex);

    if (display.roundtrip() != .SUCCESS) {
        std.log.err("Wayland roundtrip failed.", .{});
        return error.WaylandRoundtripFailed;
    }

    if (zinex.river_wm == null) {
        std.log.err("River window manager interface not found. Make sure you run this process inside the River compositor.", .{});
        return error.NoRiverCompositor;
    }

    std.log.info("Zinex window manager connected and bound to River!", .{});

    zinex.river_wm.?.setListener(*Zinex, wmListener, &zinex);

    while (true) {
        const ret = display.dispatch();
        if (ret != .SUCCESS) {
            std.log.info("Wayland compositor disconnected (status: {s}).", .{@tagName(ret)});
            break;
        }
    }
}
