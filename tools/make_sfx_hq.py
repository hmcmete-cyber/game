"""v2.27 HIGH-QUALITY SOUND EFFECTS, synthesised from scratch.

48 kHz STEREO, layered like real sound design:
  transient (click/crack)  +  body (filtered noise / tone with pitch & filter
  sweeps)  +  sub (sine drop)  +  texture (granular debris, crackle, bubbles,
  shimmer)  +  tail (stereo convolution reverb), then saturation, EQ,
  compression-ish loudness normalisation and a true-peak limiter.
Explosions get special care: crack -> fireball body -> sub boom -> debris
crackle -> rumble tail.

Output: assets/sfx_hq/<Cue>.ogg (Vorbis q7). Upload them and paste the ids
into src/shared/SfxIds.luau (key = file name without .ogg).
Run:  pip install scipy ; python3 tools/make_sfx_hq.py
"""
import os, subprocess, tempfile, wave
import numpy as np
from scipy import signal

SR = 48000
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx_hq")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(2027)


# ---------------------------------------------------------------- basics
def n(d):
    return int(SR * d)


def tt(d):
    return np.arange(n(d)) / SR


def pad(x, d):
    y = np.zeros(n(d))
    y[: min(len(x), len(y))] = x[: len(y)]
    return y


def at(x, delay, total=None):
    y = np.zeros(n(delay) + len(x))
    y[n(delay):] = x
    return y if total is None else pad(y, total)


def mix(*xs):
    L = max(len(x) for x in xs)
    y = np.zeros(L)
    for x in xs:
        y[: len(x)] += x
    return y


def white(d):
    return rng.standard_normal(n(d))


def pink(d):
    w = white(d)
    b, a = [0.049922035, -0.095993537, 0.050612699, -0.004408786], [1, -2.494956002, 2.017265875, -0.522189400]
    return signal.lfilter(b, a, w) * 3


def brown(d):
    b = np.cumsum(white(d))
    b = signal.sosfilt(signal.butter(1, 20, "hp", fs=SR, output="sos"), b)
    return b / (np.max(np.abs(b)) + 1e-9)


def env_exp(d, attack=0.002, decay=0.3, curve=1.0):
    x = tt(d)
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    return a * np.exp(-np.maximum(x - attack, 0) / max(decay, 1e-4)) ** curve


def env_adsr(d, a=0.01, dcy=0.1, s=0.7, r=0.2):
    x = tt(d)
    e = np.where(x < a, x / a, np.where(x < a + dcy, 1 - (1 - s) * (x - a) / dcy, s))
    rel = np.clip((d - x) / r, 0, 1)
    return e * rel


def sweep_osc(f0, f1, d, shape="sine", curve="exp"):
    x = tt(d)
    if curve == "exp":
        f = f0 * (f1 / f0) ** (x / d)
    else:
        f = f0 + (f1 - f0) * (x / d)
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "sine":
        return np.sin(ph)
    if shape == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1) - 1
    if shape == "square":
        return np.sign(np.sin(ph))
    if shape == "tri":
        return 2 * np.abs(2 * ((ph / (2 * np.pi)) % 1) - 1) - 1
    return np.sin(ph)


