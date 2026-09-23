#!/bin/bash
cd /tmp/audio-staging
for pass in $(seq 1 40); do
  remaining=$(python3 - <<'PY'
import json, os
OUT='/shared/public/edgetv/audio'
have = {f[:-4] for f in os.listdir(OUT) if f.endswith('.mp3')}
t = json.load(open('todo-local.json')) + json.load(open('todo-whales.json'))
seen=set(); total=[]
for x in t:
    if x['slug'] not in seen: seen.add(x['slug']); total.append(x)
print(sum(1 for x in total if x['slug'] not in have))
PY
)
  echo "$(date +%m-%d %H:%M) PASS $pass — $remaining remaining" >> retry.log
  [ "$remaining" = "0" ] && break
  while pgrep -f "worker-v2.sh|whale-streamer.sh" > /dev/null; do sleep 60; done
  for k in 0 1 2 3; do setsid nohup ./worker-v2.sh v2-shard$k.json v2w$k.log > /dev/null 2>&1 & done
  setsid nohup ./whale-streamer.sh whale-shard0.json whale0.log > /dev/null 2>&1 &
  setsid nohup ./whale-streamer.sh whale-shard1.json whale1.log > /dev/null 2>&1 &
  # backoff: let quota walls breathe between passes
  sleep 900
done
echo "$(date +%m-%d %H:%M) RETRY-LOOP-END" >> retry.log
