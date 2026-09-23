#!/bin/bash
# Keeps 3 shard workers alive until every shard slug has a node URL in its map.
cd /tmp/audio-staging
# Internet Archive S3 keys — env-only, never hardcode. Get yours at archive.org/account/s3.php
: "${IA_ACCESS:?set IA_ACCESS}"; : "${IA_SECRET:?set IA_SECRET}"
export IA_ACCESS IA_SECRET
pass=0
while true; do
  remaining=$(python3 -c "
import json, os
slugs=set()
for i in range(3):
    slugs |= {t['slug'] for t in json.load(open(f'shard{i}.json'))}
maps={}
for i in range(3):
    p=f'map{i}.json'
    if os.path.exists(p): maps.update(json.load(open(p)))
print(len(slugs - set(maps)))")
  if [ "$remaining" = "0" ]; then
    echo "$(date +%H:%M:%S) ALL SHARDS COMPLETE" >> supervisor.log
    break
  fi
  pass=$((pass+1))
  for i in 0 1 2; do
    if ! pgrep -f "worker.sh shard$i" > /dev/null; then
      echo "$(date +%H:%M:%S) pass$pass relaunch shard$i ($remaining remaining)" >> supervisor.log
      setsid nohup ./worker.sh shard$i.json map$i.json worker$i.log > /dev/null 2>&1 < /dev/null &
      sleep 20
    fi
  done
  sleep 300
done
