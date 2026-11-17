#!/usr/bin/env python3
"""Generates every R15 animation for Steal a Cloud from ONE definition list.

Outputs:
  assets/animations/<Name>.rbxmx   KeyframeSequence files you can import into
                                   the Roblox Animation Editor and publish.
  src/shared/AnimationData.luau    The same keyframes as a Luau table, so the
                                   game can play them in Studio before they are
                                   published (KeyframeSequenceProvider).

Run:  python3 tools/make_animations.py

Angles are degrees in joint space (R15, Motor6D.Transform):
  +X = swing forward (arms/legs), lean back (torso), look up (head)
  +Z on RightUpperArm = raise out to the right; -Z on LeftUpperArm = raise left
  +X on LowerArm = bend elbow forward; -X on LowerLeg = bend knee
Position offsets (studs) are allowed as a 2nd tuple, e.g. LowerTorso crouch.
"""

import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# R15 pose tree: child -> parent
PARENT = {
    "LowerTorso": "HumanoidRootPart",
    "UpperTorso": "LowerTorso",
    "Head": "UpperTorso",
    "LeftUpperArm": "UpperTorso", "LeftLowerArm": "LeftUpperArm", "LeftHand": "LeftLowerArm",
    "RightUpperArm": "UpperTorso", "RightLowerArm": "RightUpperArm", "RightHand": "RightLowerArm",
    "LeftUpperLeg": "LowerTorso", "LeftLowerLeg": "LeftUpperLeg", "LeftFoot": "LeftLowerLeg",
    "RightUpperLeg": "LowerTorso", "RightLowerLeg": "RightUpperLeg", "RightFoot": "RightLowerLeg",
}
ORDER = ["HumanoidRootPart", "LowerTorso", "UpperTorso", "Head",
         "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
         "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"]

PRIORITY = {"Idle": 0, "Movement": 1, "Action": 2, "Action2": 3, "Action3": 4, "Action4": 5}

# Short names
LT, UT, H = "LowerTorso", "UpperTorso", "Head"
LUA, LLA, RUA, RLA = "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm"
LUL, LLL, RUL, RLL = "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg"