def filt(x, kind, f, order=2):
    f = np.clip(np.atleast_1d(f), 20, SR / 2 - 100)
    if kind == "bp":
        sos = signal.butter(order, [f[0], f[1]], "bandpass", fs=SR, output="sos")
    else:
        sos = signal.butter(order, f[0], kind, fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def sweep_filter(x, kind, f0, f1, order=2, block=256, q_bw=0.6):
    """time-varying filter (cutoff moves exponentially f0 -> f1)"""
    y = np.zeros_like(x)
    nb = int(np.ceil(len(x) / block))
    zi = None
    for i in range(nb):
        fc = f0 * (f1 / f0) ** (i / max(1, nb - 1))
        fc = float(np.clip(fc, 30, SR / 2 - 200))
        if kind == "bp":
            lo, hi = fc * (1 - q_bw / 2), fc * (1 + q_bw / 2)
            sos = signal.butter(order, [max(25, lo), min(SR / 2 - 100, hi)], "bandpass", fs=SR, output="sos")
        else:
            sos = signal.butter(order, fc, kind, fs=SR, output="sos")
        if zi is None or zi.shape[0] != sos.shape[0]:
            zi = signal.sosfilt_zi(sos) * 0
        seg = x[i * block:(i + 1) * block]
        y[i * block:i * block + len(seg)], zi = signal.sosfilt(sos, seg, zi=zi)
    return y


def drive(x, amount=2.0):
    return np.tanh(x * amount) / np.tanh(amount)


def norm(x, peak=1.0):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def modal(freqs, decays, amps, d, detune=0.0):
    x = tt(d)
    y = np.zeros_like(x)
    for f, dc, a in zip(freqs, decays, amps):
        f2 = f * (1 + rng.uniform(-detune, detune))
        y += a * np.sin(2 * np.pi * f2 * x + rng.uniform(0, 6.28)) * np.exp(-x / dc)
    return y


def grains(d, rate0, rate1, lo, hi, glen=0.006, amp_decay=None):
    """sparse random clicks (debris / crackle / ice tinkle)"""
    y = np.zeros(n(d))
    t0 = 0.0
    while t0 < d:
        r = rate0 + (rate1 - rate0) * t0 / d
        t0 += rng.exponential(1 / max(r, 1))
        if t0 >= d:
            break
        L = max(8, n(glen * rng.uniform(0.5, 1.5)))
        g = rng.standard_normal(L) * np.hanning(L)
        a = rng.uniform(0.3, 1.0) * (np.exp(-t0 / amp_decay) if amp_decay else 1)
        i = n(t0)
        y[i:i + L] += g[: len(y) - i] * a
    return filt(y, "bp", [lo, hi])


def bubble(f0, d=0.08, rise=2.2):
    """water bloop: sine whose pitch rises as the bubble closes"""
    x = tt(d)
    f = f0 * (1 + (rise - 1) * (x / d) ** 1.5)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-x / (d * 0.35)) * np.clip(x / 0.003, 0, 1)


def formant(src, formants, bw=80):
    y = np.zeros_like(src)
    for f, g in formants:
        y += g * filt(src, "bp", [max(40, f - bw), f + bw])
    return y


# ---------------------------------------------------------------- stereo + space
def reverb_ir(dur=1.6, damp=4000, predelay=0.012, seed=0):
    r = np.random.default_rng(seed)
    L = n(dur)
    x = np.arange(L) / SR
    irs = []
    for ch in range(2):
        noise = r.standard_normal(L) * np.exp(-x * 6.9 / dur)
        noise = sweep_filter(noise, "lp", damp, damp * 0.18, order=1, block=1024)
        er = np.zeros(L)
        for k in range(10):  # early reflections
            i = n(predelay + r.uniform(0.003, 0.05))
            if i < L:
                er[i] += r.uniform(0.2, 0.6) * (-1) ** k
        irs.append(np.concatenate([np.zeros(n(predelay)), (noise * 0.6 + er)])[:L])
    return irs


IRS = {"room": reverb_ir(0.6, 6000, 0.006, 1), "hall": reverb_ir(1.8, 4500, 0.018, 2), "huge": reverb_ir(3.2, 3500, 0.03, 3)}


def stereo(x, width=0.25, delay_ms=0.0):
    """mono -> stereo with slight decorrelation (no phasey mono collapse)"""
    side = filt(x, "hp", 300) * width
    d = n(delay_ms / 1000)
    l = x + np.concatenate([np.zeros(d), side])[: len(x)]
    r = x - np.concatenate([np.zeros(d), side])[: len(x)]
    return np.stack([l, r])


