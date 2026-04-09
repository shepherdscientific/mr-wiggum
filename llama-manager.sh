#!/usr/bin/env bash
# llama-manager.sh — llama-server lifecycle + context watchdog for Ralph
#
# USAGE (standalone):
#   source llama-manager.sh          # load functions into current shell
#   llama_start                      # start Tier 1 server
#   llama_watch &                    # run watchdog in background
#   llama_stop                       # graceful shutdown
#
# USAGE (from ralph.sh, before iteration):
#   source "$(dirname "$0")/llama-manager.sh"
#   llama_ensure_running             # start if not up
#   llama_check_escalate             # check signal, escalate tier if needed
#
# ENVIRONMENT OVERRIDES (all optional):
#   LLAMA_BIN         path to llama-server binary
#   LLAMA_MODEL       path to GGUF model
#   LLAMA_PORT        server port (default: 8080)
#   LLAMA_GPU_LAYERS  -ngl value; auto-detected if not set
#   LLAMA_FLASH_ATTN  1 or 0 (default: 1)
#   LLAMA_LOG_FILE    server log path (default: /tmp/llama-server.log)
#   LLAMA_CTX_WARN    KV fill ratio that triggers a warning  (default: 0.75)
#   LLAMA_CTX_ESCALATE  KV fill ratio that triggers tier escalation (default: 0.88)
#   LLAMA_POLL_INTERVAL  seconds between /slots polls (default: 8)
#   LLAMA_MAX_TIER    highest tier allowed before forcing summarise+restart (default: 2)
#   LLAMA_SUMMARISE_MODEL  if set, call this endpoint for context summarisation
#                          (defaults to same LLAMA_PORT server)
#   SKIP_LLAMA_MANAGER  set to 1 to disable everything (pass-through mode)

# ---------------------------------------------------------------------------
# Guard
# ---------------------------------------------------------------------------
if [ "${SKIP_LLAMA_MANAGER:-0}" = "1" ]; then
  llama_start()           { :; }
  llama_stop()            { :; }
  llama_ensure_running()  { :; }
  llama_check_escalate()  { :; }
  llama_watch()           { :; }
  return 0 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Defaults — override via env
# ---------------------------------------------------------------------------
_LM_BIN="${LLAMA_BIN:-/Users/yoda/tools/llama-cpp-turboquant/build/bin/llama-server}"
_LM_MODEL="${LLAMA_MODEL:-${HOME}/Models/keep/qwen3-coder-next/Qwen3-Coder-Next-Q4_K_M.gguf}"
_LM_PORT="${LLAMA_PORT:-8080}"
_LM_FLASH="${LLAMA_FLASH_ATTN:-1}"
_LM_LOG="${LLAMA_LOG_FILE:-/tmp/llama-server.log}"
_LM_CTX_WARN="${LLAMA_CTX_WARN:-0.75}"
_LM_CTX_ESCALATE="${LLAMA_CTX_ESCALATE:-0.88}"
_LM_POLL="${LLAMA_POLL_INTERVAL:-8}"
_LM_MAX_TIER="${LLAMA_MAX_TIER:-2}"

# State files (co-located with this script or /tmp if sourced from elsewhere)
_LM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "/tmp")"
_LM_PID_FILE="${_LM_DIR}/.llama-server.pid"
_LM_TIER_FILE="${_LM_DIR}/.llama-tier"
_LM_SIGNAL_FILE="${_LM_DIR}/.ctx_escalate"   # ralph.sh checks this between iterations
_LM_WATCH_PID_FILE="${_LM_DIR}/.llama-watch.pid"

