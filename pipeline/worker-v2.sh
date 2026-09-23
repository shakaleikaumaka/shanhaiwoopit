#!/bin/bash
# Usage: worker-v2.sh <todo-shard.json> <logfile>
# Chunked fresh-connection downloads (defeats Drive sustained-transfer throttle),
# then local ffmpeg -> 32kbps mp3 + poster. Skips files too big for free disk.
SHARD="$1"; LOG="$2"
OUT=/shared/public/edgetv/audio
POSTERS=/shared/public/edgetv/posters
VTMP=/shared/edgetv-vidtmp
mkdir -p "$OUT" "$POSTERS" /tmp/audio-staging/tmp "$VTMP"
cd /tmp/audio-staging
CHUNK=8388608  # 8MB — stay inside Drive's burst window

stream_url() {
  echo "https://drive.usercontent.google.com/download?id=${1}&export=download&confirm=t"
}

file_size() { curl -s -D - -o /dev/null --max-time 30 -r 0-0 "$1" | grep -i '^content-range:' | sed 's/.*\///' | tr -d '\r'; }

dl_chunked() { # url out size -> 0 ok / 1 fail
  local url="$1" out="$2" size="$3"
  local nchunks=$(( (size + CHUNK - 1) / CHUNK ))
  rm -f "$out".part.*
  for c in $(seq 0 $((nchunks-1))); do
    local start=$((c*CHUNK)); local end=$((start+CHUNK-1))
    [ $end -ge $size ] && end=$((size-1))
    if ! curl -s --max-time 300 --speed-limit 51200 --speed-time 20 -r ${start}-${end} -o "$out.part.$c" "$url" < /dev/null; then
      # one retry per chunk
      sleep 3
      curl -s --max-time 300 --speed-limit 51200 --speed-time 20 -r ${start}-${end} -o "$out.part.$c" "$url" < /dev/null || { rm -f "$out".part.*; return 1; }
    fi
  done
  cat "$out".part.* > "$out" && rm -f "$out".part.*
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

  if [ "$kind" = "audio" ]; then
    # small files: direct stream transcode is fine
    for attempt in 1 2; do
      rm -f "tmp/${slug}.mp3"
      if ffmpeg -hide_banner -loglevel error -nostats -y -i "$url" -vn -ac 1 -b:a 32k -codec:a libmp3lame "tmp/${slug}.mp3" >> "$LOG" 2>&1 < /dev/null; then
        dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "tmp/${slug}.mp3" 2>/dev/null | cut -d. -f1)
        [ "${dur:-0}" -gt 60 ] && { ok=1; break; }
      fi
      echo "$(date +%H:%M:%S) RETRY($attempt) $slug" >> "$LOG"; sleep 8
    done
    [ "$ok" = "1" ] && mv "tmp/${slug}.mp3" "$OUT/${slug}.mp3"
  else
    # video: chunked download then local ffmpeg
    size=$(file_size "$url")
    free=$(df --output=avail -B1 /shared | tail -1 | tr -d ' ')
    maxfit=$((free - 1500000000))
    if ! [[ "$size" =~ ^[0-9]+$ ]] || [ "$size" -le 0 ]; then
      echo "$(date +%H:%M:%S) NOSIZE $slug" >> "$LOG"
    elif [ "$size" -gt "$maxfit" ]; then
      echo "$(date +%H:%M:%S) TOOBIG $slug ($((size/1000000))MB > free $((free/1000000))MB)" >> "$LOG"
    else
      echo "$(date +%H:%M:%S) DL $slug ($((size/1000000))MB)" >> "$LOG"
      vfile="$VTMP/${slug}.vid"
      if dl_chunked "$url" "$vfile" "$size"; then
        AARGS=""; PARGS="-vn"
        [ "$need_audio" = "1" ] && AARGS="-ac 1 -b:a 32k -codec:a libmp3lame tmp/${slug}.mp3"
        if [ "$need_poster" = "1" ]; then
          PARGS="-vf select='eq(n\,500)',scale=640:-2 -frames:v 1 -q:v 4 -update 1 tmp/${slug}.jpg"
        fi
        if [ "$need_audio" = "1" ] && [ "$need_poster" = "1" ]; then
          ffmpeg -hide_banner -loglevel error -nostats -y -i "$vfile" -map 0:a $AARGS -map 0:v:0 $PARGS >> "$LOG" 2>&1 < /dev/null
        elif [ "$need_audio" = "1" ]; then
          ffmpeg -hide_banner -loglevel error -nostats -y -i "$vfile" $AARGS >> "$LOG" 2>&1 < /dev/null
        else
          ffmpeg -hide_banner -loglevel error -nostats -y -i "$vfile" $PARGS >> "$LOG" 2>&1 < /dev/null
        fi
        if [ "$need_audio" = "1" ]; then
          dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "tmp/${slug}.mp3" 2>/dev/null | cut -d. -f1)
          [ "${dur:-0}" -gt 60 ] && ok=1
        else
          [ -s "tmp/${slug}.jpg" ] && ok=1
        fi
        if [ "$ok" = "1" ]; then
          [ "$need_audio" = "1" ] && mv "tmp/${slug}.mp3" "$OUT/${slug}.mp3"
          [ "$need_poster" = "1" ] && [ -s "tmp/${slug}.jpg" ] && mv "tmp/${slug}.jpg" "$POSTERS/${slug}.jpg"
        fi
      else
        echo "$(date +%H:%M:%S) DL-FAIL $slug" >> "$LOG"
      fi
      rm -f "$vfile"
    fi
  fi
  [ "$ok" = "1" ] && echo "$(date +%H:%M:%S) DONE $slug" >> "$LOG" || echo "$(date +%H:%M:%S) FAIL $slug" >> "$LOG"
  rm -f "tmp/${slug}.mp3" "tmp/${slug}.jpg"
done
echo "$(date +%H:%M:%S) SHARD-COMPLETE" >> "$LOG"
