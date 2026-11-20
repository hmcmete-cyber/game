"""Generates the game's ORIGINAL sound effects (v2.19).

Every cue is synthesised from scratch (oscillators, filtered noise, envelopes,
melodies), so each one is a genuinely different sound, not one sample with
effects. Output: assets/sfx/<Cue>.wav (22.05 kHz, mono, 16-bit).
Run:  python3 tools/make_sfx.py
"""
import numpy as np, wave, os

SR = 22050
rng = np.random.default_rng(7)
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, d=None, curve=4.0):
    """attack then exponential decay over n samples"""
    x = np.arange(n) / SR
    att = np.clip(x / max(a, 1e-4), 0, 1)
    dur = n / SR
    dec = np.exp(-curve * x / (d or dur))
    return att * dec


def osc(f0, f1, d, wave="sine"):
    tt = t(d)
    f = np.geomspace(max(f0, 1), max(f1, 1), len(tt))
    ph = 2 * np.pi * np.cumsum(f) / SR
    if wave == "sine":
        return np.sin(ph)
    if wave == "square":
        return np.sign(np.sin(ph)) * 0.6
    if wave == "saw":
        return ((ph / (2 * np.pi)) % 1.0) * 2 - 1
    if wave == "tri":
        return 2 * np.abs(((ph / (2 * np.pi)) % 1.0) * 2 - 1) - 1
    return np.sin(ph)


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def lowpass(x, cutoff):
    """one-pole low-pass; cutoff may be an array (sweeps)"""
    cutoff = np.broadcast_to(np.asarray(cutoff, dtype=float), x.shape)
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a[i]) * x[i] + a[i] * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bandpass(x, lo, hi):
    return lowpass(highpass(x, lo), hi)


def note(f, d, wave="sine", a=0.005, decay=None, vol=1.0):
    return osc(f, f, d, wave) * env(int(SR * d), a, decay) * vol


def bell(f, d, partials=(1, 2.76, 5.4, 8.9), vol=1.0):
    tt = t(d)
    y = np.zeros(len(tt))
    for k, p in enumerate(partials):
        y += np.sin(2 * np.pi * f * p * tt) * np.exp(-tt * (3 + k * 3) / d) / (k + 1)
    return y * vol


def seq(*parts, gap=0.0):
    out = []
    for p in parts:
        out.append(p)
        if gap:
            out.append(np.zeros(int(SR * gap)))
    return np.concatenate(out)


def mix(*parts):
    n = max(len(p) for p in parts)
    y = np.zeros(n)
    for p in parts:
        y[: len(p)] += p
    return y


def at(x, delay):
    return np.concatenate([np.zeros(int(SR * delay)), x])


def write(name, y, vol=0.9):
    y = y / (np.max(np.abs(y)) + 1e-9) * vol
    fade = min(len(y), int(SR * 0.01))
    y[-fade:] *= np.linspace(1, 0, fade)
    data = (y * 32767).astype("<i2").tobytes()
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


