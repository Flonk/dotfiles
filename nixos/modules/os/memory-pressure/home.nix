{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.t3os.module.os.memory-pressure;

  snapshotScript = pkgs.writeShellScript "t3os-mem-snapshot.sh" ''
    set -u

    PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.gawk
        pkgs.procps
        pkgs.util-linux
        pkgs.systemd
        pkgs.kmod
        pkgs.psmisc
      ]
    }:$PATH

    label="''${1:-snapshot}"
    safe_label=$(printf '%s' "$label" | tr -c 'A-Za-z0-9._-' '_')
    out="/tmp/t3os-mem-''${safe_label}.txt"
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    uptime_s=$(awk '{print int($1)}' /proc/uptime)

    {
      echo "# t3os mem snapshot"
      echo "label:     $label"
      echo "timestamp: $ts"
      echo "uptime_s:  $uptime_s"
      echo ""

      echo "## /proc/meminfo (selected)"
      grep -E '^(MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapCached|Active|Inactive|Dirty|AnonPages|Mapped|Shmem|KReclaimable|Slab|SReclaimable|SUnreclaim|SwapTotal|SwapFree|Committed_AS|VmallocUsed):' /proc/meminfo
      echo ""

      echo "## /proc/pressure (some/full avg10 avg60 avg300 total)"
      for f in memory cpu io; do
        printf "### %s\n" "$f"
        cat /proc/pressure/$f
      done
      echo ""

      echo "## swap devices"
      swapon --show --noheadings 2>/dev/null | sort || echo "(none)"
      echo ""

      echo "## zram"
      zramctl --noheadings --output-all 2>/dev/null | sort || echo "(none)"
      echo ""

      echo "## v4l2loopback module"
      if lsmod | grep -q '^v4l2loopback'; then
        lsmod | awk '$1=="v4l2loopback"'
        for p in /sys/module/v4l2loopback/parameters/*; do
          printf "  %s = %s\n" "$(basename "$p")" "$(cat "$p" 2>/dev/null || echo '?')"
        done
      else
        echo "(not loaded)"
      fi
      echo ""

      echo "## /dev/video61 holders (GoPro loopback)"
      if [ -e /dev/video61 ]; then
        holders=$(fuser /dev/video61 2>/dev/null || true)
        if [ -n "''${holders// /}" ]; then
          for pid in $holders; do
            if [ -r "/proc/$pid/comm" ]; then
              printf "  pid=%-7s comm=%s\n" "$pid" "$(cat /proc/$pid/comm)"
            fi
          done
        else
          echo "  (none)"
        fi
      else
        echo "  (device does not exist)"
      fi
      echo ""

      echo "## gopro-ffmpeg.service"
      gp_pid=$(systemctl show -p MainPID --value gopro-ffmpeg.service 2>/dev/null || echo 0)
      if [ "''${gp_pid:-0}" != "0" ] && [ -d "/proc/$gp_pid" ]; then
        printf "  pid:    %s\n" "$gp_pid"
        grep -E '^(VmPeak|VmSize|VmRSS|VmHWM|VmData|VmSwap|RssAnon|RssFile|RssShmem|Threads):' /proc/$gp_pid/status | sed 's/^/  /'
      else
        echo "  (not running)"
      fi
      echo ""

      echo "## v4l2-relayd-ipu6.service"
      systemctl is-active v4l2-relayd-ipu6.service 2>/dev/null | sed 's/^/  active=/' || echo "  (not present)"
      echo ""

      echo "## key user processes (sorted by command then pid; RSS_kB)"
      ps -eo pid=,user=,rss=,comm=,cmd= --no-headers |
        awk '
          {
            pid=$1; user=$2; rss=$3; comm=$4;
            cmd=""; for(i=5;i<=NF;i++) cmd=cmd" "$i;
            if (length(cmd) > 140) cmd = substr(cmd,1,140) "...";
            if (comm ~ /^(chromium|chrome|google-chrome|teams-jail|electron|QtWebEngineProc|pipewire|pipewire-pulse|wireplumber|xdg-desktop|xdg-dbus-proxy|portal|ffmpeg|gopro-webcam|v4l2-relayd|gst-launch|node|claude|hyprland|Xwayland|firefox)/ ||
                rss > 200000) {
              printf "%-28s pid=%-8s rss=%9d kB cmd=%s\n", comm, pid, rss, cmd;
            }
          }
        ' | sort
      echo ""

      echo "## /proc/<gp_ffmpeg>/smaps_rollup (if gopro-ffmpeg running)"
      if [ "''${gp_pid:-0}" != "0" ]; then
        rollup=$(cat /proc/$gp_pid/smaps_rollup 2>/dev/null || true)
        if [ -n "$rollup" ]; then
          printf '%s\n' "$rollup" | grep -E '^(Rss|Pss|Anonymous|Swap|Shared|Private)' | sed 's/^/  /'
        else
          echo "  (unreadable — needs root)"
        fi
      else
        echo "  (n/a)"
      fi
      echo ""

      echo "## systemd-oomd actions this boot"
      journalctl -u systemd-oomd.service -b --no-pager 2>/dev/null |
        grep -E 'Killed|managed' | tail -10 | sed 's/^/  /' || true
      [ "$(journalctl -u systemd-oomd.service -b --no-pager 2>/dev/null | grep -cE 'Killed|managed')" = "0" ] && echo "  (none)"
      echo ""

      echo "## kernel OOM events this boot"
      journalctl -k -b --no-pager 2>/dev/null |
        grep -iE 'invoked oom-killer|Out of memory: Killed' | tail -10 | sed 's/^/  /' || true
      [ "$(journalctl -k -b --no-pager 2>/dev/null | grep -ciE 'invoked oom-killer|Out of memory: Killed')" = "0" ] && echo "  (none)"
      echo ""

      echo "## ffmpeg log tail (gopro, last 2 KB)"
      if [ -r /tmp/gopro-webcam-ffmpeg.log ]; then
        tail -c 2048 /tmp/gopro-webcam-ffmpeg.log | sed 's/^/  /'
      else
        echo "  (no log)"
      fi
    } > "$out"

    echo "wrote $out"
    awk '/^Mem/ { used=$3; total=$2; gsub(/[^0-9.]/,"",used); gsub(/[^0-9.]/,"",total); if (total>0) printf "memory: %.0f%% used\n", used/total*100 }' < <(free)

    ls -1t /tmp/t3os-mem-*.txt 2>/dev/null | head -5 | sed 's/^/  /'
  '';

  logScript = pkgs.writeShellScript "t3os-mem-log.sh" ''
    set -u
    PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.gawk
        pkgs.util-linux
        pkgs.systemd
      ]
    }:$PATH

    LOG=/var/log/t3os-memwatch/metrics.tsv
    N="''${1:-30}"

    if [ ! -r "$LOG" ]; then
      echo "no memwatch log at $LOG"
      if systemctl is-active --quiet t3os-memwatch.service; then
        echo "(daemon is running — give it a few seconds, then retry)"
      else
        echo "(daemon not running — rebuild, then check: systemctl status t3os-memwatch)"
      fi
      exit 1
    fi

    want=ts,mem_avail,anon,shmem,unaccounted_kb,dmabuf_kb,swap_free,psi_some10,psi_full10,teamsjail_cg_kb,ffmpeg_cg_kb,top_name,top_cmd
    hdr=$(grep -m1 '^ts	' "$LOG")
    {
      printf '%s\n' "$hdr"
      grep -v '^#' "$LOG" | grep -v '^ts	' | tail -n "$N"
    } | awk -F'\t' -v want="$want" '
        NR==1 { n=split(want,w,","); for (i=1;i<=NF;i++) idx[$i]=i }
        {
          line="";
          for (k=1;k<=n;k++) {
            c=idx[w[k]];
            v=(NR==1 ? w[k] : (c ? $c : "-"));
            line=line (k>1?"\t":"") v;
          }
          print line;
        }' | column -t -s "$(printf '\t')"

    echo
    rows=$(grep -vc '^#' "$LOG" 2>/dev/null || echo "?")
    printf 'full TSV (%s rows, 41 cols): %s\n' "$rows" "$LOG"
    systemctl is-active --quiet t3os-memwatch.service \
      && echo "daemon: running" \
      || echo "daemon: NOT running — systemctl status t3os-memwatch"
  '';

  memScript = pkgs.writeShellScript "t3os-mem.sh" ''
    set -u

    PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.gawk
        pkgs.procps
        pkgs.util-linux
        pkgs.systemd
      ]
    }:$PATH

    bold=$(printf '\033[1m')
    dim=$(printf '\033[2m')
    red=$(printf '\033[31m')
    yel=$(printf '\033[33m')
    grn=$(printf '\033[32m')
    rst=$(printf '\033[0m')

    section() { printf "\n''${bold}%s''${rst}\n" "$1"; }

    section "Memory + swap"
    free -h | grep -E "^(Mem|Swap)"

    section "Swap devices (priority order)"
    swapon --show || echo "  (no swap configured)"

    section "Pressure (PSI — % of time stalled, last 10s / 60s / 5min)"
    awk -F'[ =]' '
      /^some/ { printf "  memory.some  %5.2f / %5.2f / %5.2f\n", $3, $5, $7 }
      /^full/ { printf "  memory.full  %5.2f / %5.2f / %5.2f\n", $3, $5, $7 }
    ' /proc/pressure/memory
    awk -F'[ =]' '
      /^some/ { printf "  cpu.some     %5.2f / %5.2f / %5.2f\n", $3, $5, $7 }
    ' /proc/pressure/cpu
    awk -F'[ =]' '
      /^some/ { printf "  io.some      %5.2f / %5.2f / %5.2f\n", $3, $5, $7 }
      /^full/ { printf "  io.full      %5.2f / %5.2f / %5.2f\n", $3, $5, $7 }
    ' /proc/pressure/io

    section "Top 10 by RSS"
    ps -eo pid,user,%mem,rss,comm --sort=-rss | head -11 |
      awk 'NR==1 { print "  " $0; next } {
        mb = $4 / 1024
        printf "  %-7s %-10s %5s%%  %6.0f MB  %s\n", $1, $2, $3, mb, $5
      }'

    section "systemd-oomd recent kills (this boot)"
    journalctl -u systemd-oomd.service -b --no-pager 2>/dev/null |
      grep -E "Killed|managed" | tail -5 ||
        echo "  none"

    section "Kernel OOM events (this boot)"
    journalctl -k -b --no-pager 2>/dev/null |
      grep -iE "invoked oom-killer|Out of memory: Killed" | tail -5 ||
        echo "  none"

    pct=$(awk '/^Mem/ { used=$3; total=$2; gsub(/[^0-9.]/,"",used); gsub(/[^0-9.]/,"",total); if (total>0) printf "%.0f", used/total*100 }' < <(free))
    if [ -n "$pct" ] && [ "$pct" -ge 85 ]; then
      printf "\n''${red}MEMORY %s%% — investigate the top RSS list above''${rst}\n" "$pct"
    elif [ -n "$pct" ] && [ "$pct" -ge 70 ]; then
      printf "\n''${yel}Memory %s%% — getting tight''${rst}\n" "$pct"
    else
      printf "\n''${grn}Memory healthy (%s%%)''${rst}\n" "''${pct:-?}"
    fi
  '';
in
{
  config = lib.mkIf cfg.enable {
    t3os.cli.scripts = [
      {
        command = [ "mem" ];
        title = "Memory + swap pressure status";
        script = memScript;
        usage = "Snapshot of memory, swap, PSI pressure, top RSS consumers, oomd kills, and kernel OOM events for this boot.";
      }
      {
        command = [
          "mem"
          "snapshot"
        ];
        title = "Capture a labeled mem/swap/v4l2/pipewire/oomd snapshot to /tmp";
        script = snapshotScript;
        usage = "Usage: t3os mem snapshot <label>. Writes /tmp/t3os-mem-<label>.txt with a diff-friendly dump of memory state, v4l2/pipewire holders of /dev/video61, gopro-ffmpeg internals, and recent oomd/kernel OOM events. Run pre-call and post-call to isolate leaks at call boundaries.";
      }
      {
        command = [
          "mem"
          "log"
        ];
        title = "Show recent rows from the t3os-memwatch daemon TSV";
        script = logScript;
        usage = "Usage: t3os mem log [N]. Prints the last N (default 30) samples from the t3os-memwatch daemon — a curated column subset of /var/log/t3os-memwatch/metrics.tsv. The full TSV persists across reboot; hand it over after the next post-call OOM to diagnose which actor exploded.";
      }
    ];
  };
}
