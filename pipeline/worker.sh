#!/bin/bash
# Usage: worker.sh <shardN.json> <mapN.json> <logN.log>
# Extracts audio from Drive videos via streaming ffmpeg, uploads to archive.org, records node URL.
SHARD="$1"; MAP="$2"; LOG="$3"
cd /tmp/audio-staging
[ -f "$MAP" ] || echo '{}' > "$MAP"

record() { # slug url
  python3 - "$MAP" "$1" "$2" <<'PYEOF'
import json,sys
m=json.load(open(sys.argv[1])); m[sys.argv[2]]=sys.argv[3]
json.dump(m,open(sys.argv[1],'w'),indent=0)
PYEOF
}

upload() { # filepath slug title -> echoes node url or NOTHING on fail
  local f="$1" slug="$2" title="$3"
  local item="edge-esmeralda-2026--${slug}"
  local fname="${slug}.mp3"
  for a in 1 2 3; do
    code=$(curl -s --max-time 600 -o /dev/null -w '%{http_code}' \
      -H "x-amz-acl: public-read" \
      -H "x-archive-auto-make-bucket: 1" \
      -H "x-archive-meta-mediatype: audio" \
      -H "x-archive-meta-collection: opensource_audio" \
      -H "x-archive-meta-title: Edge Esmeralda 2026 — ${title}" \
      -H "x-archive-meta-creator: Edge Esmeralda / Shaka Lei Kaumaka" \
      -H "x-archive-meta-description: Session audio from Edge Esmeralda 2026 (Healdsburg, CA). Part of the edgeTV Knowledge Transponder archive. https://edgetv-fnajt22goh-nqfhvcnv.taur.link/" \
      -H "x-archive-meta-subject: Edge Esmeralda; Edge City; popup city; talks; 2026" \
      -H "x-archive-meta-licenseurl: https://creativecommons.org/licenses/by/4.0/" \
      -H "authorization: LOW ${IA_ACCESS}:${IA_SECRET}" \
      --upload-file "$f" \
      "https://s3.us.archive.org/${item}/${fname}" < /dev/null)
    [ "$code" = "200" ] && break
    echo "$(date +%H:%M:%S) UPLOAD-RETRY($a) $slug http=$code" >> "$LOG"; sleep $((a*10))
  done
  [ "$code" != "200" ] && { echo "$(date +%H:%M:%S) UPLOAD-FAIL $slug" >> "$LOG"; return 1; }
  # poll for the download to appear, resolve the ia-node direct URL
  for p in $(seq 1 12); do
    node=$(curl -sIL --max-time 60 -o /dev/null -w '%{url_effective}' "https://archive.org/download/${item}/${fname}" < /dev/null)
    code2=$(curl -sIL --max-time 60 -o /dev/null -w '%{http_code}' "$node" < /dev/null)
    [ "$code2" = "200" ] && { echo "$node"; return 0; }
    sleep 20
  done
  echo "$(date +%H:%M:%S) RESOLVE-FAIL $slug" >> "$LOG"; return 1
}

stream_url() { # drive id -> echoes streamable url
  local id="$1"
  local html uuid
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
  row=$(python3 -c "import json;d=json.load(open('$SHARD'))[$i];print(d['slug']+'\t'+d['id']+'\t'+d['title'].replace('\t',' '))")
  slug="${row%%	*}"; rest="${row#*	}"; id="${rest%%	*}"; title="${rest#*	}"
  if python3 -c "import json,sys;sys.exit(0 if '$slug' in json.load(open('$MAP')) else 1)"; then
    echo "$(date +%H:%M:%S) SKIP $slug" >> "$LOG"; continue
  fi
  echo "$(date +%H:%M:%S) START $slug" >> "$LOG"
  url=$(stream_url "$id")
  ok=0
  for attempt in 1 2; do
    rm -f "tmp/${slug}.mp3"
    if ffmpeg -hide_banner -loglevel error -nostats -y -i "$url" -vn -ac 1 -b:a 64k -codec:a libmp3lame "tmp/${slug}.mp3" >> "$LOG" 2>&1 < /dev/null; then
      dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "tmp/${slug}.mp3" 2>/dev/null | cut -d. -f1)
      if [ "${dur:-0}" -gt 60 ]; then ok=1; break; fi
    fi
    echo "$(date +%H:%M:%S) EXTRACT-RETRY($attempt) $slug" >> "$LOG"; sleep 5
  done
  if [ "$ok" != "1" ]; then echo "$(date +%H:%M:%S) EXTRACT-FAIL $slug" >> "$LOG"; rm -f "tmp/${slug}.mp3"; continue; fi
  node=$(upload "tmp/${slug}.mp3" "$slug" "$title")
  if [ -n "$node" ]; then
    record "$slug" "$node"
    sz=$(du -m "tmp/${slug}.mp3" | cut -f1)
    echo "$(date +%H:%M:%S) DONE $slug (${sz}MB, ${dur}s)" >> "$LOG"
  fi
  rm -f "tmp/${slug}.mp3"
done
echo "$(date +%H:%M:%S) SHARD-COMPLETE $SHARD" >> "$LOG"
