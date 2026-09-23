#!/bin/bash
# Uploads all already-transcoded mp3s from out/ to archive.org, records node URLs in map-staged.json
cd /tmp/audio-staging
MAP="map-staged.json"; LOG="staged.log"
[ -f "$MAP" ] || echo '{}' > "$MAP"
mkdir -p tmp

record() {
  python3 - "$MAP" "$1" "$2" <<'PYEOF'
import json,sys
m=json.load(open(sys.argv[1])); m[sys.argv[2]]=sys.argv[3]
json.dump(m,open(sys.argv[1],'w'),indent=0)
PYEOF
}

for f in out/*.mp3; do
  slug=$(basename "$f" .mp3)
  if python3 -c "import json,sys;sys.exit(0 if '$slug' in json.load(open('$MAP')) else 1)"; then
    echo "$(date +%H:%M:%S) SKIP $slug" >> "$LOG"; continue
  fi
  title=$(echo "$slug" | sed 's/^[0-9-]*//; s/-/ /g')
  item="edge-esmeralda-2026--${slug}"
  code=$(curl -s --max-time 600 -o /dev/null -w '%{http_code}' \
    -H "x-amz-acl: public-read" -H "x-archive-auto-make-bucket: 1" \
    -H "x-archive-meta-mediatype: audio" \
    -H "x-archive-meta-collection: opensource_audio" \
    -H "x-archive-meta-title: Edge Esmeralda 2026 — ${title}" \
    -H "x-archive-meta-creator: Edge Esmeralda / Shaka Lei Kaumaka" \
    -H "x-archive-meta-description: Session audio from Edge Esmeralda 2026 (Healdsburg, CA). Part of the edgeTV Knowledge Transponder archive. https://edgetv-fnajt22goh-nqfhvcnv.taur.link/" \
    -H "x-archive-meta-subject: Edge Esmeralda; Edge City; popup city; talks; 2026" \
    -H "x-archive-meta-licenseurl: https://creativecommons.org/licenses/by/4.0/" \
    -H "authorization: LOW ${IA_ACCESS}:${IA_SECRET}" \
    --upload-file "$f" \
    "https://s3.us.archive.org/${item}/${slug}.mp3" < /dev/null)
  if [ "$code" != "200" ]; then echo "$(date +%H:%M:%S) UPLOAD-FAIL $slug http=$code" >> "$LOG"; continue; fi
  for p in $(seq 1 12); do
    node=$(curl -sIL --max-time 60 -o /dev/null -w '%{url_effective}' "https://archive.org/download/${item}/${slug}.mp3" < /dev/null)
    code2=$(curl -sIL --max-time 60 -o /dev/null -w '%{http_code}' "$node" < /dev/null)
    [ "$code2" = "200" ] && break
    sleep 20
  done
  if [ "$code2" = "200" ]; then
    record "$slug" "$node"
    echo "$(date +%H:%M:%S) DONE $slug" >> "$LOG"
  else
    echo "$(date +%H:%M:%S) RESOLVE-FAIL $slug" >> "$LOG"
  fi
done
echo "$(date +%H:%M:%S) STAGED-COMPLETE" >> "$LOG"
