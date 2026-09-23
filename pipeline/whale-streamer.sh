#!/bin/bash
# Slow-but-diskless: stream-transcode whale videos straight through ffmpeg.
SHARD="$1"; LOG="$2"
OUT=/shared/public/edgetv/audio
POSTERS=/shared/public/edgetv/posters
mkdir -p "$OUT" "$POSTERS" /tmp/audio-staging/tmp
cd /tmp/audio-staging
n=$(python3 -c "import json;print(len(json.load(open('$SHARD'))))")
for i in $(seq 0 $((n-1))); do
  row=$(python3 -c "import json;d=json.load(open('$SHARD'))[$i];print(d['slug']+'\t'+d['id'])")
  slug="$(printf '%s' "$row" | cut -f1)"; id="$(printf '%s' "$row" | cut -f2)"
  [ -f "$OUT/${slug}.mp3" ] && { echo "$(date +%H:%M:%S) SKIP $slug" >> "$LOG"; continue; }
  echo "$(date +%H:%M:%S) WHALE-START $slug" >> "$LOG"
  html=$(curl -sL --max-time 60 "https://drive.google.com/uc?export=download&id=${id}" < /dev/null | tr -d '\0')
  uuid=$(printf '%s' "$html" | grep -oE 'name="uuid" value="[^"]*"' | head -1 | sed 's/.*value="//;s/"//')
  if [ -n "$uuid" ]; then
    url="https://drive.usercontent.google.com/download?id=${id}&export=download&confirm=t&uuid=${uuid}"
  else
    url="https://drive.usercontent.google.com/download?id=${id}&export=download&confirm=t"
  fi
  rm -f "tmp/${slug}.mp3" "tmp/${slug}.jpg"
  if ffmpeg -hide_banner -loglevel error -nostats -y -i "$url" \
      -map 0:a -ac 1 -b:a 32k -codec:a libmp3lame "tmp/${slug}.mp3" \
      -map 0:v:0 -vf "select='eq(n\,500)',scale=640:-2" -frames:v 1 -q:v 4 -update 1 "tmp/${slug}.jpg" >> "$LOG" 2>&1 < /dev/null; then
    dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "tmp/${slug}.mp3" 2>/dev/null | cut -d. -f1)
    if [ "${dur:-0}" -gt 60 ]; then
      mv "tmp/${slug}.mp3" "$OUT/${slug}.mp3"
      [ -s "tmp/${slug}.jpg" ] && mv "tmp/${slug}.jpg" "$POSTERS/${slug}.jpg"
      echo "$(date +%H:%M:%S) WHALE-DONE $slug (${dur}s)" >> "$LOG"
    else
      echo "$(date +%H:%M:%S) WHALE-SHORT $slug" >> "$LOG"
    fi
  else
    echo "$(date +%H:%M:%S) WHALE-FAIL $slug" >> "$LOG"
  fi
  rm -f "tmp/${slug}.mp3" "tmp/${slug}.jpg"
done
echo "$(date +%H:%M:%S) WHALE-COMPLETE" >> "$LOG"
