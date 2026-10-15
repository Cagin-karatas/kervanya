#!/usr/bin/env python3
"""Kervanya ilk ses paketi (plan §12) — tamamen kodla sentezlenir, dış kaynak/lisans yok.

Çıktı:
  assets/audio/sfx/*.wav     (22.05 kHz, mono, 16 bit)
  assets/audio/music/*.ogg   (32 kHz, mono, Vorbis q3; döngüye uygun)

Tını: saz benzeri telli (Karplus-Strong), ney benzeri üflemeli, bendir/darbuka benzeri vurmalı.
Makam: Hicaz (D, Eb, F#, G, A, Bb, C) bulmaca ve yolculukta; kasabada D majör pentatonik.
Aynı komut her zaman aynı dosyaları üretir (sabit tohumlar).

Kullanım: python3 tools/gen_audio.py   (ffmpeg gerekir)
"""
import os
import subprocess
import tempfile

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MUSIC_DIR = os.path.join(ROOT, "assets", "audio", "music")
SR = 22050
MSR = 32000

HICAZ = [0, 1, 4, 5, 7, 8, 10]          # D Eb F# G A Bb C
PENTA = [0, 2, 4, 7, 9]                 # D E F# A B
D3 = 146.83


def note(base, degree, scale, octave=0):
    o, d = divmod(degree, len(scale))
    return base * 2 ** ((scale[d] + 12 * (o + octave)) / 12)


def env_ad(n, attack, sr):
    a = max(1, int(attack * sr))
    e = np.ones(n)
    e[:a] = np.linspace(0, 1, a)
    return e


def pluck(freq, dur, sr, bright=0.5, rng=None):
    rng = rng or np.random.default_rng(1)
    n = int(dur * sr)
    period = max(2, int(sr / freq))
    buf = rng.uniform(-1, 1, period)
    out = np.zeros(n)
    decay = 0.996 - (1 - bright) * 0.004
    idx = 0
    for i in range(n):
        out[i] = buf[idx]
        nxt = (idx + 1) % period
        buf[idx] = decay * (bright * buf[idx] + (1 - bright) * 0.5 * (buf[idx] + buf[nxt]))
        idx = nxt
    return out * env_ad(n, 0.002, sr)


def bell(freq, dur, sr, decay=4.0):
    t = np.arange(int(dur * sr)) / sr
    partials = [(1.0, 1.0), (2.76, 0.45), (5.4, 0.25), (8.93, 0.12)]
    s = sum(a * np.sin(2 * np.pi * freq * r * t) * np.exp(-decay * r ** 0.5 * t) for r, a in partials)
    return s * env_ad(len(t), 0.003, sr)


def flute(freq, dur, sr, rng=None):
    rng = rng or np.random.default_rng(2)
    t = np.arange(int(dur * sr)) / sr
    vib = 1 + 0.006 * np.sin(2 * np.pi * 5.2 * t) * np.clip(t / 0.4, 0, 1)
    phase = 2 * np.pi * freq * np.cumsum(vib) / sr
    s = np.sin(phase) + 0.18 * np.sin(2 * phase) + 0.06 * np.sin(3 * phase)
    breath = lowpass(rng.normal(0, 1, len(t)), 3000, sr) * 0.12
    e = np.clip(t / 0.12, 0, 1) * np.clip((dur - t) / 0.25, 0, 1)
    return (s + breath) * e


def drum(kind, sr, rng=None):
    rng = rng or np.random.default_rng(3)
    if kind == "dum":
        dur = 0.35
        t = np.arange(int(dur * sr)) / sr
        f = 55 + 70 * np.exp(-t * 30)
        s = np.sin(2 * np.pi * np.cumsum(f) / sr) * np.exp(-t * 9)
        s += lowpass(rng.normal(0, 1, len(t)), 900, sr) * np.exp(-t * 40) * 0.4
        return s
    dur = 0.12  # "tek"
    t = np.arange(int(dur * sr)) / sr
    s = bandpass(rng.normal(0, 1, len(t)), 1800, 5200, sr) * np.exp(-t * 45)
    s += np.sin(2 * np.pi * 420 * t) * np.exp(-t * 60) * 0.3
    return s