def space(st, kind="room", wet=0.2):
    if kind is None or wet <= 0:
        return st
    ir = IRS[kind]
    out = []
    for ch in range(2):
        w = signal.fftconvolve(st[ch], ir[ch])[: len(st[ch]) + len(ir[ch])]
        dry = np.concatenate([st[ch], np.zeros(len(w) - len(st[ch]))])
        out.append(dry * (1 - wet * 0.5) + w / (np.max(np.abs(w)) + 1e-9) * np.max(np.abs(st[ch])) * wet)
    return np.stack(out)


def master(st, target_rms=0.16, ceiling=0.82, hp=28):
    st = np.stack([filt(ch, "hp", hp, 2) for ch in st])
    # trim silent tail
    e = np.max(np.abs(st), axis=0)
    idx = np.where(e > 1e-3 * np.max(e))[0]
    end = min(st.shape[1], (idx[-1] if len(idx) else st.shape[1]) + n(0.05))
    st = st[:, :end]
    rms = np.sqrt(np.mean(st ** 2)) + 1e-9
    st = st * (target_rms / rms)
    st = np.tanh(st * 1.15) / np.tanh(1.15)  # soft knee
    pk = np.max(np.abs(st))
    if pk > ceiling:
        st = st * (ceiling / pk)
    f = min(st.shape[1], n(0.02))
    st[:, -f:] *= np.linspace(1, 0, f)
    st[:, : n(0.0015)] *= np.linspace(0, 1, n(0.0015))
    return st


def write(name, st, rms=0.16):
    st = master(st, target_rms=rms)
    data = (np.clip(st.T, -1, 1) * 32767).astype("<i2").tobytes()
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        path = tmp.name
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", path, "-c:a", "libvorbis", "-q:a", "7", os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(path)


C = {}


def cue(name, rms=0.16):
    def deco(fn):
        C[name] = (fn, rms)
        return fn
    return deco


# ---------------------------------------------------------------- building blocks
def crack(d=0.012, lo=1800, amp=1.0):
    return filt(white(d), "hp", lo) * env_exp(d, 0.0003, d / 4) * amp


def thump(f0=140, f1=48, d=0.25, amp=1.0, dk=0.07):
    return sweep_osc(f0, f1, d) * env_exp(d, 0.001, dk) * amp


def whoosh(d=0.35, f0=600, f1=2600, amp=1.0, q=0.9):
    body = sweep_filter(pink(d), "bp", f0, f1, order=2, q_bw=q)
    return body * np.sin(np.pi * np.clip(tt(d) / d, 0, 1)) ** 1.4 * amp


def explosion(d=2.2, size=1.0, color=1.0, debris=1.0, sub_f=55):
    """layered explosion: crack, fireball body, sub boom, debris crackle, rumble"""
    body = sweep_filter(white(d), "lp", 7000 * color, 160, order=2) * env_exp(d, 0.004, 0.35 * size)
    body = drive(body * 2.2, 2.5)
    sub = sweep_osc(sub_f, 24, d) * env_exp(d, 0.003, 0.45 * size) * 1.6
    rumble = filt(brown(d), "lp", 180) * env_exp(d, 0.05, 0.9 * size) * 0.9
    deb = grains(d, 260 * debris, 8, 1200, 5000, 0.004, amp_decay=0.5 * size) * 0.35
    cr = crack(0.02, 1500, 1.4)
    return mix(cr, body, sub, rumble, deb)


def shatter(d=1.0, bright=1.0, n_grains=1.0):
    tink = grains(d, 900 * n_grains, 20, 3000 * bright, 11000, 0.003, amp_decay=0.25) * 0.8
    partials = modal([2350 * bright, 3870 * bright, 5320 * bright, 6900 * bright, 8800 * bright], [0.25, 0.18, 0.12, 0.09, 0.06], [0.6, 0.5, 0.4, 0.3, 0.2], d, 0.04)
    return mix(crack(0.008, 2500, 1.2), tink, partials * 0.5, filt(white(0.12), "hp", 4000) * env_exp(0.12, 0.001, 0.03) * 0.6)


