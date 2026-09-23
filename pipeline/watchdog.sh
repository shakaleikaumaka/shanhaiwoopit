#!/bin/bash
# relaunch any lane that dies before SHARD-COMPLETE, until all done
cd /tmp/audio-staging
for round in $(seq 1 60); do
  alive=0
  for k in 0 1 2; do
    if ! grep -q "SHARD-COMPLETE" rc3w$k.log 2>/dev/null; then
      alive=1
      pgrep -f "rclone-worker.sh rc-shard$k.json" > /dev/null || {
        echo "$(date +%H:%M:%S) WATCHDOG relaunch shard$k" >> watchdog.log
        # clean stale claims from the dead lane
        setsid nohup ./rclone-worker.sh rc-shard$k.json rc3w$k.log > /dev/null 2>&1 &
      }
    fi
  done
  [ "$alive" = "0" ] && { echo "$(date +%H:%M:%S) WATCHDOG all complete" >> watchdog.log; break; }
  sleep 300
done
