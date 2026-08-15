#!/usr/bin/env python3
"""Compose the stats and top-languages SVGs into a single card with one
shared background (assets/stats-languages.svg). Both source cards are
fetched with a transparent background (bg_color=00000000), so the wrapper
rect here is the only visible card surface."""
import re

GAP = 0
BG = "#1a1b27"


def load(path, suffix):
    s = open(path).read().strip()
    w = int(re.search(r'width="(\d+)"', s).group(1))
    h = int(re.search(r'height="(\d+)"', s).group(1))
    # avoid duplicate element ids between the two embedded documents
    s = s.replace("titleId", f"titleId-{suffix}").replace("descId", f"descId-{suffix}")
    return s, w, h


def place(svg, x, y):
    return re.sub(r"<svg\b", f'<svg x="{x}" y="{y}"', svg, count=1)


stats, w1, h1 = load("assets/github-stats.svg", "stats")
langs, w2, h2 = load("assets/top-languages.svg", "langs")

W = w1 + GAP + w2
H = max(h1, h2)

merged = f"""<svg width="{W}" height="{H}" viewBox="0 0 {W} {H}" fill="none" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="GitHub stats and most used languages">
  <rect width="{W - 1}" height="{H - 1}" x="0.5" y="0.5" rx="4.5" fill="{BG}"/>
  {place(stats, 0, (H - h1) // 2)}
  {place(langs, w1 + GAP, (H - h2) // 2)}
</svg>
"""

with open("assets/stats-languages.svg", "w") as f:
    f.write(merged)
print(f"merged card: {W}x{H} -> assets/stats-languages.svg")
