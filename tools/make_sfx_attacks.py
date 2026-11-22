"""v2.28 A SOUND FOR EVERY ATTACK (director: "every attack plays the same
sound - give each attack its own").

Makes one unique, high-quality sound per attack, built with the same engine
as make_sfx_hq.py:
  * 58 monster/boss special abilities   (key = ability Id, e.g. "ShardVolley")
  * 28 character melee hits              (key = "<Type>Melee", e.g. "PrismawMelee")
  * pet attacks: element x kind          (key = "Pet<Element><Kind>")
  * player attacks                       (PlayerPunch / PlayerSlam / PlayerPuff)

Roblox limits audio uploads per month, so the clips are packed into a few
SOUND ATLASES (long .ogg files with every clip in a row). The game plays just
the clip's part with Sound.PlaybackRegion. Output:
  assets/sfx_atlas/AttackAtlas1.ogg, AttackAtlas2.ogg ...
  src/shared/SfxAtlas.luau  (clip -> atlas, start, length; atlas ids to fill)
Run:  python3 tools/make_sfx_attacks.py
"""
import os, sys, subprocess, tempfile, wave
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from make_sfx_hq import *  # noqa: F401,F403  (building blocks)
import make_sfx_hq as H

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx_atlas")
LUA = os.path.join(os.path.dirname(__file__), "..", "src", "shared", "SfxAtlas.luau")
os.makedirs(OUT, exist_ok=True)
rng = H.rng

A = {}  # name -> fn returning stereo


def snd(name, reverb="room", wet=0.18, width=0.4):
    def deco(fn):
        A[name] = lambda: H.space(H.stereo(fn(), width), reverb, wet)
        return fn
    return deco


# ---------- extra blocks ----------
def snap(amp=1.0, f=2600):
    return H.mix(H.crack(0.006, min(f, 1500), amp * 0.8), H.thump(300, 140, 0.05, amp * 0.5))  # v2.29 woody snap


def chomp(n_bites=1, low=1.0):
    y = np.zeros(1)
    for k in range(n_bites):
        b = H.mix(snap(1, 2400), H.thump(260 * low, 110 * low, 0.1, 0.7, 0.025), H.filt(H.white(0.09), "bp", [500, 2500]) * H.env_exp(0.09, 0.001, 0.025) * 0.7)
        y = H.mix(y, H.at(b, k * 0.085))
    return y


def boing(f0=180, d=0.5, depth=0.35, rate=12):
    x = H.tt(d)
    f = f0 * (1 + depth * np.sin(2 * np.pi * rate * x) * np.exp(-x * 5))
    return np.sin(2 * np.pi * np.cumsum(f) / H.SR) * H.env_exp(d, 0.003, d * 0.4)


def hiss(d=0.6, lo=3000, amp=1.0):
    # v2.29: a low, crunchy SIZZLE instead of a bright hiss
    sizzle = H.grains(d, 500, 200, 700, 3200, 0.004) * 0.8
    return (H.filt(H.white(d), "bp", [500, 2200]) * 0.35 + sizzle) * H.env_adsr(d, 0.02, 0.1, 0.7, d * 0.5) * amp


def slurp(d=0.35, f0=300, f1=900):
    return H.sweep_filter(H.white(d), "bp", f0, f1, q_bw=0.4) * H.env_adsr(d, 0.02, 0.05, 0.8, 0.1) * 1.4


def rumble(d=1.0, amp=1.0, f=140):
    return H.filt(H.brown(d), "lp", f) * H.env_adsr(d, 0.05, 0.2, 0.8, d * 0.5) * amp


def ice_crack(amp=1.0):
    # v2.29: deep ice CRACK with crunch, not glassy tinkle
    return H.mix(H.crack(0.01, 1200, amp * 0.7), H.thump(160, 60, 0.2, amp * 0.8), H.grains(0.35, 500, 40, 700, 3800, 0.005, amp_decay=0.1) * amp)


def pluck(f=900, d=0.25):
    # v2.29: heavier crystal "chunk" (pitch down + body thump), not a bright ping
    f = min(f, 1100) * 0.55
    return H.mix(H.modal([f, f * 2.01, f * 2.9], [d * 0.5, d * 0.25, d * 0.1], [1, 0.3, 0.1], d), H.thump(220, 90, 0.12, 0.6))