def zap(d=0.35, f0=2400, f1=180, buzz=110):
    x = tt(d)
    car = sweep_osc(f0, f1, d, "saw")
    mod = np.sin(2 * np.pi * buzz * x) * 0.5 + 0.5
    noise = filt(white(d), "bp", [2000, 9000]) * (rng.random(n(d)) > 0.93)
    y = car * (0.6 + 0.4 * mod) + noise * 1.2
    y = filt(y, "lp", 9000)
    return drive(y * env_exp(d, 0.001, d / 3), 3)


def fire_roar(d=1.2, amp=1.0):
    base = filt(pink(d), "bp", [120, 1600])
    lfo = 0.65 + 0.35 * np.sin(2 * np.pi * 7 * tt(d) + rng.uniform(0, 6)) * np.sin(2 * np.pi * 3.1 * tt(d))
    crackles = grains(d, 70, 30, 1500, 6000, 0.002) * 1.2
    return (base * lfo + crackles) * env_adsr(d, 0.05, 0.2, 0.7, d * 0.5) * amp


def splash(d=0.9, size=1.0):
    impact = filt(white(0.25), "bp", [500, 6000]) * env_exp(0.25, 0.002, 0.07 * size)
    spray = filt(white(d), "hp", 2500) * env_exp(d, 0.01, 0.2 * size) * 0.5
    blips = np.zeros(n(d))
    for _ in range(int(14 * size)):
        b = bubble(rng.uniform(300, 1200) / size, rng.uniform(0.04, 0.12))
        t0 = rng.uniform(0.02, d * 0.8)
        i = n(t0)
        blips[i:i + len(b)] += b[: len(blips) - i] * rng.uniform(0.2, 0.6) * np.exp(-t0 / (d * 0.3))  # later bubbles fade
    return mix(impact * 1.4, spray, blips, thump(110, 50, 0.3, 0.6))


def rock_crunch(d=0.8, size=1.0):
    crunch = grains(d, 600 * size, 30, 300, 3500, 0.008, amp_decay=0.25 * size)
    return mix(thump(95, 38, 0.5, 1.2), crunch * 0.9, filt(brown(d), "lp", 400) * env_exp(d, 0.01, 0.3 * size) * 0.7)


def chime(notes, d=1.2, spacing=0.07, bright=1.0):
    y = np.zeros(n(d + spacing * len(notes)))
    for i, f in enumerate(notes):
        b = modal([f, f * 2.0, f * 3.01, f * 4.17 * bright], [0.9, 0.5, 0.3, 0.15], [1, 0.4, 0.25, 0.12], d, 0.002)
        y = mix(y, at(b, i * spacing))
    return y


def pad_chord(freqs, d=1.6, bright=2500):
    y = np.zeros(n(d))
    for f in freqs:
        for det in (-0.004, 0, 0.005):
            y += sweep_osc(f * (1 + det), f * (1 + det), d, "saw") / 3
    return filt(y, "lp", bright) * env_adsr(d, 0.25, 0.3, 0.8, 0.6)


def growl(d=1.6, f0=85, f1=60, vowel=((650, 1), (1100, 0.6), (2600, 0.3))):
    x = tt(d)
    f = f0 * (f1 / f0) ** (x / d) * (1 + 0.04 * np.sin(2 * np.pi * 23 * x))
    src = 2 * ((np.cumsum(f) / SR) % 1) - 1
    src += filt(white(d), "lp", 900) * 0.6
    src *= 0.75 + 0.25 * np.sin(2 * np.pi * 31 * x)  # throat rattle
    y = formant(src, vowel, 120)
    return drive(y * 3, 2) * env_adsr(d, 0.08, 0.3, 0.85, 0.5)


# ================================================================== CUES
# ---- hits ----
@cue("HitPunch")
def _():
    return space(stereo(mix(crack(0.006, 2500, 0.8), thump(160, 52, 0.22, 1.3, 0.06), filt(white(0.06), "bp", [300, 2200]) * env_exp(0.06, 0.001, 0.015))), "room", 0.12)


