# XDG Defaults (Terminal, MIME, Portals)

Session-level defaults that make Sway behave like a first-class desktop on a GNOME-based distro. None of this lives in the Sway `config` file; it is XDG/session state, applied by [`scripts/setup-defaults.sh`](../scripts/setup-defaults.sh) (idempotent; user-level steps run without root, root steps are printed).

## Session environment

The one variable that matters for both portals and MIME routing is `XDG_CURRENT_DESKTOP`. The main `config` exports it and the Wayland/session vars into the D-Bus and systemd user environments so portals and launched apps see them:

```
exec dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway XDG_SESSION_TYPE=wayland
```

`XDG_CURRENT_DESKTOP=sway` is also what selects the desktop-specific `sway-portals.conf` and (if present) `sway-mimeapps.list` variants.

## Default terminal

There are **four independent "default terminal" layers** on a Debian + Sway box. `setup-defaults.sh` sets the first three; the Nautilus one needs a package swap.

| Layer | File / mechanism | Read by |
|-------|------------------|---------|
| freedesktop / GLib | `~/.config/xdg-terminals.list` ([`xdg-terminal-exec` spec](https://github.com/Vladimir-csp/xdg-terminal-exec)) | GLib ≥ 2.79 "launch in terminal", anything honoring the spec |
| `$TERMINAL` env | `~/.config/environment.d/10-terminal.conf` | `xdg-terminal-exec` fallback, many CLI tools |
| Debian alternative | `x-terminal-emulator` (`update-alternatives`) | tools that exec `x-terminal-emulator` |
| GNOME legacy | `org.gnome.desktop.default-applications.terminal` gsettings | some GNOME components |

### Nautilus "Open in Terminal"

Served by the `nautilus-extension-gnome-terminal` package, which is **hardwired to gnome-terminal and ignores every layer above**. To make it open kitty, replace it with [`nautilus-open-any-terminal`](https://github.com/Stunkymonkey/nautilus-open-any-terminal):

```bash
sudo apt remove nautilus-extension-gnome-terminal
pipx install nautilus-open-any-terminal      # not in Debian apt; or pip install --user
gsettings set com.github.stunkymonkey.nautilus-open-any-terminal terminal kitty
nautilus -q
```

## MIME defaults

The authoritative file is `~/.config/mimeapps.list`; its `[Default Applications]` section overrides all system defaults. Lookup precedence (highest first):

1. `~/.config/sway-mimeapps.list` — desktop-specific; only for Sway≠GNOME divergence
2. **`~/.config/mimeapps.list`** — shared across both sessions (what we use)
3. `/etc/xdg/mimeapps.list`, then system `/usr/share/applications/…`

Drive it with `xdg-mime` (writes the correct file for you) rather than editing by hand:

```bash
gio mime application/pdf                                  # query
xdg-mime default org.gnome.Evince.desktop application/pdf # set
```

`setup-defaults.sh` sets sane defaults (text → GNOME Text Editor, PDF → Evince, images → Loupe) only when the target app is installed. Edit its `MIME_MAP` to taste.

## Portals

The canonical wlroots stack is **`xdg-desktop-portal-gtk`** (file chooser, settings, open-with) **+ `xdg-desktop-portal-wlr`** (screenshot / screencast). `/usr/share/xdg-desktop-portal/sway-portals.conf` already requests `wlr;gtk`:

```
[preferred]
default=wlr;gtk;
```

If screensharing fails to find a source, the wlr backend is missing:

```bash
sudo apt install xdg-desktop-portal-wlr
systemctl --user restart xdg-desktop-portal.service
```

`xdg-desktop-portal-gnome` may stay installed (pulled in by the GNOME fallback session); the preference list above steers Sway to wlr/gtk regardless.

## Verifying

```bash
cat ~/.config/xdg-terminals.list                 # kitty.desktop
gio mime text/plain                              # org.gnome.TextEditor.desktop
ls /usr/share/xdg-desktop-portal/portals/        # gtk + wlr present
```
