#!/usr/bin/env python3
"""Converte o dump do catálogo NAPL em um asset embutido no app.

Entrada: o JSON extraído do ZIP público do NAPL
(`napl_catalogo_completo_*.json`, chaves `catalog.games[].ports[]`).

Saída: `assets/catalog/portix_catalog.json` — a forma já indexada que
`lib/data/local_catalog.dart` consome, sem rede e sem servidor.

Uso:
    python3 tools/catalog/build_catalog.py \
        --input /caminho/napl_catalogo_completo_2026-11-22.json \
        --output assets/catalog/portix_catalog.json
"""
from __future__ import annotations

import argparse
import json
import re
import unicodedata
from collections import Counter
from pathlib import Path


def clean(value) -> str:
    if value is None:
        return ""
    return str(value).replace("\u00a0", " ").strip()


def slugify(text: str) -> str:
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    text = re.sub(r"[^a-zA-Z0-9]+", "-", text.lower()).strip("-")
    return text or "unknown"


def year_of(value) -> int | None:
    match = re.match(r"^(\d{4})", clean(value))
    return int(match.group(1)) if match else None


_MONTHS = {
    "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
    "july": 7, "august": 8, "september": 9, "october": 10, "november": 11,
    "december": 12,
}


def date_of(value) -> str | None:
    """Aceita ISO (2026-11-22) e o formato do site ("2026, November 20")."""
    text = clean(value)
    iso = re.match(r"^(\d{4})-(\d{2})-(\d{2})", text)
    if iso:
        return f"{iso.group(1)}-{iso.group(2)}-{iso.group(3)}"
    named = re.match(r"^(\d{4})\s*,\s*([A-Za-z]+)\s*(\d{1,2})?", text)
    if named and named.group(2).lower() in _MONTHS:
        month = _MONTHS[named.group(2).lower()]
        day = int(named.group(3)) if named.group(3) else 1
        return f"{named.group(1)}-{month:02d}-{day:02d}"
    return None


# Plataformas sem console "clássico" recebem selo secundário na UI.
_MULTI = {"multi-game apps"}
_OTHER = {"others", "other"}


def platform_kind(name: str) -> str:
    lowered = name.strip().lower()
    if lowered in _MULTI:
        return "multi"
    if lowered in _OTHER:
        return "other"
    return "console"


def port_of(raw: dict, game_platform: str) -> dict:
    port_id = clean(raw.get("portId")) or clean(raw.get("project"))
    platform = game_platform
    files = clean(raw.get("files"))
    needs_files = bool(re.search(r"need\s*rom", files, re.IGNORECASE))
    source = clean(raw.get("link"))
    return {
        "id": port_id,
        "port_key": port_id,
        "platform_name": platform,
        "platform_slug": slugify(platform),
        "project": clean(raw.get("project")) or None,
        "source": source or None,
        "url": clean(raw.get("url")) or None,
        "data_url": clean(raw.get("dataUrl")) or None,
        "developer": clean(raw.get("developer")) or None,
        "version": clean(raw.get("version")) or None,
        "last_update": date_of(raw.get("lastUpdate")) or None,
        "date_added": date_of(raw.get("dateAdded")) or None,
        "needs_game_files": needs_files,
        "needs_game_files_note": files or None,
        "works": clean(raw.get("works")) or None,
        "controller_support": clean(raw.get("controller")) or None,
        "notes": clean(raw.get("notes")) or None,
        "visits": 0,
    }


def build(document: dict) -> dict:
    games_raw = document.get("catalog", {}).get("games", [])
    games: list[dict] = []
    platform_counts: Counter[str] = Counter()
    genre_counts: Counter[str] = Counter()

    for raw in games_raw:
        slug = clean(raw.get("slug"))
        if not slug:
            continue
        platform = clean(raw.get("platform")) or "Others"
        ports_raw = raw.get("ports") or []
        ports = [port_of(p, platform) for p in ports_raw if isinstance(p, dict)]
        # Porta de `catalog.games[].ports[]` é a fonte canônica.
        ports = [p for p in ports if p["id"]]
        if not ports:
            continue

        developer = next((p["developer"] for p in ports if p["developer"]), None)
        is_free = any(
            (p["source"] or "").lower().startswith(("free", "mirror")) for p in ports
        )
        needs_rom = any(p["needs_game_files"] for p in ports)
        # "Populares": usa a data de adição mais recente como sinal de atividade
        # e a quantidade de ports como peso de relevância.
        latest = max((p["date_added"] or "" for p in ports), default="")
        year = year_of(raw.get("year")) or year_of(ports[0].get("year"))

        genre = clean(raw.get("genre")) or None
        if genre:
            for token in re.split(r"[,/]", genre):
                token = token.strip()
                if token:
                    genre_counts[token] += 1
        platform_counts[platform] += 1

        games.append(
            {
                "id": slug,
                "slug": slug,
                "title": clean(raw.get("name")) or slug,
                "year": year,
                "genre": genre,
                "cover_url": clean(raw.get("coverUrl")) or None,
                "developer": developer,
                "description": clean(raw.get("description")) or "",
                "platforms": [platform],
                "port_count": len(ports),
                "needs_rom": needs_rom,
                "is_free": is_free,
                "released_on": date_of(raw.get("year")) or (f"{year}-01-01" if year else None),
                "latest_activity": latest or None,
                "ports": ports,
            }
        )

    platform_order = document.get("siteInfo", {}).get("platformOrder") or []
    known = set(platform_counts)
    ordered = [p for p in platform_order if p in known] + sorted(known - set(platform_order))
    platforms = [
        {
            "slug": slugify(name),
            "name": name,
            "kind": platform_kind(name),
            "port_count": platform_counts[name],
        }
        for name in ordered
    ]
    genres = [
        {"name": name, "game_count": count}
        for name, count in sorted(genre_counts.items(), key=lambda kv: (-kv[1], kv[0]))
    ]

    return {
        "version": 1,
        "updated_at": document.get("catalog", {}).get("updatedAt")
        or document.get("source", {}).get("extractedAt"),
        "stats": {
            "games": len(games),
            "ports": sum(g["port_count"] for g in games),
            "platforms": len(platforms),
        },
        "platforms": platforms,
        "genres": genres,
        "games": games,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("assets/catalog/portix.json"),
    )
    args = parser.parse_args()

    document = json.loads(args.input.read_text(encoding="utf-8"))
    catalog = build(document)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(catalog, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    stats = catalog["stats"]
    size_mb = args.output.stat().st_size / 1_048_576
    print(
        f"OK: {stats['games']} jogos, {stats['ports']} ports, "
        f"{stats['platforms']} plataformas → {args.output} ({size_mb:.2f} MiB)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
