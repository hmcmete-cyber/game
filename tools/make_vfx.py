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

# ---------------------------------------------------------------------------
# v2.25 SECOND SHEET: character-specific shapes + animated flipbooks
# (flipbooks: 4x4 grid, 1024x1024, frame order left->right, top->bottom;
#  ParticleEmitter.FlipbookLayout = Grid4x4)
# ---------------------------------------------------------------------------
from PIL import ImageDraw
def canvas(n=N):
    return Image.new("L", (n, n), 0)
def to_np(im):
    return np.asarray(im, dtype=float) / 255
def save_l(name, im, blur=0, glow=0):
    a = to_np(im.filter(ImageFilter.GaussianBlur(blur)) if blur else im)
    if glow:
        a = np.clip(a + to_np(im.filter(ImageFilter.GaussianBlur(glow))) * 0.8, 0, 1)
    save(name, a)

# snowflake (6 arms with branches)
im = canvas(); dr = ImageDraw.Draw(im)
for k in range(6):
    a = k * math.pi / 3
    ex, ey = cx + math.cos(a) * 118, cy + math.sin(a) * 118
    dr.line([(cx, cy), (ex, ey)], fill=255, width=9)
    for t_, l in ((0.45, 38), (0.72, 26)):
        bx, by = cx + math.cos(a) * 118 * t_, cy + math.sin(a) * 118 * t_
        for sgn in (-1, 1):
            b = a + sgn * math.radians(50)
            dr.line([(bx, by), (bx + math.cos(b) * l, by + math.sin(b) * l)], fill=255, width=6)
dr.ellipse([cx - 16, cy - 16, cx + 16, cy + 16], fill=255)
save_l("Snowflake", im, 1, 6)
# leaf
lx = dx / 0.42; ly = dy / 0.95
leaf = np.clip(1 - (lx ** 2 + ly ** 2), 0, 1) ** 0.4 * (np.abs(dx) > 0.012) + np.exp(-(dx * 90) ** 2) * (np.abs(dy) < 0.95) * 0.5
save("Leaf", leaf, white=0.75 + 0.25 * np.exp(-(dx * 30) ** 2), blur=1)
# feather (shaft + barbs)
im = canvas(); dr = ImageDraw.Draw(im)
dr.line([(cx, 20), (cx, 240)], fill=255, width=5)
for y in range(30, 220, 7):
    w = 70 * math.sin((y - 20) / 220 * math.pi)
    dr.line([(cx, y), (cx - w, y + 18)], fill=200, width=3)
    dr.line([(cx, y), (cx + w, y + 18)], fill=200, width=3)
save_l("Feather", im, 1.2)
# bubble (thin rim + highlight)
bub = np.exp(-((r - 0.85) * 18) ** 2) + 0.15 * (r < 0.85) + 0.9 * np.exp(-(((dx + 0.35) ** 2 + (dy + 0.35) ** 2) * 60))
save("Bubble", bub)
# 5-point star
im = canvas(); dr = ImageDraw.Draw(im)
pts = []
for k in range(10):
    a = -math.pi / 2 + k * math.pi / 5
    rr = 120 if k % 2 == 0 else 48
    pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
dr.polygon(pts, fill=255)
save_l("Star", im, 1, 10)
# rune circle (rings + glyph ticks + hexagram)
im = canvas(512); dr = ImageDraw.Draw(im); C = 255.5
for rr, w in ((240, 8), (205, 5), (120, 4)):
    dr.ellipse([C - rr, C - rr, C + rr, C + rr], outline=255, width=w)
for k in range(36):
    a = k / 36 * 2 * math.pi
    r1, r2 = (210, 235) if k % 3 else (200, 238)
    dr.line([(C + math.cos(a) * r1, C + math.sin(a) * r1), (C + math.cos(a) * r2, C + math.sin(a) * r2)], fill=255, width=4)
for off in (0, math.pi / 3):
    tri = [(C + math.cos(off + k * 2 * math.pi / 3 - math.pi / 2) * 200, C + math.sin(off + k * 2 * math.pi / 3 - math.pi / 2) * 200) for k in range(3)]
    dr.polygon(tri, outline=255, width=5)
