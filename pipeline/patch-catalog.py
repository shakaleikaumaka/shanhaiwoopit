#!/usr/bin/env python3
"""Patch edgeTV catalog: point hosted audio at archive.org node URLs, enable transponder for all."""
import json, re, os, sys

CAT = '/shared/public/edgetv/data/catalog.json'
MAPS = ['/tmp/audio-staging/map-all.json', '/tmp/audio-staging/map-staged.json'] + [f'/tmp/audio-staging/map{i}.json' for i in range(3)]

nodes = {}
for mp in MAPS:
    if os.path.exists(mp):
        nodes.update(json.load(open(mp)))
print(f"node URLs available: {len(nodes)}")

cat = json.load(open(CAT))

def slugify(t):
    return re.sub(r'[^a-z0-9]+', '-', t.lower()).strip('-')[:58]

# rebuild the exact 107-slug mapping (same logic as shard build)
todo = []
for s in cat:
    if s.get('transponder') or not s.get('transcript'):
        continue
    vids = [m for m in s['media'] if m['kind'] == 'video']
    if not vids:
        continue
    todo.append(s)
todo.sort(key=lambda s: min(m.get('size') or 1e15 for m in s['media'] if m['kind'] == 'video'))
seen = {}
slug_of = {}
for s in todo:
    sl = f"{s.get('date','nodate')}-{slugify(s['title'])}"
    if sl in seen:
        seen[sl] += 1; sl = f"{sl}-{seen[sl]}"
    else:
        seen[sl] = 1
    slug_of[id(s)] = sl

patched_hosted = added_audio = tp_on = 0
for s in cat:
    # 1) swap existing local hosted paths for archive.org node URLs
    for m in s['media']:
        h = m.get('hosted')
        if h and h.startswith('audio/'):
            sl = os.path.basename(h)[:-4]
            if sl in nodes:
                m['hosted'] = nodes[sl]; patched_hosted += 1
    # 2) add hosted audio entries for video-only sessions
    if id(s) in slug_of:
        sl = slug_of[id(s)]
        if sl in nodes and not any(m.get('hosted') for m in s['media']):
            vid = min((m for m in s['media'] if m['kind'] == 'video'), key=lambda m: m.get('size') or 1e15)
            s['media'].append({'id': vid['id'], 'kind': 'audio', 'size': None, 'stream': True, 'hosted': nodes[sl]})
            added_audio += 1
    # 3) no-transcript staged audio sessions (zee prime, consciousness, after party)
    for m in s['media']:
        if m['kind'] == 'audio' and not m.get('hosted'):
            cand = f"{s.get('date','nodate')}-{slugify(s['title'])}"
            hit = nodes.get(cand) or next((v for k, v in nodes.items() if slugify(s['title']) in k), None)
            if hit:
                m['hosted'] = hit; patched_hosted += 1
    # 4) transponder on for everything with transcript + hosted audio
    if s.get('transcript') and any(m.get('hosted') for m in s['media']):
        if not s.get('transponder'):
            tp_on += 1
        s['transponder'] = True

json.dump(cat, open(CAT, 'w'), indent=1)
total_tp = sum(1 for s in cat if s.get('transponder'))
print(f"swapped local->IA: {patched_hosted} · audio entries added: {added_audio} · transponder newly on: {tp_on} · total transponder: {total_tp}/{len(cat)}")