@cue("HitLaser")
def _():
    y = mix(zap(0.28, 3200, 600, 180) * 0.8, sweep_filter(white(0.4), "bp", 6000, 1500, q_bw=0.5) * env_exp(0.4, 0.002, 0.08) * 0.6, chime([1760], 0.35) * 0.2)
    return space(stereo(y, 0.4), "room", 0.18)


@cue("HitQuake")
def _():
    return space(stereo(rock_crunch(1.1, 1.3), 0.35), "hall", 0.25)


@cue("HitGadget")
def _():
    metal = modal([420, 1130, 1960, 2870, 4100], [0.5, 0.35, 0.22, 0.15, 0.08], [1, 0.7, 0.5, 0.35, 0.2], 0.8, 0.01)
    return space(stereo(mix(crack(0.008, 2000), thump(180, 70, 0.2, 0.9), metal * 0.6), 0.3), "room", 0.2)


@cue("HitBoss")
def _():
    y = mix(crack(0.012, 1500, 1.2), thump(120, 34, 0.6, 1.8, 0.15), filt(brown(0.8), "lp", 300) * env_exp(0.8, 0.005, 0.2), modal([180, 470, 890], [0.6, 0.4, 0.25], [0.5, 0.3, 0.2], 0.8) * 0.4)
    return space(stereo(drive(y, 1.8), 0.3), "hall", 0.22)


# ---- pet attacks ----
@cue("PetBite")
def _():
    snap = mix(crack(0.005, 3000, 1), at(crack(0.005, 2600, 0.8), 0.07))
    wet = filt(white(0.15), "bp", [600, 3000]) * env_exp(0.15, 0.002, 0.04)
    return space(stereo(mix(snap, wet, thump(220, 90, 0.12, 0.6, 0.03))), "room", 0.1)


@cue("PetBolt")
def _():
    y = mix(sweep_osc(900, 2600, 0.18, "tri") * env_exp(0.18, 0.002, 0.07) * 0.6, chime([1568, 2349], 0.5, 0.03) * 0.4, whoosh(0.25, 1500, 5000, 0.5))
    return space(stereo(y, 0.5), "room", 0.25)


@cue("PetLob")
def _():
    return space(stereo(mix(bubble(260, 0.14, 2.6), at(splash(0.5, 0.6) * 0.7, 0.05))), "room", 0.15)


@cue("PetPulse")
def _():
    swell = sweep_osc(110, 220, 0.6) * env_adsr(0.6, 0.15, 0.1, 0.8, 0.3)
    return space(stereo(mix(swell, chime([523, 659, 784], 0.8, 0.04) * 0.35), 0.4), "hall", 0.3)


@cue("PetChain")
def _():
    y = mix(*[at(zap(0.16, 2800 - k * 300, 400, 90 + k * 30) * (1 - k * 0.15), k * 0.07) for k in range(4)])
    return space(stereo(y, 0.45), "room", 0.18)


# ---- element ability hits ----
@cue("Melee")
def _():
    return space(stereo(mix(whoosh(0.22, 400, 2200, 0.7), at(thump(150, 55, 0.2, 1.1), 0.12), at(crack(0.006, 2200, 0.7), 0.12))), "room", 0.12)


@cue("Fire")
def _():
    return space(stereo(mix(whoosh(0.4, 300, 1800, 0.8), at(fire_roar(0.8, 0.9), 0.1), at(explosion(0.7, 0.35, 0.8, 0.6, 80) * 0.6, 0.12)), 0.4), "room", 0.2)


@cue("Ice")
def _():
    return space(stereo(mix(shatter(0.8, 1.1, 0.8), thump(200, 80, 0.15, 0.5)), 0.5), "room", 0.25)


@cue("Electric")
def _():
    return space(stereo(mix(zap(0.45, 3000, 250, 120), at(zap(0.2, 4000, 800, 60) * 0.5, 0.08)), 0.5), "room", 0.2)


@cue("Earth")
def _():
    return space(stereo(rock_crunch(0.8, 1.0), 0.3), "room", 0.18)


