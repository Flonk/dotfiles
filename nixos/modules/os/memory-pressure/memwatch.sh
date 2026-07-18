#!/usr/bin/env bash
#
# skynet-memwatch — periodic aggregated memory snapshot for debugging the
# post-meeting OOM explosion on chonkler. Appends one TSV row per sample to
# $LOGS_DIRECTORY/metrics.tsv. The log lives on /var/log so it survives the
# reboot — read it afterward with `skynet mem log`.
#
# Modes:
#   memwatch.sh            one sample to stdout (manual test)
#   memwatch.sh header     print just the TSV header
#   memwatch.sh sample     append one sample to the log
#   memwatch.sh daemon     loop forever, sampling every $MEMWATCH_INTERVAL s
#
# Adaptive cadence: samples every MEMWATCH_INTERVAL s normally, but drops to
# 1 s while MemAvailable is below 35 % of RAM — so a 4-second explosion is
# captured in detail instead of missed between two slow samples.
#
# One column per actor in the meeting-quit → must-reboot chain (see
# obsidian://claude/video-setup "Actor map"). Each sample is fork-light
# (~10 forks, mostly /proc reads) so it stays well under the interval.

set -u

LOG_DIR="${LOGS_DIRECTORY:-/var/log/skynet-memwatch}"
LOG="$LOG_DIR/metrics.tsv"
INTERVAL="${MEMWATCH_INTERVAL:-5}"
FAST_INTERVAL=1
FAST_AVAIL_PCT=35
ROTATE_BYTES=$((40 * 1024 * 1024))

# Tab-separated column names. *_kb = kB, psi_* = % stalled, counters are
# cumulative-since-boot, *_frozen / v4l2lb are 0/1.
COLS=$(printf '%s' \
'ts	epoch	uptime	mem_total	mem_free	mem_avail	anon	cached	buffers	shmem	'\
'slab	sreclaim	sunreclaim	pagetables	kstack	committed	swap_total	swap_free	'\
'zram_orig	zram_compr	psi_some10	psi_some60	psi_full10	pswpin	pswpout	oom_kill	'\
'pgmajfault	dmabuf_kb	dmabuf_n	ffmpeg_cg_kb	ffmpeg_frozen	v4l2lb	pipewire_kb	'\
'wireplumber_kb	portal_kb	portalbe_kb	teamsjail_cg_kb	chromium_gpu_kb	top_rss_kb	'\
'top_name	unaccounted_kb	top_pid	top_cmd')

AVAIL_PCT=100

header() {
  printf '# skynet-memwatch  *_kb=kB  psi=%%stall  counters cumulative since boot\n'
  printf '%s\n' "$COLS"
}

# read a single unsigned int from a file, 0 on any failure
read_uint() {
  local v=0
  [[ -r $1 ]] && read -r v <"$1" 2>/dev/null
  [[ $v =~ ^[0-9]+$ ]] && printf '%s' "$v" || printf '0'
}

