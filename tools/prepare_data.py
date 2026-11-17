#!/usr/bin/env python3
"""
Prepare data for Wird (وِرد) Quran app.

Downloads:
  1. Quran text (Uthmani) from AlQuran Cloud - edition quran-uthmani
     GET https://api.alquran.cloud/v1/quran/quran-uthmani
  2. Tanzil metadata (per-surah ayah counts)
     https://tanzil.net/res/text/metadata/quran-data.xml
  3. Per-ayah timings for reciter 13 (الشيخ الزين محمد أحمد) from mp3quran
     GET https://www.mp3quran.net/api/v3/ayat_timing?read=13&sura=N
     for N = 1..114, returns [{ayah, start_time, end_time, ...}] in ms

Verifies (fails loudly, non-zero exit, on any mismatch):
  - 114 surahs
  - 6236 ayahs total
  - per-surah ayah counts == Tanzil metadata
  - timing count per surah == ayah count (and ayah numbers sequential)

Outputs (compact JSON, UTF-8, ensure_ascii=False):
  assets/data/quran.json
    {"surahs":[{"number":..,"name":..,"englishName":..,
                "englishNameTranslation":..,"revelationType":..,
                "ayahs":[{"numberInSurah":..,"text":..,"juz":..,"page":..,
                          "hizbQuarter":..,"ruku":..}]}]}
  assets/data/timings.json
    {"1":[{"ayah":1,"start":0,"end":1234},...], "2":[...], ...}

Notes:
  - Strips BOM U+FEFF at the start of Al-Fatiha ayah 1 if present (it is
    present in the upstream AlQuran Cloud payload) and reports it.
  - Uses only Python stdlib (urllib, json, xml). Retries with backoff.
"""

import json
import sys
import time
import urllib.request
import urllib.error
import xml.etree.ElementTree as ET
from pathlib import Path

QURAN_URL = "https://api.alquran.cloud/v1/quran/quran-uthmani"
METADATA_URL = "https://tanzil.net/res/text/metadata/quran-data.xml"
TIMING_URL_TEMPLATE = "https://www.mp3quran.net/api/v3/ayat_timing?read=13&sura={n}"

EXPECTED_SURAHS = 114
EXPECTED_AYAHS = 6236
BOM = "\ufeff"

PROJECT_ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = PROJECT_ROOT / "assets" / "data"
QURAN_OUT = OUT_DIR / "quran.json"
TIMINGS_OUT = OUT_DIR / "timings.json"

HEADERS = {"User-Agent": "Wird-PrepareData/1.0 (stdlib urllib)"}


def fetch_bytes(url: str, retries: int = 4, timeout: int = 60) -> bytes:
    """GET url with retries and exponential backoff. Raises on final failure."""
    last_err = None
    for attempt in range(1, retries + 1):
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return resp.read()
        except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, OSError) as e:
            last_err = e
            wait = 2 ** (attempt - 1)
            print(f"  [retry {attempt}/{retries}] {url} -> {e}; waiting {wait}s", file=sys.stderr)
            if attempt < retries:
                time.sleep(wait)
    raise RuntimeError(f"Failed to fetch {url} after {retries} attempts: {last_err}")


def fetch_json(url: str, retries: int = 4, timeout: int = 60):
    raw = fetch_bytes(url, retries=retries, timeout=timeout)
    return json.loads(raw.decode("utf-8"))


def fail(errors: list[str]) -> None:
    print("\nVERIFICATION FAILED:", file=sys.stderr)
    for e in errors:
        print(f"  - {e}", file=sys.stderr)
    sys.exit(1)


