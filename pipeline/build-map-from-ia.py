#!/usr/bin/env python3
"""Rebuild slug->node-URL map from archive.org metadata (source of truth), merge into map-*.json files."""
import json, subprocess, sys, os

def curl(url):
    return subprocess.run(['curl','-s','--max-time','60',url], capture_output=True, text=True).stdout

q = curl('https://archive.org/advancedsearch.php?q=identifier%3Aedge-esmeralda-2026--*&fl%5B%5D=identifier&rows=300&output=json')
ids = [d['identifier'] for d in json.loads(q)['response']['docs']]
print(f"items on archive.org: {len(ids)}")

found = {}
for ident in ids:
    slug = ident.replace('edge-esmeralda-2026--', '', 1)
    try:
        md = json.loads(curl(f'https://archive.org/metadata/{ident}'))
    except Exception:
        continue
    d1, dir_ = md.get('d1'), md.get('dir')
    if not d1 or not dir_:
        continue
    for f in md.get('files', []):
        if f['name'].endswith('.mp3') and f.get('source') == 'original':
            url = f"https://{d1}{dir_}/{f['name']}"
            found[slug] = url
            break

# merge with existing maps
merged = {}
for mp in ['map-staged.json','map0.json','map1.json','map2.json']:
    if os.path.exists(mp):
        merged.update(json.load(open(mp)))
merged.update(found)  # IA metadata wins
json.dump(merged, open('map-all.json','w'), indent=0)
print(f"total slug->node mappings: {len(merged)}")
missing = [i for i in ids if i.replace('edge-esmeralda-2026--','',1) not in merged]
if missing: print("items without mp3 mapping:", missing)
