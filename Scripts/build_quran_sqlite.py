#!/usr/bin/env python3
"""Rebuild Resources/Quran/quran.sqlite from quran.com API v4.

Preserves verbatim Uthmani text (no normalization). Writes arabic.sha256 sidecar.
Run only when intentionally refreshing the bundle — checksum tests will fail on drift.
"""
from __future__ import annotations

import hashlib
import html
import json
import os
import re
import sqlite3
import sys
import time
import urllib.request

BASE = "https://api.quran.com/api/v4"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "Resources", "Quran", "quran.sqlite")
SHA = os.path.join(ROOT, "Resources", "Quran", "arabic.sha256")
FOOTNOTE = re.compile(r"<[^>]+>")


def get(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": "IqraLockBuild/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode())


def main() -> int:
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    if os.path.exists(OUT):
        os.remove(OUT)

    print("chapters…")
    chapters = get(f"{BASE}/chapters?language=en")["chapters"]
    print("uthmani…")
    uthmani = get(f"{BASE}/quran/verses/uthmani")["verses"]
    print("translations 20…")
    translations = get(f"{BASE}/quran/translations/20?per_page=7000")["translations"]

    page_map = {}
    for ch in range(1, 115):
        page = 1
        while True:
            data = get(f"{BASE}/verses/by_chapter/{ch}?fields=page_number&per_page=50&page={page}")
            for v in data["verses"]:
                page_map[v["verse_key"]] = v["page_number"]
            if not (data.get("pagination") or {}).get("next_page"):
                break
            page = data["pagination"]["next_page"]
        time.sleep(0.05)

    conn = sqlite3.connect(OUT)
    c = conn.cursor()
    c.executescript(
        """
        CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE surahs (
          number INTEGER PRIMARY KEY,
          name_arabic TEXT NOT NULL,
          name_english TEXT NOT NULL,
          name_transliteration TEXT NOT NULL,
          ayah_count INTEGER NOT NULL,
          revelation_place TEXT NOT NULL
        );
        CREATE TABLE ayahs (
          id INTEGER PRIMARY KEY,
          surah INTEGER NOT NULL,
          ayah INTEGER NOT NULL,
          verse_key TEXT NOT NULL UNIQUE,
          text_uthmani TEXT NOT NULL,
          translation_en TEXT NOT NULL,
          page INTEGER NOT NULL,
          UNIQUE(surah, ayah)
        );
        CREATE INDEX idx_ayahs_page ON ayahs(page);
        """
    )

    for ch in chapters:
        c.execute(
            "INSERT INTO surahs VALUES (?,?,?,?,?,?)",
            (
                ch["id"],
                ch["name_arabic"],
                ch["name_simple"],
                (ch.get("translated_name") or {}).get("name") or ch["name_simple"],
                ch["verses_count"],
                ch.get("revelation_place") or "",
            ),
        )

    arabic_concat = []
    for i, v in enumerate(uthmani, start=1):
        vk = v["verse_key"]
        surah, ayah = map(int, vk.split(":"))
        text = v["text_uthmani"]
        arabic_concat.append(text)
        en = FOOTNOTE.sub("", translations[i - 1].get("text") or "")
        en = html.unescape(en).strip()
        c.execute(
            "INSERT INTO ayahs VALUES (?,?,?,?,?,?,?)",
            (i, surah, ayah, vk, text, en, page_map[vk]),
        )

    digest = hashlib.sha256("\n".join(arabic_concat).encode("utf-8")).hexdigest()
    c.execute("INSERT INTO meta VALUES ('arabic_sha256', ?)", (digest,))
    c.execute(
        "INSERT INTO meta VALUES ('arabic_source', ?)",
        ("quran.com API v4 /quran/verses/uthmani (Tanzil Uthmani)",),
    )
    c.execute(
        "INSERT INTO meta VALUES ('translation_source', ?)",
        ("Saheeh International via quran.com resource_id=20",),
    )
    conn.commit()
    conn.close()
    open(SHA, "w").write(digest + "\n")
    print("wrote", OUT, "sha256", digest)
    return 0


if __name__ == "__main__":
    sys.exit(main())
