"""Original procedural sounds for ExitRoom, deterministic and freely editable."""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1] / "audio" / "anthology"
RATE = 22050
ROOT.mkdir(parents=True, exist_ok=True)
rng = random.Random(407)

def noise():
    return rng.uniform(-1, 1)

def tone(t, hz):
    return math.sin(2 * math.pi * hz * t)

def write(name, seconds, sample):
    with wave.open(str(ROOT / f"{name}.wav"), "wb") as out:
        out.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        values = bytearray()
        for i in range(int(RATE * seconds)):
            t = i / RATE
            fade = max(0, min(1, t * 100, (seconds - t) * 25))
            value = max(-.95, min(.95, sample(t))) * fade
            values.extend(struct.pack("<h", int(value * 28000)))
        out.writeframes(values)

write("ui_move", .11, lambda t: tone(t, 480) * .18 * math.exp(-t*34) + noise() * .04 * math.exp(-t*55))
write("ui_accept", .27, lambda t: (tone(t, 230) + tone(t, 460)*.25)*.23*math.exp(-t*15))
write("tape", 3.4, lambda t: noise()*.14 + tone(t, 57)*.07 + (noise()*.3 if t % .79 < .03 else 0))
write("knock", 1.55, lambda t: sum((noise()*.5+tone(t-s, 105)*.6)*math.exp(-(t-s)*32) if 0 <= t-s < .24 else 0 for s in [.04,.52,1.02]))
write("message", .8, lambda t: sum((tone(t-s, 640)+tone(t-s, 840)*.2)*.22*math.exp(-(t-s)*10) if 0<=t-s<.3 else 0 for s in [.03,.32]))
write("door", 1.8, lambda t: (noise()*.07 + tone(t, 85+12*math.sin(t*6))*.12)*max(0, 1-t/1.6) + (noise()*.6*math.exp(-(t-1.3)*32) if t>1.3 else 0))
write("sting", 2.7, lambda t: (tone(t, 67)+tone(t, 71)*.6+tone(t, 138)*.3)*.18*math.exp(-t*1.2) + noise()*.08*math.exp(-t*3))
write("fluorescent", 4, lambda t: (tone(t, 100)*.22+tone(t, 200)*.06+noise()*.035)*(.7+.3*math.sin(t*17)**2))
write("low_pulse", 3.1, lambda t: tone(t, 47)*.32*(math.sin(t*math.pi*1.4)**8) + noise()*.012)

# No sampled music: filtered wind, low beating tones and sparse distant chimes.
wind = 0.0
def ambience(t):
    global wind
    wind = .988*wind + .012*noise()
    pad = (tone(t, 49)+tone(t, 49.23)*.6)*.048
    chime = 0
    for start, hz in [(2, 196), (7.3, 233.08), (13.8, 146.83), (18, 185)]:
        if t >= start:
            u = t-start
            chime += (tone(u, hz)+.18*tone(u, hz*2.01))*.055*math.exp(-u*.85)
    return wind*.9+pad+chime+noise()*.012
write("menu_ambience", 24, ambience)
print("Created 10 original anthology sound effects and ambience tracks.")
