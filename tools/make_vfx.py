"""Generates our own VFX particle/beam textures into assets/vfx (PNG, RGBA,
white/greyscale so ParticleEmitter.Color tints them). Upload them to Roblox
(Asset Manager -> Bulk Import, as Decals/Images) and paste the image ids into
src/shared/FxIds.luau. Until then FxKit uses Roblox's built-in textures."""
import math, os
import numpy as np
from PIL import Image, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "vfx")
os.makedirs(OUT, exist_ok=True)
N = 256
rng = np.random.default_rng(7)
yy, xx = np.mgrid[0:N, 0:N]
cx = cy = (N - 1) / 2
dx, dy = (xx - cx) / (N / 2), (yy - cy) / (N / 2)
r = np.sqrt(dx * dx + dy * dy)
ang = np.arctan2(dy, dx)

def save(name, alpha, white=None, blur=0):
    a = np.clip(alpha, 0, 1)
    w = np.ones_like(a) if white is None else np.clip(white, 0, 1)
    img = np.dstack([w * 255, w * 255, w * 255, a * 255]).astype(np.uint8)
    im = Image.fromarray(img, "RGBA")
    if blur:
        im = im.filter(ImageFilter.GaussianBlur(blur))
    im.save(os.path.join(OUT, name + ".png"))

# soft glow orb with a hot centre
save("Glow", np.exp(-(r * 2.6) ** 2) + 0.6 * np.exp(-(r * 7) ** 2))
# 4-point star flare (+ diagonal minor rays) - the bright "pop" in image 1/3
rays = np.exp(-np.abs(dy) * 60) * np.exp(-np.abs(dx) * 2.2) + np.exp(-np.abs(dx) * 60) * np.exp(-np.abs(dy) * 2.2)
d1, d2 = (dx + dy) / 1.414, (dx - dy) / 1.414
rays2 = 0.5 * (np.exp(-np.abs(d1) * 80) * np.exp(-np.abs(d2) * 4) + np.exp(-np.abs(d2) * 80) * np.exp(-np.abs(d1) * 4))
save("Flare", rays + rays2 + np.exp(-(r * 5) ** 2))
# thin streak spark (vertical, stretched along velocity)
save("Streak", np.exp(-(dx * 14) ** 2) * np.clip(1 - np.abs(dy), 0, 1) ** 1.5 * (0.6 + 0.4 * np.exp(-(dy * 2) ** 2)))
# spiky splatter burst (dark explosion in image 3)
spikes = np.zeros_like(r)
for k in range(46):
    a0 = rng.uniform(-math.pi, math.pi)
    length = rng.uniform(0.35, 0.98)
    width = rng.uniform(0.02, 0.07)
    da = np.angle(np.exp(1j * (ang - a0)))
    spikes = np.maximum(spikes, np.clip(1 - np.abs(da) / (width * (1.2 - r / length)), 0, 1) * (r < length))
save("Spikes", np.maximum(spikes * (1 - r * 0.6), np.exp(-(r * 3.2) ** 2)), blur=1)
# shockwave ring
save("Ring", np.exp(-((r - 0.82) * 22) ** 2) + 0.35 * np.exp(-((r - 0.7) * 8) ** 2) * (r < 0.82))
# crescent swirl / slash (for beams + swirl particles)
cres = np.exp(-((r - 0.72) * 16) ** 2) * np.clip((ang + math.pi) / (2 * math.pi), 0, 1) ** 1.6
save("Swirl", cres, blur=1)
# lightning crackle: random branching zig-zags
canvas = Image.new("L", (N, N), 0)
from PIL import ImageDraw
dr = ImageDraw.Draw(canvas)
def bolt(x, y, a, length, w, depth):
    for _ in range(int(length / 10)):
        a += rng.uniform(-0.7, 0.7)
        nx, ny = x + math.cos(a) * 10, y + math.sin(a) * 10
        dr.line([(x, y), (nx, ny)], fill=255, width=w)
        if depth < 2 and rng.random() < 0.18:
            bolt(nx, ny, a + rng.uniform(-1, 1), length * 0.5, max(1, w - 1), depth + 1)
        x, y = nx, ny
for k in range(5):
    bolt(cx, cy, k / 5 * 2 * math.pi + rng.uniform(0, 1), 120, 4, 0)
c = np.asarray(canvas.filter(ImageFilter.GaussianBlur(1.2)), dtype=float) / 255
glow = np.asarray(canvas.filter(ImageFilter.GaussianBlur(6)), dtype=float) / 255
save("Crackle", np.clip(c * 1.6 + glow * 1.2, 0, 1))
# flame tongue (wispy, pointed at the top)
u = dx / np.clip(1 - (dy + 1) / 2.2, 0.05, 1)
noise = Image.fromarray((rng.random((32, 32)) * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC)
nz = np.asarray(noise, dtype=float) / 255
flame = np.exp(-(u * 2.4) ** 2) * np.clip((dy + 1) / 1.6, 0, 1) ** 0.8 * (0.65 + 0.5 * nz)
save("Flame", flame, white=0.85 + 0.15 * np.exp(-(u * 4) ** 2), blur=2)
# puffy smoke (soft noisy blob)
noise2 = Image.fromarray((rng.random((12, 12)) * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC)
nz2 = np.asarray(noise2, dtype=float) / 255
save("Smoke", np.clip((1 - r) * 1.4, 0, 1) ** 1.3 * (0.45 + 0.75 * nz2), blur=3)
# crystal shard (diamond)
save("Shard", np.clip(1 - (np.abs(dx) * 3.2 + np.abs(dy) * 1.05), 0, 1) ** 0.6)
# beam gradient strip (soft edges across, for beams/trails)
save("BeamSoft", np.exp(-(dy * 2.2) ** 2) * np.ones_like(dx) * (0.75 + 0.25 * np.exp(-(dy * 7) ** 2)))
print("ok", sorted(os.listdir(OUT)))
