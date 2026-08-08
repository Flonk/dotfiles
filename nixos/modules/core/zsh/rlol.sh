# lol / rlol — pretty git log, sourced from zshrc.sh

export LOL_FULL_NAME=${LOL_FULL_NAME:-0}

# own path, so fzf's resize binding can re-source us in a child shell
_LOL_FILE=${${(%):-%x}:A}

_lol_scan() {
  local dir="$1" want_tips="$2" nm="${1##*/}"

  # branch tips replace the hash, but only when logging a single repo
  [[ -n $want_tips ]] && git -C "$dir" show-ref 2>/dev/null | awk -v r="$nm" '
    $2 ~ /^refs\/(heads|remotes\/origin)\/(main|master|develop)$/ {
      n = split($2, p, "/")
      printf "T|%s|%s=%s\n", r, $1, p[n]
    }'
  git -C "$dir" log --no-merges --date=iso-local \
    --pretty=format:"%ad|$nm|%h|%an|%ae|%s" 2>/dev/null
  echo
}

# lol — pretty git log. inside a repo: every commit, author column, no repo
# column. outside one: every repo below <dir>, repo column, only my commits.
lol() {
  local root me mail ticket all branch label header top data rc render
  local after before span
  local repo_mode=0 filter=1 gitdir
  # read back by _lol_render, which fzf re-runs on resize
  local -x _LOL_TICKET _LOL_COLS _LOL_SHOW_REPO=1 _LOL_SHOW_AUTHOR=0

  usage() {
    cat <<EOF
usage: lol [options] [dir]

options:
  --author <NAME|EMAIL|all>  who counts as you (highlighted); outside a repo
                             also filters to them. "all" shows everyone and
                             brings back the author column
  --ticket <TICKET>          override detected ticket (PROJECTKEY-NUMBER)
  --after <yyyy-MM-dd>       only commits on or after this day
  --before <yyyy-MM-dd>      only commits on or before this day
  --help                     show this help

in a git repo: every commit, author column, no repo column
elsewhere:     every repo below <dir>, repo column, only your commits

examples:
  lol
  lol --author all
  lol ~/repos
  lol --author "Florian Schindler" ~/repos
  lol --ticket ABC-123
  lol --after 2026-07-01 --before 2026-07-31
EOF
  }

  while [ $# -gt 0 ]; do
    case "$1" in
      --author) me="$2"; mail="$2"; shift 2 ;;
      --ticket) ticket="$2"; shift 2 ;;
      --after) after="$2"; shift 2 ;;
      --before) before="$2"; shift 2 ;;
      --help) usage; return 0 ;;
      -*) echo "unknown option: $1" >&2; usage; return 1 ;;
      *) root="$1"; shift ;;
    esac
  done

  root="${root:-.}"
  [[ -d $root ]] || { echo "no such directory: $root" >&2; return 1 }
  [[ ${me:l} == all ]] && { all=1; me=""; mail="" }

  local iso='[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
  for span in "$after" "$before"; do
    [[ -z $span || $span == ${~iso} ]] || {
      echo "dates must be yyyy-MM-dd, got: $span" >&2
      return 1
    }
  done
  [[ -n $after && -n $before && $after > $before ]] && {
    echo "--after $after is later than --before $before" >&2
    return 1
  }

  git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 && repo_mode=1
  (( repo_mode )) && { _LOL_SHOW_REPO=0; _LOL_SHOW_AUTHOR=1 }
  [[ -n $all ]] && _LOL_SHOW_AUTHOR=1
  { (( repo_mode )) || [[ -n $all ]] } && filter=0

  if [[ -z $me && -z $mail ]]; then
    me="$(git -C "$root" config user.name 2>/dev/null)"
    mail="$(git -C "$root" config user.email 2>/dev/null)"
    if (( ! repo_mode )) && [[ -z $all && -z $me && -z $mail ]]; then
      echo "could not determine author (set git user.name / user.email, or pass --author)" >&2
      return 1
    fi
  fi

  if (( repo_mode )); then
    top="$(git -C "$root" rev-parse --show-toplevel)"
    label="${top##*/}"
    branch="$(git -C "$root" symbolic-ref --short HEAD 2>/dev/null)"
    : "${ticket:=$(echo "$branch" | grep -oE '[A-Z]+-[0-9]+')}"
    header="$label${branch:+ ($branch)} · all commits${ticket:+ · $ticket}"
  elif [[ -n $all ]]; then
    header="${${root:A}/#$HOME/~} · all commits, every repo below"
  else
    header="${${root:A}/#$HOME/~} · commits for ${me:-$mail}, every repo below"
  fi
  if [[ -n $after && -n $before ]]; then
    header+=" · $after…$before"
  elif [[ -n $after ]]; then
    header+=" · since $after"
  elif [[ -n $before ]]; then
    header+=" · until $before"
  fi
  _LOL_TICKET=$ticket
  _LOL_COLS=$COLUMNS
  [[ $_LOL_COLS == <20-> ]] || _LOL_COLS=${$( { stty size </dev/tty } 2>/dev/null )##* }
  [[ $_LOL_COLS == <20-> ]] || _LOL_COLS=100
  data=$(mktemp)

  {
    if (( repo_mode )); then
      _lol_scan "$top" 1
    else
      find "$root" -type d -name .git -prune 2>/dev/null | while read -r gitdir; do
        _lol_scan "${gitdir%/.git}"
      done
    fi
  } | awk -F'|' -v me="$me" -v mail="$mail" -v filter="$filter" \
                -v after="$after" -v before="$before" '
    function lower(s){ return tolower(s) }
    function trim(s){ sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }

    BEGIN {
      me_l = lower(trim(me))
      mail_l = lower(trim(mail))
      n = split(me_l, p, /[[:space:]]+/)
      two = (n == 2)
      if (two) {
        r1 = p[1] ".*[[:space:]]*" p[2]
        r2 = p[2] ".*[[:space:]]*" p[1]
      }
    }

    $1 == "T" { print "T\t" $2 "\t" $3; next }

    {
      if (NF < 6) next
      date_raw=$1; repo=$2; hash=$3; author=$4; email=$5

      # yyyy-MM-dd window, both ends inclusive
      day = substr(date_raw, 1, 10)
      if (after != "" && day < after) next
      if (before != "" && day > before) next

      # subject may contain "|" — rejoin fields 6..NF
      subj=$6
      for (i=7; i<=NF; i++) subj = subj "|" $i

      a_l = lower(trim(author))
      e_l = lower(trim(email))
      is_me = 0
      if (mail_l != "" && e_l == mail_l) is_me = 1
      else if (me_l != "") {
        if (two) is_me = (a_l ~ r1 || a_l ~ r2)
        else     is_me = (a_l == me_l)
      }
      if (filter && !is_me) next

      # trim seconds + timezone: "2024-01-13 14:30:45 +0100" -> "2024-01-13 14:30"
      sub(/:[0-9][0-9] [+-][0-9]+$/, "", date_raw)

      print "C\t" date_raw "\t" repo "\t" hash "\t" author "\t" is_me "\t" subj
    }
  ' | sort -r > "$data"

  # fzf owns the list: it renders it at start and again on every resize, so the
  # breakpoints follow the window instead of freezing at launch width
  render="zsh -c 'source ${(q)_LOL_FILE}; _lol_render ${(q)data}'"
  {
    fzf --ansi --reverse --header "$header" </dev/null \
        --bind "start:reload($render)" \
        --bind "resize:reload($render)"
    rc=$?
  } always {
    rm -f "$data"
  }
  return $rc
}