@cue("Spore")
def _():
    puff = filt(pink(0.5), "lp", 1400) * env_exp(0.5, 0.01, 0.12)
    return space(stereo(mix(puff * 1.3, chime([1046, 1318, 1568], 0.6, 0.05, 1.2) * 0.25), 0.5), "room", 0.25)


@cue("Water")
def _():
    return space(stereo(splash(0.8, 0.9), 0.5), "room", 0.18)


@cue("Wind")
def _():
    return space(stereo(mix(whoosh(0.55, 300, 3000, 1.0, 1.2), whoosh(0.4, 800, 5000, 0.4, 0.5)), 0.6, 8), "room", 0.15)


@cue("Crystal")
def _():
    return space(stereo(mix(shatter(1.0, 1.3, 1.0), chime([2093, 2637], 0.9, 0.04) * 0.3), 0.55), "hall", 0.22)


@cue("Slash")
def _():
    blade = sweep_filter(white(0.25), "bp", 1500, 7000, q_bw=0.3) * np.sin(np.pi * tt(0.25) / 0.25) ** 2
    ring = modal([2100, 3300, 5200], [0.25, 0.15, 0.08], [0.6, 0.4, 0.2], 0.4)
    return space(stereo(mix(blade, at(ring * 0.5, 0.12), at(crack(0.005, 3000, 0.6), 0.12)), 0.5), "room", 0.15)


@cue("PlayerHurt")
def _():
    oof = formant(sweep_osc(210, 150, 0.22, "saw"), ((520, 1), (950, 0.5), (2500, 0.15)), 90) * env_adsr(0.22, 0.01, 0.05, 0.7, 0.1)
    return space(stereo(mix(thump(140, 60, 0.18, 1.0), crack(0.006, 2500, 0.6), oof * 0.6)), "room", 0.1)


# ---- monster deaths (bigger, with tails) ----
@cue("DeathFire", 0.17)
def _():
    return space(stereo(mix(explosion(2.0, 1.0, 1.0, 1.0), at(fire_roar(1.4, 0.6), 0.15)), 0.4), "hall", 0.25)


@cue("DeathIce", 0.16)
def _():
    return space(stereo(mix(shatter(1.4, 1.0, 1.5), thump(160, 50, 0.4, 0.9), at(shatter(0.8, 0.8, 0.6) * 0.5, 0.12)), 0.6), "hall", 0.28)


@cue("DeathElectric", 0.16)
def _():
    over = mix(*[at(zap(0.18, 3500, 500, 140) * 0.6, k * 0.05) for k in range(5)])
    return space(stereo(mix(over, at(explosion(1.2, 0.5, 1.3, 0.5, 70) * 0.8, 0.28)), 0.5), "hall", 0.25)


@cue("DeathEarth", 0.17)
def _():
    return space(stereo(mix(rock_crunch(1.6, 1.8), at(rock_crunch(1.0, 1.0) * 0.6, 0.25)), 0.4), "hall", 0.25)


@cue("DeathSpore", 0.15)
def _():
    puff = filt(pink(1.0), "lp", 1800) * env_exp(1.0, 0.01, 0.25)
    return space(stereo(mix(puff * 1.5, thump(120, 60, 0.3, 0.6), chime([784, 988, 1175, 1568], 1.0, 0.06) * 0.3), 0.6), "hall", 0.3)


@cue("DeathWater", 0.16)
def _():
    return space(stereo(mix(splash(1.4, 1.6), at(splash(0.8, 0.8) * 0.5, 0.18)), 0.6), "hall", 0.22)


@cue("DeathWind", 0.15)
def _():
    return space(stereo(mix(whoosh(1.0, 200, 4000, 1.0, 1.4), at(whoosh(0.6, 3000, 300, 0.6, 1.0), 0.3)), 0.7, 10), "hall", 0.25)


@cue("DeathCrystal", 0.16)
def _():
    return space(stereo(mix(shatter(1.6, 1.2, 1.8), at(chime([1568, 1976, 2349, 3136], 1.4, 0.05) * 0.35, 0.1)), 0.6), "hall", 0.3)


