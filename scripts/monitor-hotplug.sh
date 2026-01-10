#!/usr/bin/env bash
set -euo pipefail

# monitor-hotplug.sh
#
# A robust alternative to Kanshi for handling monitor hotplugging.
# Optimized for ThinkPad T480 clamshell mode.

# --- Configuration ---
INTERNAL_OUTPUT="eDP-1"
EXT_RES="3840x2160@60Hz"
EXT_SCALE="1"
LOG_FILE="/tmp/sway-monitor-hotplug.log"

# --- State ---
CURRENT_STATE=""

log() {
  echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"
}

get_lid_state() {
  if [[ -f /proc/acpi/button/lid/LID/state ]]; then
    awk '{print $2}' /proc/acpi/button/lid/LID/state
  else
    echo "unknown"
  fi
}

move_workspaces() {
  local target="$1"
  log "Moving all workspaces to $target"
  for ws in $(swaymsg -t get_workspaces -r | jq -r '.[].name'); do
    swaymsg "[workspace=\"$ws\"] move workspace to output $target" >/dev/null 2>&1 || true
  done
}

update_monitors() {
  local outputs_json
  outputs_json=$(swaymsg -t get_outputs)
  
  local lid_state
  lid_state=$(get_lid_state)
  
  # Find an external monitor (first non-internal output)
  local ext_output
  ext_output=$(echo "$outputs_json" | jq -r ".[] | select(.name != \"$INTERNAL_OUTPUT\") | .name" | head -n1)
  
  if [[ -n "$ext_output" && "$ext_output" != "null" ]]; then
    NEW_STATE="docked:$ext_output:$lid_state"
    
    if [[ "$CURRENT_STATE" != "$NEW_STATE" ]]; then
      log "External detected: $ext_output (Lid: $lid_state). Configuring..."
      
      # 1. Enable external first
      swaymsg output "$ext_output" enable mode "$EXT_RES" scale "$EXT_SCALE" pos 0 0 || true
      
      # 2. Move workspaces
      move_workspaces "$ext_output"
      
      # 3. Handle internal display based on lid
      if [[ "$lid_state" == "closed" ]]; then
        log "Lid closed: disabling $INTERNAL_OUTPUT"
        swaymsg output "$INTERNAL_OUTPUT" disable
      else
        log "Lid open: keeping $INTERNAL_OUTPUT enabled (extended mode)"
        swaymsg output "$INTERNAL_OUTPUT" enable pos 3840 0 # Position it to the right of 4K
      fi
      
      CURRENT_STATE="$NEW_STATE"
    fi
  else
    # No external monitor
    NEW_STATE="mobile:$lid_state"
    
    if [[ "$lid_state" == "closed" ]]; then
      log "Lid closed and no external monitor. Suspending system..."
      # We don't update CURRENT_STATE here so it re-evaluates on wake
      systemctl suspend
      return
    fi

    if [[ "$CURRENT_STATE" != "$NEW_STATE" ]]; then
      log "No external detected. Switching to mobile mode (Lid: $lid_state)."
      swaymsg output "$INTERNAL_OUTPUT" enable
      move_workspaces "$INTERNAL_OUTPUT"
      CURRENT_STATE="$NEW_STATE"
    fi
  fi
}

# --- Execution ---

if [[ "${1:-}" == "--once" ]]; then
  update_monitors
  exit 0
fi

log "Monitor hotplug daemon started (PID: $$)"
update_monitors

# Listen for events (output and input for lid changes)
swaymsg -m -t subscribe '["output", "input"]' | \
while read -r event; do
  if echo "$event" | grep -qE "change|switch"; then
    sleep 0.2
    update_monitors
  fi
done
