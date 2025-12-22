#!/bin/sh
# Simple orchestrator for RubyFPV station on Radxa/DRM path

export PATH=/usr/bin:/bin:/usr/sbin:/sbin
export HOME=/root

# Start essential station processes in background
start_station()
{
  # Start radio/telemetry/control daemons (ignore failures if missing)
  for bin in ruby_rt_station ruby_controller ruby_rx_telemetry ruby_tx_rc; do
    if command -v "$bin" >/dev/null 2>&1; then
      "$bin" &
    fi
  done

  # Start UI last in foreground to keep process attached
  if command -v ruby_central >/dev/null 2>&1; then
    exec ruby_central
  else
    # Fallback to player-only if central UI is not present
    if command -v ruby_player_radxa >/dev/null 2>&1; then
      exec ruby_player_radxa
    fi
  fi
}

case "$1" in
  start)
    start_station
    ;;
  stop)
    # stop handled by init script
    ;;
  *)
    echo "Usage: $0 {start|stop}"
    exit 1
    ;;
 esac
