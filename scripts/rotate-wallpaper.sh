#!/usr/bin/env bash
# rotate-wallpaper.sh
# Pick a random image from images/wallpapers/ and apply it as the desktop
# background. Repoints the images/wp.png symlink (used by `output * bg` and
# swaylock) and applies the change live via swaymsg.
#
# Empty folder → no-op. Rotation is on-demand — bound to $mod+Shift+w. With
# --if-unset the script only picks when wp.png isn't already a valid wallpaper,
# so start/reload (config.d/wallpaper) bootstrap one on first run but leave an
# existing wallpaper in place.
set -euo pipefail

# --if-unset: no-op when wp.png already resolves to an existing file. Used by
# config.d/wallpaper so start/reload only set a wallpaper when none is present,
# letting the chosen wallpaper persist until an explicit rotate.
IF_UNSET=0
[[ "${1:-}" == "--if-unset" ]] && IF_UNSET=1

SWAY_DIR="${SWAY_DIR:-$HOME/.config/sway}"
WALLPAPER_DIR="$SWAY_DIR/images/wallpapers"
LINK="$SWAY_DIR/images/wp.png"

# Machine-local pool override — wallpaper_dir.local (gitignored, like
# compose_key.local) holds one path to an external wallpaper folder.
# Absent file → the in-repo images/wallpapers/ pool above.
# First non-blank, non-comment line is the path (~ is expanded).
OVERRIDE_FILE="$SWAY_DIR/wallpaper_dir.local"
if [[ -f "$OVERRIDE_FILE" ]]; then
  override="$(grep -m1 -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$OVERRIDE_FILE" || true)"
  [[ -n "$override" ]] && WALLPAPER_DIR="${override/#\~/$HOME}"
fi

# In --if-unset (start/reload) mode, leave an already-set wallpaper alone so it
# persists until the user explicitly rotates with $mod+Shift+w. `-e` follows the
# symlink, so a missing or dangling wp.png still triggers a first pick.
if [[ "$IF_UNSET" -eq 1 && -e "$LINK" ]]; then
  exit 0
fi

[[ -d "$WALLPAPER_DIR" ]] || exit 0

mapfile -d '' -t candidates < <(
  find "$WALLPAPER_DIR" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -print0
)

[[ "${#candidates[@]}" -gt 0 ]] || exit 0

pick="${candidates[RANDOM % ${#candidates[@]}]}"

# In-repo pool → relative target (portable across machines); external
# override dir → absolute path is the only option.
if [[ "$pick" == "$SWAY_DIR/images/wallpapers/"* ]]; then
  ln -sfn "wallpapers/$(basename "$pick")" "$LINK"
else
  ln -sfn "$pick" "$LINK"
fi

# Apply live if sway IPC is reachable. On cold boot the socket may not exist
# yet — sway will pick up the symlink when it processes `output * bg` itself.
if [[ -n "${SWAYSOCK:-}" ]] && command -v swaymsg >/dev/null 2>&1; then
  swaymsg "output * bg $LINK fill" >/dev/null 2>&1 || true
fi