a = to_np(im.filter(ImageFilter.GaussianBlur(1))); a = np.clip(a + to_np(im.filter(ImageFilter.GaussianBlur(8))) * 0.7, 0, 1)
Image.fromarray(np.dstack([np.full_like(a, 255), np.full_like(a, 255), np.full_like(a, 255), a * 255]).astype(np.uint8), "RGBA").save(os.path.join(OUT, "Rune.png"))
# crescent slash (thick tapered arc)
cr = np.clip(1 - np.abs(r - 0.7) / (0.16 * np.clip((ang + math.pi) / (2 * math.pi), 0, 1) ** 0.7 + 0.005), 0, 1) * (ang > -math.pi * 0.95)
save("Crescent", cr ** 0.8, blur=1)
# claw marks (3 tapered slashes)
im = canvas(); dr = ImageDraw.Draw(im)
for k in (-1, 0, 1):
    for t_ in range(0, 100):
        f = t_ / 100
        x = cx + k * 45 + (f - 0.5) * 120
        y = 30 + f * 196
        w = 14 * math.sin(f * math.pi) + 1
        dr.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=255)
save_l("Claw", im, 1, 5)
# water splash crown (droplets + crown spikes)
im = canvas(); dr = ImageDraw.Draw(im)
for k in range(14):
    a = math.pi + k / 13 * math.pi
    l = rng.uniform(60, 115)
    dr.line([(cx, cy + 40), (cx + math.cos(a) * l, cy + 40 + math.sin(a) * l)], fill=255, width=int(rng.uniform(5, 11)))
    dx_, dy_ = cx + math.cos(a) * (l + 16), cy + 40 + math.sin(a) * (l + 16)
    rr = rng.uniform(5, 10)
    dr.ellipse([dx_ - rr, dy_ - rr, dx_ + rr, dy_ + rr], fill=255)
dr.ellipse([cx - 80, cy + 25, cx + 80, cy + 55], fill=200)
save_l("Splash", im, 1.5)
# ink splat (blobby)
im = canvas(); dr = ImageDraw.Draw(im)
dr.ellipse([cx - 70, cy - 70, cx + 70, cy + 70], fill=255)
for k in range(22):
    a = rng.uniform(0, 2 * math.pi); l = rng.uniform(60, 120); rr = rng.uniform(6, 22)
    x, y = cx + math.cos(a) * l, cy + math.sin(a) * l
    dr.ellipse([x - rr, y - rr, x + rr, y + rr], fill=255)
    dr.line([(cx, cy), (x, y)], fill=255, width=int(rr))
save_l("Ink", im, 2.5)
# spore ball (dotted fuzzy sphere)
sp = np.clip(1 - r, 0, 1) ** 0.7 * 0.55
for k in range(40):
    px_, py_ = rng.uniform(-0.7, 0.7), rng.uniform(-0.7, 0.7)
    if px_ * px_ + py_ * py_ < 0.5:
        sp += np.exp(-(((dx - px_) ** 2 + (dy - py_) ** 2) * 900)) * 0.8
save("Spore", np.clip(sp, 0, 1), blur=1)
# rock chunk silhouette
im = canvas(); dr = ImageDraw.Draw(im)
pts = [(cx + math.cos(k / 9 * 2 * math.pi) * rng.uniform(70, 115), cy + math.sin(k / 9 * 2 * math.pi) * rng.uniform(70, 115)) for k in range(9)]
dr.polygon(pts, fill=230)
a = to_np(im)
shade = 0.55 + 0.45 * np.clip(-(dx + dy) * 0.8 + 0.5, 0, 1)
save("Rock", a, white=shade, blur=1)
# petal
px2 = dx / (0.38 * np.clip(1 - dy, 0.1, 2) ** 0.6); petal = np.clip(1 - (px2 ** 2 + (dy / 0.9) ** 2), 0, 1) ** 0.5
save("Petal", petal, white=0.8 + 0.2 * np.clip(-dy, 0, 1), blur=1)
# soft thick shockwave with inner haze
save("Wave", np.exp(-((r - 0.8) * 9) ** 2) + 0.25 * np.exp(-((r - 0.55) * 4) ** 2) * (r < 0.8))