@cue("DeathSlash", 0.17)
def _():
    return space(stereo(explosion(1.6, 0.8, 1.0, 0.8, 60), 0.4), "hall", 0.22)


# ---- bosses ----
@cue("BossRoar", 0.18)
def _():
    roar = mix(growl(1.8, 90, 62), growl(1.8, 61, 45, ((450, 1), (800, 0.6), (2200, 0.2))) * 0.7, filt(brown(1.8), "lp", 120) * env_adsr(1.8, 0.1, 0.3, 0.8, 0.5) * 0.8)
    return space(stereo(roar, 0.35, 6), "huge", 0.3)


@cue("BossArrive", 0.18)
def _():
    rise = sweep_filter(white(1.2), "bp", 200, 4000, q_bw=0.8) * np.linspace(0, 1, n(1.2)) ** 2
    return space(stereo(mix(rise * 0.8, at(explosion(2.2, 1.4, 0.7, 0.4, 45), 1.1)), 0.4), "huge", 0.3)


@cue("BossStagger", 0.16)
def _():
    groan = sweep_osc(120, 70, 0.9, "saw")
    groan = filt(groan, "bp", [80, 900]) * env_adsr(0.9, 0.05, 0.2, 0.7, 0.4)
    return space(stereo(mix(thump(110, 40, 0.5, 1.4), groan * 0.7, modal([140, 390, 760], [0.7, 0.4, 0.2], [0.4, 0.3, 0.2], 1.0) * 0.5), 0.3), "hall", 0.25)


@cue("BossCollapse", 0.18)
def _():
    return space(stereo(mix(rock_crunch(2.4, 2.6), filt(brown(2.6), "lp", 140) * env_adsr(2.6, 0.2, 0.5, 0.8, 1.2) * 1.2, at(thump(90, 30, 0.8, 1.6, 0.25), 1.2)), 0.45), "huge", 0.3)


@cue("BossDefeat", 0.19)
def _():
    big = mix(explosion(3.2, 2.0, 1.1, 1.4, 48), at(explosion(2.0, 1.0, 0.9, 1.0, 60) * 0.6, 0.35), at(shatter(1.0, 0.8, 1.0) * 0.3, 0.05))
    return space(stereo(big, 0.5), "huge", 0.32)


@cue("BossReward", 0.15)
def _():
    fan = mix(at(pad_chord([261.6, 329.6, 392.0], 0.5, 3500), 0), at(pad_chord([293.7, 370.0, 440.0], 0.5, 3800), 0.18), at(pad_chord([392.0, 493.9, 587.3, 784.0], 1.8, 4500), 0.36))
    return space(stereo(mix(fan, at(chime([1568, 1976, 2349, 3136], 1.4, 0.06) * 0.35, 0.4)), 0.5), "hall", 0.3)


# ---- eggs ----
@cue("EggTake")
def _():
    return space(stereo(mix(bubble(380, 0.09, 1.8) * 0.8, at(chime([1318, 1976], 0.7, 0.06) * 0.6, 0.04)), 0.4), "room", 0.2)


@cue("EggDeliver")
def _():
    return space(stereo(mix(thump(170, 90, 0.2, 0.8), at(chime([988, 1318, 1568], 1.0, 0.08) * 0.6, 0.06)), 0.4), "hall", 0.25)


@cue("HatchPulse")
def _():
    crk = grains(0.4, 700, 60, 400, 4500, 0.005, amp_decay=0.12)
    return space(stereo(mix(crk * 1.3, thump(85, 50, 0.3, 0.7)), 0.35), "room", 0.15)


@cue("HatchCrack")
def _():
    return space(stereo(mix(grains(0.25, 900, 100, 1200, 7000, 0.003, amp_decay=0.08) * 1.3, crack(0.006, 2500, 0.7)), 0.4), "room", 0.12)


@cue("HatchBurst", 0.17)
def _():
    shell = grains(0.9, 1500, 20, 600, 6000, 0.006, amp_decay=0.2)
    return space(stereo(mix(crack(0.015, 1200, 1.4), shell * 1.1, thump(110, 40, 0.5, 1.3, 0.12), filt(brown(0.8), "lp", 300) * env_exp(0.8, 0.005, 0.2) * 0.6), 0.45), "hall", 0.22)


