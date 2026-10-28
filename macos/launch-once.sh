#!/bin/bash
# Integration adapter for Dream Skin 1.5.21. Never restart or retry the client.
set -euo pipefail
engine="$1"
theme="$2"
. "$engine/scripts/common-macos.sh"
discover_codex_app
require_signed_node_runtime
# A process appearing after the Swift preflight wins; do not touch its theme.
if codex_is_running; then exit 21; fi
verify_macos_app_signature deep
"$engine/scripts/switch-theme-macos.sh" --id "$theme" --no-apply
ensure_state_root
if [ -f "$STATE_PATH" ]; then stop_recorded_injector; fi
sync_appearance_pin >/dev/null || true
port="$(select_available_port 9341)"
if codex_is_running; then exit 21; fi
# A single LaunchServices request. In particular, no direct-executable fallback.
/usr/bin/open -a "$CODEX_BUNDLE" --args --remote-debugging-address=127.0.0.1 --remote-debugging-port="$port"
wait_for_cdp "$port"
injector_pid="$(launch_injector_daemon "$port")"
started="$(process_started_at "$injector_pid")"
[ -n "$started" ]
client_pid="$(codex_main_pids | /usr/bin/head -n 1)"
write_state "$port" "$injector_pid" "$started" "$client_pid"
if "$NODE" "$INJECTOR" --verify --port "$port" --theme-dir "$THEME_DIR" --timeout-ms 20000; then
  mark_state_active
else
  stop_recorded_injector
  mark_state_stale
  exit 22
fi