# render the collected data at the current width; fzf sets FZF_COLUMNS on
# resize, _LOL_COLS carries the launch width for the first pass
_lol_render() {
  local cols=$FZF_COLUMNS
  [[ $cols == <20-> ]] || cols=$_LOL_COLS
  [[ $cols == <20-> ]] || cols=100

  awk -F'\t' -v cols="$cols" -v tk="$_LOL_TICKET" -v full_name="$LOL_FULL_NAME" \
             -v show_repo="$_LOL_SHOW_REPO" -v show_author="$_LOL_SHOW_AUTHOR" '
    function lower(s){ return tolower(s) }
    function trim(s){ sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    function tc(w){ return (w == tolower(w)) ? toupper(substr(w,1,1)) tolower(substr(w,2)) : w }
    function namefmt(s, full,   n, p, first, last, i, out) {
      s = trim(s)
      if (index(s, "@")) {
        s = substr(s, 1, index(s, "@") - 1)
        gsub(/[._+-]+/, " ", s)
        gsub(/[0-9]+/, "", s)
      } else if (index(s, ",")) {
        last = trim(substr(s, 1, index(s, ",") - 1))
        first = trim(substr(s, index(s, ",") + 1))
        s = first " " last
      } else if (s !~ /[[:space:]]/) {
        gsub(/[._]+/, " ", s)
      }
      n = split(trim(s), p, /[[:space:]]+/)
      if (n == 0) return ""
      if (!full) return tc(p[1])
      out = tc(p[1])
      for (i = 2; i <= n; i++) out = out " " tc(p[i])
      return out
    }
    function gam(c) {
      if (c <= 0) return 0
      if (c >= 1) return 1
      return (c <= 0.0031308) ? 12.92 * c : 1.055 * exp(log(c) / 2.4) - 0.055
    }
    function oklch(L, C, H,   a, b, l_, m_, s_, l, m, s, r, g, bb) {
      H = H * 3.14159265358979 / 180
      a = C * cos(H); b = C * sin(H)
      l_ = L + 0.3963377774 * a + 0.2158037573 * b
      m_ = L - 0.1055613458 * a - 0.0638541728 * b
      s_ = L - 0.0894841775 * a - 1.2914855480 * b
      l = l_ * l_ * l_; m = m_ * m_ * m_; s = s_ * s_ * s_
      r =  4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
      g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
      bb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
      return sprintf("\033[38;2;%d;%d;%dm", \
        int(gam(r) * 255 + 0.5), int(gam(g) * 255 + 0.5), int(gam(bb) * 255 + 0.5))
    }
    # ticket keys, only when followed by a space, a colon or the end of the line
    function hl(s, restore,   out, nxt) {
      out = ""
      while (match(s, /[A-Z0-9]+-[0-9]+/)) {
        nxt = substr(s, RSTART + RLENGTH, 1)
        if (nxt == "" || nxt == " " || nxt == ":")
          out = out substr(s, 1, RSTART-1) "\033[1m" tk_color substr(s, RSTART, RLENGTH) "\033[0m" restore
        else
          out = out substr(s, 1, RSTART + RLENGTH - 1)
        s = substr(s, RSTART+RLENGTH)
      }
      return out s
    }
    # conventional-commit prefix; leaves the rest of the subject in label_rest
    function labelfmt(s, restore,   m, type, scope, lc, color) {
      label_rest = s
      if (!match(s, /^[A-Za-z]+(\([^)]*\))?:/)) return ""
      m = substr(s, 1, RLENGTH - 1)
      type = m
      if (index(m, "(")) {
        type = substr(m, 1, index(m, "(") - 1)
        scope = substr(m, index(m, "(") + 1, length(m) - index(m, "(") - 1)
      }
      lc = tolower(type)
      if (tolower(scope) ~ /dep/)                 color = brown
      else if (lc == "fix")                       color = red
      else if (lc == "chore")                     color = brown
      else if (lc == "feat" || lc == "feature")   color = green
      else return ""
      label_rest = substr(s, RLENGTH)
      return color m "\033[0m" restore
    }
    function trunc(s, w) { return length(s) > w ? substr(s, 1, w - 1) "…" : s }
    # breakpoints: pick the first row the terminal is wide enough for.
    # every size-dependent number lives in this table — add a field here
    # (and read it out below) to make something else shrink with the window.
    #
    #   min cols | date width | repo cap | author cap
    # date width doubles as the format: 16 full, 10 date only, 5 month-day
    function datefmt(s, w) {
      if (w >= 16) return substr(s, 1, 16)
      if (w >= 10) return substr(s, 1, 10)
      return substr(s, 6, 5)
    }
    function breakpoint(c,   i, f) {
      for (i = 1; i <= nbp; i++) {
        split(bp[i], f, " ")
        if (c >= f[1] + 0) { bp_date = f[2] + 0; bp_repo = f[3] + 0; bp_auth = f[4] + 0; return }
      }
    }

    BEGIN {
      nbp = split("150 16 32 16;" \
                  "120 16 24 16;" \
                  "100 16 20 14;" \
                  " 80  5 16 10;" \
                  " 60  5 12  8;" \
                  "  0  5  8  6", bp, ";")

      white = "\033[38;2;255;255;255m"
      repo_color = "\033[35m"
      hash_base = "\033[33m"
      red = "\033[31m"
      green = "\033[32m"
      date_color = green
      brown = oklch(0.66, 0.09, 50)
      me_color = red
      tk_color = oklch(0.798, 0.106, 250)
      aw_max = full_name ? 20 : 10
      if (cols < 40) cols = 40
    }

    $1 == "T" { tipmap[$2] = tipmap[$2] $3 ";"; next }

    {
      n++
      date[n]=$2; repo[n]=$3; hash[n]=$4; mine[n]=$6; subj[n]=$7
      # subject may contain a tab — rejoin fields 7..NF
      for (i = 8; i <= NF; i++) subj[n] = subj[n] "\t" $i
      auth[n] = show_author ? namefmt($5, full_name) : ""
      if (length($3) > rw) rw = length($3)
      if (length($4) > hw) hw = length($4)
      if (length(auth[n]) > aw) aw = length(auth[n])
    }

    END {
      breakpoint(cols)
      # columns size to their content, then get clamped by the breakpoint
      if (aw > aw_max) aw = aw_max
      if (aw > bp_auth) aw = bp_auth
      if (rw > bp_repo) rw = bp_repo
      datew = bp_date
      # chrome: hash + date + 3 spaces + border + fzf pointer gutter
      room = cols - hw - datew - 7 - (show_repo ? rw + 1 : 0) - (show_author ? aw + 1 : 0)
      # still cramped (long hashes, tiny window): claw back from the repo column
      if (room < 24 && show_repo) {
        grab = 24 - room
        if (grab > rw - 6) grab = rw - 6
        if (grab > 0) rw -= grab
      }

      border = "\033[1;90m│\033[0m"
      for (i = 1; i <= n; i++) {
        is_me = (mine[i] == 1)
        bold = (tk != "" && index(subj[i], tk)) ? "\033[1m" : ""

        # a commit sitting on main/master/develop shows the branch instead of the hash
        hash_out = hash[i]
        hash_color = hash_base
        ntips = split(tipmap[repo[i]], tp, ";")
        for (j = 1; j <= ntips; j++) {
          if (tp[j] == "") continue
          sha = substr(tp[j], 1, index(tp[j], "=") - 1)
          if (substr(sha, 1, length(hash[i])) == hash[i]) {
            hash_out = substr(tp[j], index(tp[j], "=") + 1)
            hash_color = "\033[1m" tk_color
            break
          }
        }

        line = ""
        if (show_repo)
          line = line sprintf("%s%-" rw "s\033[0m ", repo_color, trunc(repo[i], rw))
        line = line sprintf("%s%s%-" hw "s\033[0m%s ", bold, hash_color, trunc(hash_out, hw), bold)
        line = line sprintf("%s%s%s\033[0m%s ", bold, date_color, datefmt(date[i], datew), bold)
        if (show_author)
          line = line sprintf("%s%s%" aw "s\033[0m%s ", bold, (is_me ? me_color : white), trunc(auth[i], aw), bold)
        # full subject: fzf trims it to the live width too
        msg = bold white
        pre = labelfmt(subj[i], msg)
        line = line border " " msg pre hl(label_rest, msg) "\033[0m"
        print line
      }
    }' "$1"
}

# rlol — same thing; lol already picks the recursive layout when you are not in a repo
rlol() { lol "$@" }
