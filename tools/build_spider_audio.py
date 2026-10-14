"""Generate original, reproducible sounds for the spider (no downloads)."""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / "audio" / "spider"
ROOT.mkdir(parents=True, exist_ok=True)
RATE = 22050
rng = random.Random(8)
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

# Skitter: eight legs ticking on tiles, uneven, about 30 taps a second. Loops.
taps = []
t = 0.0
while t < 1.2:
    taps.append((t, rng.uniform(.35, 1.0), rng.uniform(2600, 4200)))
    t += rng.uniform(.018, .05)
def skitter(t):
    s = 0.0
    for start, amp, freq in taps:
        x = t - start
        if 0 < x < .012:
            s += (noise() * .6 + math.sin(TAU * freq * x) * .4) * amp * math.exp(-x * 420)
    return s * .9
save("skitter", 1.2, skitter, edge=400)

# Scrape: legs dragging down the wall paper, a falling hiss.
prev = [0.0]
def scrape(t):
    prev[0] += (noise() - prev[0]) * (.55 - .35 * t / .7)
    env = min(1, t / .05) * max(0, 1 - t / .7)
    return prev[0] * env * .8
save("scrape", .7, scrape, edge=200)

# Thud: a heavy body landing on the floor.
def thud(t):
    env = math.exp(-t * 11)
    return (math.sin(TAU * (78 - 30 * t) * t) * .8 + noise() * .25 * math.exp(-t * 40)) * env
save("thud", .55, thud, edge=400)
print("Created 3 original spider sounds")