def lowpass(x, cutoff, sr, order=2):
    b, a = butter(order, cutoff / (sr / 2), btype="low")
    return lfilter(b, a, x)


def bandpass(x, lo, hi, sr, order=2):
    b, a = butter(order, [lo / (sr / 2), hi / (sr / 2)], btype="band")
    return lfilter(b, a, x)


def whoosh(dur, sr, f0, f1, rng=None):
    rng = rng or np.random.default_rng(4)
    n = int(dur * sr)
    noise = rng.normal(0, 1, n)
    out = np.zeros(n)
    seg = 256
    for i in range(0, n, seg):
        f = f0 + (f1 - f0) * (i / n)
        chunk = bandpass(noise[i:i + seg + 64], max(80, f * 0.7), min(sr / 2 - 100, f * 1.4), sr)[:min(seg, n - i)]
        out[i:i + len(chunk)] = chunk
    t = np.arange(n) / n
    return out * np.sin(np.pi * t) ** 1.5


def reverb(x, sr, mix=0.25, room=0.35):
    out = x.copy()
    for d, g in [(0.029, 0.6), (0.037, 0.5), (0.041, 0.45), (0.053, 0.4)]:
        k = int(d * sr * (1 + room))
        y = np.zeros(len(x) + k * 6)
        y[:len(x)] += x
        for rep in range(1, 6):
            y[k * rep:k * rep + len(x)] += x * (g ** rep)
        out = out + mix * 0.35 * y[:len(x)]
    return out


def place(buf, sig, at, sr, gain=1.0):
    i = int(at * sr)
    j = min(len(buf), i + len(sig))
    if i < len(buf):
        buf[i:j] += sig[:j - i] * gain


def normalize(x, peak=0.85):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def write_wav(path, x, sr):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    wavfile.write(path, sr, (np.clip(x, -1, 1) * 32767).astype(np.int16))


def write_ogg(path, x, sr):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        write_wav(tmp.name, x, sr)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp.name, "-c:a", "libvorbis", "-q:a", "3",
                    "-map_metadata", "-1", "-fflags", "+bitexact", path], check=True)
    os.unlink(tmp.name)


def loopable(buf, tail):
    """Kuyruğu başa ekleyerek kesintisiz döngü yapar."""
    body, rest = buf[:-tail], buf[-tail:]
    body[:tail] += rest
    return body


# ---------------------------------------------------------------- efektler

