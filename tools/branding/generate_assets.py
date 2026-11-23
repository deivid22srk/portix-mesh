#!/usr/bin/env python3
"""Gera os PNGs de marca do PORTIX sem dependências externas.

O desenho repete a mesma geometria do `PortixMark` em Flutter
(lib/shared/widgets/app_mark.dart): um portal branco com um núcleo
ciano/violeta. A saída é usada por flutter_launcher_icons e
flutter_native_splash no CI.
"""

from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

Color = tuple[float, float, float]

BG_TOP = (0x0A / 255, 0x0A / 255, 0x16 / 255)
BG_BOTTOM = (0x06 / 255, 0x06 / 255, 0x0C / 255)
VIOLET = (0x8B / 255, 0x5C / 255, 0xFF / 255)
CYAN = (0x22 / 255, 0xD3 / 255, 0xEE / 255)
ARCH_TOP = (1.0, 1.0, 1.0)
ARCH_BOTTOM = (0xD8 / 255, 0xDD / 255, 0xFF / 255)

OUTER = (0.15, 0.10, 0.70, 0.78, 0.30)
INNER = (0.31, 0.30, 0.38, 0.70, 0.17)
ORB_CENTER = (0.50, 0.42)
ORB_RADIUS = 0.105


def _mix(a: Color, b: Color, t: float) -> Color:
    t = min(1.0, max(0.0, t))
    return (
        a[0] + (b[0] - a[0]) * t,
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
    )


def _inside_rrect(
    x: float, y: float, rect: tuple[float, float, float, float, float]
) -> bool:
    left, top, width, height, radius = rect
    cx = left + width / 2
    cy = top + height / 2
    dx = abs(x - cx) - (width / 2 - radius)
    dy = abs(y - cy) - (height / 2 - radius)
    dx = max(dx, 0.0)
    dy = max(dy, 0.0)
    return math.hypot(dx, dy) <= radius


def _blend(base: tuple[float, float, float, float], top: tuple[float, float, float, float]):
    ba = base[3]
    ta = top[3]
    out_a = ta + ba * (1 - ta)
    if out_a <= 0:
        return (0.0, 0.0, 0.0, 0.0)
    return (
        (top[0] * ta + base[0] * ba * (1 - ta)) / out_a,
        (top[1] * ta + base[1] * ba * (1 - ta)) / out_a,
        (top[2] * ta + base[2] * ba * (1 - ta)) / out_a,
        out_a,
    )


def _mark_sample(x: float, y: float, background: bool) -> tuple[float, float, float, float]:
    if background:
        base = (*_mix(BG_TOP, BG_BOTTOM, (x + y) / 2), 1.0)
        glow = max(0.0, 1.0 - math.hypot(x - 0.18, y - 0.12) / 0.72)
        if glow > 0:
            base = _blend(base, (*VIOLET, 0.22 * glow * glow))
        glow = max(0.0, 1.0 - math.hypot(x - 0.86, y - 0.88) / 0.58)
        if glow > 0:
            base = _blend(base, (*CYAN, 0.16 * glow * glow))
    else:
        base = (0.0, 0.0, 0.0, 0.0)

    # Halo do núcleo, atrás do arco.
    orb_distance = math.hypot(x - ORB_CENTER[0], y - ORB_CENTER[1])
    halo_radius = ORB_RADIUS * 2.2
    if orb_distance < halo_radius:
        strength = 1.0 - orb_distance / halo_radius
        tone = _mix(CYAN, VIOLET, (x + y) / 2)
        base = _blend(base, (*tone, 0.18 * strength * strength * strength))

    if _inside_rrect(x, y, OUTER) and not _inside_rrect(x, y, INNER):
        base = _blend(base, (*_mix(ARCH_TOP, ARCH_BOTTOM, (x + y) / 2), 1.0))

    if orb_distance < ORB_RADIUS * 2.0:
        strength = max(0.0, 1.0 - orb_distance / (ORB_RADIUS * 2.0))
        base = _blend(base, (*CYAN, 0.28 * strength * strength))
    if orb_distance <= ORB_RADIUS:
        tone = _mix(CYAN, VIOLET, ((x - (ORB_CENTER[0] - ORB_RADIUS)) / (ORB_RADIUS * 2)))
        base = _blend(base, (*tone, 1.0))
    return base


def _render(
    size: int,
    background: bool,
    scale: float,
    samples: int = 2,
) -> bytes:
    pixels = bytearray(size * size * 4)
    offset = (1.0 - scale) / 2
    weight = 1.0 / (samples * samples)
    for py in range(size):
        for px in range(size):
            r = g = b = a = 0.0
            for sy in range(samples):
                for sx in range(samples):
                    u = (px * samples + sx + 0.5) / (size * samples)
                    v = (py * samples + sy + 0.5) / (size * samples)
                    mx = (u - offset) / scale
                    my = (v - offset) / scale
                    if 0.0 <= mx <= 1.0 and 0.0 <= my <= 1.0:
                        sr, sg, sb, sa = _mark_sample(mx, my, background)
                    elif background:
                        base = _mix(BG_TOP, BG_BOTTOM, (u + v) / 2)
                        sr, sg, sb, sa = (*base, 1.0)
                    else:
                        sr = sg = sb = sa = 0.0
                    r += sr * sa
                    g += sg * sa
                    b += sb * sa
                    a += sa
            index = (py * size + px) * 4
            if a <= 0:
                pixels[index] = 0
                pixels[index + 1] = 0
                pixels[index + 2] = 0
                pixels[index + 3] = 0
            else:
                pixels[index] = int(round(min(1.0, r / a) * 255))
                pixels[index + 1] = int(round(min(1.0, g / a) * 255))
                pixels[index + 2] = int(round(min(1.0, b / a) * 255))
                pixels[index + 3] = int(round(min(1.0, a * weight) * 255))
    return bytes(pixels)


def _chunk(tag: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + tag
        + payload
        + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
    )


def write_png(path: Path, size: int, pixels: bytes) -> None:
    stride = size * 4
    raw = bytearray()
    for row in range(size):
        raw.append(0)
        raw.extend(pixels[row * stride : (row + 1) * stride])
    header = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    payload = (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", header)
        + _chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + _chunk(b"IEND", b"")
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    assets = root / "assets" / "branding"

    write_png(assets / "icon.png", 1024, _render(1024, background=True, scale=0.92))
    write_png(
        assets / "icon_foreground.png",
        1024,
        _render(1024, background=False, scale=0.64),
    )
    write_png(
        assets / "splash_logo.png",
        768,
        _render(768, background=False, scale=0.68),
    )
    print("Branding PNGs gerados em", assets)


if __name__ == "__main__":
    main()
