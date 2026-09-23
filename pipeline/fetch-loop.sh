#!/bin/bash
cd /tmp/audio-staging
while IFS=$'\t' read -r id name; do
  [ -f "out/${name}.mp3" ] && continue
  ok=0
  for attempt in 1 2 3; do
    html=$(curl -sL --max-time 60 "https://drive.google.com/uc?export=download&id=${id}" < /dev/null)
    uuid=$(echo "$html" | grep -oE 'name="uuid" value="[^"]*"' | head -1 | sed 's/.*value="//;s/"//')
    if [ -n "$uuid" ]; then
      curl -sL --max-time 300 "https://drive.usercontent.google.com/download?id=${id}&export=download&confirm=t&uuid=${uuid}" -o "raw/${id}.bin" 2>/dev/null < /dev/null
    else
      curl -sL --max-time 300 "https://drive.usercontent.google.com/download?id=${id}&export=download&confirm=t" -o "raw/${id}.bin" 2>/dev/null < /dev/null
    fi
    ftype=$(file -b "raw/${id}.bin" 2>/dev/null)
    case "$ftype" in
      *Audio*|*"ISO Media"*|*MPEG*|*audio*|*MP4*) ok=1; break;;
      *) rm -f "raw/${id}.bin"; sleep $((attempt*5));;
    esac
  done
  if [ "$ok" = "1" ]; then
    ffmpeg -y -i "raw/${id}.bin" -vn -ac 1 -b:a 64k -codec:a libmp3lame "out/${name}.mp3" > /dev/null 2>&1 \
      && echo "OK   ${name}" || echo "FFAIL ${name}"
  else
    echo "DLFAIL ${name}"
  fi
  rm -f "raw/${id}.bin"
done < missing2.txt
echo "LOOP-DONE"
