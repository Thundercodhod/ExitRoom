"""Generate original, reproducible effects for the field chapter (no downloads)."""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / "audio" / "frog_chapter"
ROOT.mkdir(parents=True, exist_ok=True)
RATE = 22050
rng = random.Random(407)

def save(name, duration, sample, loop=False):
    with wave.open(str(ROOT / (name + ".wav")), "wb") as out:
        out.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        data = []
        for i in range(int(RATE * duration)):
            t = i / RATE
            fade = min(1, t * 80, (duration - t) * 30)
            value = max(-1, min(1, sample(t) * fade))
            data.append(struct.pack("<h", int(value * 26000)))
        out.writeframes(b"".join(data))

def noise():
    return rng.uniform(-1, 1)

save("starter", 2.2, lambda t: (math.sin(2*math.pi*(65*t-6*t*t))*.34+noise()*.13) * (.35+.65*max(0, math.sin(t*35))))
save("knock", 1.2, lambda t: sum(math.exp(-(t-s)*32)*(noise()*.5+math.sin((t-s)*710)*.5) if 0<t-s<.17 else 0 for s in [0,.32,.75]))
save("clamp", 1.4, lambda t: sum(noise()*.8*math.exp(-(t-s)*55) if 0<t-s<.12 else 0 for s in [.12,.84]))
save("seatbelt", .4, lambda t: noise()*.7*math.exp(-t*32)+math.sin(t*2400)*.25*math.exp(-t*45))
save("phone", 6, lambda t: (math.sin(t*2*math.pi*670)+math.sin(t*2*math.pi*850))*.16 if t%2<.65 else 0)
save("engine", 14, lambda t: math.sin(t*2*math.pi*43)*.2+math.sin(t*2*math.pi*86)*.07+noise()*.035)
save("field", 20, lambda t: noise()*.028+(math.sin(t*2*math.pi*3300)*.019 if t%.38<.16 else 0))
print("Created 7 original chapter sounds")