# name: (loop, priority, description, [(time, {part: (rx, ry, rz) or ((rx,ry,rz),(px,py,pz))})])
ANIMS = {
    "NpcIdle": (True, "Idle", "Shopkeeper breathing idle (Tayron, Aurelius)", [
        (0.0, {}),
        (1.4, {UT: (-3, 4, 0), H: (3, -4, 0), RUA: (0, 0, 3), LUA: (0, 0, -3)}),
        (2.8, {}),
    ]),
    "NpcWave": (False, "Action", "Shopkeeper greets a player", [
        # Upper arm out to the side just above shoulder height, forearm up and
        # swinging OUTSIDE the head (old version raised it to 150 deg and the
        # hand passed through the head).
        (0.0, {}),
        (0.3, {RUA: (10, 0, 95), RLA: (0, 0, 60), H: (0, 0, -6)}),
        (0.5, {RUA: (10, 0, 95), RLA: (0, 0, 35), H: (0, 0, -6)}),
        (0.7, {RUA: (10, 0, 95), RLA: (0, 0, 80), H: (0, 0, -6)}),
        (0.9, {RUA: (10, 0, 95), RLA: (0, 0, 35), H: (0, 0, -6)}),
        (1.1, {RUA: (10, 0, 95), RLA: (0, 0, 80), H: (0, 0, -6)}),
        (1.5, {}),
    ]),
    "LeashHold": (True, "Action", "Left arm holds the leash back toward the cloud (legs keep walking)", [
        (0.0, {LUA: (-35, 0, -12), LLA: (15, 0, 0)}),
        (0.6, {LUA: (-42, 0, -16), LLA: (22, 0, 0)}),
        (1.2, {LUA: (-35, 0, -12), LLA: (15, 0, 0)}),
    ]),
    "Catch": (False, "Action2", "Reach up and hug a wild cloud in (hold E)", [
        (0.0, {}),
        (0.15, {UT: (8, 0, 0), RUA: (150, 0, 15), LUA: (150, 0, -15), H: (15, 0, 0)}),
        (0.35, {UT: (-8, 0, 0), RUA: (60, 0, 25), LUA: (60, 0, -25), RLA: (70, 0, 0), LLA: (70, 0, 0)}),
        (0.6, {}),
    ]),
    "Steal": (False, "Action2", "Crouch, reach into a vault, yank the cloud out", [
        (0.0, {}),
        (0.3, {LT: ((0, 0, 0), (0, -0.6, 0)), UT: (-25, 0, 0), RUA: (70, 0, 10), LUA: (70, 0, -10),
               LUL: (35, 0, 0), RUL: (35, 0, 0), LLL: (-50, 0, 0), RLL: (-50, 0, 0)}),
        (0.75, {LT: ((0, 0, 0), (0, -0.6, 0)), UT: (-30, 10, 0), RUA: (95, 0, 10), LUA: (95, 0, -10),
                RLA: (10, 0, 0), LLA: (10, 0, 0), LUL: (35, 0, 0), RUL: (35, 0, 0), LLL: (-50, 0, 0), RLL: (-50, 0, 0)}),
        (1.0, {UT: (10, -10, 0), RUA: (30, 0, 20), LUA: (30, 0, -20), RLA: (80, 0, 0), LLA: (80, 0, 0)}),
        (1.25, {}),
    ]),
    "Slip": (True, "Action3", "Arms flail while sliding on ice/rain", [
        (0.0, {UT: (12, 0, 0), RUA: (40, 0, 80), LUA: (-20, 0, -110), RUL: (40, 0, 0), H: (15, 0, 0)}),
        (0.18, {UT: (15, 0, 8), RUA: (-20, 0, 120), LUA: (40, 0, -70), LUL: (45, 0, 0), H: (20, 10, 0)}),
        (0.36, {UT: (12, 0, 0), RUA: (40, 0, 80), LUA: (-20, 0, -110), RUL: (40, 0, 0), H: (15, 0, 0)}),
    ]),
    "UpdraftFloat": (True, "Action", "Skydiver pose while riding the updraft", [
        (0.0, {UT: (10, 0, 0), RUA: (0, 0, 70), LUA: (0, 0, -70), RLA: (0, 0, 15), LLA: (0, 0, -15),
               LUL: (-15, 0, -8), RUL: (-15, 0, 8), LLL: (-25, 0, 0), RLL: (-25, 0, 0), H: (10, 0, 0)}),
        (0.8, {UT: (12, 0, 0), RUA: (0, 0, 80), LUA: (0, 0, -80), RLA: (0, 0, 20), LLA: (0, 0, -20),
               LUL: (-20, 0, -10), RUL: (-10, 0, 10), LLL: (-30, 0, 0), RLL: (-20, 0, 0), H: (12, 0, 0)}),
        (1.6, {UT: (10, 0, 0), RUA: (0, 0, 70), LUA: (0, 0, -70), RLA: (0, 0, 15), LLA: (0, 0, -15),
               LUL: (-15, 0, -8), RUL: (-15, 0, 8), LLL: (-25, 0, 0), RLL: (-25, 0, 0), H: (10, 0, 0)}),
    ]),
    "Cheer": (False, "Action2", "Victory pose after delivering a cloud", [
        (0.0, {}),
        (0.2, {LT: ((0, 0, 0), (0, -0.4, 0)), LUL: (25, 0, 0), RUL: (25, 0, 0), LLL: (-40, 0, 0), RLL: (-40, 0, 0),
               RUA: (20, 0, 40), LUA: (20, 0, -40)}),
        (0.45, {LT: ((0, 0, 0), (0, 0.5, 0)), RUA: (0, 0, 165), LUA: (0, 0, -165), H: (15, 0, 0)}),
        (0.7, {RUA: (0, 0, 150), LUA: (0, 0, -150), RLA: (0, 0, 20), LLA: (0, 0, -20), H: (10, 0, 0)}),
        (0.95, {RUA: (0, 0, 165), LUA: (0, 0, -165), H: (15, 0, 0)}),
        (1.3, {}),
    ]),
    "Shoot": (False, "Action2", "Fire the Laser Gun (right arm aims, recoil)", [
        (0.0, {UT: (0, 20, 0), RUA: (90, 0, 0), H: (0, -15, 0)}),
        (0.08, {UT: (4, 22, 0), RUA: (105, 0, 0), RLA: (15, 0, 0), H: (0, -15, 0)}),
        (0.3, {UT: (0, 20, 0), RUA: (90, 0, 0), H: (0, -15, 0)}),
        (0.5, {}),
    ]),
    "Drink": (False, "Action2", "Drink a potion (Speed/Jump/Nitro)", [
        (0.0, {}),
        (0.25, {RUA: (60, 0, 15), RLA: (110, 0, 0)}),
        (0.45, {RUA: (75, 0, 25), RLA: (125, 0, 0), H: (25, 0, 0)}),
        (0.75, {RUA: (75, 0, 25), RLA: (125, 0, 0), H: (30, 0, 0)}),
        (1.0, {}),
    ]),
    "Throw": (False, "Action2", "Wind up and throw (Flare, Grappling Hook, Shield Generator)", [
        (0.0, {}),
        (0.18, {UT: (0, -25, 0), RUA: (150, 0, 20), RLA: (60, 0, 0), LUA: (40, 0, -10)}),
        (0.32, {UT: (-10, 20, 0), RUA: (70, 0, 5), RLA: (5, 0, 0), LUA: (-10, 0, -15)}),
        (0.6, {}),
    ]),
    "Knocked": (False, "Action3", "Hit by lightning / laser: flinch back", [
        (0.0, {}),
        (0.1, {UT: (20, 0, 0), H: (25, 0, 0), RUA: (30, 0, 60), LUA: (30, 0, -60), RLA: (40, 0, 0), LLA: (40, 0, 0)}),
        (0.35, {UT: (10, 0, 5), H: (10, 0, 0), RUA: (10, 0, 30), LUA: (10, 0, -30)}),
        (0.7, {}),
    ]),
    "Ability": (False, "Action2", "Use a perk ability (Blink / Dazzle): clap and burst", [
        (0.0, {}),
        (0.15, {RUA: (90, 0, -20), LUA: (90, 0, 20), RLA: (20, 0, 0), LLA: (20, 0, 0)}),
        (0.3, {RUA: (60, 0, 110), LUA: (60, 0, -110), UT: (8, 0, 0), H: (10, 0, 0)}),
        (0.6, {}),
    ]),
}