def make_sfx():
    s = {}
    rng = np.random.default_rng(10)
    t = lambda d: np.arange(int(d * SR)) / SR
    tt = t(0.05)
    s["ui_tap"] = np.sin(2 * np.pi * 880 * tt) * np.exp(-tt * 90) + bandpass(rng.normal(0, 1, len(tt)), 2000, 6000, SR) * np.exp(-tt * 150) * 0.3
    s["tile_pick"] = pluck(note(D3, 4, HICAZ, 2), 0.12, SR, 0.3, rng) * np.exp(-t(0.12) * 25)
    thunk = drum("dum", SR, rng)[: int(0.18 * SR)] * 0.7
    place_buf = np.zeros(int(0.25 * SR))
    place(place_buf, thunk, 0, SR)
    place(place_buf, pluck(note(D3, 0, HICAZ, 1), 0.2, SR, 0.25, rng) * 0.6, 0.0, SR)
    s["tile_place"] = place_buf
    rot = whoosh(0.12, SR, 1500, 3500, rng) * 0.6
    place(rot, pluck(note(D3, 2, HICAZ, 2), 0.08, SR, 0.3, rng) * 0.5, 0.06, SR)
    s["tile_rotate"] = rot
    s["tile_return"] = whoosh(0.2, SR, 2500, 600, rng) * 0.7
    tb = t(0.28)
    buzz = np.sign(np.sin(2 * np.pi * 110 * tb)) * 0.3 * np.exp(-tb * 8)
    buzz = lowpass(buzz, 900, SR)
    buzz2 = np.zeros(int(0.32 * SR))
    place(buzz2, buzz[: int(0.1 * SR)], 0, SR)
    place(buzz2, buzz[: int(0.12 * SR)], 0.14, SR)
    s["tile_invalid"] = buzz2
    s["undo"] = pluck(note(D3, 4, HICAZ, 1), 0.15, SR, 0.4, rng)[::-1] * np.linspace(0.2, 1, int(0.15 * SR))
    s["route_connect"] = bell(note(D3, 4, HICAZ, 2), 0.6, SR, 5) * 0.6
    win = np.zeros(int(1.6 * SR))
    for i, deg in enumerate([0, 2, 4, 7]):
        place(win, pluck(note(D3, deg, HICAZ, 1), 0.8, SR, 0.55, rng), i * 0.11, SR, 0.8)
    place(win, bell(note(D3, 7, HICAZ, 1), 1.2, SR, 3), 0.44, SR, 0.6)
    s["level_win"] = reverb(win, SR)
    fail = np.zeros(int(1.0 * SR))
    place(fail, flute(note(D3, 4, HICAZ, 1), 0.35, SR, rng), 0, SR, 0.6)
    place(fail, flute(note(D3, 1, HICAZ, 1), 0.6, SR, rng), 0.3, SR, 0.6)
    s["level_fail"] = reverb(fail, SR)
    for i, deg in enumerate([4, 6, 7]):
        s["star_%d" % (i + 1)] = bell(note(D3, deg, HICAZ, 2), 0.5, SR, 6) * 0.7
    s["journey_coin"] = bell(note(D3, 7, PENTA, 2), 0.3, SR, 9) * 0.6 + bell(note(D3, 9, PENTA, 2), 0.3, SR, 9) * 0.3
    rare = np.zeros(int(0.7 * SR))
    for i, deg in enumerate([0, 2, 4, 5]):
        place(rare, bell(note(D3, deg, PENTA, 3), 0.4, SR, 7), i * 0.06, SR, 0.5)
    s["journey_rare"] = rare
    hit = drum("dum", SR, rng) * 1.0
    hit[: int(0.06 * SR)] += lowpass(rng.normal(0, 1, int(0.06 * SR)), 2500, SR) * 0.6
    s["journey_hit"] = hit
    s["journey_swipe"] = whoosh(0.16, SR, 900, 2600, rng) * 0.6
    s["journey_boost"] = whoosh(0.45, SR, 500, 4000, rng) * 0.7
    build = np.zeros(int(1.2 * SR))
    for i in range(3):
        place(build, drum("tek", SR, rng) * 0.8, i * 0.16, SR)
    place(build, bell(note(D3, 0, PENTA, 2), 0.7, SR, 4), 0.5, SR, 0.6)
    s["building_build"] = build
    up = np.zeros(int(1.2 * SR))
    for i, deg in enumerate([0, 2, 4, 5, 7]):
        place(up, bell(note(D3, deg, PENTA, 2), 0.6, SR, 5), i * 0.08, SR, 0.45)
    s["building_upgrade"] = reverb(up, SR)
    s["hint"] = flute(note(D3, 4, PENTA, 2), 0.5, SR, rng) * 0.5
    for name, x in s.items():
        write_wav(os.path.join(SFX_DIR, name + ".wav"), normalize(x, 0.8), SR)
    return sorted(s.keys())


# ---------------------------------------------------------------- müzik

def melody_walk(rng, length, lo=0, hi=9, start=4):
    deg, out = start, []
    for _ in range(length):
        deg = int(np.clip(deg + rng.choice([-2, -1, -1, 0, 1, 1, 2]), lo, hi))
        out.append(deg)
    return out


