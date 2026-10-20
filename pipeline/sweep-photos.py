#!/usr/bin/env python3
"""
sweep-photos.py — keep the Living Slideshow growing. 🕳️📸
Run from the repo root: python3 pipeline/sweep-photos.py

What it does:
 1. Pulls the ShanHaiWoo Luma calendar (future + past) and downloads any event
    cover not yet in photos/ (downscaled to 1600px JPEG).
 2. Appends new entries to photos/photos.json with date/chapter/source.
 3. Prints a summary — commit + push by hand (or via the sysadmin's scheduled run).

Also: any image dropped manually into photos/incoming/ gets web-sized, moved
into photos/, and added to the manifest with a stub caption (edit after).
"""
import json, os, re, sys, time, io, urllib.request
from PIL import Image

CAL = "cal-I0HcrjXDeVsmd8g"
API = "https://api.lu.ma/calendar/get-items?calendar_api_id={cal}&period={period}&pagination_limit=50"
UA = {"User-Agent": "Mozilla/5.0 (shanhaipit sweep)"}
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PHOTOS = os.path.join(ROOT, "photos")
MANIFEST = os.path.join(PHOTOS, "photos.json")

def chapter_for(date):
    if date >= "2026-10-15": return "2026 · Shenzhen GBA 深圳"
    if date >= "2026-01": return "2026 · On the road 路上"
    if date >= "2025-01": return "2025 · Singapore 新加坡"
    return "2024 · Chiang Mai 清迈"

def slug(s):
    s = re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")
    return s[:48] or "photo"

def webimg(data, out):
    im = Image.open(io.BytesIO(data)).convert("RGB")
    if im.width > 1600:
        im = im.resize((1600, int(im.height * 1600 / im.width)), Image.LANCZOS)
    im.save(out, "JPEG", quality=84, optimize=True)
    return im.size

def main():
    man = json.load(open(MANIFEST))
    have = {p["src"] for p in man["photos"]}
    added = 0
    for period in ("future", "past"):
        try:
            req = urllib.request.Request(API.format(cal=CAL, period=period), headers=UA)
            d = json.loads(urllib.request.urlopen(req, timeout=30).read())
        except Exception as e:
            print(f"luma {period}: {e}"); continue
        for e in d.get("entries", []):
            ev = e.get("event", {})
            cov, name, start = ev.get("cover_url"), ev.get("name", ""), ev.get("start_at", "")
            if not cov or not start: continue
            date = start[:10]
            fn = f"photos/{date}-{slug(name)}.jpg"
            if fn in have or os.path.exists(os.path.join(ROOT, fn)): continue
            try:
                data = urllib.request.urlopen(urllib.request.Request(cov, headers=UA), timeout=30).read()
                webimg(data, os.path.join(ROOT, fn))
            except Exception as ex:
                print("dl fail", name, ex); continue
            man["photos"].append({"src": fn, "title": name, "title_cn": "",
                                  "date": date, "chapter": chapter_for(date),
                                  "source": "Luma · official event cover"})
            have.add(fn); added += 1; print("➕", fn)
            time.sleep(1)
    # manual drops
    incoming = os.path.join(PHOTOS, "incoming")
    if os.path.isdir(incoming):
        for f in sorted(os.listdir(incoming)):
            if not re.search(r"\.(jpe?g|png|webp|heic)$", f, re.I): continue
            date = time.strftime("%Y-%m-%d")
            fn = f"photos/{date}-{slug(os.path.splitext(f)[0])}.jpg"
            try:
                webimg(open(os.path.join(incoming, f), "rb").read(), os.path.join(ROOT, fn))
                os.remove(os.path.join(incoming, f))
            except Exception as ex:
                print("incoming fail", f, ex); continue
            man["photos"].append({"src": fn, "title": f"ShanHaiWoo — {date} (caption me!)", "title_cn": "",
                                  "date": date, "chapter": chapter_for(date),
                                  "source": "the family's camera roll 📷"})
            added += 1; print("➕ incoming", fn)
    man["updated"] = time.strftime("%Y-%m-%d")
    json.dump(man, open(MANIFEST, "w"), ensure_ascii=False, indent=1)
    print(f"done — {added} new photo(s), manifest now {len(man['photos'])}")

if __name__ == "__main__":
    main()
