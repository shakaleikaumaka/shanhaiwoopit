#!/bin/bash
# Usage: whale-worker.sh <shard.json> <logfile>
# Diskless stream-transcode for >4GB files via local rclone http (range-seekable).
SHARD="$1"; LOG="$2"
OUT=/shared/public/edgetv/audio
POSTERS=/shared/public/edgetv/posters
cd /tmp/audio-staging
n=$(python3 -c "import json;print(len(json.load(open('$SHARD'))))")
for i in $(seq 0 $((n-1))); do
  row=$(python3 -c "import json;d=json.load(open('$SHARD'))[$i];print(d['slug']+'\t'+d['id']+'\t'+d['kind'])")
  slug="$(printf '%s' "$row" | cut -f1)"; id="$(printf '%s' "$row" | cut -f2)"; kind="$(printf '%s' "$row" | cut -f3)"
  [ -f "$OUT/${slug}.mp3" ] && { echo "$(date +%H:%M:%S) SKIP $slug" >> "$LOG"; continue; }
  url=$(python3 -c "import json,urllib.parse;print(urllib.parse.quote(json.load(open('id2path.json'))['$id']))")
  echo "$(date +%H:%M:%S) WHALE-START $slug" >> "$LOG"
  if timeout 10800 ffmpeg -y -i "http://127.0.0.1:8099/$url" -vn -ac 1 -b:a 32k "$OUT/${slug}.tmp.mp3" >> "$LOG" 2>&1; then
    mv "$OUT/${slug}.tmp.mp3" "$OUT/${slug}.mp3"
    echo "$(date +%H:%M:%S) WHALE-OK $slug" >> "$LOG"
    [ "$kind" = "video" ] && [ ! -f "$POSTERS/${slug}.jpg" ] && \
      timeout 300 ffmpeg -y -ss 500 -i "http://127.0.0.1:8099/$url" -frames:v 1 -q:v 5 "$POSTERS/${slug}.jpg" >/dev/null 2>&1
  else
    echo "$(date +%H:%M:%S) WHALE-FAIL $slug" >> "$LOG"; rm -f "$OUT/${slug}.tmp.mp3"
  fi
done
echo "$(date +%H:%M:%S) SHARD-COMPLETE" >> "$LOG"