@cue("HatchLegendary", 0.18)
def _():
    boom = explosion(2.6, 1.5, 0.8, 0.6, 42)
    pad = pad_chord([130.8, 196.0, 261.6, 329.6], 2.6, 2200) * 0.6
    return space(stereo(mix(boom, at(shatter(1.2, 0.9, 1.4) * 0.6, 0.02), at(pad, 0.1)), 0.5), "huge", 0.32)


@cue("PetLevelUp", 0.14)
def _():
    arp = mix(*[at(modal([f, f * 2, f * 3.01], [0.35, 0.2, 0.1], [1, 0.4, 0.2], 0.4), i * 0.075) for i, f in enumerate([523, 659, 784, 1046, 1318])])
    sh = filt(white(1.0), "hp", 6000) * env_adsr(1.0, 0.3, 0.2, 0.5, 0.4) * 0.2
    return space(stereo(mix(arp, at(sh, 0.3)), 0.5), "hall", 0.3)


# ---- vendors / base / clouds / UI ----
@cue("OrbOffer", 0.14)
def _():
    absorb = sweep_filter(white(0.9), "bp", 300, 5000, q_bw=0.5) * np.linspace(0, 1, n(0.9)) ** 2 * 0.6
    return space(stereo(mix(absorb, at(chime([784, 1175, 1568], 1.0, 0.05) * 0.7, 0.85)), 0.5), "hall", 0.3)


@cue("OrbRefuse", 0.13)
def _():
    buzz = filt(sweep_osc(180, 150, 0.35, "square"), "lp", 1500) * env_adsr(0.35, 0.01, 0.05, 0.8, 0.08)
    return space(stereo(mix(buzz * 0.6, at(buzz * 0.5, 0.17))), "room", 0.1)


@cue("Buy", 0.13)
def _():
    coin = modal([2637, 3951, 5274], [0.25, 0.18, 0.1], [1, 0.6, 0.3], 0.5)
    return space(stereo(mix(crack(0.004, 4000, 0.4), coin, at(modal([3520, 5274], [0.3, 0.15], [0.8, 0.4], 0.6), 0.08))), "room", 0.18)


@cue("BaseLock", 0.15)
def _():
    clunk = mix(thump(160, 60, 0.25, 1.2), modal([380, 920, 1700], [0.25, 0.15, 0.08], [0.7, 0.4, 0.2], 0.4), crack(0.006, 2000, 0.8))
    hum = sweep_osc(110, 110, 0.9, "saw")
    hum = filt(hum, "lp", 700) * env_adsr(0.9, 0.2, 0.2, 0.6, 0.4) * 0.35
    return space(stereo(mix(clunk, at(hum, 0.1), at(chime([523, 784], 0.8, 0.05) * 0.3, 0.15)), 0.4), "room", 0.2)


@cue("CloudCatch", 0.14)
def _():
    return space(stereo(mix(whoosh(0.4, 500, 3500, 0.7), at(chime([1318, 1568, 2093], 0.8, 0.05) * 0.6, 0.15)), 0.6), "hall", 0.28)


@cue("CloudDeliver", 0.14)
def _():
    return space(stereo(mix(chime([784, 988, 1175, 1568], 1.2, 0.07), at(filt(white(0.6), "hp", 5000) * env_exp(0.6, 0.05, 0.2) * 0.2, 0.2)), 0.5), "hall", 0.3)


@cue("TutorialStep", 0.11)
def _():
    return space(stereo(mix(bubble(500, 0.07, 1.7) * 0.6, at(chime([1046, 1568], 0.5, 0.06) * 0.5, 0.03))), "room", 0.15)


if __name__ == "__main__":
    for name, (fn, r) in C.items():
        st = fn()
        write(name, st, r)
    print("wrote", len(C), "cues to", os.path.abspath(OUT))
