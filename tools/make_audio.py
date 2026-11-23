"""Small original sound cues and ambient pad, generated reproducibly."""
import math
import random
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / 'game/assets/audio'
OUT.mkdir(parents=True, exist_ok=True)
RATE = 22050

def save(name, duration, sample):
    rng = random.Random(1729)
    frames = bytearray()
    for index in range(int(duration * RATE)):
        t = index / RATE
        value = max(-0.95, min(0.95, sample(t, duration, rng)))
        frames.extend(struct.pack('<h', int(value * 32767)))
    with wave.open(str(OUT / (name + '.wav')), 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(frames)

tau = math.tau
save('slash', .18, lambda t, d, r: (r.uniform(-1, 1) * .25 + math.sin(tau * (1400*t - 2200*t*t)) * .12) * math.sin(math.pi*t/d)**2)
save('shift', .28, lambda t, d, r: (math.sin(tau * (220*t + 1700*t*t)) * .23 + r.uniform(-1, 1) * .1) * math.sin(math.pi*t/d)**2)
save('impact', .2, lambda t, d, r: (r.uniform(-1, 1) * .3 + math.sin(tau * 72*t) * .35) * math.exp(-t * 28))
save('death', .65, lambda t, d, r: (math.sin(tau * (160*t - 65*t*t)) * .3 + r.uniform(-1, 1) * .12) * math.exp(-t * 5))
save('switch', .22, lambda t, d, r: (r.uniform(-1, 1) * .28 + math.sin(tau * 96*t) * .23) * math.exp(-t * 30))
save('door', .45, lambda t, d, r: (math.sin(tau * (78*t + 12*t*t)) * .16 + r.uniform(-1, 1) * .055) * math.sin(math.pi*t/d))
save('key', .4, lambda t, d, r: (math.sin(tau*880*t) + .45*math.sin(tau*1320*t)) * .18 * math.exp(-t*10))
save('alarm', 1.1, lambda t, d, r: (math.sin(tau*220*t) + .45*math.sin(tau*233*t)) * .22 * max(0, math.sin(tau*3*t)) * min(1, (d-t)*5))
save('win', 1.4, lambda t, d, r: sum(math.sin(tau*f*t) for f in [261.63, 311.13, 392.0, 523.25]) * .08 * math.exp(-t*2.2))

def ambience(t, duration, _rng):
    # Sixteen-second exact-period oscillators: quiet original C-minor drone.
    value = 0.0
    for frequency, amplitude in [(65.375, .18), (98.0, .09), (130.75, .07), (155.5625, .055), (196.0, .04)]:
        value += math.sin(tau * frequency * t) * amplitude
    return value * (.7 + .15 * math.sin(tau*t/8))

save('ambience', 16, ambience)
print('Generated 10 original WAV files (9 cues and a looping ambient pad).')
