"""Builds the Google Play feature graphic (1024x500) from a ThingSpeak field export.

The curve is real data: docs/screenshots/feature_graphic.png uses 24 hours of temperature from the public channel 357142 (Air quality with SDS011).

    curl -sS "https://api.thingspeak.com/channels/357142/fields/3.json?results=150" -o temp.json
    python3 tool/make_feature_graphic.py temp.json field3 feature.html "#FFFFFF" "Your ThingSpeak™ data at a glance"
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars \
        --force-device-scale-factor=1 --window-size=1024,500 --virtual-time-budget=4000 \
        --screenshot=raw.png "file://$PWD/feature.html"
    magick raw.png -background "#067BC2" -alpha remove -alpha off PNG24:docs/screenshots/feature_graphic.png

Play rejects PNGs with an alpha channel, hence the last step.
"""
import json
import math
import sys

W, H = 1024, 500
TOP, BOTTOM = 250, 440  # vertical band the line occupies

src, key, out = sys.argv[1], sys.argv[2], sys.argv[3]
line_colour = sys.argv[4] if len(sys.argv) > 4 else "#FFFFFF"
subtitle = sys.argv[5] if len(sys.argv) > 5 else ""

feeds = json.load(open(src))["feeds"]
values = [float(f[key]) for f in feeds if f.get(key) not in (None, "")]

# Play warns against fine detail, so the curve keeps only the day's overall shape: a Gaussian blur, then a spline through a handful of evenly spaced samples.
SIGMA = len(values) / 25
KNOTS = 16
smooth = []
for i in range(len(values)):
    weights = [math.exp(-((j - i) ** 2) / (2 * SIGMA**2)) for j in range(len(values))]
    smooth.append(sum(w * v for w, v in zip(weights, values)) / sum(weights))
samples = [smooth[round(k * (len(smooth) - 1) / (KNOTS - 1))] for k in range(KNOTS)]
lo, hi = min(samples), max(samples)
n = len(samples)
pts = [(-20 + i * (W + 40) / (n - 1), BOTTOM - (v - lo) / (hi - lo) * (BOTTOM - TOP)) for i, v in enumerate(samples)]


def catmull_rom(points):
    d = f"M {points[0][0]:.1f} {points[0][1]:.1f}"
    for i in range(len(points) - 1):
        p0 = points[i - 1] if i > 0 else points[i]
        p1, p2 = points[i], points[i + 1]
        p3 = points[i + 2] if i + 2 < len(points) else p2
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f" C {c1[0]:.1f} {c1[1]:.1f}, {c2[0]:.1f} {c2[1]:.1f}, {p2[0]:.1f} {p2[1]:.1f}"
    return d


line = catmull_rom(pts)
area = line + f" L {W + 20} {H} L -20 {H} Z"

# Two highlighted readings either side of the centre echo the dotted line in the app icon.
dots = [pts[int(n * 0.36)], pts[int(n * 0.62)]]
dots_svg = "".join(
    f'<circle cx="{x:.1f}" cy="{y:.1f}" r="13" fill="{line_colour}"/>'
    f'<circle cx="{x:.1f}" cy="{y:.1f}" r="6" fill="#067BC2"/>'
    for x, y in dots
)

tag_html = f'<div class="tag">{subtitle}</div>' if subtitle else ""
# Without a subtitle the name sits lower, in the middle of the space above the curve.
text_top = 118 if subtitle else 150

html = f"""<!doctype html>
<html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;700&display=swap" rel="stylesheet">
<style>
  html, body {{ margin: 0; width: {W}px; height: {H}px; overflow: hidden; background: #067BC2; }}
  .wrap {{ position: relative; width: {W}px; height: {H}px; font-family: 'Roboto', sans-serif; color: #fff; }}
  svg {{ position: absolute; inset: 0; }}
  .text {{ position: absolute; left: 0; right: 0; top: {text_top}px; text-align: center; }}
  .name {{ font-size: 76px; font-weight: 700; letter-spacing: -0.5px; line-height: 1; }}
  .tag {{ margin-top: 16px; font-size: 30px; font-weight: 400; opacity: 0.92; }}
</style></head>
<body><div class="wrap">
<svg width="{W}" height="{H}" viewBox="0 0 {W} {H}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#0A8FDE"/><stop offset="1" stop-color="#05609A"/>
    </linearGradient>
    <linearGradient id="fill" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{line_colour}" stop-opacity="0.28"/><stop offset="1" stop-color="{line_colour}" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <rect width="{W}" height="{H}" fill="url(#bg)"/>
  <path d="{area}" fill="url(#fill)"/>
  <path d="{line}" fill="none" stroke="{line_colour}" stroke-width="7" stroke-linecap="round" stroke-linejoin="round"/>
  {dots_svg}
</svg>
<div class="text"><div class="name">ThingViewer</div>{tag_html}</div>
</div></body></html>
"""
open(out, "w").write(html)
print(out, n, "points")
