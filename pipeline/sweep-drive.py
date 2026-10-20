#!/usr/bin/env python3
"""
sweep-drive.py — pull the family's Google Drive album into the Living Slideshow. 🕳️📸
Run from the repo root:  python3 pipeline/sweep-drive.py

Shaka's shared Drive folder (date-named subfolders of camera photos) is the
source of truth. Because the originals are ~12MB each and number in the
hundreds, we curate: ALL files from folders containing "retouch", plus an
evenly-spaced sample of up to SAMPLE_PER_DAY per date folder. Everything is
downscaled to <=1400px JPEG and self-hosted in photos/drive/ (Cloudflare edge
→ loads inside China, unlike Drive hotlinks). Idempotent: already-imported
frames are skipped, so new Drive folders/days just flow in on the next run.
"""
import io, json, os, re, sys, time

FOLDER = "https://drive.google.com/drive/folders/1S4GlQFN51zRkNaNxaOYMhmONnrfXaJxo"
SAMPLE_PER_DAY = 25
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST = os.path.join(ROOT, "photos", "photos.json")
OUTDIR = os.path.join(ROOT, "photos", "drive")

import gdown
from PIL import Image

def folder_meta(folder):
    f = folder.lower()
    m = re.search(r"10\D{0,2}17|1017", f)
    if "retouch" in f:
        return ("2026-10-17", "Opening Ceremony — retouched picks ✨", "开幕式精修", True)
    if m:
        return ("2026-10-17", "Opening Ceremony & Woocon 0 Town Hall", "山海坞2026开幕式 · 坞民大会 0", False)
    if re.search(r"10\D{0,2}19|1019", f):
        return ("2026-10-19", "ShanHaiWoo Livehouse with Shaka 🎸", "山海坞 Livehouse × Shaka", False)
    m2 = re.search(r"(1[0-2]|0?[1-9])\D{0,2}([0-3]?\d)", f)
    if m2:
        date = f"2026-{int(m2.group(1)):02d}-{int(m2.group(2)):02d}"
        return (date, f"ShanHaiWoo — {folder}", "", False)
    return ("2026-10", f"ShanHaiWoo — {folder}", "", False)

def main():
    man = json.load(open(MANIFEST))
    have = {p["src"] for p in man["photos"]}
    os.makedirs(OUTDIR, exist_ok=True)
    files = gdown.download_folder(FOLDER, skip_download=True, quiet=True)
    bydir = {}
    for f in files:
        p = str(f.path).replace("\\", "/")
        if not re.search(r"\.(jpe?g|png|webp)$", p, re.I):
            continue
        d = p.split("/")[-2] if "/" in p else "(root)"
        bydir.setdefault(d, []).append((p.split("/")[-1], f.id))
    added = 0
    for folder, items in sorted(bydir.items()):
        items.sort()
        date, ten, tcn, take_all = folder_meta(folder)
        if take_all or len(items) <= SAMPLE_PER_DAY:
            chosen = items
        else:  # deterministic even spacing → idempotent reruns
            step = len(items) / SAMPLE_PER_DAY
            chosen = [items[int(i * step)] for i in range(SAMPLE_PER_DAY)]
        for name, fid in chosen:
            base = re.sub(r"[^a-z0-9]+", "-", os.path.splitext(name)[0].lower()).strip("-")
            src = f"photos/drive/{date}-{base}.jpg"
            out = os.path.join(ROOT, src)
            if src in have or os.path.exists(out):
                continue
            tmp = os.path.join(OUTDIR, ".tmp-dl")
            try:
                gdown.download(id=fid, output=tmp, quiet=True)
                im = Image.open(tmp).convert("RGB")
                if im.width > 1400:
                    im = im.resize((1400, int(im.height * 1400 / im.width)), Image.LANCZOS)
                im.save(out, "JPEG", quality=82, optimize=True)
            except Exception as e:
                print("fail", name, e)
                continue
            finally:
                if os.path.exists(tmp):
                    os.remove(tmp)
            man["photos"].append({
                "src": src, "title": ten, "title_cn": tcn, "date": date,
                "chapter": "2026 · Shenzhen GBA 深圳",
                "source": f"the family's Drive 📷 · {name}"})
            have.add(src)
            added += 1
            print("➕", src)
            time.sleep(0.4)
    man["updated"] = time.strftime("%Y-%m-%d")
    json.dump(man, open(MANIFEST, "w"), ensure_ascii=False, indent=1)
    print(f"done — {added} new photo(s), manifest now {len(man['photos'])}")

if __name__ == "__main__":
    main()