def magic(notes, d=0.8):
    # v2.29: warm low bell + soft swell (no airy shimmer)
    notes = [f / 2 for f in notes]
    return H.mix(H.chime(notes, d, 0.05, 0.7) * 0.55, H.sweep_osc(notes[0] / 2, notes[0] / 2, d) * H.env_adsr(d, 0.1, 0.1, 0.6, d * 0.5) * 0.25)


def gust(d=0.5, f0=300, f1=2500, amp=1.0):
    return H.whoosh(d, min(f0, 2200), min(f1, 2600), amp, 1.1)  # v2.29 capped: airy, not hissy


# =====================================================================
# MONSTER / BOSS ABILITIES (58)
# =====================================================================
# Crystal Stalker
@snd("ShardVolley")
def _(): return H.mix(*[H.at(H.mix(gust(0.14, 500, 1800, 0.5), H.thump(170 - k * 15, 70, 0.18, 1.0, 0.05), H.grains(0.18, 600, 100, 500, 2600, 0.006, amp_decay=0.06) * 0.8), k * 0.09) for k in range(3)])
@snd("RefractionDash", "hall", 0.25)
def _(): return H.mix(H.sweep_osc(200, 700, 0.3, "tri") * H.env_exp(0.3, 0.005, 0.12) * 0.5, gust(0.35, 400, 2200, 0.8), H.at(H.thump(140, 60, 0.2, 0.8), 0.25))
# Glacier Tortoise
@snd("PermafrostSlam", "hall", 0.25)
def _(): return H.mix(H.thump(120, 40, 0.5, 1.4, 0.12), ice_crack(1.2), H.at(H.shatter(0.8, 0.9, 1.0) * 0.6, 0.05))
@snd("ShellBastion", "hall", 0.3)
def _(): return H.mix(H.thump(200, 90, 0.2, 0.8), H.sweep_osc(220, 330, 1.2, "tri") * H.env_adsr(1.2, 0.1, 0.2, 0.6, 0.6) * 0.4, H.at(H.chime([659, 988], 1.2, 0.08) * 0.4, 0.1))
# Storm Wraith
@snd("ChainLightning")
def _(): return H.mix(*[H.at(H.zap(0.14, 3800 - k * 400, 600, 150) * (1 - k * 0.12), k * 0.06) for k in range(5)])
@snd("StaticBlink")
def _(): return H.mix(H.sweep_osc(3000, 200, 0.15, "square") * H.env_exp(0.15, 0.001, 0.05) * 0.4, H.at(H.sweep_osc(200, 3000, 0.15, "square") * H.env_exp(0.15, 0.001, 0.05) * 0.4, 0.18), H.at(H.zap(0.2, 2500, 400, 90) * 0.6, 0.18))
# Crystal Whirlwind
@snd("PrismVortex", "hall", 0.25)
def _(): return H.mix(H.sweep_filter(H.pink(1.4), "bp", 300, 2500, q_bw=0.6) * (0.6 + 0.4 * np.sin(2 * np.pi * 6 * H.tt(1.4))) * H.env_adsr(1.4, 0.2, 0.2, 0.8, 0.5), H.grains(1.4, 60, 60, 4000, 11000, 0.003) * 0.4)
@snd("ShardCyclone")
def _(): return H.mix(gust(0.5, 400, 3500, 0.8), H.at(H.shatter(0.7, 1.2, 0.7) * 0.7, 0.3))
@snd("VortexPull")
def _(): return H.sweep_filter(H.pink(1.0), "bp", 3000, 300, q_bw=0.7) * H.env_adsr(1.0, 0.1, 0.2, 0.8, 0.4) * 1.2
@snd("GaleBurst")
def _(): return H.mix(H.thump(90, 50, 0.3, 0.6), gust(0.6, 200, 4000, 1.2), gust(0.4, 2000, 8000, 0.4))
# Magma Tyrant
@snd("MagmaGeyser", "hall", 0.25)
def _(): return H.mix(rumble(0.6, 0.8, 120), H.at(H.mix(H.explosion(1.2, 0.6, 0.7, 0.6, 60), H.fire_roar(1.2, 0.8)), 0.4))
@snd("EmberWings")
def _(): return H.mix(H.at(gust(0.35, 300, 1500, 0.9), 0), H.at(gust(0.35, 300, 1500, 0.9), 0.18), H.fire_roar(0.8, 0.6))
# Ember Blob
@snd("FuseHop", "hall", 0.2)
def _(): return H.mix(hiss(0.5, 4000, 0.4), H.at(boing(220, 0.25, 0.3, 9) * 0.6, 0.3), H.at(H.explosion(1.0, 0.45, 1.1, 0.7, 75), 0.45))
@snd("AshPuff")
def _(): return H.mix(H.filt(H.pink(0.9), "lp", 900) * H.env_exp(0.9, 0.01, 0.25) * 1.5, H.grains(0.9, 120, 20, 1500, 5000, 0.002) * 0.4)
# Toadstool Strider
@snd("SporeBloom", "hall", 0.25)
def _(): return H.mix(H.filt(H.pink(0.8), "lp", 1600) * H.env_exp(0.8, 0.05, 0.25), magic([523, 784, 1046], 1.0) * 0.6)
@snd("SproutSquad")
def _(): return H.mix(*[H.at(H.bubble(500 + k * 160, 0.12, 2.0) * 0.7, k * 0.12) for k in range(3)], H.at(magic([1046, 1318]) * 0.3, 0.1))
# Fungal Brute
@snd("SpineSpray")
def _(): return H.mix(*[H.at(H.mix(snap(0.6, 1400), H.thump(260, 120, 0.06, 0.4)), k * 0.035) for k in range(10)], gust(0.4, 300, 1500, 0.4))
@snd("MyceliumGrip")
def _(): return H.mix(H.grains(0.7, 400, 100, 300, 2500, 0.01) * 1.2, H.sweep_osc(90, 60, 0.7, "saw") * H.env_adsr(0.7, 0.1, 0.1, 0.7, 0.3) * 0.2)
# Watching Rubble
@snd("OrbitCrush", "hall", 0.22)
def _(): return H.mix(H.sweep_filter(H.pink(0.6), "bp", 200, 1200, q_bw=0.8) * np.linspace(0.2, 1, H.n(0.6)) * 0.6, H.at(H.rock_crunch(0.9, 1.4), 0.55))
@snd("VoidGaze", "hall", 0.3)
def _(): return H.mix(H.sweep_osc(60, 40, 1.2, "saw") * H.env_adsr(1.2, 0.3, 0.2, 0.8, 0.4) * 0.5, H.sweep_filter(H.white(1.2), "bp", 4000, 300, q_bw=0.3) * H.env_adsr(1.2, 0.4, 0.1, 0.8, 0.3) * 0.5, H.at(H.thump(100, 30, 0.5, 1.2), 0.9))
# Bramble Brute
@snd("ThornCharge")
def _(): return H.mix(H.grains(0.6, 200, 200, 200, 1500, 0.02) * 0.9, H.at(H.mix(H.thump(140, 45, 0.3, 1.3), H.grains(0.3, 600, 50, 1500, 6000, 0.004) * 0.7), 0.45))
@snd("BrambleWall")
def _(): return H.mix(*[H.at(H.mix(H.grains(0.25, 600, 80, 400, 3000, 0.006), H.thump(180, 80, 0.12, 0.5)), k * 0.08) for k in range(5)])
# Storm Snapper
@snd("SnapLunge")
def _(): return H.mix(chomp(1, 0.9), H.at(H.zap(0.25, 2500, 300, 120) * 0.7, 0.04))
@snd("AcidSpit")
def _(): return H.mix(slurp(0.2, 300, 900) * 0.7, H.at(H.mix(H.thump(150, 60, 0.2, 0.9), H.splash(0.5, 0.7) * 0.5, hiss(0.8, 0, 0.7), *[H.at(H.bubble(rng.uniform(180, 320), 0.1, 1.6) * 0.4, rng.uniform(0.05, 0.5)) for _ in range(5)]), 0.15))
# Mossy Golem
@snd("BoulderToss", "hall", 0.22)
def _(): return H.mix(gust(0.5, 150, 900, 0.6), H.at(H.rock_crunch(1.1, 1.6), 0.45))
@snd("VineLash")
def _(): return H.mix(H.sweep_filter(H.white(0.25), "bp", 800, 6000, q_bw=0.3) * H.env_exp(0.25, 0.005, 0.06), H.at(snap(1.2, 2000), 0.12), H.at(H.grains(0.2, 300, 50, 600, 3000, 0.006) * 0.5, 0.12))
# Fanged Glutton
@snd("FrenzyBite")
def _(): return H.mix(chomp(4, 0.8), H.growl(0.4, 140, 110) * 0.3)
@snd("GroundPound", "hall", 0.22)
def _(): return H.mix(H.at(H.thump(110, 35, 0.6, 1.6, 0.18), 0), H.at(H.thump(110, 35, 0.4, 1.1, 0.12), 0.22), H.at(H.rock_crunch(0.8, 0.9) * 0.8, 0.22))
# Sky Shark
@snd("FinDive")
def _(): return H.mix(gust(0.4, 2500, 400, 0.6), H.at(H.splash(1.0, 1.3), 0.35))
@snd("TailSpin")
def _(): return H.mix(*[H.at(gust(0.18, 600, 3000, 0.7), k * 0.13) for k in range(4)], H.at(H.splash(0.5, 0.6) * 0.5, 0.4))
# Cloud Ram
@snd("WoolBounce")
def _(): return H.mix(boing(130, 0.6, 0.4, 7), H.thump(150, 70, 0.25, 0.9), H.filt(H.pink(0.4), "lp", 1200) * H.env_exp(0.4, 0.01, 0.1) * 0.6)
@snd("StaticFluff")
def _(): return H.mix(H.grains(0.9, 300, 300, 800, 3500, 0.003) * 0.8, H.filt(H.pink(0.9), "lp", 900) * H.env_exp(0.9, 0.02, 0.3) * 0.7, H.at(H.zap(0.2, 1800, 300, 70) * 0.4, 0.3))
# Snow Owl
@snd("SnowballBarrage")
def _(): return H.mix(*[H.at(H.mix(H.filt(H.white(0.12), "bp", [400, 2500]) * H.env_exp(0.12, 0.002, 0.03), H.thump(200, 100, 0.08, 0.4)), k * 0.11) for k in range(5)])
@snd("WingGust", "hall", 0.2)
def _(): return H.mix(*[H.at(gust(0.3, 250, 1800, 0.8), k * 0.22) for k in range(2)], H.at(gust(0.6, 1500, 6000, 0.4), 0.3))
# Spore Moth
@snd("SporeSpiral")
def _(): return H.mix(H.sweep_osc(600, 1500, 0.6, "sine") * (0.5 + 0.5 * np.sin(2 * np.pi * 14 * H.tt(0.6))) * H.env_adsr(0.6, 0.05, 0.1, 0.7, 0.3) * 0.4, magic([1318, 1760], 0.6) * 0.5)
@snd("LullabyDust", "hall", 0.35)
def _(): return H.mix(H.chime([784, 659, 523, 392], 1.4, 0.18, 0.8) * 0.6, H.filt(H.white(1.6), "hp", 7000) * H.env_adsr(1.6, 0.4, 0.2, 0.5, 0.8) * 0.15)
# Storm Frog
@snd("TongueLash")
def _(): return H.mix(slurp(0.3, 400, 1600), H.at(snap(0.9, 1800), 0.25), H.at(H.bubble(300, 0.1, 1.6) * 0.5, 0.3))
@snd("ThunderCroak", "hall", 0.25)
def _(): return H.mix(H.formant(H.sweep_osc(90, 70, 0.6, "saw"), ((300, 1), (900, 0.5)), 60) * H.env_adsr(0.6, 0.02, 0.1, 0.8, 0.2) * 0.9, H.at(H.zap(0.35, 2600, 200, 80) * 0.7, 0.35))
# Crystal Scuttler
@snd("PincerSnap")
def _(): return H.mix(H.modal([1800, 3100, 4600], [0.15, 0.1, 0.06], [1, 0.6, 0.3], 0.3) * 0.7, snap(1.2, 3000), H.at(snap(0.8, 3200), 0.06))
@snd("CrystalSting")
def _(): return H.mix(gust(0.14, 600, 2000, 0.5), H.at(pluck(1000, 0.4) * 0.8, 0.1), H.at(ice_crack(0.6), 0.1))
# Lava Salamander
@snd("FlameDash")
def _(): return H.mix(gust(0.5, 200, 2500, 1.0), H.fire_roar(0.7, 0.8), H.grains(0.6, 150, 50, 1500, 6000, 0.002) * 0.5)
@snd("EmberSpit")
def _(): return H.mix(H.sweep_filter(H.white(0.12), "bp", 400, 1400, q_bw=0.6) * H.env_exp(0.12, 0.002, 0.04), H.at(H.mix(H.fire_roar(0.6, 0.7), H.thump(160, 60, 0.2, 0.9)), 0.1))
# Tide Octopus
@snd("InkCloud")
def _(): return H.mix(H.filt(H.brown(0.9), "lp", 600) * H.env_exp(0.9, 0.02, 0.3) * 1.2, *[H.at(H.bubble(rng.uniform(150, 350), 0.15, 1.6) * 0.5, rng.uniform(0, 0.6)) for _ in range(6)])
@snd("TentacleSlam", "hall", 0.22)
def _(): return H.mix(H.sweep_filter(H.white(0.3), "bp", 400, 2500, q_bw=0.4) * H.env_exp(0.3, 0.01, 0.1), H.at(H.mix(H.thump(120, 45, 0.4, 1.2), H.splash(0.6, 0.7) * 0.6), 0.2))
# ---- boss abilities ----
@snd("PillarRise", "huge", 0.25)
def _(): return H.mix(rumble(0.7, 0.9, 120), *[H.at(H.mix(H.rock_crunch(0.6, 1.2), H.thump(90, 40, 0.3, 1.0)), 0.5 + k * 0.12) for k in range(3)])
@snd("RidgeShockwave", "huge", 0.25)
def _(): return H.mix(*[H.at(H.mix(H.thump(100, 40, 0.3, 1.0), H.grains(0.3, 500, 40, 300, 2500, 0.008) * 0.8), k * 0.09) for k in range(6)])
@snd("AvalancheSweep", "huge", 0.25)
def _(): return H.mix(rumble(1.8, 1.2, 250), H.filt(H.pink(1.8), "lp", 2500) * H.env_adsr(1.8, 0.3, 0.3, 0.8, 0.6) * 0.7, H.grains(1.8, 200, 300, 800, 4000, 0.01) * 0.6)
@snd("IceRing", "huge", 0.28)
def _(): return H.mix(H.sweep_osc(300, 900, 0.5, "tri") * H.env_adsr(0.5, 0.3, 0.05, 0.8, 0.1) * 0.3, H.at(H.mix(*[H.at(ice_crack(0.9), k * 0.05) for k in range(6)], H.thump(100, 40, 0.5, 1.2)), 0.5))
@snd("SporeDoubles", "hall", 0.3)
def _(): return H.mix(*[H.at(H.mix(H.filt(H.pink(0.4), "lp", 1400) * H.env_exp(0.4, 0.02, 0.1), H.bubble(260 + k * 80, 0.15, 2.0) * 0.5), k * 0.2) for k in range(3)], H.at(magic([392, 523, 659]) * 0.5, 0.1))
@snd("RootSnare", "hall", 0.25)
def _(): return H.mix(H.grains(1.0, 300, 600, 200, 1800, 0.015) * 1.2, H.sweep_osc(70, 50, 1.0, "saw") * H.env_adsr(1.0, 0.2, 0.2, 0.7, 0.3) * 0.25, H.at(snap(1.0, 1500), 0.6))
@snd("ThunderWave", "huge", 0.28)
def _(): return H.mix(H.zap(0.6, 3500, 150, 60), H.at(H.explosion(1.6, 0.8, 1.2, 0.3, 50), 0.15), H.at(H.zap(0.3, 2000, 300, 90) * 0.5, 0.5))
@snd("TongueSweep", "hall", 0.22)
def _(): return H.mix(slurp(0.6, 250, 1200) * 1.2, H.at(gust(0.4, 300, 2000, 0.7), 0.15), H.at(snap(0.9, 1500), 0.55))
@snd("ShardBarrage", "hall", 0.25)
def _(): return H.mix(*[H.at(H.mix(pluck(2000 + 250 * k, 0.35) * 0.6, gust(0.1, 3000, 9000, 0.3)), k * 0.05) for k in range(9)])
@snd("CrystalWalls", "huge", 0.25)
def _(): return H.mix(*[H.at(H.mix(H.thump(140, 60, 0.25, 0.8), H.shatter(0.5, 0.9, 0.4) * 0.6), k * 0.1) for k in range(4)])
@snd("LavaLanes", "huge", 0.25)
def _(): return H.mix(rumble(0.8, 1.0, 160), H.at(H.mix(*[H.at(H.fire_roar(0.6, 0.7), k * 0.1) for k in range(4)]), 0.4), H.at(H.explosion(1.0, 0.5, 0.8, 0.5, 60) * 0.6, 0.45))
@snd("CraterStomp", "huge", 0.3)
def _(): return H.mix(H.thump(80, 25, 0.9, 2.0, 0.3), H.explosion(2.2, 1.4, 0.9, 1.2, 40), H.at(H.rock_crunch(1.2, 1.5) * 0.7, 0.1))
@snd("TideWall", "huge", 0.25)
def _(): return H.mix(H.filt(H.pink(1.6), "bp", [150, 2000]) * H.env_adsr(1.6, 0.6, 0.2, 0.9, 0.5) * 1.1, H.at(H.splash(1.2, 1.8), 0.7))
@snd("InkSweep", "hall", 0.22)
def _(): return H.mix(gust(0.5, 200, 1500, 0.8), H.at(H.mix(H.filt(H.brown(0.7), "lp", 700) * H.env_exp(0.7, 0.01, 0.2), H.splash(0.5, 0.5) * 0.5), 0.2))

