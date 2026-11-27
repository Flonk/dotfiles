command=$(jq -r '.tool_input.command // ""')
bare="[A-Za-z0-9_.,:@%+=/-]+"
single="'[^']*'"
double='"[^"$`\\]*"'
if [[ "$command" =~ ^t3os\ twitch\ [a-z]+(\ +($bare|$single|$double))*\ *$ ]]; then
  exit 0
fi
jq -n '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: "Only a single t3os twitch command is allowed, with arguments as plain words, single-quoted strings or double-quoted strings without $, backticks or backslashes."}}'
