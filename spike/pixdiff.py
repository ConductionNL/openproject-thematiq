"""Region pixel diff. usage: pixdiff.py a.png b.png out_prefix
Regions (canon): top bar 0,0,1440,68 ; sidebar 0,68,264,1000.
A pixel differs when any channel differs by more than THRESH (anti-alias tolerance)."""
import sys
import numpy as np
from PIL import Image

THRESH = 24
a = np.asarray(Image.open(sys.argv[1]).convert("RGB")).astype(int)
b = np.asarray(Image.open(sys.argv[2]).convert("RGB")).astype(int)
assert a.shape == b.shape, (a.shape, b.shape)
prefix = sys.argv[3]
regions = {"topbar": (0, 0, 1440, 68), "sidebar": (0, 68, 264, 1000), "full": (0, 0, 1440, 1000)}
for name, (x0, y0, x1, y1) in regions.items():
    ra, rb = a[y0:y1, x0:x1], b[y0:y1, x0:x1]
    d = np.abs(ra - rb).max(axis=2)
    mask = d > THRESH
    strict = d > 0
    out = (rb * 0.25 + 190).clip(0, 255).astype(np.uint8)
    out[mask] = (220, 0, 40)
    Image.fromarray(out).save(f"{prefix}-{name}.png")
    print(f"{name}: {100 * mask.mean():.2f}% differ (>{THRESH}/255), {100 * strict.mean():.2f}% differ (any), {mask.size} px")