# ---------------------------------------------------------------------------
# Architecture detection
# Determines: gpu_layers, parallel slot count, cache strategy hint
# ---------------------------------------------------------------------------
_lm_detect_arch() {
  # Already overridden
  if [ -n "${LLAMA_GPU_LAYERS:-}" ]; then
    _LM_GPU_LAYERS="$LLAMA_GPU_LAYERS"
    _LM_ARCH="custom"
    return
  fi

  _LM_ARCH="cpu"
  _LM_GPU_LAYERS=0

  # NVIDIA CUDA
  if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
    _LM_ARCH="cuda"
    _LM_GPU_LAYERS=99
    # Rough VRAM headroom hint (used by tier config below)
    _LM_VRAM_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ' || echo 0)
    return
  fi

  # Apple Silicon (Metal)
  if [ "$(uname -s)" = "Darwin" ] && sysctl -n hw.optional.arm64 2>/dev/null | grep -q 1; then
    _LM_ARCH="apple_silicon"
    _LM_GPU_LAYERS=99
    _LM_VRAM_MB=$(( $(sysctl -n hw.memsize 2>/dev/null || echo 0) / 1048576 ))
    return
  fi

  # ROCm / AMD
  if command -v rocm-smi &>/dev/null && rocm-smi &>/dev/null; then
    _LM_ARCH="rocm"
    _LM_GPU_LAYERS=99
    return
  fi

  echo "  [llama-manager] No GPU detected — running CPU-only (set LLAMA_GPU_LAYERS to override)" >&2
}

# ---------------------------------------------------------------------------
# Tier definitions
# Derived from benchmark results (apple-silicon turbo/f16 runs, April 2026).
# Override by setting LLAMA_TIER_1_* / LLAMA_TIER_2_* env vars.
#
# Tier 1: f16 KV, 131072 ctx — fastest decode (~34 tok/s on M4 Pro)
# Tier 2: turbo KV, 196608 ctx — slower (~5 tok/s) but 2 GB lighter at peak
#          turbo wins on CUDA because VRAM is discrete; see notes at bottom.
# ---------------------------------------------------------------------------
_lm_tier_args() {
  local tier="${1:-1}"

  # Allow full override via env
  local ctx_var="LLAMA_TIER_${tier}_CTX"
  local batch_var="LLAMA_TIER_${tier}_BATCH"
  local ubatch_var="LLAMA_TIER_${tier}_UBATCH"
  local kvk_var="LLAMA_TIER_${tier}_CACHE_K"
  local kvv_var="LLAMA_TIER_${tier}_CACHE_V"

  case "$tier" in
    1)
      local ctx="${!ctx_var:-131072}"
      local batch="${!batch_var:-1024}"
      local ubatch="${!ubatch_var:-128}"
      local cache_k="${!kvk_var:-f16}"
      local cache_v="${!kvv_var:-f16}"
      ;;
    2)
      local ctx="${!ctx_var:-196608}"
      local batch="${!batch_var:-512}"
      local ubatch="${!ubatch_var:-128}"
      # CUDA: turbo pays off more (discrete VRAM cliff) — use turbo4 if arch is cuda
      # Apple Silicon: turbo3 is the sweet spot from benchmarks
      local default_kv="turbo3"
      [ "${_LM_ARCH:-}" = "cuda" ] && default_kv="turbo4"
      local cache_k="${!kvk_var:-$default_kv}"
      local cache_v="${!kvv_var:-$default_kv}"
      ;;
    *)
      echo "  [llama-manager] Unknown tier $tier" >&2
      return 1
      ;;
  esac

  # Emit as array-style string for eval
  printf -- "--ctx-size %s --batch-size %s --ubatch-size %s --cache-type-k %s --cache-type-v %s" \
    "$ctx" "$batch" "$ubatch" "$cache_k" "$cache_v"
}

