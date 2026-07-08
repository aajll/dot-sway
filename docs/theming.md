# Theme Toggle & Wallpaper

## Theme toggle (dark/light)

A single keybind (`Mod+Shift+t`) flips Sway, Waybar, kitty, wofi, mako, and (under GNOME) Gnome's `color-scheme` between dark and light. The script is `scripts/toggle_theme.sh`; it runs `init` at Sway startup to bootstrap all components.

- **Status indicator:** 🌙 dark / ☀️ light (`waybar/modules/theme.sh`).
- **Gnome sync:** when `gsettings` reports `org.gnome.desktop.interface color-scheme`, that is the source of truth; otherwise `.theme_state` is.
- **Live Waybar repaint:** symlink swap + `SIGUSR2`, no restart.

```bash
scripts/toggle_theme.sh toggle   # flip
scripts/toggle_theme.sh init     # re-apply current theme to all components
scripts/toggle_theme.sh get      # print "dark" or "light"
```

## Wallpaper rotation

`config.d/wallpaper` runs `scripts/rotate-wallpaper.sh` on each Sway start/reload:

1. Scans the pool for `.png/.jpg/.jpeg` (case-insensitive, top level). Pool is `images/wallpapers/` by default; a gitignored `wallpaper_dir.local` (copy `wallpaper_dir.local.example`) can point it at an external folder.
2. Picks one uniformly at random.
3. Repoints the `images/wp.png` symlink at the pick.
4. Applies it live with `swaymsg output * bg images/wp.png fill`.

Because everything that references the wallpaper (`output * bg`, the swaylock keybind, the swayidle `before-sleep` hook) reads `images/wp.png`, the lock screen and idle blur follow the rotation automatically.

```bash
cp ~/Pictures/*.jpg ~/.config/sway/images/wallpapers/   # add wallpapers
$mod+Shift+c                                            # reload sway -> re-rolls
scripts/rotate-wallpaper.sh                             # or roll directly
```

An empty or missing pool is a no-op; the current `wp.png` is left untouched, so you can disable rotation by emptying the folder.

**Cold-boot note:** on a fresh login Sway parses `output * bg` before `exec_always` fires, so the boot wallpaper is whatever `wp.png` pointed at when you last shut down; the rotation then applies the new pick live, so expect a sub-second flash of the previous wallpaper.
