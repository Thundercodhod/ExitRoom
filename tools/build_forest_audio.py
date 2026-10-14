"""Generate original, reproducible sounds for the forest chapter (no downloads)."""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / "audio" / "forest"
ROOT.mkdir(parents=True, exist_ok=True)
RATE = 22050
rng = random.Random(505)
TAU = 2 * math.pi

def save(name, duration, sample, edge=30):
    with wave.open(str(ROOT / (name + ".wav")), "wb") as out:
        out.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        data = []
        for i in range(int(RATE * duration)):
            t = i / RATE
            fade = min(1, t * edge, (duration - t) * edge)
            value = max(-1, min(1, sample(t) * fade))
            data.append(struct.pack("<h", int(value * 26000)))
        out.writeframes(b"".join(data))

def noise():
    return rng.uniform(-1, 1)

def lowpass(k):
    state = [0.0]
    def step(x):
        state[0] += (x - state[0]) * k
        return state[0]
    return step

# Crickets: three voices chirping at their own rhythm over a faint breeze.
breeze = lowpass(.02)
CRICKETS = [(4300, 3.1, .0), (4650, 2.4, .37), (3900, 3.7, .71)]
def night(t):
    s = breeze(noise()) * .5
    for f, rate, ph in CRICKETS:
        phase = (t * rate + ph) % 1
        if phase < .42:
            pulse = 1 if (t * 38) % 1 < .55 else 0
            s += math.sin(TAU * f * t) * .045 * pulse
    return s
save("night", 16, night, edge=200)

# An owl: two soft hoots and a longer third.
def hoot(t, start, length):
    x = t - start
    if not 0 < x < length: return 0
    env = math.sin(math.pi * x / length) ** 2
    return math.sin(TAU * (390 - 25 * x / length) * x) * env * .45
save("bird", 2.0, lambda t: hoot(t, .05, .32) + hoot(t, .5, .32) + hoot(t, 1.05, .7))

# A frog's croak: a rough, pulsing low tone, twice.
def croak(t):
    s = 0
    for start in (0.0, .42):
        x = t - start
        if 0 < x < .3:
            env = math.sin(math.pi * x / .3)
            buzz = 1 if (x * 32) % 1 < .45 else .15
            s += (math.sin(TAU * 135 * x) * .6 + math.sin(TAU * 270 * x) * .25 + noise() * .12) * env * buzz
    return s * .8
save("croak", .85, croak)

# Heavy breathing after waking, slowing down.
pant_lp = lowpass(.18)
def pant(t):
    rate = 1.15 - t * .06
    env = math.sin(math.pi * ((t * rate) % 1)) ** 2
    return pant_lp(noise()) * env * .55 * max(0, 1 - t / 8)
save("pant", 8, pant)

print("Created 4 original forest sounds")
# player_gasp, pladuk_hello, campfire and wind_gust are recorded effects (Epidemic Sound), not generated here.