# =====================================================================
# MELEE per character (28): body size + element texture + its own gesture
# =====================================================================
MELEE = {
    "Prismaw": lambda: H.mix(gust(0.15, 1500, 6000, 0.5), H.at(H.mix(snap(1, 3000), pluck(2600, 0.3) * 0.6), 0.1)),
    "Frostback": lambda: H.mix(H.thump(110, 45, 0.4, 1.3, 0.1), ice_crack(0.7)),
    "Voltwraith": lambda: H.mix(gust(0.15, 800, 4000, 0.4), H.at(H.zap(0.18, 3000, 600, 160) * 0.8, 0.08)),
    "Shardstorm": lambda: H.mix(gust(0.25, 800, 5000, 0.7), H.at(H.shatter(0.4, 1.1, 0.4) * 0.5, 0.15)),
    "Cindermaw": lambda: H.mix(H.thump(120, 40, 0.4, 1.4), H.fire_roar(0.4, 0.6), snap(0.8, 1500)),
    "Smoldlet": lambda: H.mix(boing(240, 0.2, 0.2, 10) * 0.5, H.thump(220, 90, 0.12, 0.6), hiss(0.3, 3500, 0.4)),
    "Capstride": lambda: H.mix(H.thump(180, 80, 0.15, 0.8), H.filt(H.pink(0.3), "lp", 1200) * H.env_exp(0.3, 0.01, 0.08) * 0.8),
    "Sporeback": lambda: H.mix(H.thump(130, 50, 0.3, 1.1), H.mix(*[H.at(snap(0.4, 3500), k * 0.02) for k in range(5)])),
    "Rubbleye": lambda: H.mix(H.rock_crunch(0.4, 0.7), H.sweep_osc(60, 40, 0.3, "saw") * H.env_exp(0.3, 0.01, 0.1) * 0.3),
    "Bristlehulk": lambda: H.mix(H.thump(120, 45, 0.3, 1.2), H.grains(0.25, 500, 60, 600, 4000, 0.005) * 0.7),
    "Gulpvine": lambda: H.mix(chomp(1, 1.1), H.at(H.zap(0.12, 2500, 800, 100) * 0.4, 0.05)),
    "Mossgrave": lambda: H.mix(H.thump(90, 32, 0.5, 1.6, 0.14), H.rock_crunch(0.4, 0.6) * 0.6),
    "Gnashgut": lambda: chomp(2, 0.7),
    "Skyfin": lambda: H.mix(chomp(1, 1.0), H.at(H.splash(0.3, 0.4) * 0.5, 0.05)),
    "Puffhorn": lambda: H.mix(H.thump(160, 70, 0.2, 1.0), boing(170, 0.3, 0.25, 8) * 0.4),
    "Snowpeck": lambda: H.mix(gust(0.15, 700, 3000, 0.6), H.at(H.mix(snap(0.8, 3000), H.filt(H.white(0.08), "bp", [1000, 5000]) * H.env_exp(0.08, 0.001, 0.02) * 0.5), 0.08)),
    "Glowmoth": lambda: H.mix(gust(0.2, 1500, 5000, 0.4), H.at(magic([1568]) * 0.4, 0.05)),
    "Croakle": lambda: H.mix(H.thump(170, 80, 0.15, 0.8), H.bubble(320, 0.1, 1.7) * 0.6, H.at(H.zap(0.1, 3000, 900, 150) * 0.3, 0.05)),
    "Geoscuttle": lambda: H.mix(H.modal([1700, 2900], [0.12, 0.08], [1, 0.5], 0.25) * 0.5, snap(1, 2800)),
    "Scorchtail": lambda: H.mix(gust(0.2, 300, 2000, 0.6), H.at(H.mix(snap(0.9, 2000), H.fire_roar(0.35, 0.5)), 0.1)),
    "Octoblob": lambda: H.mix(H.sweep_filter(H.white(0.2), "bp", 400, 1800, q_bw=0.5) * H.env_exp(0.2, 0.005, 0.06), H.thump(140, 60, 0.2, 0.8), H.bubble(240, 0.12, 1.5) * 0.4),
    "Shroomling": lambda: H.mix(H.thump(260, 140, 0.08, 0.5), H.filt(H.pink(0.15), "lp", 1500) * H.env_exp(0.15, 0.005, 0.04) * 0.6),
    "MesaColossus": lambda: H.mix(H.thump(80, 25, 0.8, 2.0, 0.22), H.rock_crunch(0.9, 1.4), snap(1.0, 1200)),
    "FrostpeakWarden": lambda: H.mix(H.thump(85, 28, 0.7, 1.8, 0.2), ice_crack(1.2), H.shatter(0.6, 0.8, 0.5) * 0.4),
    "MyceliumMonarch": lambda: H.mix(H.thump(95, 35, 0.6, 1.6, 0.18), H.filt(H.pink(0.6), "lp", 1400) * H.env_exp(0.6, 0.02, 0.15) * 0.8),
    "BogstormCroaker": lambda: H.mix(H.thump(90, 30, 0.6, 1.7, 0.18), H.zap(0.3, 3000, 300, 80) * 0.6),
    "PrismSovereign": lambda: H.mix(H.thump(100, 35, 0.5, 1.5, 0.15), H.shatter(0.7, 1.1, 0.7) * 0.6),
    "CalderaTitan": lambda: H.mix(H.thump(75, 24, 0.9, 2.1, 0.25), H.fire_roar(0.7, 0.8), H.rock_crunch(0.6, 0.9) * 0.6),
    "Tidebreaker": lambda: H.mix(H.thump(85, 28, 0.7, 1.8, 0.2), H.splash(0.7, 1.1) * 0.7),
}
for name, fn in MELEE.items():
    big = name in ("MesaColossus", "FrostpeakWarden", "MyceliumMonarch", "BogstormCroaker", "PrismSovereign", "CalderaTitan", "Tidebreaker")
    A[name + "Melee"] = (lambda f=fn, b=big: H.space(H.stereo(f(), 0.35), "hall" if b else "room", 0.22 if b else 0.14))

