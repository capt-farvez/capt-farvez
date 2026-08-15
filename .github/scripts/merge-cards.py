#!/usr/bin/env python3
"""Compose pairs of transparent-background card SVGs into single cards
with one shared background:

  github-stats.svg  + top-languages.svg   -> stats-languages.svg
  github-streak.svg + github-trophies.svg -> streak-trophies.svg

The source cards are fetched with transparent backgrounds, so the wrapper
rect drawn here is the only visible card surface."""
import os
import re

BG = "#1a1b27"


def load(path, suffix):
    with open(path) as f:
        s = f.read().strip()
    s = re.sub(r"<\?xml[^>]*\?>", "", s).strip()
    w = int(re.search(r'width=["\'](\d+)', s).group(1))
    h = int(re.search(r'height=["\'](\d+)', s).group(1))
    # namespace every id so the two embedded documents can't collide
    ids = sorted(set(re.findall(r'\bid=["\']([^"\']+)["\']', s)), key=len, reverse=True)
    for i in ids:
        for q in ('"', "'"):
            s = s.replace(f"id={q}{i}{q}", f"id={q}{i}-{suffix}{q}")
            s = s.replace(f"href={q}#{i}{q}", f"href={q}#{i}-{suffix}{q}")
            s = s.replace(f"aria-labelledby={q}{i}{q}", f"aria-labelledby={q}{i}-{suffix}{q}")
        s = s.replace(f"url(#{i})", f"url(#{i}-{suffix})")
    return s, w, h


def place(svg, x, y):
    return re.sub(r"<svg\b", f'<svg x="{x}" y="{y}"', svg, count=1)


def compose(left_path, right_path, out_path, label):
    if not (os.path.exists(left_path) and os.path.exists(right_path)):
        print(f"WARN: missing input for {out_path} — skipped")
        return
    left, w1, h1 = load(left_path, "l")
    right, w2, h2 = load(right_path, "r")
    W = w1 + w2
    H = max(h1, h2)
    merged = f"""<svg width="{W}" height="{H}" viewBox="0 0 {W} {H}" fill="none" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="{label}">
  <rect width="{W - 1}" height="{H - 1}" x="0.5" y="0.5" rx="4.5" fill="{BG}"/>
  {place(left, 0, (H - h1) // 2)}
  {place(right, w1, (H - h2) // 2)}
</svg>
"""
    with open(out_path, "w") as f:
        f.write(merged)
    print(f"merged card: {W}x{H} -> {out_path}")


compose("assets/github-stats.svg", "assets/top-languages.svg",
        "assets/stats-languages.svg", "GitHub stats and most used languages")
compose("assets/github-streak.svg", "assets/github-trophies.svg",
        "assets/streak-trophies.svg", "GitHub streak and trophies")
