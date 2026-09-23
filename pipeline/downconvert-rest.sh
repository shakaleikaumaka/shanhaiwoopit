#!/bin/bash
OUT=/shared/public/edgetv/audio
for f in /tmp/audio-staging/out/*.mp3; do
  slug=$(basename "$f" .mp3)
  [ -f "$OUT/$slug.mp3" ] || ffmpeg -hide_banner -loglevel error -y -i "$f" -ac 1 -b:a 32k -codec:a libmp3lame "$OUT/$slug.mp3" < /dev/null
done
echo "downconvert complete: $(ls $OUT | wc -l) files"