# =====================================================================
# PETS: element texture x attack gesture  (cute & lighter than monsters)
# =====================================================================
EL = {
    "Earth": lambda: H.rock_crunch(0.35, 0.5) * 0.7,
    "Ice": lambda: ice_crack(0.6),
    "Spore": lambda: H.filt(H.pink(0.35), "lp", 1500) * H.env_exp(0.35, 0.01, 0.1) * 0.9,
    "Electric": lambda: H.zap(0.16, 3200, 900, 180) * 0.6,
    "Crystal": lambda: pluck(900, 0.4) * 0.7,
    "Fire": lambda: H.fire_roar(0.4, 0.6),
    "Water": lambda: H.mix(H.bubble(420, 0.1, 1.8) * 0.6, H.at(H.bubble(600, 0.08, 1.8) * 0.4, 0.06)),
    "Wind": lambda: gust(0.25, 800, 4000, 0.6),
}
PITCH = {"Earth": 0.75, "Ice": 0.95, "Spore": 0.9, "Electric": 0.9, "Crystal": 1.0, "Fire": 0.85, "Water": 0.9, "Wind": 1.0}
KIND = {
    "Bite": lambda p: chomp(1, 1.3 * p),
    "Bolt": lambda p: H.mix(H.sweep_osc(300 * p, 800 * p, 0.15, "tri") * H.env_exp(0.15, 0.002, 0.06) * 0.5, H.at(H.thump(200 * p, 80, 0.12, 0.8), 0.12)),
    "Lob": lambda p: H.mix(gust(0.25, 600, 1500, 0.4), H.at(H.thump(200 * p, 90 * p, 0.15, 0.7), 0.25)),
    "Pulse": lambda p: H.mix(H.sweep_osc(180 * p, 360 * p, 0.4) * H.env_adsr(0.4, 0.05, 0.1, 0.7, 0.2) * 0.6, magic([880 * p, 1320 * p], 0.5) * 0.4),
    "Chain": lambda p: H.mix(*[H.at(H.zap(0.1, 1600 * p, 300, 90) * 0.5, k * 0.06) for k in range(3)]),
    "Mend": lambda p: magic([660 * p, 880 * p, 1100 * p], 0.7),
}
for el, tex in EL.items():
    for kind, gest in KIND.items():
        A["Pet" + el + kind] = (lambda t=tex, g=gest, p=PITCH[el]: H.space(H.stereo(H.mix(g(p), H.at(t(), 0.04)), 0.4), "room", 0.16))

