#!/bin/bash
id="$1"; name="$2"
[ -f "out/${name}.mp3" ] && { echo "SKIP $name"; exit 0; }
ok=0
for attempt in 1 2 3; do
  html=$(curl -sL --max-time 60 "https://drive.google.com/uc?export=download&id=${id}" < /dev/null)
  uuid=$(printf '%s' "$html" | grep -oE 'name="uuid" value="[^"]*"' | head -1 | sed 's/.*value="//;s/"//')
  if [ -n "$uuid" ]; then
    curl -sL --max-time 300 "https://drive.usercontent.google.com/download?id=${id}&export=download&confirm=t&uuid=${uuid}" -o "raw/${id}.bin" < /dev/null 2>/dev/null
  else
    curl -sL --max-time 300 "https://drive.usercontent.google.com/download?id=${id}&export=download&confirm=t" -o "raw/${id}.bin" < /dev/null 2>/dev/null
  fi
  ftype=$(file -b "raw/${id}.bin" 2>/dev/null)
  case "$ftype" in
    *Audio*|*"ISO Media"*|*MPEG*|*audio*|*MP4*) ok=1; break;;
    *) rm -f "raw/${id}.bin"; sleep $((attempt*4));;
  esac
done
if [ "$ok" = "1" ]; then
  ffmpeg -y -i "raw/${id}.bin" -vn -ac 1 -b:a 64k -codec:a libmp3lame "out/${name}.mp3" > /dev/null 2>&1 \
    && echo "OK   ${name}" || { echo "FFAIL ${name}"; rm -f "out/${name}.mp3"; }
else
  echo "DLFAIL ${name}"
fi
rm -f "raw/${id}.bin"