# ---- flipbooks (4x4, 1024) ----
FN = 256
fy, fxx = np.mgrid[0:FN, 0:FN]
fdx, fdy = (fxx - FN / 2) / (FN / 2), (fyy := fy - FN / 2) / (FN / 2)
fr = np.sqrt(fdx ** 2 + fdy ** 2); fang = np.arctan2(fdy, fdx)
def noise_field(seed, cells):
    g = np.random.default_rng(seed).random((cells, cells))
    return to_np(Image.fromarray((g * 255).astype(np.uint8)).resize((FN, FN), Image.BICUBIC))
def sheet(name, frames, white_frames=None):
    out = np.zeros((1024, 1024)); wout = np.ones((1024, 1024))
    for i, f in enumerate(frames):
        y0, x0 = (i // 4) * FN, (i % 4) * FN
        out[y0:y0 + FN, x0:x0 + FN] = np.clip(f, 0, 1)
        if white_frames is not None:
            wout[y0:y0 + FN, x0:x0 + FN] = np.clip(white_frames[i], 0, 1)
    img = np.dstack([wout * 255, wout * 255, wout * 255, out * 255]).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, name + ".png"))
n1, n2, n3 = noise_field(11, 10), noise_field(12, 20), noise_field(13, 6)
# fire burst: grows, licks upward, breaks up
fr_frames, fw = [], []
for i in range(16):
    t_ = i / 15
    rad = 0.25 + 0.6 * t_ ** 0.6
    ydist = fdy + t_ * 0.35
    rr = np.sqrt(fdx ** 2 + (ydist * 0.8) ** 2)
    lick = (n1 * 0.6 + n2 * 0.4)
    body = np.clip((rad - rr) / 0.25 + (lick - 0.5) * 1.6 - t_ * 0.6, 0, 1)
    fr_frames.append(body * (1 - t_ ** 3))
    fw.append(np.clip(1.2 - rr / rad * 0.7 - t_ * 0.4, 0.35, 1))
sheet("FireFlip", fr_frames, fw)
# explosion: hot core + spikes -> rolling smoke
ex_frames, exw = [], []
spk = np.zeros_like(fr)
for k in range(30):
    a0 = rng.uniform(-math.pi, math.pi)
    da = np.angle(np.exp(1j * (fang - a0)))
    spk = np.maximum(spk, np.clip(1 - np.abs(da) / 0.05, 0, 1))
for i in range(16):
    t_ = i / 15
    rad = 0.2 + 0.75 * t_ ** 0.5
    core = np.clip((rad - fr) / 0.2 + (n3 - 0.5) * (0.6 + t_), 0, 1)
    spikes_ = spk * (fr < rad * 1.25) * (1 - t_) ** 2
    ex_frames.append(np.clip(core * (1 - t_ ** 2.5) + spikes_, 0, 1))
    exw.append(np.clip(1 - t_ * 0.9 + (1 - fr / rad) * 0.3, 0.15, 1))
sheet("ExplosionFlip", ex_frames, exw)
# billowing smoke puff
sm = []
for i in range(16):
    t_ = i / 15
    rad = 0.3 + 0.6 * t_
    shifted = np.roll(n1, int(t_ * 40), axis=0) * 0.6 + n2 * 0.4
    sm.append(np.clip((rad - fr) / 0.3 + (shifted - 0.5) * 1.4, 0, 1) * (1 - t_ ** 2) * 0.9)
sheet("SmokeFlip", sm)
# electric crackle (loop: new bolts every frame)
el = []
for i in range(16):
    im = Image.new("L", (FN, FN), 0); dr = ImageDraw.Draw(im)
    rr_ = np.random.default_rng(100 + i)
    for k in range(4):
        x, y = FN / 2, FN / 2
        a = rr_.uniform(0, 2 * math.pi)
        for _ in range(12):
            a += rr_.uniform(-0.8, 0.8)
            nx, ny = x + math.cos(a) * 10, y + math.sin(a) * 10
            dr.line([(x, y), (nx, ny)], fill=255, width=3)
            x, y = nx, ny
    a = to_np(im.filter(ImageFilter.GaussianBlur(0.8))); g_ = to_np(im.filter(ImageFilter.GaussianBlur(5)))
    el.append(np.clip(a * 1.5 + g_, 0, 1))
sheet("ElectricFlip", el)
print("sheet2 ok")
