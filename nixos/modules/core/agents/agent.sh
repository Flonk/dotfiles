cmd="${1:-}"
[ $# -gt 0 ] && shift
name="${1:-}"
[ $# -gt 0 ] && shift

usage() {
  cat >&2 <<'USAGE'
usage: t3os agent list
       t3os agent ask NAME MESSAGE   (stdin, if piped, is attached as untrusted context)
       t3os agent attach NAME
       t3os agent reset NAME
USAGE
  exit 2
}

if [ "$cmd" = list ]; then
  jq -r 'to_entries[] | [.key, .value.model, .value.mode, (if .value.full then "full access" else "restricted" end), .value.description] | @tsv' "$T3OS_AGENTS" | column -t -s $'\t'
  exit 0
fi

[ -n "$name" ] || usage
def=$(jq -c --arg n "$name" '.[$n] // empty' "$T3OS_AGENTS")
[ -n "$def" ] || { echo "no agent named $name (t3os agent list)" >&2; exit 1; }
mapfile -d '' -t args < <(jq -j '.args[] | ., "\u0000"' <<<"$def")
cwd=$(jq -r '.cwd' <<<"$def")
state="${XDG_STATE_HOME:-$HOME/.local/state}/t3os/agents/$name"
mkdir -p "$state" "$cwd"
export T3_AGENT T3_AGENT_MODEL T3_AGENT_ALLOW
T3_AGENT=$(jq -r '.bus' <<<"$def")
T3_AGENT_MODEL=$(jq -r '.model' <<<"$def")
T3_AGENT_ALLOW=$(jq -r '.subagents | join(" ")' <<<"$def")

session() {
  if [ -s "$state/session" ]; then
    printf '%s\n' --resume "$(cat "$state/session")"
  else
    local id
    id=$(cat /proc/sys/kernel/random/uuid)
    echo "$id" >"$state/session"
    printf '%s\n' --session-id "$id"
  fi
}

case "$cmd" in
reset)
  rm -f "$state/session"
  echo "started a fresh conversation with $name"
  ;;

attach)
  [ "$(jq -r '.mode' <<<"$def")" = headless ] || { echo "$name is a remote agent, open it from claude.ai" >&2; exit 1; }
  mapfile -t s < <(session)
  cd "$cwd" || exit 1
  exec claude "${args[@]}" "${s[@]}"
  ;;

ask)
  [ "$(jq -r '.mode' <<<"$def")" = headless ] || { echo "$name is a remote agent, message it from claude.ai" >&2; exit 1; }
  msg="$*"
  [ -n "$msg" ] || usage
  context=""
  [ -t 0 ] || context=$(cat)
  input="$msg"
  [ -z "$context" ] || input=$(printf '%s\n\n<context>\n%s\n</context>' "$msg" "$context")
  exec 9>"$state/lock"
  flock 9
  mapfile -t s < <(session)
  cd "$cwd" || exit 1
  if ! out=$(claude -p "${args[@]}" --output-format json "${s[@]}" "$input" </dev/null); then
    rm -f "$state/session"
    echo "$name failed: $(jq -r '.result // empty' <<<"$out" 2>/dev/null)" >&2
    exit 1
  fi
  jq -r '.result' <<<"$out"
  ;;

*) usage ;;
esac
