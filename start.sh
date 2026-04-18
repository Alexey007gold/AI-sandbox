#!/bin/bash

_src="${BASH_SOURCE[0]}"
while [ -L "$_src" ]; do
  _dir="$(cd -P "$(dirname "$_src")" && pwd)"; _src="$(readlink "$_src")"
  [[ "$_src" != /* ]] && _src="$_dir/$_src"
done
SCRIPT_DIR="$(cd -P "$(dirname "$_src")" && pwd)"; unset _src _dir
CURRENT_DIR="$(pwd)"
WORKER_SCRIPT="$HOME/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"

WORKSPACE="$CURRENT_DIR"
while IFS= read -r dir; do
  dir="${dir/#\~/$HOME}"
  [[ "$CURRENT_DIR" == "$dir"* ]] && WORKSPACE="$dir" && break
done < <(jq -r '.workspaces[]' "$SCRIPT_DIR/config.json")

CONTAINER_NAME="sbx-$(echo "$WORKSPACE" | md5 -q | head -c 8)"
SESSION_LOCK="/tmp/session.$$"

if ! nc -z 127.0.0.1 37777 2>/dev/null && [ -f "$WORKER_SCRIPT" ]; then
  CLAUDE_MEM_WORKER_PORT=37777 bun "$WORKER_SCRIPT" & disown $!
  for i in $(seq 50); do nc -z 127.0.0.1 37777 2>/dev/null && break || sleep 0.5; done
fi

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    docker start "$CONTAINER_NAME"
  else
    docker run -d --name "$CONTAINER_NAME" \
      --add-host=host.docker.internal:host-gateway --cap-add NET_ADMIN \
      -v "$WORKSPACE":"$WORKSPACE" \
      -v "$HOME/.claude:/root/.claude" -v "$HOME/.claude-mem:/root/.claude-mem" -v "$HOME/.m2:/root/.m2" \
      -e TZ="$(readlink /etc/localtime | sed 's|.*/zoneinfo/||')" \
      -e KIBANA_QA_API_KEY -e KIBANA_QA_URL \
      -e KIBANA_PROD_API_KEY -e KIBANA_PROD_URL \
      sbx sleep infinity
  fi
  docker exec "$CONTAINER_NAME" sh -c 'rm -f /tmp/session.*' 2>/dev/null
fi

docker exec -u root "$CONTAINER_NAME" bash -c "
  mkdir -p '$HOME'
  ln -sfn /root/.claude '$HOME/.claude'
  ln -sfn /root/.claude-mem '$HOME/.claude-mem'
  ln -sfn /root/.claude/claude_.json /root/.claude.json
"

docker exec -u root "$CONTAINER_NAME" sh -c '
  HOST_GW=$(ip route show default | awk "/default/ {print \$3}")
  for PORT in 9090 9091 37777; do
    iptables -C OUTPUT -d "$HOST_GW" -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null || \
      iptables -A OUTPUT -d "$HOST_GW" -p tcp --dport "$PORT" -j ACCEPT
  done
  iptables -C OUTPUT -d "$HOST_GW" -j DROP 2>/dev/null || iptables -A OUTPUT -d "$HOST_GW" -j DROP
'

for PORT in 9090 9091 37777; do
  docker exec -d "$CONTAINER_NAME" sh -c \
    "ss -tlnp | grep -q :${PORT} || socat TCP-LISTEN:${PORT},fork,reuseaddr TCP:host.docker.internal:${PORT}" 2>/dev/null || true
done

DOCKER_EXEC_PID=""
_stop_if_last_session() {
  trap - EXIT HUP INT TERM
  [ -n "$DOCKER_EXEC_PID" ] && kill "$DOCKER_EXEC_PID" 2>/dev/null
  # Killing docker exec client doesn't stop container-side processes; signal them directly
  docker exec "$CONTAINER_NAME" sh -c '
    for f in /tmp/session.*; do [ -f "$f" ] && kill -HUP "$(cat "$f" 2>/dev/null)" 2>/dev/null; done
  ' 2>/dev/null || true
  for _ in 1 2 3 4 5; do
    docker exec "$CONTAINER_NAME" sh -c '
      for f in /tmp/session.*; do
        [ -f "$f" ] && kill -0 "$(cat "$f" 2>/dev/null)" 2>/dev/null && exit 0
      done; exit 1
    ' 2>/dev/null || { docker stop "$CONTAINER_NAME" >/dev/null 2>&1 && echo "container stopped"; return; }
    sleep 1
  done
}
trap _stop_if_last_session EXIT HUP INT TERM

_PARENT_PID=$PPID
_SCRIPT_PID=$$

docker exec -it -e TERM -e COLORTERM -e SESSION_LOCK="$SESSION_LOCK" -e WORK_DIR="$CURRENT_DIR" \
  -w "$CURRENT_DIR" "$CONTAINER_NAME" bash -lc '
  echo '$CURRENT_DIR' > '$SESSION_LOCK'
  _cleanup() {
    trap - EXIT HUP INT TERM
    kill "$CLAUDE_PID" 2>/dev/null
    rm -f "$SESSION_LOCK"
  }
  trap _cleanup EXIT HUP INT TERM
  claude --dangerously-skip-permissions &
  CLAUDE_PID=$!
  wait $CLAUDE_PID
' </dev/tty &
DOCKER_EXEC_PID=$!

(
  while kill -0 "$_PARENT_PID" 2>/dev/null && kill -0 "$_SCRIPT_PID" 2>/dev/null; do
    sleep 3
  done
  if kill -0 "$_SCRIPT_PID" 2>/dev/null; then
    kill -HUP "$_SCRIPT_PID" 2>/dev/null
  else
    _stop_if_last_session
  fi
) &
disown $!

wait $DOCKER_EXEC_PID
