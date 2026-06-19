#!/usr/bin/env bash
# Shared helpers for driving a headless KWin session inside the container.
# Source this file; it defines fz_* functions and exports DISPLAY.

: "${DISPLAY:=:99}"
: "${FZ_SCREEN:=1920x1080x24}"
: "${FZ_SRC:=/opt/fz/src}"
: "${FZ_LOG_DIR:=/opt/fz/logs}"
export DISPLAY

mkdir -p "$FZ_LOG_DIR"

log() { echo "[harness] $*" >&2; }

fz_start_dbus() {
  if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    eval "$(dbus-launch --sh-syntax)"
    export DBUS_SESSION_BUS_ADDRESS DBUS_SESSION_BUS_PID
    log "session dbus: $DBUS_SESSION_BUS_ADDRESS"
  fi
}

fz_start_xvfb() {
  log "starting Xvfb on $DISPLAY ($FZ_SCREEN)"
  Xvfb "$DISPLAY" -screen 0 "$FZ_SCREEN" -nolisten tcp >"$FZ_LOG_DIR/xvfb.log" 2>&1 &
  FZ_XVFB_PID=$!
  local _
  for _ in $(seq 1 50); do
    xdpyinfo -display "$DISPLAY" >/dev/null 2>&1 && { log "Xvfb ready"; return 0; }
    sleep 0.2
  done
  log "ERROR: Xvfb did not come up"
  return 1
}

fz_start_kwin() {
  # KWin scripting print() output is routed through Qt logging categories; enable
  # the relevant ones so script logs land in kwin.log.
  export QT_LOGGING_RULES="${QT_LOGGING_RULES:-kwin_scripting.debug=true;js.debug=true}"
  log "starting kwin_x11"
  kwin_x11 --replace >"$FZ_LOG_DIR/kwin.log" 2>&1 &
  FZ_KWIN_PID=$!
  local _
  for _ in $(seq 1 150); do
    if gdbus introspect --session --dest org.kde.KWin --object-path /KWin >/dev/null 2>&1; then
      log "org.kde.KWin is up on the bus"
      return 0
    fi
    sleep 0.2
  done
  log "ERROR: org.kde.KWin never appeared on the session bus"
  sed 's/^/[kwin] /' "$FZ_LOG_DIR/kwin.log" >&2 || true
  return 1
}

fz_start_session() {
  fz_start_dbus
  fz_start_xvfb
  fz_start_kwin
}

# Load a KWin JS script by file path.
#   $1 = path to main.js
#   $2 = plugin name (optional, default "fancyzones")
# Echoes the script id.
fz_load_script() {
  local path="$1" name="${2:-fancyzones}" out id
  log "loading KWin script: $path"
  out=$(gdbus call --session --dest org.kde.KWin --object-path /Scripting \
          --method org.kde.kwin.Scripting.loadScript "$path" "$name" 2>&1) || {
    log "loadScript failed: $out"
    return 1
  }
  id=$(echo "$out" | grep -oE '[0-9]+' | head -1)
  log "loadScript returned id=${id:-?}"
  # Start scripts. The method name has moved across versions, so try the known forms.
  gdbus call --session --dest org.kde.KWin --object-path /Scripting \
        --method org.kde.kwin.Scripting.start >/dev/null 2>&1 \
    || gdbus call --session --dest org.kde.KWin --object-path "/Scripting/Script${id}" \
            --method org.kde.kwin.Script.run >/dev/null 2>&1 \
    || log "note: no explicit start succeeded (script may auto-start on load)"
  echo "${id:-0}"
}

# Spawn a normal test window. $1 = title. Echoes its PID.
fz_spawn_window() {
  local title="${1:-testwin}" pid _
  xterm -T "$title" -geometry 80x24+50+50 -e "sleep 100000" >/dev/null 2>&1 &
  pid=$!
  for _ in $(seq 1 50); do
    xdotool search --name "^${title}$" >/dev/null 2>&1 && break
    sleep 0.2
  done
  echo "$pid"
}

# Echo "X Y W H" for the first window whose title matches $1 (exact).
fz_window_geometry() {
  local title="$1" wid
  wid=$(xdotool search --name "^${title}$" 2>/dev/null | head -1)
  [ -n "$wid" ] || { echo ""; return 1; }
  local X Y WIDTH HEIGHT SCREEN WINDOW
  eval "$(xdotool getwindowgeometry --shell "$wid")"
  echo "$X $Y $WIDTH $HEIGHT"
}

# Simulate a titlebar drag: down at (x1,y1), move to (x2,y2), release.
fz_drag() {
  xdotool mousemove "$1" "$2" mousedown 1
  sleep 0.2
  xdotool mousemove "$3" "$4"
  sleep 0.2
  xdotool mouseup 1
  sleep 0.3
}

# Capture the root window. $1 = output path (default $FZ_LOG_DIR/screenshot.png).
fz_screenshot() {
  local out="${1:-$FZ_LOG_DIR/screenshot.png}"
  if command -v import >/dev/null 2>&1; then
    import -window root "$out" 2>/dev/null && { log "screenshot -> $out"; return 0; }
  fi
  magick import -window root "$out" 2>/dev/null && log "screenshot -> $out"
}