def rot(rx, ry, rz):
    """CFrame.Angles(rx, ry, rz) == Rx * Ry * Rz, returns 3x3 row-major."""
    a, b, c = math.radians(rx), math.radians(ry), math.radians(rz)
    ca, sa, cb, sb, cc, sc = math.cos(a), math.sin(a), math.cos(b), math.sin(b), math.cos(c), math.sin(c)
    Rx = [[1, 0, 0], [0, ca, -sa], [0, sa, ca]]
    Ry = [[cb, 0, sb], [0, 1, 0], [-sb, 0, cb]]
    Rz = [[cc, -sc, 0], [sc, cc, 0], [0, 0, 1]]

    def mul(A, B):
        return [[sum(A[i][k] * B[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    return mul(mul(Rx, Ry), Rz)


def split(v):
    if isinstance(v[0], (tuple, list)):
        return tuple(v[0]), tuple(v[1])
    return tuple(v), (0, 0, 0)


def keyed_parts(frames):
    parts = set()
    for _, poses in frames:
        parts.update(poses.keys())
    return parts


def needed_parts(keyed):
    need = set(keyed)
    for p in list(keyed):
        while p in PARENT:
            p = PARENT[p]
            need.add(p)
    need.add("HumanoidRootPart")
    return need


_ref = [0]


def ref():
    _ref[0] += 1
    return f"RBX{_ref[0]}"


def fmt(x):
    return f"{x:.6f}".rstrip("0").rstrip(".") if abs(x) > 1e-9 else "0"


def pose_xml(name, poses, keyed, need, indent):
    (rx, ry, rz), (px, py, pz) = split(poses.get(name, (0, 0, 0)))
    m = rot(rx, ry, rz)
    weight = 1 if name in keyed else 0
    pad = "\t" * indent
    out = [f'{pad}<Item class="Pose" referent="{ref()}">',
           f'{pad}\t<Properties>',
           f'{pad}\t\t<string name="Name">{name}</string>',
           f'{pad}\t\t<CoordinateFrame name="CFrame">'
           f'<X>{fmt(px)}</X><Y>{fmt(py)}</Y><Z>{fmt(pz)}</Z>'
           + "".join(f"<R{i}{j}>{fmt(m[i][j])}</R{i}{j}>" for i in range(3) for j in range(3))
           + '</CoordinateFrame>',
           f'{pad}\t\t<token name="EasingDirection">2</token>',
           f'{pad}\t\t<token name="EasingStyle">5</token>',
           f'{pad}\t\t<float name="Weight">{weight}</float>',
           f'{pad}\t</Properties>']
    for child in ORDER:
        if PARENT.get(child) == name and child in need:
            out += pose_xml(child, poses, keyed, need, indent + 1)
    out.append(f"{pad}</Item>")
    return out


def rbxmx(name, loop, priority, frames):
    keyed = keyed_parts(frames)
    need = needed_parts(keyed)
    lines = ['<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
             'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
             'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
             f'\t<Item class="KeyframeSequence" referent="{ref()}">',
             '\t\t<Properties>',
             f'\t\t\t<string name="Name">{name}</string>',
             f'\t\t\t<bool name="Loop">{"true" if loop else "false"}</bool>',
             f'\t\t\t<token name="Priority">{PRIORITY[priority]}</token>',
             '\t\t</Properties>']
    for t, poses in frames:
        lines += [f'\t\t<Item class="Keyframe" referent="{ref()}">',
                  '\t\t\t<Properties>',
                  '\t\t\t\t<string name="Name">Keyframe</string>',
                  f'\t\t\t\t<float name="Time">{fmt(t)}</float>',
                  '\t\t\t</Properties>']
        lines += pose_xml("HumanoidRootPart", poses, keyed, need, 3)
        lines.append("\t\t</Item>")
    lines += ["\t</Item>", "</roblox>", ""]
    return "\n".join(lines)


def luau():
    out = ["-- GENERATED by tools/make_animations.py — do not edit by hand.",
           "-- Keyframes for every animation (degrees + stud offsets per R15 joint).",
           "-- Shared/AnimLib builds KeyframeSequences from this for Studio testing;",
           "-- published asset ids go in Shared/Animations.luau.",
           "", "return {"]
    for name, (loop, prio, desc, frames) in ANIMS.items():
        out.append(f"\t{name} = {{ -- {desc}")
        out.append(f"\t\tLoop = {'true' if loop else 'false'},")
        out.append(f'\t\tPriority = "{prio}",')
        out.append("\t\tFrames = {")
        for t, poses in frames:
            parts = []
            for part in ORDER:
                if part in poses:
                    (rx, ry, rz), (px, py, pz) = split(poses[part])
                    parts.append(f"{part} = {{ {fmt(rx)}, {fmt(ry)}, {fmt(rz)}, {fmt(px)}, {fmt(py)}, {fmt(pz)} }}")
            out.append(f"\t\t\t{{ {fmt(t)}, {{ {', '.join(parts)} }} }},")
        out.append("\t\t},")
        out.append("\t},")
    out += ["}", ""]
    return "\n".join(out)


def main():
    adir = os.path.join(ROOT, "assets", "animations")
    os.makedirs(adir, exist_ok=True)
    for name, (loop, prio, _desc, frames) in ANIMS.items():
        with open(os.path.join(adir, f"{name}.rbxmx"), "w", encoding="utf-8") as f:
            f.write(rbxmx(name, loop, prio, frames))
    with open(os.path.join(ROOT, "src", "shared", "AnimationData.luau"), "w", encoding="utf-8") as f:
        f.write(luau())
    print(f"wrote {len(ANIMS)} animations to assets/animations and src/shared/AnimationData.luau")


if __name__ == "__main__":
    main()
