"""Photo de test (paysage de terre et de ciel) pour les tests : jamais livrée avec le projet."""
import sys
from PIL import Image, ImageDraw
W, H = 1200, 800
img = Image.new("RGB", (W, H))
d = ImageDraw.Draw(img)
for y in range(H):
    t = y / H
    d.line([(0, y), (W, y)], fill=(int(214 - 40 * t), int(205 - 30 * t), int(180 - 20 * t)))
import math
for k, (base, col) in enumerate([(430, (126, 138, 118)), (520, (104, 123, 112)), (640, (70, 82, 74))]):
    pts = [(0, H)]
    for x in range(0, W + 20, 20):
        pts.append((x, base + 40 * math.sin(x / (170 - 30 * k) + k) + 14 * math.sin(x / 41 + k)))
    pts.append((W, H))
    d.polygon(pts, fill=col)
d.ellipse([820, 130, 940, 250], fill=(236, 226, 196))
img.save(sys.argv[1])