def main() -> int:
    errors: list[str] = []
    notes: list[str] = []

    print("== Wird prepare_data ==")
    print(f"Project root: {PROJECT_ROOT}")

    # ---- 1. Quran text ----
    print(f"\n[1/3] Downloading Quran text: {QURAN_URL}")
    quran_payload = fetch_json(QURAN_URL)
    data = quran_payload.get("data") or {}
    edition = (data.get("edition") or {}).get("identifier")
    print(f"  edition identifier: {edition}")
    if edition != "quran-uthmani":
        errors.append(f"Unexpected edition identifier: {edition!r} (expected 'quran-uthmani')")
    raw_surahs = data.get("surahs") or []

    # ---- 2. Tanzil metadata ----
    print(f"\n[2/3] Downloading Tanzil metadata: {METADATA_URL}")
    meta_raw = fetch_bytes(METADATA_URL)
    # Tanzil file may start with BOM / whitespace; ET handles utf-8 declared XML.
    meta_text = meta_raw.decode("utf-8-sig")
    root = ET.fromstring(meta_text)
    meta_counts: dict[int, int] = {}
    # Structure: <quran><suras><sura index="1" ayas="7" .../></suras>...</quran>
    for elem in root.iter("sura"):
        idx = elem.get("index")
        ayas = elem.get("ayas")
        if idx is not None and ayas is not None:
            meta_counts[int(idx)] = int(ayas)
    print(f"  metadata surahs parsed: {len(meta_counts)}")
    if len(meta_counts) != EXPECTED_SURAHS:
        errors.append(f"Metadata has {len(meta_counts)} surahs, expected {EXPECTED_SURAHS}")
    meta_total = sum(meta_counts.values())
    print(f"  metadata total ayahs: {meta_total}")
    if meta_total != EXPECTED_AYAHS:
        errors.append(f"Metadata total ayahs {meta_total} != {EXPECTED_AYAHS}")

    # ---- Build compact quran structure + BOM handling ----
    bom_stripped_fatiha = False
    bom_stripped_elsewhere = 0
    surahs_out = []
    total_ayahs = 0
    per_surah_counts: dict[int, int] = {}

    for s in raw_surahs:
        number = s.get("number")
        ayahs_out = []
        for a in s.get("ayahs") or []:
            text = a.get("text") or ""
            # Strip leading BOM(s)
            if text.startswith(BOM):
                text = text.lstrip(BOM)
                if number == 1 and a.get("numberInSurah") == 1:
                    bom_stripped_fatiha = True
                else:
                    bom_stripped_elsewhere += 1
            ayahs_out.append({
                "numberInSurah": a.get("numberInSurah"),
                "text": text,
                "juz": a.get("juz"),
                "page": a.get("page"),
                "hizbQuarter": a.get("hizbQuarter"),
                "ruku": a.get("ruku"),
            })
        per_surah_counts[number] = len(ayahs_out)
        total_ayahs += len(ayahs_out)
        surahs_out.append({
            "number": number,
            "name": s.get("name"),
            "englishName": s.get("englishName"),
            "englishNameTranslation": s.get("englishNameTranslation"),
            "revelationType": s.get("revelationType"),
            "ayahs": ayahs_out,
        })

    if bom_stripped_fatiha:
        msg = "BOM U+FEFF found at start of Al-Fatiha ayah 1 and stripped."
        notes.append(msg)
        print(f"  NOTE: {msg}")
    else:
        print("  NOTE: No BOM at start of Al-Fatiha ayah 1.")
    if bom_stripped_elsewhere:
        msg = f"BOM also stripped from {bom_stripped_elsewhere} other ayah(s)."
        notes.append(msg)
        print(f"  NOTE: {msg}")

    # ---- Verify quran counts ----
    print("\nVerifying Quran text...")
    print(f"  surahs: {len(surahs_out)} (expected {EXPECTED_SURAHS})")
    print(f"  total ayahs: {total_ayahs} (expected {EXPECTED_AYAHS})")
    if len(surahs_out) != EXPECTED_SURAHS:
        errors.append(f"Quran surah count {len(surahs_out)} != {EXPECTED_SURAHS}")
    if total_ayahs != EXPECTED_AYAHS:
        errors.append(f"Quran total ayahs {total_ayahs} != {EXPECTED_AYAHS}")
    for n in range(1, EXPECTED_SURAHS + 1):
        qc = per_surah_counts.get(n)
        mc = meta_counts.get(n)
        if qc is None:
            errors.append(f"Surah {n}: missing from Quran payload")
        elif mc is None:
            errors.append(f"Surah {n}: missing from Tanzil metadata")
        elif qc != mc:
            errors.append(f"Surah {n}: quran ayah count {qc} != metadata {mc}")
    mismatches = [n for n in range(1, 115) if per_surah_counts.get(n) != meta_counts.get(n)]
    print(f"  per-surah count mismatches vs metadata: {len(mismatches)} {mismatches if mismatches else ''}")

    # ---- 3. Timings ----
    print(f"\n[3/3] Downloading timings for 114 surahs (read=13): {TIMING_URL_TEMPLATE}")
    timings_out: dict[str, list] = {}
    timing_total = 0
    timing_mismatches: list[int] = []
    for n in range(1, EXPECTED_SURAHS + 1):
        url = TIMING_URL_TEMPLATE.format(n=n)
        payload = fetch_json(url)
        if not isinstance(payload, list):
            errors.append(f"Surah {n}: timing payload is not a list (got {type(payload).__name__})")
            payload = []
        entries = []
        for item in payload:
            entries.append({
                "ayah": item.get("ayah"),
                "start": item.get("start_time"),
                "end": item.get("end_time"),
            })
        timings_out[str(n)] = entries
        timing_total += len(entries)
        expected = per_surah_counts.get(n)
        if len(entries) != expected:
            timing_mismatches.append(n)
            errors.append(f"Surah {n}: timing count {len(entries)} != ayah count {expected}")
        # Sequential ayah numbers check
        for i, e in enumerate(entries, start=1):
            if e["ayah"] != i:
                errors.append(f"Surah {n}: timing entry #{i} has ayah={e['ayah']} (not sequential)")
                break
            if e["start"] is None or e["end"] is None:
                errors.append(f"Surah {n} ayah {i}: missing start_time/end_time")
                break
        if n % 10 == 0 or n == 1:
            print(f"  surah {n}/114: {len(entries)} timings")

    print(f"  timings total entries: {timing_total}")
    print(f"  timing count mismatches: {len(timing_mismatches)} {timing_mismatches if timing_mismatches else ''}")

    if errors:
        fail(errors)

    # ---- Write outputs ----
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    quran_obj = {"surahs": surahs_out}
    with open(QURAN_OUT, "w", encoding="utf-8") as f:
        json.dump(quran_obj, f, ensure_ascii=False, separators=(",", ":"))
    with open(TIMINGS_OUT, "w", encoding="utf-8") as f:
        json.dump(timings_out, f, ensure_ascii=False, separators=(",", ":"))

    quran_size = QURAN_OUT.stat().st_size
    timings_size = TIMINGS_OUT.stat().st_size

    print("\n=== VERIFICATION SUMMARY ===")
    print(f"Surahs: {len(surahs_out)} / {EXPECTED_SURAHS} OK")
    print(f"Total ayahs: {total_ayahs} / {EXPECTED_AYAHS} OK")
    print(f"Per-surah counts vs Tanzil metadata: 0 mismatches OK")
    print(f"Metadata total ayahs: {meta_total} OK")
    print(f"Timings: {timing_total} entries across 114 surahs, 0 mismatches OK")
    print(f"Edition: {edition}")
    for note in notes:
        print(f"Note: {note}")
    print(f"Output: {QURAN_OUT} ({quran_size} bytes)")
    print(f"Output: {TIMINGS_OUT} ({timings_size} bytes)")
    print("ALL CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
