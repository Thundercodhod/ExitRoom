"""Prepare the supplied CC0 grass recording and synthesise a seamless wind bed."""
from pathlib import Path
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "source_assets/dream_field"
AUDIO = ROOT / "audio/dream_field"
AUDIO.mkdir(parents=True, exist_ok=True)

with wave.open(str(SRC / "525268__thesuprememuffinpooter__dry-grass-rustle.wav")) as w:
    RATE = w.getframerate()
    sound = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").reshape(-1, 2).astype(np.float32) / 32768

def save_audio(name, data, rate):
    data = np.clip(data, -0.97, 0.97)
    channels = 1 if data.ndim == 1 else data.shape[1]
    with wave.open(str(AUDIO / name), "wb") as w:
        w.setnchannels(channels)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(np.int16(data * 32767).tobytes())

overlap = int(RATE * 0.65)
mix = np.linspace(0, np.pi / 2, overlap)[:, None]
seam = sound[-overlap:] * np.cos(mix) + sound[:overlap] * np.sin(mix)
loop = np.concatenate((sound[overlap:-overlap], seam))
save_audio("dry_grass_loop.wav", loop, RATE)
for index, start_seconds in enumerate([1.4, 3.1, 5.3, 7.0]):
    clip = sound[int(start_seconds * RATE):int((start_seconds + 0.28) * RATE)].mean(axis=1).copy()
    attack = int(RATE * 0.018)
    clip[:attack] *= np.linspace(0, 1, attack)
    clip *= np.linspace(1, 0, len(clip)) ** 0.8
    peak = max(float(np.abs(clip).max()), 0.001)
    save_audio(f"grass_step_{index + 1}.wav", clip * 0.38 / peak, RATE)

# A restrained original wind bed, synthesised as a periodic filtered signal.
# FFT filtering makes the 24-second seam continuous without a sudden gust.
rate = 22050
length = rate * 24
rng = np.random.default_rng(6407)
frequencies = np.fft.rfftfreq(length, 1 / rate)
spectrum = np.fft.rfft(rng.normal(size=length))
curve = (np.maximum(frequencies, 40) / 180) ** -0.78
curve *= 1 - np.exp(-(frequencies / 65) ** 2)
curve *= np.exp(-(frequencies / 2600) ** 2)
wind = np.fft.irfft(spectrum * curve, n=length)
t = np.arange(length) / rate
wind *= 0.62 + 0.17 * np.sin(t * np.pi / 6) + 0.12 * np.sin(t * np.pi / 4)
wind *= 0.35 / max(float(np.abs(wind).max()), 0.001)
save_audio("wind_loop.wav", wind, rate)
print("Prepared seamless dry-grass loop, four steps and wind bed.")
