#!/bin/bash

_src="${BASH_SOURCE[0]}"
while [ -L "$_src" ]; do
  _dir="$(cd -P "$(dirname "$_src")" && pwd)"
  _src="$(readlink "$_src")"
  [[ "$_src" != /* ]] && _src="$_dir/$_src"
done
SCRIPT_DIR="$(cd -P "$(dirname "$_src")" && pwd)"
unset _src _dir
CURRENT_DIR="$(pwd)"
WORKER_SCRIPT="$HOME/.claude/plugins/marketplaces/thedotmack/plugin/scripts/worker-service.cjs"

# Workspace: first configured workspace that is a prefix of current dir, else current dir
WORKSPACE="$CURRENT_DIR"
while IFS= read -r dir; do
  dir="${dir/#\~/$HOME}"
  if [[ "$CURRENT_DIR" == "$dir"* ]]; then
    WORKSPACE="$dir"
    break
  fi
done < <(jq -r '.workspaces[]' "$SCRIPT_DIR/config.json")

CONTAINER_NAME="sbx-$(echo "$WORKSPACE" | md5 -q | head -c 8)"
SESSION_LOCK="/tmp/session.$$"


# Start claude-mem worker on host if not already running
if ! nc -z 127.0.0.1 37777 2>/dev/null && [ -f "$WORKER_SCRIPT" ]; then
  CLAUDE_MEM_WORKER_PORT=37777 bun "$WORKER_SCRIPT" &
  disown $!
  for i in $(seq 1 10); do
    nc -z 127.0.0.1 37777 2>/dev/null && break
    sleep 0.5
  done
fi

# Create or start container
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    docker start "$CONTAINER_NAME"
  else
    docker run -d \
      --name "$CONTAINER_NAME" \
      --add-host=host.docker.internal:host-gateway \
      --cap-add NET_ADMIN \
      -v "$WORKSPACE":"$WORKSPACE" \
      -v "$HOME/.claude:/root/.claude" \
      -v "$HOME/.claude-mem:/root/.claude-mem" \
      -v "$HOME/.m2:/root/.m2" \
      -e TZ="$(readlink /etc/localtime | sed 's|.*/zoneinfo/||')" \
      -e ELASTIC_API_KEY \
      -e KIBANA_URL \
      -e KIBANA_QA_API_KEY \
      -e KIBANA_QA_URL \
      -e KIBANA_PROD_API_KEY \
      -e KIBANA_PROD_URL \
      sbx \
      sleep infinity
  fi
  docker exec "$CONTAINER_NAME" sh -c 'rm -f /tmp/session.*' 2>/dev/null
fi

# Symlink host paths so plugin installPaths resolve correctly inside container
docker exec -u root "$CONTAINER_NAME" bash -c "
  mkdir -p "$HOME"
  ln -sfn /root/.claude "$HOME/.claude"
  ln -sfn /root/.claude-mem "$HOME/.claude-mem"
  ln -sfn /root/.claude/claude_.json /root/.claude.json
"

# Restrict outbound to host gateway to allowed ports only
docker exec -u root "$CONTAINER_NAME" sh -c '
  HOST_GW=$(ip route show default | awk "/default/ {print \$3}")
  for PORT in 9090 9091 37777; do
    iptables -C OUTPUT -d "$HOST_GW" -p tcp --dport "$PORT" -j ACCEPT 2>/dev/null || \
      iptables -A OUTPUT -d "$HOST_GW" -p tcp --dport "$PORT" -j ACCEPT
  done
  iptables -C OUTPUT -d "$HOST_GW" -j DROP 2>/dev/null || \
    iptables -A OUTPUT -d "$HOST_GW" -j DROP
'

# Forward allowed ports so localhost:PORT inside container reaches host
for PORT in 9090 9091 37777; do
  docker exec -d "$CONTAINER_NAME" sh -c \
    "ss -tlnp | grep -q :${PORT} || socat TCP-LISTEN:${PORT},fork,reuseaddr TCP:host.docker.internal:${PORT}" 2>/dev/null || true
done

# Register session, attach, and clean up on exit
docker exec -it -e TERM -e COLORTERM -w "$CURRENT_DIR" "$CONTAINER_NAME" bash -c "
  echo '$CURRENT_DIR' > '$SESSION_LOCK'
  trap 'rm -f $SESSION_LOCK; [ \$(ls /tmp/session.* 2>/dev/null | wc -l | tr -d \" \") -eq 0 ] && kill 1' EXIT
  claude --dangerously-skip-permissions
"
