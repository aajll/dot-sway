# Utility scripts

The following scripts are used in some of the Swayfx configuration or supporting status scripts. They should be placed into:

```bash
$HOME/.local/bin/
```

- `move-ws-to-active.sh`: Moves all workspaces to the currently focused output.
- `move-ws-to-output.sh`: Moves all workspaces to a specific output (arg 1).
- `toggle-touchpad.sh`: Toggles the touchpad on/off and sends a notification.
- `monitor-hotplug.sh`: **(New)** Auto-switches between "Mobile" (internal screen only) and "Docked" (external screen only) modes.
    - **Logic:**
        - If an external monitor is connected:
            - Enables the external monitor.
            - Moves all workspaces to it.
            - If the laptop lid is closed, disables the internal display (`eDP-1`).
        - If no external monitor is connected:
            - Enables the internal display.
            - Moves all workspaces to it.
            - If the laptop lid is closed, **suspends** the system (ensures it doesn't stay awake in your bag).
    - **Hardware Support:** Uses `/proc/acpi/button/lid/LID/state` to detect lid status. Optimized for ThinkPad T480.
    - **Logging:** Logs actions to `/tmp/sway-monitor-hotplug.log`.