def make_puzzle_music():
    rng = np.random.default_rng(101)
    bpm, bars = 84, 16
    beat = 60 / bpm
    total = bars * 4 * beat
    tail = int(2.5 * MSR)
    buf = np.zeros(int(total * MSR) + tail)
    tt = np.arange(len(buf)) / MSR
    drone = (np.sin(2 * np.pi * D3 / 2 * tt) * 0.5 + np.sin(2 * np.pi * D3 * 0.75 * tt) * 0.25)
    drone *= 0.18 * (0.8 + 0.2 * np.sin(2 * np.pi * tt / (total / 2)))
    buf += lowpass(drone, 600, MSR)
    phrase = melody_walk(rng, 8)
    for bar in range(bars):
        if bar % 4 == 0:
            phrase = melody_walk(rng, 8, start=phrase[-1])
        for i, deg in enumerate(phrase):
            if rng.random() < 0.28:
                continue
            at = (bar * 4 + i * 0.5) * beat
            place(buf, pluck(note(D3, deg, HICAZ, 1), 1.2, MSR, 0.5, rng), at, MSR, 0.32)
        place(buf, drum("dum", MSR, rng), bar * 4 * beat, MSR, 0.18)
        place(buf, drum("tek", MSR, rng), (bar * 4 + 2) * beat, MSR, 0.08)
        if bar % 4 == 3:
            place(buf, flute(note(D3, phrase[0], HICAZ, 1), beat * 3, MSR, rng), (bar * 4 + 0.5) * beat, MSR, 0.12)
    return normalize(loopable(reverb(buf, MSR, 0.3), tail), 0.6)


def make_town_music():
    rng = np.random.default_rng(202)
    bpm, bars = 96, 12
    beat = 60 / bpm
    total = bars * 4 * beat
    tail = int(2.5 * MSR)
    buf = np.zeros(int(total * MSR) + tail)
    chords = [0, 3, 1, 4]
    for bar in range(bars):
        root = chords[bar % 4]
        for i in range(8):
            deg = root + [0, 2, 4, 2][i % 4]
            place(buf, pluck(note(D3, deg, PENTA, 1), 0.9, MSR, 0.6, rng), (bar * 4 + i * 0.5) * beat, MSR, 0.22)
        if bar % 2 == 0:
            place(buf, flute(note(D3, root + 5, PENTA, 1), beat * 3.5, MSR, rng), bar * 4 * beat, MSR, 0.15)
        place(buf, drum("dum", MSR, rng), bar * 4 * beat, MSR, 0.12)
    return normalize(loopable(reverb(buf, MSR, 0.3), tail), 0.6)


def make_journey_music():
    rng = np.random.default_rng(303)
    bpm, bars = 120, 24
    beat = 60 / bpm
    total = bars * 2 * beat
    tail = int(1.5 * MSR)
    buf = np.zeros(int(total * MSR) + tail)
    ostinato = [0, 1, 4, 1, 0, 4, 5, 4]
    for bar in range(bars):
        base = bar * 2 * beat
        place(buf, drum("dum", MSR, rng), base, MSR, 0.3)
        place(buf, drum("tek", MSR, rng), base + beat, MSR, 0.18)
        place(buf, drum("tek", MSR, rng), base + 1.5 * beat, MSR, 0.12)
        for i in range(4):
            deg = ostinato[(bar * 4 + i) % len(ostinato)]
            place(buf, pluck(note(D3, deg, HICAZ, 1), 0.5, MSR, 0.55, rng), base + i * 0.5 * beat, MSR, 0.22)
        if bar % 8 in (4, 5):
            place(buf, flute(note(D3, 7, HICAZ, 1), beat * 1.8, MSR, rng), base, MSR, 0.14)
    return normalize(loopable(reverb(buf, MSR, 0.2), tail), 0.65)


def make_music():
    tracks = {
        "puzzle_world1": make_puzzle_music(),
        "town": make_town_music(),
        "journey": make_journey_music(),
    }
    for name, x in tracks.items():
        write_ogg(os.path.join(MUSIC_DIR, name + ".ogg"), x, MSR)
    return sorted(tracks.keys())


if __name__ == "__main__":
    sfx = make_sfx()
    music = make_music()
    print("efekt:", len(sfx), ", ".join(sfx))
    print("müzik:", ", ".join(music))
