"""Procedural placeholder scrape for timing; replace with recorded foley later."""
from pathlib import Path
import math,random,wave,struct
rng=random.Random(407);rate=22050;filtered=0.;samples=[]
for i in range(rate*4):
    t=i/rate;envelope=0.
    for start,duration in [(.2,1.05),(2,1.35)]:
        u=(t-start)/duration
        if 0<u<1:envelope=math.sin(u*math.pi)**.5
    filtered=.82*filtered+.18*rng.uniform(-1,1)
    scrape=filtered*(.7+.3*math.sin(t*math.tau*34))+.03*math.sin(t*math.tau*83)
    samples.append(struct.pack('<h',int(max(-1,min(1,scrape*envelope*.7))*32767)))
with wave.open(str(Path(__file__).resolve().parents[1]/'audio/drag_placeholder.wav'),'wb') as f:
    f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes(b''.join(samples))