C = {}
# --- hits -------------------------------------------------------------------
C["HitPunch"] = mix(osc(160, 55, 0.14) * env(int(SR * 0.14), 0.002), lowpass(noise(0.04), 3000) * env(int(SR * 0.04), 0.001) * 0.6)
C["HitLaser"] = osc(1900, 380, 0.2, "square") * env(int(SR * 0.2), 0.002, 0.2, 3)
C["HitQuake"] = mix(lowpass(noise(0.6), 250) * env(int(SR * 0.6), 0.01, 0.6, 3) * 2.5, osc(70, 35, 0.5) * env(int(SR * 0.5), 0.005))
C["HitGadget"] = mix(lowpass(noise(0.4), np.geomspace(4000, 300, int(SR * 0.4))) * env(int(SR * 0.4), 0.002), osc(110, 45, 0.3) * env(int(SR * 0.3)))
C["HitBoss"] = mix(osc(95, 30, 0.45) * env(int(SR * 0.45), 0.002) * 1.2, bell(320, 0.5, (1, 2.4, 3.9, 5.7)) * 0.4)
# --- pet attacks -------------------------------------------------------------
chomp = bandpass(noise(0.05), 800, 3500) * env(int(SR * 0.05), 0.001)
C["PetBite"] = seq(chomp, at(chomp * 0.8, 0.03))
C["PetBolt"] = osc(1300, 280, 0.16) * env(int(SR * 0.16), 0.002)
C["PetLob"] = mix(osc(280, 760, 0.18) * env(int(SR * 0.18), 0.005), at(bandpass(noise(0.05), 400, 2000) * env(int(SR * 0.05)), 0.18))
C["PetPulse"] = mix(osc(180, 160, 0.5) * env(int(SR * 0.5), 0.02) * (0.6 + 0.4 * np.sin(2 * np.pi * 14 * t(0.5))), bell(1046, 0.5) * 0.4)
zap = osc(120, 90, 0.3, "square") * env(int(SR * 0.3), 0.002)
C["PetChain"] = mix(zap, highpass(noise(0.3), 3000) * (rng.random(int(SR * 0.3)) > 0.93) * 1.5)
# --- monster casts by element -----------------------------------------------
C["Melee"] = bandpass(noise(0.25), np.geomspace(500, 3000, int(SR * 0.25)), 5000) * env(int(SR * 0.25), 0.05, 0.25, 5)
C["Fire"] = mix(lowpass(noise(0.6), np.geomspace(300, 3000, int(SR * 0.6))) * env(int(SR * 0.6), 0.08, 0.6, 3), (rng.random(int(SR * 0.6)) > 0.985) * 0.8)
C["Ice"] = mix(*[at(bell(f, 0.6, (1, 2.1, 3.3)), dl) for f, dl in ((2400, 0), (3100, 0.04), (3900, 0.08))], highpass(noise(0.05), 4000) * env(int(SR * 0.05)))
buzz = osc(60, 60, 0.5, "square") * env(int(SR * 0.5), 0.01, 0.5, 2)
C["Electric"] = mix(buzz, highpass(noise(0.5), 2500) * (rng.random(int(SR * 0.5)) > 0.95) * 1.2)
C["Earth"] = mix(lowpass(noise(0.7), 180) * env(int(SR * 0.7), 0.02, 0.7, 2.5) * 3, osc(50, 40, 0.6) * env(int(SR * 0.6), 0.01))
C["Spore"] = mix(lowpass(noise(0.3), 900) * env(int(SR * 0.3), 0.01), osc(300, 200, 0.4) * env(int(SR * 0.4)) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t(0.4))) * 0.6)
C["Water"] = mix(bandpass(noise(0.4), 300, 2500) * env(int(SR * 0.4), 0.002, 0.4, 5), at(osc(400, 900, 0.12) * env(int(SR * 0.12)) * 0.6, 0.1))
wind_env = np.sin(np.linspace(0, np.pi, int(SR * 0.9)))
C["Wind"] = bandpass(noise(0.9), np.geomspace(300, 1200, int(SR * 0.9)), 2500) * wind_env
C["Crystal"] = seq(*[bell(f, 0.35) for f in (1047, 1319, 1568)], gap=0.0)
C["Slash"] = highpass(noise(0.18), np.geomspace(1000, 6000, int(SR * 0.18))) * env(int(SR * 0.18), 0.03, 0.18, 4)
C["PlayerHurt"] = osc(420, 230, 0.22, "tri") * env(int(SR * 0.22), 0.005) * (1 + 0.15 * np.sin(2 * np.pi * 30 * t(0.22)))
# --- deaths -----------------------------------------------------------------
C["DeathFire"] = mix(lowpass(noise(0.9), np.geomspace(3000, 200, int(SR * 0.9))) * env(int(SR * 0.9), 0.01, 0.9, 2), osc(90, 30, 0.8) * env(int(SR * 0.8)))
ticks = np.zeros(int(SR * 0.6))
for k in range(18):
    p = int(rng.uniform(0, 0.5) * SR)
    ticks[p:p + 200] += highpass(noise(200 / SR), 3000) * np.linspace(1, 0, 200)
