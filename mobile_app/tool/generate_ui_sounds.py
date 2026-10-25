"""Original deterministic PCM cues for Duiqi, inspired by interaction layering.

Run: python mobile_app/tool/generate_ui_sounds.py
The five generic cues use only Python's standard library. The separately
user-selected check-in reference is retained as an asset and checksummed below.
"""
from pathlib import Path
import hashlib
import json
import math
import random
import struct
import wave

RATE = 44100
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'android/app/src/main/res/raw'


def tone(t, start, length, frequency, amplitude):
    x = t - start
    if not 0 <= x < length:
        return 0.0
    envelope = min(1.0, x / .003) * math.exp(-5 * x / length) * (1 - x / length)
    return amplitude * envelope * (math.sin(2 * math.pi * frequency * x) + .12 * math.sin(4 * math.pi * frequency * x))


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    specs = {
        'tap': (.045, [(0, .04, 740, .4)]),
        'select': (.085, [(0, .06, 660, .28), (.018, .065, 990, .22)]),
        'success': (.28, [(0, .09, 260, .23), (.025, .13, 880, .29), (.09, .18, 1320, .25)]),
        'failure': (.19, [(0, .085, 440, .26), (.07, .11, 330, .23)]),
        'transition': (.12, []),
    }
    manifest = []
    for name, (duration, notes) in specs.items():
        randomizer = random.Random(42)
        low = 0.0
        samples = []
        for i in range(round(duration * RATE)):
            t = i / RATE
            value = sum(tone(t, *note) for note in notes)
            if name == 'transition':
                low += .16 * (randomizer.uniform(-1, 1) - low)
                value = .30 * low * math.sin(math.pi * t / duration) ** 2
            samples.append(max(-32767, min(32767, round(value * 32767))))
        path = OUTPUT / f'ui_{name}.wav'
        with wave.open(str(path), 'wb') as output:
            output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
            output.writeframes(struct.pack('<' + 'h' * len(samples), *samples))
        manifest.append(dict(cue=name, file=path.name, seconds=len(samples) / RATE,
                             peak=max(abs(v) for v in samples) / 32767,
                             sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    reference = OUTPUT / 'ui_checkin_success.wav'
    if reference.is_file():
        with wave.open(str(reference), 'rb') as audio:
            samples = struct.unpack('<' + 'h' * audio.getnframes() * audio.getnchannels(), audio.readframes(audio.getnframes()))
            manifest.append(dict(cue='checkinSuccess', file=reference.name,
                                 seconds=audio.getnframes() / audio.getframerate(),
                                 peak=max(abs(v) for v in samples) / 32767,
                                 sha256=hashlib.sha256(reference.read_bytes()).hexdigest(),
                                 origin='User-selected complete-preview.wav, deep + select'))
    manifest_path = ROOT / 'build/selected-motion-20261025/audio-manifest.json'
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print(f'Generated 5 original cues; indexed {len(manifest)} total cues, {sum((OUTPUT / item["file"]).stat().st_size for item in manifest)} bytes.')


if __name__ == '__main__':
    main()