# ---------------------------------------------------------------------------
# Start server at a given tier
# ---------------------------------------------------------------------------
llama_start() {
  local tier="${1:-1}"

  _lm_detect_arch

  if llama_is_running; then
    echo "  [llama-manager] Server already running (PID $(cat "$_LM_PID_FILE")). Use llama_stop first." >&2
    return 0
  fi

  local tier_args
  tier_args="$(_lm_tier_args "$tier")" || return 1

  echo "  [llama-manager] Starting Tier $tier server (arch: ${_LM_ARCH}) on port ${_LM_PORT}" >&2
  echo "  [llama-manager] Args: $tier_args" >&2

  # shellcheck disable=SC2086
  "$_LM_BIN" \
    -m "$_LM_MODEL" \
    --port "$_LM_PORT" \
    --n-gpu-layers "$_LM_GPU_LAYERS" \
    --flash-attn "$_LM_FLASH" \
    --jinja \
    $tier_args \
    --log-disable \
    >> "$_LM_LOG" 2>&1 &

  local pid=$!
  echo "$pid"         > "$_LM_PID_FILE"
  echo "$tier"        > "$_LM_TIER_FILE"
  rm -f "$_LM_SIGNAL_FILE"

  echo "  [llama-manager] Server PID $pid — waiting for health..." >&2
  _lm_wait_healthy 30 || {
    echo "  [llama-manager] ❌ Server did not become healthy. Check $_LM_LOG" >&2
    llama_stop
    return 1
  }
  echo "  [llama-manager] ✅ Server healthy (Tier $tier)" >&2
}

