#!/usr/bin/env python3
"""Assign hosted audio paths to catalog sessions whose mp3 has landed."""
import json, os

CAT = '/shared/public/edgetv/data/catalog.json'
OUT = '/shared/public/edgetv/audio'
slug2sess = json.load(open('/tmp/audio-staging/slug2session.json'))  # slug -> session idx
id2slug = json.load(open('/tmp/audio-staging/id2slug-all.json'))     # media id -> slug

cat = json.load(open(CAT))
have = {f[:-4] for f in os.listdir(OUT) if f.endswith('.mp3')}
assigned = 0
for s in cat:
    # prefer the audio-entry slug, else video-entry slug — whichever file exists
    cands = [m for m in s['media'] if m['kind'] == 'audio'] + [m for m in s['media'] if m['kind'] == 'video']
    path = None
    for m in cands:
        slug = id2slug.get(m['id'])
        if slug and slug in have:
            path = f"audio/{slug}.mp3"
            break
    # set hosted on the primary entry (the one pickMedia chooses)
    if path:
        vids = [m for m in s['media'] if m['kind'] == 'video']
        auds = [m for m in s['media'] if m['kind'] == 'audio']
        primary = (auds[0] if (s.get('quality') == 'failed' and auds) else (vids[0] if vids else auds[0] if auds else s['media'][0]))
        if primary.get('hosted') != path:
            primary['hosted'] = path
            assigned += 1
json.dump(cat, open(CAT, 'w'), ensure_ascii=False, separators=(',', ':'))
print(f"hosted assigned on {assigned} sessions ({len(have)} mp3s on disk)")