C["DeathIce"] = mix(ticks, bell(2800, 0.7, (1, 2.3, 4.1)) * 0.5)
C["DeathElectric"] = mix(osc(400, 40, 0.6, "square") * env(int(SR * 0.6), 0.002, 0.6, 2), highpass(noise(0.6), 3000) * (rng.random(int(SR * 0.6)) > 0.97))
thuds = mix(*[at(osc(90, 40, 0.18) * env(int(SR * 0.18)), d) for d in (0, 0.12, 0.27, 0.45)])
C["DeathEarth"] = mix(thuds, lowpass(noise(0.8), 200) * env(int(SR * 0.8), 0.02) * 1.5)
C["DeathSpore"] = mix(lowpass(noise(0.6), np.geomspace(2000, 300, int(SR * 0.6))) * env(int(SR * 0.6), 0.01, 0.6, 3), osc(500, 120, 0.6) * env(int(SR * 0.6)) * 0.4)
C["DeathWater"] = mix(bandpass(noise(0.5), 300, 2500) * env(int(SR * 0.5)), *[at(osc(f, f * 0.6, 0.1) * env(int(SR * 0.1)) * 0.5, d) for f, d in ((700, 0.15), (550, 0.27), (420, 0.39))])
C["DeathWind"] = bandpass(noise(1.0), np.geomspace(1500, 250, int(SR * 1.0)), 3000) * np.sin(np.linspace(0, np.pi, int(SR * 1.0)))
C["DeathCrystal"] = seq(*[bell(f, 0.3) for f in (1568, 1319, 1047, 784)])
C["DeathSlash"] = mix(osc(130, 50, 0.3) * env(int(SR * 0.3)), at(C["Slash"] * 0.6, 0.05))
# --- bosses -----------------------------------------------------------------
g = t(1.4)
growl = (osc(75, 55, 1.4, "saw") + 0.6 * osc(150, 110, 1.4, "saw")) * (1 + 0.3 * np.sin(2 * np.pi * 22 * g))
C["BossRoar"] = mix(lowpass(growl, 900) * np.sin(np.linspace(0, np.pi, len(g))) ** 0.5, lowpass(noise(1.4), 600) * 0.5 * np.sin(np.linspace(0, np.pi, len(g))))
C["BossArrive"] = mix(osc(60, 28, 1.2) * env(int(SR * 1.2), 0.005) * 1.5, bandpass(noise(1.2), np.geomspace(200, 3000, int(SR * 1.2)), 4000) * np.linspace(0, 1, int(SR * 1.2)) * 0.6)
C["BossStagger"] = mix(bell(220, 0.7, (1, 2.7, 4.3, 6.1)), osc(80, 40, 0.3) * env(int(SR * 0.3)))
C["BossCollapse"] = mix(lowpass(noise(1.8), np.geomspace(800, 80, int(SR * 1.8))) * env(int(SR * 1.8), 0.05, 1.8, 2) * 2.5, osc(55, 25, 1.6) * env(int(SR * 1.6), 0.02))
C["BossDefeat"] = mix(lowpass(noise(2.0), np.geomspace(5000, 120, int(SR * 2.0))) * env(int(SR * 2.0), 0.002, 2.0, 2.5) * 2, osc(70, 22, 1.5) * env(int(SR * 1.5)) * 1.4)
fan = [(523, 0.12), (659, 0.12), (784, 0.12), (1047, 0.5)]
C["BossReward"] = mix(seq(*[note(f, d, "square", decay=d * 2, vol=0.5) + note(f * 2, d, "sine", vol=0.25) for f, d in fan]),
                      at(mix(note(523, 0.8, "tri"), note(659, 0.8, "tri"), note(784, 0.8, "tri")) * 0.5, 0.36))
# --- eggs, hatching, pets -----------------------------------------------------
C["EggTake"] = mix(osc(300, 900, 0.08) * env(int(SR * 0.08)), at(bell(1319, 0.4), 0.06))
C["EggDeliver"] = seq(bell(988, 0.25), bell(1319, 0.45))
C["HatchPulse"] = mix(bell(880, 0.6), bell(1760, 0.6) * 0.4, note(440, 0.6, "sine", 0.05) * 0.3)
crack = mix(*[at(highpass(noise(0.02), 1500) * env(int(SR * 0.02)), d) for d in (0, 0.03, 0.05, 0.09)])
C["HatchBurst"] = mix(crack * 1.5, at(seq(*[bell(f, 0.18) for f in (1047, 1319, 1568, 2093)]), 0.08))
leg = [(523, 0.15), (523, 0.15), (659, 0.15), (784, 0.3), (659, 0.15), (784, 0.7)]
C["HatchLegendary"] = mix(seq(*[note(f, d, "square", decay=d * 3, vol=0.45) + note(f / 2, d, "tri", vol=0.4) for f, d in leg]),
                          at(seq(*[bell(f, 0.2) * 0.5 for f in (2093, 2637, 3136, 4186)]), 1.2))
C["PetLevelUp"] = seq(*[note(f, 0.09, "square", decay=0.15, vol=0.5) for f in (523, 659, 784, 1047)], note(1319, 0.4, "square", decay=0.5, vol=0.5))
# --- vendors / base / clouds --------------------------------------------------
C["OrbOffer"] = mix(bandpass(noise(0.7), np.geomspace(300, 3000, int(SR * 0.7)), 5000) * np.linspace(0, 1, int(SR * 0.7)) * 0.7, at(bell(784, 0.8) + bell(1175, 0.8) * 0.6, 0.6))
C["OrbRefuse"] = seq(note(130, 0.12, "square"), note(110, 0.25, "square"), gap=0.05)
C["Buy"] = seq(bell(1976, 0.12), bell(2637, 0.4))
C["BaseLock"] = mix(highpass(noise(0.03), 2000) * env(int(SR * 0.03)), at(osc(140, 70, 0.2) * env(int(SR * 0.2)), 0.02), at(note(440, 0.5, "tri", 0.05) * 0.4, 0.1))
C["CloudCatch"] = mix(bandpass(noise(0.2), np.geomspace(500, 4000, int(SR * 0.2)), 6000) * env(int(SR * 0.2), 0.02), at(osc(600, 1200, 0.1) * env(int(SR * 0.1)) * 0.6, 0.15))
C["CloudDeliver"] = seq(bell(1568, 0.1), bell(1976, 0.1), bell(2637, 0.45))
C["TutorialStep"] = note(1175, 0.12, "sine", 0.002, vol=0.8)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, y in C.items():
        write(name, np.asarray(y, dtype=float))
    print(f"wrote {len(C)} sounds to {os.path.normpath(OUT)}")