# emit one TSV row to stdout; also sets global AVAIL_PCT
collect() {
  local epoch ts uptime
  epoch=$(date +%s)
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  uptime=$(awk '{print int($1)}' /proc/uptime)

  # /proc/meminfo — pure-bash, no fork
  local -A M=()
  local k v _rest
  while read -r k v _rest; do M["${k%:}"]=$v; done </proc/meminfo
  local mem_total=${M[MemTotal]:-0} mem_free=${M[MemFree]:-0} mem_avail=${M[MemAvailable]:-0}
  local anon=${M[AnonPages]:-0} cached=${M[Cached]:-0} buffers=${M[Buffers]:-0}
  local shmem=${M[Shmem]:-0} slab=${M[Slab]:-0}
  local sre=${M[SReclaimable]:-0} sun=${M[SUnreclaim]:-0}
  local ptbl=${M[PageTables]:-0} kstk=${M[KernelStack]:-0} commit=${M[Committed_AS]:-0}
  local swap_total=${M[SwapTotal]:-0} swap_free=${M[SwapFree]:-0}

  # zram (mm_stat: orig_data_size compr_data_size mem_used_total ...)
  local zram_orig=0 zram_compr=0 zo zc
  if [[ -r /sys/block/zram0/mm_stat ]]; then
    read -r zo zc _rest </sys/block/zram0/mm_stat 2>/dev/null
    zram_orig=$(( ${zo:-0} / 1024 ))
    zram_compr=$(( ${zc:-0} / 1024 ))
  fi

  # PSI memory pressure
  local psi_some10=0 psi_some60=0 psi_full10=0
  if [[ -r /proc/pressure/memory ]]; then
    read -r psi_some10 psi_some60 psi_full10 < <(
      awk -F'[ =]' '/^some/{s10=$3;s60=$5} /^full/{f10=$3}
                    END{printf "%s %s %s", s10+0, s60+0, f10+0}' /proc/pressure/memory)
  fi

  # vmstat cumulative counters
  local pswpin=0 pswpout=0 oomk=0 pgmf=0
  read -r pswpin pswpout oomk pgmf < <(
    awk '$1=="pswpin"{a=$2} $1=="pswpout"{b=$2} $1=="oom_kill"{c=$2} $1=="pgmajfault"{d=$2}
         END{printf "%s %s %s %s", a+0, b+0, c+0, d+0}' /proc/vmstat)

  # dma-buf total — the prime uncapped suspect (kernel DRM buffers)
  local dmabuf_kb=0 dmabuf_n=0
  if [[ -r /sys/kernel/debug/dma_buf/bufinfo ]]; then
    read -r dmabuf_kb dmabuf_n < <(
      awk '$1 ~ /^[0-9]+$/ {s+=$1; c++} END{printf "%d %d", int(s/1024), c+0}' \
        /sys/kernel/debug/dma_buf/bufinfo)
  fi

  # gopro-ffmpeg cgroup memory + freeze state
  local fcg=/sys/fs/cgroup/system.slice/gopro-ffmpeg.service
  local ffmpeg_cg=0 ffmpeg_frozen=0
  if [[ -d $fcg ]]; then
    ffmpeg_cg=$(( $(read_uint "$fcg/memory.current") / 1024 ))
    ffmpeg_frozen=$(read_uint "$fcg/cgroup.freeze")
  fi

  # v4l2loopback loaded?
  local v4l2lb=0
  [[ -d /sys/module/v4l2loopback ]] && v4l2lb=1

  # teams-jail scope cgroup — aggregates ALL chromium (renderers, GPU,
  # WebRTC, teams-gateway, Meet/Teams JS) in one capped number
  local teamsjail_cg=0 d
  d=$(find /sys/fs/cgroup -maxdepth 7 -type d -name 'teams-jail-*.scope' 2>/dev/null | head -1)
  [[ -n $d && -r $d/memory.current ]] && teamsjail_cg=$(( $(read_uint "$d/memory.current") / 1024 ))

  # per-process RSS aggregation — one ps, one awk. Classify on the
  # executable basename ($4 of the ps line), NOT anywhere in args: nix
  # store paths embed version suffixes like ".../xdg-desktop-portal-1.20.4/"
  # which would otherwise misclassify the main portal as a backend.
  local pw=0 wp=0 por=0 pbe=0 cgpu=0 top=0 topn=- topp=0
  read -r pw wp por pbe cgpu top topn topp < <(
    ps -eo pid=,rss=,comm=,args= 2>/dev/null | awk '
      { pid=$1; rss=$2; name=$3;
        exe=$4; sub(/.*\//, "", exe);
        a=""; for (i=4;i<=NF;i++) a=a" "$i;
        if      (exe=="pipewire")    pw+=rss;
        else if (exe=="wireplumber") wp+=rss;
        if      (exe ~ /^xdg-desktop-portal-/) pbe+=rss;
        else if (exe=="xdg-desktop-portal")    por+=rss;
        if (exe ~ /chrom/ && a ~ /--type=gpu-process/) cgpu+=rss;
        if (rss+0 > top+0) { top=rss; topn=name; topp=pid } }
      END { printf "%d %d %d %d %d %d %s %d",
            pw+0, wp+0, por+0, pbe+0, cgpu+0, top+0, (topn==""?"-":topn), topp+0 }')

  # full cmdline of the top process (sanitized, truncated) — so the actor
  # behind a generic comm like "python3.13" is unambiguous in the log,
  # even after the process is gone
  local top_cmd=-
  if [[ ''${topp:-0} -gt 0 && -r /proc/$topp/cmdline ]]; then
    top_cmd=$(tr '\0\t' '  ' </proc/$topp/cmdline 2>/dev/null | cut -c1-160)
    [[ -z ''${top_cmd// /} ]] && top_cmd=-
  fi

  # unaccounted: RAM not explained by anon/cache/slab/pagetables/kstack.
  # If THIS spikes during the explosion, the leak is kernel/driver memory
  # (dma-buf / GPU) rather than any userspace process.
  local used_known=$(( anon + cached + buffers + sre + sun + ptbl + kstk ))
  local unacc=$(( mem_total - mem_free - used_known ))

  AVAIL_PCT=100
  (( mem_total > 0 )) && AVAIL_PCT=$(( mem_avail * 100 / mem_total ))

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$ts" "$epoch" "$uptime" "$mem_total" "$mem_free" "$mem_avail" "$anon" "$cached" \
    "$buffers" "$shmem" "$slab" "$sre" "$sun" "$ptbl" "$kstk" "$commit" "$swap_total" \
    "$swap_free" "$zram_orig" "$zram_compr" "$psi_some10" "$psi_some60" "$psi_full10" \
    "$pswpin" "$pswpout" "$oomk" "$pgmf" "$dmabuf_kb" "$dmabuf_n" "$ffmpeg_cg" \
    "$ffmpeg_frozen" "$v4l2lb" "$pw" "$wp" "$por" "$pbe" "$teamsjail_cg" "$cgpu" \
    "$top" "$topn" "$unacc" "$topp" "$top_cmd"
}

case "${1:-print}" in
  header)
    header
    ;;
  print)
    collect
    ;;
  sample)
    mkdir -p "$LOG_DIR"
    [[ -s $LOG ]] || header >"$LOG"
    collect >>"$LOG"
    sync "$LOG" 2>/dev/null || true
    ;;
  daemon)
    mkdir -p "$LOG_DIR"
    # rotate a single old generation if the log got large OR the column
    # schema changed (so every row in a file matches its header). The COLS
    # header is always line 2 (line 1 is the '# skynet-memwatch' comment).
    if [[ -f $LOG ]]; then
      sz=$(stat -c %s "$LOG" 2>/dev/null || echo 0)
      cur_hdr=""
      { read -r _l1; read -r cur_hdr; } <"$LOG" 2>/dev/null || true
      if (( sz > ROTATE_BYTES )) || [[ -n $cur_hdr && $cur_hdr != "$COLS" ]]; then
        mv -f "$LOG" "$LOG.1"
      fi
    fi
    [[ -s $LOG ]] || header >"$LOG"
    # boot marker so the time series can be segmented per boot
    bootid=$(read_uint /dev/null; cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo unknown)
    printf '# daemon start %s boot=%s interval=%ss\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$bootid" "$INTERVAL" >>"$LOG"
    sync "$LOG" 2>/dev/null || true
    while :; do
      collect >>"$LOG"
      sync "$LOG" 2>/dev/null || true
      if (( AVAIL_PCT < FAST_AVAIL_PCT )); then
        sleep "$FAST_INTERVAL"
      else
        sleep "$INTERVAL"
      fi
    done
    ;;
  *)
    echo "usage: memwatch.sh [print|sample|daemon|header]" >&2
    exit 2
    ;;
esac
