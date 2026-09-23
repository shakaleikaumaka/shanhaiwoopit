#!/bin/bash
# Usage: local-worker.sh <todo-shard.json> <logfile>
# Streams Drive media -> 32kbps mono mp3 + poster frame -> /shared/public/edgetv/
SHARD="$1"; LOG="$2"
OUT=/shared/public/edgetv/audio
POSTERS=/shared/public/edgetv/posters
mkdir -p "$OUT" "$POSTERS" /tmp/audio-staging/tmp
cd /tmp/audio-staging

stream_url() {
  local id="$1" html uuid
  html=$(curl -sL --max-time 60 "https://drive.google.com/uc?export=download&id=${id}" < /dev/null | tr -d '\0')
  uuid=$(printf '%s' "$html" | grep -oE 'name="uuid" value="[^"]*"' | head -1 | sed 's/.*value="//;s/"//')
  if [ -n "$uuid" ]; then
    echo "https://drive.usercontent.google.com/download?id=${id}&export=download&confirm=t&uuid=${uuid}"
  else
    echo "https://drive.usercontent.google.com/download?id=${id}&export=download&confirm=t"
  fi
}

n=$(python3 -c "import json;print(len(json.load(open('$SHARD'))))")
for i in $(seq 0 $((n-1))); do
  row=$(python3 -c "import json;d=json.load(open('$SHARD'))[$i];print(d['slug']+'\t'+d['id']+'\t'+d['kind'])")
  slug="$(printf '%s' "$row" | cut -f1)"; id="$(printf '%s' "$row" | cut -f2)"; kind="$(printf '%s' "$row" | cut -f3)"
  need_audio=1; need_poster=0
  [ -f "$OUT/${slug}.mp3" ] && need_audio=0
  [ "$kind" = "video" ] && [ ! -f "$POSTERS/${slug}.jpg" ] && need_poster=1
  [ "$need_audio" = "0" ] && [ "$need_poster" = "0" ] && { echo "$(date +%H:%M:%S) SKIP $slug" >> "$LOG"; continue; }
  echo "$(date +%H:%M:%S) START $slug ($kind)" >> "$LOG"
  url=$(stream_url "$id")
  ok=0
  for attempt in 1 2; do
    [ "$need_audio" = "1" ] && rm -f "tmp/${slug}.mp3"
    [ "$need_poster" = "1" ] && rm -f "tmp/${slug}.jpg"
    AARGS=""; PARGS=""
    [ "$need_audio" = "1" ] && AARGS="-map 0:a -ac 1 -b:a 32k -codec:a libmp3lame tmp/${slug}.mp3"
    if [ "$need_poster" = "1" ]; then
      PARGS="-map 0:v:0 -vf select='eq(n\,500)',scale=640:-2 -frames:v 1 -q:v 4 -update 1 tmp/${slug}.jpg"
    else
      PARGS="-vn"
    fi
    if ffmpeg -hide_banner -loglevel error -nostats -y -i "$url" $AARGS $PARGS >> "$LOG" 2>&1 < /dev/null; then
      if [ "$need_audio" = "1" ]; then
        dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "tmp/${slug}.mp3" 2>/dev/null | cut -d. -f1)
        [ "${dur:-0}" -gt 60 ] && ok=1
      else
        [ -s "tmp/${slug}.jpg" ] && ok=1
      fi
      [ "$ok" = "1" ] && break
    fi
    echo "$(date +%H:%M:%S) RETRY($attempt) $slug" >> "$LOG"; sleep 8
  done
  if [ "$ok" = "1" ]; then
    [ "$need_audio" = "1" ] && mv "tmp/${slug}.mp3" "$OUT/${slug}.mp3"
    [ "$need_poster" = "1" ] && [ -s "tmp/${slug}.jpg" ] && mv "tmp/${slug}.jpg" "$POSTERS/${slug}.jpg"
    echo "$(date +%H:%M:%S) DONE $slug" >> "$LOG"
  else
    echo "$(date +%H:%M:%S) FAIL $slug" >> "$LOG"; rm -f "tmp/${slug}.mp3" "tmp/${slug}.jpg"
  fi
done
echo "$(date +%H:%M:%S) SHARD-COMPLETE" >> "$LOG"
