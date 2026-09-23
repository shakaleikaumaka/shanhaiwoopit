#!/bin/bash
# Usage: IA_ACCESS=xxx IA_SECRET=yyy ./upload-to-archive.sh
# Creates one archive.org item per session under collection opensource_audio
ITEM_PREFIX="edge-esmeralda-2026"
cd /tmp/audio-staging
for f in out/*.mp3; do
  base=$(basename "$f" .mp3)
  item="${ITEM_PREFIX}--${base}"
  title=$(echo "$base" | sed 's/^[0-9-]*//; s/-/ /g')
  echo "→ uploading $base"
  curl -s --retry 3 \
    -H "x-amz-acl: public-read" \
    -H "x-archive-meta-mediatype: audio" \
    -H "x-archive-meta-collection: opensource_audio" \
    -H "x-archive-meta-title: Edge Esmeralda 2026 — ${title}" \
    -H "x-archive-meta-creator: Edge Esmeralda / Shaka Lei Kaumaka" \
    -H "x-archive-meta-description: Session audio from Edge Esmeralda 2026 (Healdsburg, CA). Part of the edgeTV Knowledge Transponder — an open archive of village talks. https://edgetv-fnajt22goh-nqfhvcnv.taur.link/" \
    -H "x-archive-meta-subject: Edge Esmeralda; Edge City; popup city; talks; 2026" \
    -H "x-archive-meta-licenseurl: https://creativecommons.org/licenses/by/4.0/" \
    -H "authorization: LOW ${IA_ACCESS}:${IA_SECRET}" \
    --upload-file "$f" \
    "https://s3.us.archive.org/${item}/${base}.mp3" > /dev/null
done
echo "ALL UPLOADED"
