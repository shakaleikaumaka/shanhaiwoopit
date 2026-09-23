#!/bin/bash
# Usage: rclone-worker.sh <shard.json> <logfile> [overwrite]
# Owner-authenticated downloads via rclone (no anon quota wall) -> 32k mono mp3.
# Disk-guarded: waits for space before each download. Cleans up after itself.
export RCLONE_CONFIG=/workspace/.config/rclone/rclone.conf
RCLONE=/workspace/bin/rclone
OUT=/shared/public/edgetv/audio
POSTERS=/shared/public/edgetv/posters
VTMP=/shared/edgetv-vidtmp
SHARD="$1"; LOG="$2"; OW="$3"
mkdir -p "$OUT" "$POSTERS" "$VTMP"
cd /tmp/audio-staging

n=$(python3 -c "import json;print(len(json.load(open('$SHARD'))))")
for i in $(seq 0 $((n-1))); do
  row=$(python3 -c "import json;d=json.load(open('$SHARD'))[$i];print(d['slug']+'\t'+d['id']+'\t'+d['kind'])")
  slug="$(printf '%s' "$row" | cut -f1)"; id="$(printf '%s' "$row" | cut -f2)"; kind="$(printf '%s' "$row" | cut -f3)"
  if [ "$OW" != "overwrite" ] && [ -f "$OUT/${slug}.mp3" ]; then
    echo "$(date +%H:%M:%S) SKIP $slug" >> "$LOG"; continue
  fi
  path=$(python3 -c "import json;print(json.load(open('id2path.json'))['$id'])" 2>/dev/null)
  size=$(python3 -c "import json;d={x['ID']:x['Size'] for x in json.load(open('rclone-tree.json')) if x.get('ID')};print(d.get('$id',0))" 2>/dev/null)
  if [ -z "$path" ]; then echo "$(date +%H:%M:%S) NOPATH $slug" >> "$LOG"; continue; fi
  echo "$(date +%H:%M:%S) START $slug ($kind, $((size/1048576))MB)" >> "$LOG"

  # disk-budget semaphore: concurrent downloads up to ~4.3GB staged total
  # (atomic check+claim under a short flock; claim released after transcode)
  need=$(( size/1024 ))
  mkdir -p /tmp/audio-staging/inflight
  CLAIM=/tmp/audio-staging/inflight/$$.$i
  while true; do
    exec 9>/tmp/audio-staging/budget.lock
    flock 9
    cur=$(cat /tmp/audio-staging/inflight/* 2>/dev/null | awk '{s+=$1} END{print s+0}')
    free=$(df --output=avail /shared | tail -1 | tr -d ' ')
    if [ $((cur + need)) -lt 4300000 ] && [ "$free" -gt $((need + 716800)) ]; then
      echo "$need" > "$CLAIM"
      flock -u 9
      break
    fi
    flock -u 9
    sleep 15
  done

  base="$(basename "$path")"
  rm -f "$VTMP/$base"
  if ! $RCLONE copy "gd:$path" "$VTMP" --multi-thread-streams=12 --multi-thread-cutoff=32M --retries=3 --low-level-retries=10 >> "$LOG" 2>&1; then
    echo "$(date +%H:%M:%S) DL-FAIL $slug" >> "$LOG"; rm -f "$VTMP/$base" "$CLAIM"; continue
  fi
  if ffmpeg -y -i "$VTMP/$base" -vn -ac 1 -b:a 32k "$OUT/${slug}.tmp.mp3" >> "$LOG" 2>&1; then
    mv "$OUT/${slug}.tmp.mp3" "$OUT/${slug}.mp3"
    echo "$(date +%H:%M:%S) OK $slug" >> "$LOG"
  else
    echo "$(date +%H:%M:%S) FF-FAIL $slug" >> "$LOG"; rm -f "$OUT/${slug}.tmp.mp3"
  fi
  if [ "$kind" = "video" ] && [ ! -f "$POSTERS/${slug}.jpg" ] && [ -f "$VTMP/$base" ]; then
    ffmpeg -y -ss 500 -i "$VTMP/$base" -frames:v 1 -q:v 5 "$POSTERS/${slug}.jpg" >/dev/null 2>&1
  fi
  rm -f "$VTMP/$base" "$CLAIM"
done
echo "$(date +%H:%M:%S) SHARD-COMPLETE" >> "$LOG"
