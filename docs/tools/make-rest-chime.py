#!/usr/bin/env python3
"""Generate the rest-over chime (m5-haptics spec 5.6). Provenance only, not a build step.

Usage: python3 docs/tools/make-rest-chime.py <out.caf>

An 880 Hz sine, 0.2 s, 44 100 Hz mono 16-bit PCM, 10 ms linear fade in and out, peak -6 dBFS, converted to IMA4 in a
CAF container with /usr/bin/afconvert. The intermediate WAV is written to a temporary directory and deleted: any file
left under HomeGymLog/ would become a bundle resource.
"""
import math
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import wave

FREQUENCY_HZ = 880.0
DURATION_S = 0.2
SAMPLE_RATE = 44_100
FADE_S = 0.010
PEAK_DBFS = -6.0
FULL_SCALE = 32_767


def samples():
    count = round(DURATION_S * SAMPLE_RATE)          # 8 820
    fade = round(FADE_S * SAMPLE_RATE)               # 441
    peak = FULL_SCALE * 10 ** (PEAK_DBFS / 20)       # -6 dBFS of full scale
    for n in range(count):
        envelope = min(1.0, n / fade, (count - 1 - n) / fade)
        yield int(round(peak * envelope * math.sin(2 * math.pi * FREQUENCY_HZ * n / SAMPLE_RATE)))


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: make-rest-chime.py <out.caf>")
    out = sys.argv[1]
    tmp = tempfile.mkdtemp()
    try:
        wav_path = os.path.join(tmp, "tone.wav")
        with wave.open(wav_path, "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(SAMPLE_RATE)
            wav.writeframes(b"".join(struct.pack("<h", s) for s in samples()))
        subprocess.run(["/usr/bin/afconvert", wav_path, out, "-d", "ima4", "-f", "caff"], check=True)
    finally:
        shutil.rmtree(tmp)


if __name__ == "__main__":
    main()
