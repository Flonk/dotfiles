command=$(jq -r '.tool_input.command // ""')
bare="[A-Za-z0-9_.,:@%+=/-]+"
single="'[^']*'"
double='"[^"$`\\]*"'
for prefix in "$@"; do
  head=${prefix// /\\ }
  if [[ "$command" =~ ^$head(\ +($bare|$single|$double))*\ *$ ]]; then
    exit 0
  fi
done
jq -n --arg allowed "$(printf '%s, ' "$@")" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: ("Only a single command starting with one of: " + ($allowed | rtrimstr(", ")) + " is allowed, with arguments as plain words, single-quoted strings or double-quoted strings without $, backticks or backslashes.")}}'