# ---------------------------------------------------------------------------
# Stop server
# ---------------------------------------------------------------------------
llama_stop() {
  if [ -f "$_LM_PID_FILE" ]; then
    local pid
    pid=$(cat "$_LM_PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      echo "  [llama-manager] Stopping server (PID $pid)..." >&2
      kill "$pid" 2>/dev/null || true
      # Give it up to 10s to exit cleanly
      local i=0
      while kill -0 "$pid" 2>/dev/null && [ $i -lt 10 ]; do
        sleep 1; i=$((i+1))
      done
      kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$_LM_PID_FILE"
  fi

  # Stop watchdog if running
  if [ -f "$_LM_WATCH_PID_FILE" ]; then
    local wpid
    wpid=$(cat "$_LM_WATCH_PID_FILE")
    kill "$wpid" 2>/dev/null || true
    rm -f "$_LM_WATCH_PID_FILE"
  fi
}

# ---------------------------------------------------------------------------
# Check if server process is alive
# ---------------------------------------------------------------------------
llama_is_running() {
  [ -f "$_LM_PID_FILE" ] && kill -0 "$(cat "$_LM_PID_FILE")" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Start if not already running
# ---------------------------------------------------------------------------
llama_ensure_running() {
  local tier="${1:-1}"
  if ! llama_is_running; then
    llama_start "$tier"
  fi
}

# ---------------------------------------------------------------------------
# Wait for /health to return 200
# ---------------------------------------------------------------------------
_lm_wait_healthy() {
  local max_attempts="${1:-30}"
  local i=0
  while [ $i -lt "$max_attempts" ]; do
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" \
      "http://localhost:${_LM_PORT}/health" 2>/dev/null || echo "000")
    if [ "$status" = "200" ]; then
      return 0
    fi
    sleep 2
    i=$((i+1))
  done
  return 1
}

# ---------------------------------------------------------------------------
# Query current KV fill ratio from /slots
# Returns a float 0.0-1.0, or "unavailable" on error
# ---------------------------------------------------------------------------
llama_ctx_fill() {
  local slots_json
  # -sf: silent + fail-on-HTTP-error; empty body → "unavailable"
  slots_json=$(curl -sf "http://localhost:${_LM_PORT}/slots" 2>/dev/null) || true

  if [ -z "$slots_json" ]; then
    echo "unavailable"
    return 0
  fi

  # Pass JSON via env var to avoid any stdin/pipe/echo quoting edge cases.
  # Single python3 call with try/except — all errors produce "unavailable".
  LLAMA_SLOTS_JSON="$slots_json" python3 - 2>/dev/null <<'PY' || echo "unavailable"
import os, json
try:
    slots = json.loads(os.environ["LLAMA_SLOTS_JSON"])
    if not isinstance(slots, list):
        raise ValueError("unexpected shape")
    active = [s for s in slots if isinstance(s, dict) and
              (s.get("is_processing") or s.get("n_ctx_used", 0) > 0)]
    pool = active if active else [s for s in slots if isinstance(s, dict)]
    if not pool:
        print("0.0")
    else:
        ratios = [s.get("n_ctx_used", 0) / max(s.get("n_ctx", 1), 1) for s in pool]
        print(f"{sum(ratios) / len(ratios):.4f}")
except Exception:
    print("unavailable")
PY
}

# ---------------------------------------------------------------------------
# Escalate: stop current server, start at next tier
# If already at max tier, trigger context summarisation instead
# ---------------------------------------------------------------------------
llama_escalate() {
  local current_tier=1
  [ -f "$_LM_TIER_FILE" ] && current_tier=$(cat "$_LM_TIER_FILE")
  local next_tier=$(( current_tier + 1 ))

  if [ "$next_tier" -gt "$_LM_MAX_TIER" ]; then
    echo "  [llama-manager] Already at max tier ($_LM_MAX_TIER). Triggering context summarisation." >&2
    _lm_summarise_and_restart "$current_tier"
    return $?
  fi

  echo "  [llama-manager] 📈 Escalating Tier $current_tier → Tier $next_tier" >&2
  llama_stop
  sleep 1
  llama_start "$next_tier"
  rm -f "$_LM_SIGNAL_FILE"
}

# ---------------------------------------------------------------------------
# Summarise + restart at Tier 1
# Calls the running server to produce a dense summary of recent context,
# writes it to a "context carry-forward" file that CLAUDE.md/prompt.md
# can inject as a prefix on the next iteration.
# ---------------------------------------------------------------------------
_lm_summarise_and_restart() {
  local restart_tier="${1:-1}"
  local carry_file="${_LM_DIR}/.ctx_summary.md"
  local summarise_port="${LLAMA_SUMMARISE_PORT:-$_LM_PORT}"

  echo "  [llama-manager] 📝 Requesting context summary before restart..." >&2

  # Best-effort — if the server is too full to respond, skip summarisation
  local summary raw_resp
  raw_resp=$(curl -sf -m 60 \
    -H "Content-Type: application/json" \
    -d '{
      "model": "local",
      "max_tokens": 600,
      "messages": [
        {
          "role": "system",
          "content": "You are a concise technical summariser. Reply only with the summary, no preamble."
        },
        {
          "role": "user",
          "content": "Summarise the work done in this session in under 500 tokens. Focus on: (1) which story was in progress, (2) files changed, (3) any blockers or open questions. This will be injected as context into the next agent iteration."
        }
      ]
    }' \
    "http://localhost:${summarise_port}/v1/chat/completions" 2>/dev/null) || raw_resp=""

  summary=""
  if [ -n "$raw_resp" ]; then
    summary=$(LLAMA_RESP="$raw_resp" python3 - 2>/dev/null <<'PY' || true
import os, json
try:
    d = json.loads(os.environ["LLAMA_RESP"])
    print(d["choices"][0]["message"]["content"])
except Exception:
    pass
PY
  )
  fi

  if [ -n "$summary" ]; then
    printf '## Context carry-forward (auto-summarised before server restart)\n\n%s\n\n---\n\n' "$summary" > "$carry_file"
    echo "  [llama-manager] Summary saved to $carry_file" >&2
  else
    echo "  [llama-manager] ⚠️  Summarisation failed or timed out — restarting without carry-forward." >&2
    rm -f "$carry_file"
  fi

  llama_stop
  sleep 1
  llama_start "$restart_tier"
  rm -f "$_LM_SIGNAL_FILE"
}

# ---------------------------------------------------------------------------
# Check signal file and escalate if set — call this from ralph.sh
# between iterations (safe: no-ops if server is not managed here)
# ---------------------------------------------------------------------------
llama_check_escalate() {
  if [ -f "$_LM_SIGNAL_FILE" ]; then
    echo "  [llama-manager] 🚦 Escalation signal detected." >&2
    llama_escalate
  fi
}

# ---------------------------------------------------------------------------
# Background watchdog — polls /slots and writes signal file when fill is high
# Designed to run as a background job:   llama_watch &
# ---------------------------------------------------------------------------
llama_watch() {
  echo $$ > "$_LM_WATCH_PID_FILE"
  echo "  [llama-manager] 👁  Watchdog started (PID $$, polling every ${_LM_POLL}s)" >&2

  while true; do
    sleep "$_LM_POLL"

    if ! llama_is_running; then
      echo "  [llama-manager] Watchdog: server not running, exiting." >&2
      rm -f "$_LM_WATCH_PID_FILE"
      return 0
    fi

    local fill
    fill=$(llama_ctx_fill)

    if [ "$fill" = "unavailable" ]; then
      continue
    fi

    # Compare with python (bash can't do float comparison reliably).
    # Values injected via env to avoid inline quoting / injection issues.
    local action
    action=$(LM_FILL="$fill" LM_WARN="$_LM_CTX_WARN" LM_ESC="$_LM_CTX_ESCALATE" \
      python3 - 2>/dev/null <<'PY' || true
import os
try:
    fill = float(os.environ["LM_FILL"])
    warn = float(os.environ["LM_WARN"])
    esc  = float(os.environ["LM_ESC"])
    pct  = int(fill * 100)
    if fill >= esc:
        print(f"ESCALATE {pct}")
    elif fill >= warn:
        print(f"WARN {pct}")
    else:
        print(f"OK {pct}")
except Exception:
    print("OK 0")
PY
    )
    [ -z "$action" ] && continue

    local state="${action%% *}"
    local pct="${action##* }"

    case "$state" in
      ESCALATE)
        echo "  [llama-manager] ⚠️  KV fill ${pct}% ≥ escalate threshold — writing signal." >&2
        touch "$_LM_SIGNAL_FILE"
        ;;
      WARN)
        echo "  [llama-manager] 🟡 KV fill ${pct}% — approaching limit." >&2
        ;;
      OK)
        # Uncomment to see fill each poll:
        # echo "  [llama-manager] KV fill ${pct}%" >&2
        ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Status summary — human-readable