# =====================================================================
# PLAYER (cloud wind)
# =====================================================================
@snd("PlayerPunch")
def _(): return H.mix(gust(0.18, 600, 3500, 0.7), H.at(H.mix(snap(0.7, 2500), H.thump(170, 70, 0.12, 0.6)), 0.1))
@snd("PlayerSlam", "hall", 0.2)
def _(): return H.mix(gust(0.3, 2500, 400, 0.5), H.at(H.mix(H.thump(120, 40, 0.4, 1.3, 0.1), H.filt(H.pink(0.5), "lp", 1500) * H.env_exp(0.5, 0.01, 0.12) * 0.8), 0.25))
@snd("PlayerPuff")
def _(): return H.mix(H.filt(H.pink(0.3), "bp", [300, 2500]) * H.env_exp(0.3, 0.005, 0.07) * 1.2, H.bubble(380, 0.08, 1.4) * 0.3)


# =====================================================================
# pack into atlases
# =====================================================================
# v2.29: the 50 base cues go into the atlas too (re-made darker; an atlas
# clip wins over SfxIds), so fixing them costs no extra uploads
for _name, (_fn, _r) in H.C.items():
    A.setdefault(_name, _fn)

UI = {"Buy", "TutorialStep", "CloudDeliver", "CloudCatch", "PetLevelUp", "BossReward", "OrbOffer", "OrbRefuse", "EggTake", "EggDeliver"}


