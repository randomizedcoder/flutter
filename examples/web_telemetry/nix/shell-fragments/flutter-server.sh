# Flutter web server lifecycle functions
# Expects global variables: PORT, FLUTTER_PID, FLUTTER_LOG

flutter_cleanup() {
  if [ -n "$FLUTTER_PID" ]; then
    kill "$FLUTTER_PID" 2>/dev/null || true
    sleep 1
    kill -0 "$FLUTTER_PID" 2>/dev/null && kill -9 "$FLUTTER_PID" 2>/dev/null || true
    wait "$FLUTTER_PID" 2>/dev/null || true

    RETRIES=0
    while lsof -ti :"$PORT" >/dev/null 2>&1; do
      if [ "$RETRIES" -eq 0 ]; then
        echo "Port $PORT still in use, killing remaining processes ..." >&2
      fi
      lsof -ti :"$PORT" 2>/dev/null | xargs -r kill -9 2>/dev/null || true
      sleep 1
      RETRIES=$((RETRIES + 1))
      if [ "$RETRIES" -ge 5 ]; then
        echo "WARNING: Could not free port $PORT after ${RETRIES}s" >&2
        break
      fi
    done

    if ! lsof -ti :"$PORT" >/dev/null 2>&1; then
      echo "Port $PORT is free" >&2
    fi
  fi

  [ -f "$FLUTTER_LOG" ] && rm -f "$FLUTTER_LOG"
}

check_port_free() {
  if curl -s -o /dev/null "http://localhost:$PORT" 2>/dev/null; then
    echo "ERROR: Port $PORT is already in use." >&2
    echo "Kill the existing process first: lsof -ti :$PORT | xargs kill" >&2
    exit 1
  fi
}

start_flutter_server() {
  FLUTTER_LOG=$(mktemp /tmp/flutter-XXXXXX.log)
  echo "Starting Flutter web server (port $PORT) ..." >&2
  flutter run -d web-server \
    --web-port "$PORT" \
    --machine \
    "${FLUTTER_EXTRA_ARGS[@]}" \
    > "$FLUTTER_LOG" 2>&1 &
  FLUTTER_PID=$!
}

wait_for_flutter() {
  local ELAPSED=0
  local TIMEOUT=180
  while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
    if grep -q '"app.started"' "$FLUTTER_LOG" 2>/dev/null; then
      echo "Server started after ${ELAPSED}s" >&2
      break
    fi
    if grep -q '"app.stop"' "$FLUTTER_LOG" 2>/dev/null; then
      echo "FAIL: Flutter stopped unexpectedly" >&2
      grep 'error' "$FLUTTER_LOG" 2>/dev/null | head -5 >&2 || true
      exit 1
    fi
    sleep 2
    ELAPSED=$((ELAPSED + 2))
    if [ $((ELAPSED % 20)) -eq 0 ]; then
      echo "  ... still waiting (${ELAPSED}s)" >&2
    fi
  done

  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    echo "FAIL: Flutter did not start within ${TIMEOUT}s" >&2
    exit 1
  fi

  # Wait for HTTP to be ready
  ELAPSED=0
  while [ "$ELAPSED" -lt 30 ]; do
    if curl -s -o /dev/null "http://localhost:$PORT" 2>/dev/null; then
      break
    fi
    sleep 1
    ELAPSED=$((ELAPSED + 1))
  done
}