# ---------------------------------------------------------------------------
llama_status() {
  echo ""
  echo "=== llama-manager status ==="
  if llama_is_running; then
    local pid tier fill
    pid=$(cat "$_LM_PID_FILE")
    tier=$(cat "$_LM_TIER_FILE" 2>/dev/null || echo "?")
    fill=$(llama_ctx_fill)
    echo "  Server  : running (PID $pid)"
    echo "  Tier    : $tier"
    echo "  KV fill : $fill"
    echo "  Port    : $_LM_PORT"
    echo "  Log     : $_LM_LOG"
    [ -f "$_LM_SIGNAL_FILE" ] && echo "  Signal  : ESCALATE PENDING"
  else
    echo "  Server  : stopped"
  fi
  [ -f "$_LM_WATCH_PID_FILE" ] && echo "  Watchdog: running (PID $(cat "$_LM_WATCH_PID_FILE"))" || echo "  Watchdog: stopped"
  echo "==========================="
  echo ""
}

# ---------------------------------------------------------------------------
# Standalone entrypoint (when executed directly rather than sourced)
# Usage: ./llama-manager.sh start|stop|status|escalate|watch
# ---------------------------------------------------------------------------
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  _lm_detect_arch
  case "${1:-status}" in
    start)    llama_start "${2:-1}" ;;
    stop)     llama_stop ;;
    restart)  llama_stop; sleep 1; llama_start "${2:-1}" ;;
    escalate) llama_escalate ;;
    watch)    llama_watch ;;
    status)   llama_status ;;
    fill)     llama_ctx_fill ;;
    *)
      echo "Usage: $0 {start [tier]|stop|restart [tier]|escalate|watch|status|fill}"
      exit 1
      ;;
  esac
fi