def darken(name, st):
    """v2.29 director: no bright/tinny sounds - roll off the top, add weight"""
    cut = 8000 if name in UI else 5500
    out = []
    for ch in st:
        y = H.filt(ch, "lp", cut, 2)
        y = y + 0.35 * H.filt(y, "lp", 220, 2)
        out.append(y)
    return np.stack(out)


GAP = 0.35
MAX_LEN = 175.0  # seconds per atlas (well under Roblox's audio length limit)


def encode(path_ogg, st):
    data = (np.clip(st.T, -1, 1) * 32767).astype("<i2").tobytes()
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        p = tmp.name
    with wave.open(p, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(H.SR)
        w.writeframes(data)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", p, "-c:a", "libvorbis", "-q:a", "6", path_ogg], check=True)
    os.remove(p)


if __name__ == "__main__":
    atlases, clips = [], {}
    cur, cur_len, idx = [], 0.0, 1
    for name, fn in A.items():
        st = H.master(darken(name, fn()), target_rms=0.15)
        L = st.shape[1] / H.SR
        if cur_len + L + GAP > MAX_LEN and cur:
            atlases.append(cur)
            cur, cur_len, idx = [], 0.0, idx + 1
        clips[name] = ("AttackAtlas%d" % idx, round(cur_len + 0.01, 4), round(L - 0.02, 4))
        cur.append(st)
        cur.append(np.zeros((2, H.n(GAP))))
        cur_len += L + GAP
    if cur:
        atlases.append(cur)
    for i, parts in enumerate(atlases, 1):
        encode(os.path.join(OUT, "AttackAtlas%d.ogg" % i), np.concatenate(parts, axis=1))
    # Luau map
    lines = [
        "-- v2.28 GENERATED by tools/make_sfx_attacks.py — do not edit by hand.",
        "-- One unique sound per attack, packed into sound atlases (Roblox limits",
        "-- audio uploads). Sfx plays only the clip's part (PlaybackRegion).",
        "-- Upload assets/sfx_atlas/AttackAtlas*.ogg and paste their ids in Atlases.",
        "local M = {}",
        "M.Atlases = {",
    ]
    for i in range(1, len(atlases) + 1):
        lines.append('\tAttackAtlas%d = "",' % i)
    lines += ["}", "-- clip = { atlas, start (s), length (s) }", "M.Clips = {"]
    for name, (atl, start, length) in clips.items():
        lines.append('\t%s = { "%s", %s, %s },' % (name, atl, start, length))
    lines += ["}", "return M", ""]
    # keep ids already pasted
    if os.path.exists(LUA):
        old = open(LUA).read()
        import re
        for m in re.finditer(r'(AttackAtlas\d+) = "(rbxassetid://\d+)"', old):
            lines = [l.replace('\t%s = "",' % m.group(1), '\t%s = "%s",' % (m.group(1), m.group(2))) for l in lines]
    open(LUA, "w").write("\n".join(lines))
    print("clips:", len(clips), "atlases:", len(atlases), [round(sum(p.shape[1] for p in a) / H.SR, 1) for a in atlases])
