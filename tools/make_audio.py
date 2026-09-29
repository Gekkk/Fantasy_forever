#!/usr/bin/env python3
"""Synthesizes all music and sound effects for Fantasy Forever.

Everything is generated from code (additive synthesis + a convolution reverb),
so there are no third-party audio assets. Requires numpy.

    python3 tools/make_audio.py            # writes into godot/audio/
"""
import os
import sys
import wave

import numpy as np

SR = 32000
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "godot", "audio")
rng = np.random.default_rng(7)
TAU = 2 * np.pi

# ----------------------------------------------------------------- helpers
SEMI = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6,
        "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def hz(note):
    name, octave = note[:-1], int(note[-1])
    midi = 12 * (octave + 1) + SEMI[name]
    return 440.0 * 2 ** ((midi - 69) / 12)


def tt(dur):
    return np.arange(int(dur * SR)) / SR


def partials(f, t, amps, decays=None, phase=0.0):
    y = np.zeros_like(t)
    for k, a in enumerate(amps, start=1):
        if a == 0 or f * k > SR / 2.2:
            continue
        p = np.sin(TAU * f * k * t + phase * k)
        if decays is not None:
            p *= np.exp(-t * decays[k - 1])
        y += a * p
    return y


def release_env(t, dur, rel):
    e = np.ones_like(t)
    m = t > dur
    e[m] = np.exp(-(t[m] - dur) / rel)
    return e


def attack(t, a):
    return np.minimum(1.0, t / max(a, 1e-4))


def noise(n):
    return rng.standard_normal(n)


def lowpass(x, cutoff):
    """Simple one-pole lowpass implemented in the frequency domain."""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 / np.sqrt(1 + (f / cutoff) ** 4)
    return np.fft.irfft(X, len(x))


def highpass(x, cutoff):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 / np.sqrt(1 + (cutoff / np.maximum(f, 1)) ** 4)
    return np.fft.irfft(X, len(x))


# ------------------------------------------------------------- instruments
def musicbox(f, dur, v=1.0):
    t = tt(dur + 1.6)
    y = partials(f, t, [1, 0.35, 0, 0.12], [2.6, 5.5, 1, 11])
    y += 0.07 * np.sin(TAU * f * 5.4 * t) * np.exp(-t * 16)
    return y * attack(t, 0.003) * v


def vibes(f, dur, v=1.0):
    t = tt(dur + 1.8)
    y = partials(f, t, [1, 0, 0, 0.18], [1.5, 1, 1, 6])
    y *= 1 + 0.18 * np.sin(TAU * 5.2 * t)
    return y * attack(t, 0.004) * v


def pluck(f, dur, v=1.0, bright=1.0):
    t = tt(dur + 1.0)
    amps = [1 / k ** 1.3 for k in range(1, 10)]
    decs = [2.2 + k * 1.9 / bright for k in range(1, 10)]
    y = partials(f, t, amps, decs, phase=0.3)
    return y * attack(t, 0.002) * release_env(t, dur + 0.25, 0.15) * v


def pad(f, dur, v=1.0, bright=5):
    t = tt(dur + 0.9)
    y = np.zeros_like(t)
    for det in (0.9985, 1.0015):
        y += partials(f * det, t, [1 / k for k in range(1, bright + 1)], phase=det * 7)
    env = attack(t, 0.35) * release_env(t, dur, 0.3)
    return y * env * 0.5 * v


def organ(f, dur, v=1.0):
    t = tt(dur + 0.3)
    y = partials(f, t, [1, 0.6, 0.3, 0.25, 0, 0.15, 0, 0.1])
    y *= 1 + 0.08 * np.sin(TAU * 6 * t)
    return y * attack(t, 0.02) * release_env(t, dur, 0.08) * 0.4 * v


def bass(f, dur, v=1.0):
    t = tt(dur + 0.3)
    y = partials(f, t, [1, 0.45, 0.18, 0.08])
    env = attack(t, 0.005) * np.exp(-t * 1.8) * release_env(t, dur * 0.95, 0.05)
    return y * env * v


def epiano(f, dur, v=1.0):
    t = tt(dur + 1.2)
    y = partials(f, t, [1, 0.25, 0.05], [1.4, 2.8, 4])
    y += 0.06 * np.sin(TAU * f * 7 * t) * np.exp(-t * 25)
    y *= 1 + 0.12 * np.sin(TAU * 4.5 * t)
    return y * attack(t, 0.003) * release_env(t, dur, 0.2) * v


def lead(f, dur, v=1.0):
    t = tt(dur + 0.25)
    vib = 1 + 0.004 * np.sin(TAU * 5.5 * t) * np.minimum(1, np.maximum(0, t - 0.12) * 5)
    ph = TAU * f * np.cumsum(vib) / SR
    amps = [1, 0.25, 0.45, 0.12, 0.25, 0.06, 0.14, 0.03, 0.08]
    y = sum(a * np.sin(k * ph) for k, a in enumerate(amps, start=1) if f * k < SR / 2.2)
    env = attack(t, 0.012) * (0.75 + 0.25 * np.exp(-t * 8)) * release_env(t, dur, 0.06)
    return y * env * 0.5 * v


def flute(f, dur, v=1.0):
    t = tt(dur + 0.3)
    vib = 1 + 0.005 * np.sin(TAU * 5 * t) * np.minimum(1, t * 3)
    ph = TAU * f * np.cumsum(vib) / SR
    y = np.sin(ph) + 0.18 * np.sin(2 * ph) + 0.05 * np.sin(3 * ph)
    y += 0.03 * lowpass(noise(len(t)), 3000)
    return y * attack(t, 0.07) * release_env(t, dur, 0.1) * 0.6 * v


def bell(f, dur, v=1.0):
    t = tt(dur + 2.0)
    y = np.zeros_like(t)
    for ratio, amp, dec in ((1, 1, 1.6), (2.76, 0.45, 3.2), (5.4, 0.25, 6), (8.93, 0.12, 9)):
        y += amp * np.sin(TAU * f * ratio * t) * np.exp(-t * dec)
    return y * attack(t, 0.002) * v


def kick(v=1.0):
    t = tt(0.4)
    f = 42 + 120 * np.exp(-t * 28)
    y = np.sin(TAU * np.cumsum(f) / SR) * np.exp(-t * 8)
    y += 0.3 * noise(len(t)) * np.exp(-t * 120)
    return y * v


def snare(v=1.0):
    t = tt(0.3)
    n = highpass(noise(len(t)), 1200) * np.exp(-t * 16)
    tone = np.sin(TAU * 185 * t) * np.exp(-t * 22)
    return (0.55 * n + 0.5 * tone) * v


def hat(v=1.0, open_=False):
    t = tt(0.25 if open_ else 0.08)
    n = highpass(noise(len(t)), 7000) * np.exp(-t * (14 if open_ else 70))
    return n * 0.35 * v


def shaker(v=1.0):
    t = tt(0.09)
    n = highpass(noise(len(t)), 5000) * np.sin(np.pi * t / t[-1]) ** 2
    return n * 0.25 * v


def wood(f, v=1.0):
    t = tt(0.12)
    return (np.sin(TAU * f * t) + 0.3 * np.sin(TAU * f * 2.7 * t)) * np.exp(-t * 45) * v


# -------------------------------------------------------------- mixing desk
class Track:
    def __init__(self, seconds, tail=3.0):
        self.loop = int(seconds * SR)
        n = self.loop + int(tail * SR)
        self.L = np.zeros(n)
        self.R = np.zeros(n)
        self.dryL = np.zeros(n)
        self.dryR = np.zeros(n)

    def add(self, sig, start, gain=1.0, pan=0.0, wet=True):
        i = int(start * SR)
        if i >= len(self.L):
            return
        sig = sig[: len(self.L) - i]
        gl = gain * np.cos((pan + 1) * np.pi / 4)
        gr = gain * np.sin((pan + 1) * np.pi / 4)
        tl, tr = (self.L, self.R) if wet else (self.dryL, self.dryR)
        tl[i:i + len(sig)] += sig * gl
        tr[i:i + len(sig)] += sig * gr


def reverb_ir(seconds, decay, seed):
    r = np.random.default_rng(seed)
    t = tt(seconds)
    ir = r.standard_normal(len(t)) * np.exp(-t / decay)
    ir = lowpass(ir, 5000)
    ir[: int(0.018 * SR)] = 0
    ir /= np.sqrt(np.sum(ir ** 2))
    return ir


def convolve(x, ir):
    n = len(x) + len(ir)
    nfft = 1 << (n - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(x, nfft) * np.fft.rfft(ir, nfft), nfft)[: len(x)]


def master(track, wet=0.22, decay=0.5, loop=True, peak=0.89):
    irl, irr = reverb_ir(2.2, decay, 1), reverb_ir(2.2, decay, 2)
    L = track.L + wet * convolve(track.L, irl) + track.dryL
    R = track.R + wet * convolve(track.R, irr) + track.dryR
    if loop:  # fold the tail back onto the start so the loop is seamless
        n = track.loop
        tail = len(L) - n
        L[:tail] += L[n:]
        R[:tail] += R[n:]
        L, R = L[:n], R[:n]
    else:
        nz = np.nonzero(np.abs(L) + np.abs(R) > 1e-4)[0]
        end = nz[-1] + 1 if len(nz) else len(L)
        L, R = L[:end], R[:end]
    st = np.stack([L, R], axis=1)
    st = st / (np.max(np.abs(st)) + 1e-9) * 1.15
    st = np.tanh(st)  # gentle glue / soft clip
    return st / np.max(np.abs(st)) * peak


def write_wav(name, data):
    os.makedirs(OUT, exist_ok=True)
    data = np.asarray(data)
    ch = 1 if data.ndim == 1 else data.shape[1]
    pcm = (np.clip(data, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"  {name:22s} {len(data) / SR:5.1f}s")


# ---------------------------------------------------------------- harmony
CH = {
    "F": ["F", "A", "C"], "Dm": ["D", "F", "A"], "Bb": ["Bb", "D", "F"], "C": ["C", "E", "G"],
    "Am": ["A", "C", "E"], "C7": ["C", "E", "G", "Bb"], "G": ["G", "B", "D"], "E": ["E", "G#", "B"],
    "Cmaj7": ["C", "E", "G", "B"], "Am7": ["A", "C", "E", "G"], "Dm7": ["D", "F", "A", "C"],
    "G7": ["G", "B", "D", "F"], "Fmaj7": ["F", "A", "C", "E"], "Em7": ["E", "G", "B", "D"],
    "A7": ["A", "C#", "E", "G"], "A": ["A", "C#", "E"], "Gm": ["G", "Bb", "D"],
}


def voicing(chord, octave):
    """Stack chord tones upward starting at the root in the given octave."""
    out, last = [], -1
    for name in CH[chord]:
        o = octave
        while True:
            m = 12 * (o + 1) + SEMI[name]
            if m > last:
                break
            o += 1
        last = m
        out.append(f"{name}{o}")
    return out


def play_line(track, inst, line, start, beat, gain, pan=0.0, octave_shift=0, legato=1.0):
    t = start
    for note, beats in line:
        if note:
            f = hz(note) * 2 ** octave_shift
            track.add(inst(f, beats * beat * legato), t, gain, pan)
        t += beats * beat
    return t


# ================================================================ MUSIC
def town_melody():
    return [
        [("A5", 1.5), ("G5", 0.5), ("F5", 1)], [("D5", 2), ("F5", 1)],
        [("D5", 1.5), ("C5", 0.5), ("Bb4", 1)], [("C5", 3)],
        [("A5", 1.5), ("G5", 0.5), ("F5", 1)], [("E5", 2), ("A5", 1)],
        [("G5", 1), ("F5", 1), ("D5", 1)], [("E5", 2), ("G5", 1)],
        [("F5", 1), ("A5", 1), ("D6", 1)], [("C6", 1.5), ("Bb5", 0.5), ("A5", 1)],
        [("A5", 1), ("G5", 1), ("F5", 1)], [("G5", 3)],
        [("F5", 1), ("G5", 1), ("A5", 1)], [("Bb5", 1.5), ("A5", 0.5), ("G5", 1)],
        [("F5", 3)], [("C5", 1), ("F5", 1), ("A5", 1)],
    ]


TOWN_PROG = ["F", "Dm", "Bb", "C", "F", "Am", "Bb", "C7", "Dm", "Bb", "F", "C", "Bb", "C", "F", "F"]


def make_town(name="town.wav", bpm=100, solo=False):
    beat = 60 / bpm
    bar = 3 * beat
    bars = 32
    tr = Track(bars * bar)
    mel = town_melody()
    for b in range(bars):
        chord = TOWN_PROG[b % 16]
        t0 = b * bar
        second = b >= 16
        v = voicing(chord, 3)
        tr.add(pad(hz(v[0]), bar, 1), t0, 0.05 if solo else 0.07, -0.3)
        tr.add(pad(hz(v[1]), bar, 1), t0, 0.05 if solo else 0.07, 0.3)
        if not solo:
            tr.add(bass(hz(v[0]) / 2, beat * 1.2), t0, 0.5)
            for k in (1, 2):
                for i, n in enumerate(voicing(chord, 4)):
                    tr.add(pluck(hz(n), beat * 0.6, bright=0.8), t0 + k * beat + i * 0.012, 0.12, -0.4 + 0.4 * i)
            if second:
                tr.add(shaker(), t0 + beat, 0.5, 0.5)
                tr.add(shaker(), t0 + 2 * beat, 0.35, 0.5)
        play_line(tr, musicbox, mel[b % 16], t0, beat, 0.42, 0.1)
        if second and not solo:
            play_line(tr, flute, mel[b % 16], t0, beat, 0.2, -0.2, octave_shift=-1)
        if b % 8 == 0:
            for i, n in enumerate(["C6", "F6", "A6", "C7"]):
                tr.add(bell(hz(n), 0.3), t0 + i * 0.07, 0.05, 0.6)
    write_wav(name, master(tr, wet=0.35 if solo else 0.28, decay=0.6))


def make_tower():
    bpm = 108
    beat = 60 / bpm
    bar = 4 * beat
    prog = ["Cmaj7", "Am7", "Dm7", "G7", "Cmaj7", "Am7", "Dm7", "G7",
            "Fmaj7", "Em7", "Dm7", "G7", "Em7", "A7", "Dm7", "G7"]
    mel = [
        [("E5", 1), ("G5", .5), ("B5", 1.5), ("A5", 1)], [("G5", 1), ("E5", 1), ("C5", 2)],
        [("D5", .5), ("F5", .5), ("A5", 1), ("C6", 1), ("B5", 1)], [("G5", 3), (None, 1)],
        [("E5", 1), ("G5", .5), ("B5", 1.5), ("D6", 1)], [("C6", 1), ("A5", 1), ("E5", 2)],
        [("F5", .5), ("A5", .5), ("C6", 1), ("B5", .5), ("A5", .5), ("G5", 1)], [("G5", 2), ("F5", 1), ("D5", 1)],
        [("A5", 1.5), ("G5", .5), ("E5", 1), ("C5", 1)], [("B4", 1), ("D5", 1), ("G5", 2)],
        [("F5", 1), ("A5", 1), ("C6", 1), ("A5", 1)], [("B5", 2), ("G5", 2)],
        [("G5", 1), ("E5", .5), ("G5", .5), ("B5", 2)], [("C#6", 1.5), ("A5", .5), ("E5", 2)],
        [("D6", 1), ("C6", 1), ("A5", 1), ("F5", 1)], [("G5", 2), ("B5", 1), ("D6", 1)],
    ]
    bars = 32
    tr = Track(bars * bar)
    for b in range(bars):
        ch = prog[b % 16]
        nxt = prog[(b + 1) % 16]
        t0 = b * bar
        v = voicing(ch, 4)
        for hit, d in ((0, 1.3), (2.5, 1.2)):
            for i, n in enumerate(v):
                tr.add(epiano(hz(n), d * beat), t0 + hit * beat + i * 0.008, 0.11, -0.3 + 0.2 * i)
        root = hz(CH[ch][0] + "2")
        third = hz(voicing(ch, 2)[1])
        fifth = hz(voicing(ch, 2)[2])
        approach = hz(CH[nxt][0] + "2") * 2 ** (1 / 12)
        for i, f in enumerate((root, third, fifth, approach)):
            tr.add(bass(f, beat * 0.9), t0 + i * beat, 0.42)
        for i in range(8):
            swing = 0.08 * beat if i % 2 else 0
            tr.add(hat(0.6 if i % 2 else 0.9), t0 + i * beat / 2 + swing, 0.4, 0.4)
        tr.add(kick(), t0, 0.35)
        tr.add(wood(900), t0 + beat, 0.12, -0.3)
        tr.add(wood(900), t0 + 3 * beat, 0.12, -0.3)
        play_line(tr, vibes, mel[b % 16], t0, beat, 0.33, 0.15)
        if b >= 16:
            play_line(tr, flute, mel[b % 16], t0, beat, 0.14, -0.3, legato=0.9)
    write_wav("tower.wav", master(tr, wet=0.25, decay=0.45))


def make_battle():
    bpm = 144
    beat = 60 / bpm
    bar = 4 * beat
    prog = ["Am", "F", "G", "E", "Am", "F", "G", "E", "Am", "F", "C", "G", "F", "G", "Am", "Am"]
    mel = [
        [("E5", .5), ("A5", .5), ("C6", 1), ("B5", .5), ("A5", .5), ("E5", 1)],
        [("F5", .5), ("A5", .5), ("C6", 1), ("D6", 1), ("C6", 1)],
        [("B5", 1), ("G5", .5), ("A5", .5), ("B5", 1), ("D6", 1)],
        [("E6", 1.5), ("D6", .5), ("B5", 1), ("G#5", 1)],
        [("E5", .5), ("A5", .5), ("C6", 1), ("B5", .5), ("A5", .5), ("E6", 1)],
        [("F6", .5), ("E6", .5), ("C6", 1), ("A5", 1), ("C6", 1)],
        [("D6", 1), ("B5", .5), ("G5", .5), ("B5", 1), ("D6", 1)],
        [("E6", 3), (None, 1)],
        [("A5", 1), ("C6", 1), ("E6", 1), ("D6", 1)],
        [("C6", 1), ("A5", 1), ("F5", 2)],
        [("G5", 1), ("C6", 1), ("E6", 1), ("G6", 1)],
        [("F6", 1.5), ("E6", .5), ("D6", 2)],
        [("C6", 1), ("A5", 1), ("F5", 1), ("A5", 1)],
        [("B5", 1), ("D6", 1), ("G6", 2)],
        [("E6", 1.5), ("D6", .5), ("C6", 1), ("B5", 1)],
        [("A5", 4)],
    ]
    bars = 32
    tr = Track(bars * bar)
    for b in range(bars):
        ch = prog[b % 16]
        t0 = b * bar
        root = hz(CH[ch][0] + "2")
        for i in range(8):
            f = root * (2 if i in (3, 7) else 1)
            tr.add(bass(f, beat * 0.45), t0 + i * beat / 2, 0.42)
        arp = voicing(ch, 4) + [voicing(ch, 5)[0]]
        for i in range(16):
            n = arp[[0, 1, 2, 3, 2, 1, 0, 1][i % 8] % len(arp)]
            tr.add(pluck(hz(n), beat * 0.2, bright=1.4), t0 + i * beat / 4, 0.08, 0.5 - (i % 2))
        for i, n in enumerate(voicing(ch, 3)):
            tr.add(pad(hz(n), bar, bright=4), t0, 0.045, -0.5 + 0.5 * i)
        for i in range(4):
            tr.add(kick(), t0 + i * beat, 0.5 if i % 2 == 0 else 0.35)
            if i % 2:
                tr.add(snare(), t0 + i * beat, 0.4, 0.1)
        for i in range(8):
            tr.add(hat(0.8 if i % 2 else 0.5), t0 + i * beat / 2, 0.45, -0.3)
        if b % 4 == 3:
            tr.add(snare(0.6), t0 + 3.5 * beat, 0.3, 0.1)
            tr.add(snare(0.8), t0 + 3.75 * beat, 0.35, 0.1)
        play_line(tr, lead, mel[b % 16], t0, beat, 0.34, 0.05)
        if b >= 16:
            play_line(tr, bell, mel[b % 16], t0, beat, 0.1, -0.4, octave_shift=1)
    write_wav("battle.wav", master(tr, wet=0.18, decay=0.4))


def make_boss():
    bpm = 160
    beat = 60 / bpm
    bar = 4 * beat
    prog = ["Dm", "Bb", "C", "A"] * 4
    a = [
        [("D5", .5), ("F5", .5), ("A5", .5), ("D6", .5), ("C#6", 1), ("A5", 1)],
        [("Bb5", 1), ("A5", .5), ("G5", .5), ("F5", 1), ("D5", 1)],
        [("E5", .5), ("G5", .5), ("C6", 1), ("Bb5", .5), ("A5", .5), ("G5", 1)],
        [("A5", 1), ("C#6", 1), ("E6", 1), ("A6", 1)],
    ]
    alarm = [
        [("A5", .25)] * 8 + [("F5", .5), ("A5", .5), ("D6", 1)],
        [("F5", .25)] * 8 + [("D5", .5), ("F5", .5), ("Bb5", 1)],
        [("G5", .25)] * 8 + [("E5", .5), ("G5", .5), ("C6", 1)],
        [("A5", 1), ("G5", .5), ("F5", .5), ("E5", 1), ("C#5", 1)],
    ]
    mel = a + a + alarm + a
    bars = 32
    tr = Track(bars * bar)
    for b in range(bars):
        ch = prog[b % 16]
        t0 = b * bar
        root = hz(CH[ch][0] + "2")
        for i in range(8):
            f = root * (2 if i % 2 else 1)
            tr.add(bass(f, beat * 0.4), t0 + i * beat / 2, 0.45)
        for i, n in enumerate(voicing(ch, 3)):
            tr.add(organ(hz(n), bar * 0.98), t0, 0.1, -0.4 + 0.4 * i)
        for i in range(4):
            tr.add(kick(), t0 + i * beat, 0.5)
            if i % 2:
                tr.add(snare(), t0 + i * beat, 0.42)
        for i in range(8):  # the ticking clock
            tr.add(wood(1500 if i % 2 == 0 else 1100), t0 + i * beat / 2, 0.16, 0.6 if i % 2 else -0.6)
        if b % 4 == 3:
            for k in range(4):
                tr.add(snare(0.7), t0 + (3 + k / 4) * beat, 0.3)
        m = mel[b % 16]
        play_line(tr, lead, m, t0, beat, 0.33, 0.0)
        if b >= 16:
            play_line(tr, bell, m, t0, beat, 0.09, 0.4, octave_shift=1)
        if b % 8 == 0:
            tr.add(hat(1, open_=True), t0, 0.6)
    write_wav("boss.wav", master(tr, wet=0.2, decay=0.45))


def make_victory():
    beat = 60 / 132
    tr = Track(6, tail=0)
    t = 0.0
    for n in ("G5", "C6", "E6"):
        tr.add(lead(hz(n), beat / 3 * 0.9), t, 0.35)
        tr.add(bell(hz(n), 0.2), t, 0.08, 0.4)
        t += beat / 3
    for n, d in (("G6", 1), ("E6", .5), ("G6", .5)):
        tr.add(lead(hz(n), beat * d * 0.9), t, 0.35)
        t += beat * d
    tr.add(lead(hz("C7"), beat * 2.5), t, 0.38)
    for i, n in enumerate(voicing("C", 4) + ["C5"]):
        tr.add(pad(hz(n), beat * 3), t, 0.09, -0.4 + 0.25 * i)
        tr.add(pluck(hz(n), beat), t + i * 0.05, 0.14)
    tr.add(bass(hz("C2"), beat * 2), t, 0.5)
    for i, n in enumerate(["C6", "E6", "G6", "C7", "E7", "G7"]):
        tr.add(bell(hz(n), 0.3), t + 0.1 + i * 0.06, 0.06, 0.5 - i * 0.2)
    tr.add(kick(), 0, 0.4)
    tr.add(kick(), t, 0.5)
    tr.add(hat(1, open_=True), t, 0.4)
    write_wav("victory.wav", master(tr, wet=0.3, decay=0.6, loop=False))


# ============================================================ SOUND EFFECTS
def sfx(name, sig, peak=0.8):
    sig = np.asarray(sig, dtype=float)
    ir = reverb_ir(0.8, 0.18, 3)
    sig = sig + 0.15 * convolve(np.concatenate([sig, np.zeros(int(0.4 * SR))]), ir)[: len(sig)]
    sig = sig / (np.max(np.abs(sig)) + 1e-9) * peak
    fade = min(len(sig), int(0.01 * SR))
    sig[-fade:] *= np.linspace(1, 0, fade)
    write_wav(name, sig)


def seq(parts, length):
    out = np.zeros(int(length * SR))
    for start, s, g in parts:
        i = int(start * SR)
        s = s[: len(out) - i]
        out[i:i + len(s)] += s * g
    return out


def sweep_noise(dur, f0, f1, decay):
    t = tt(dur)
    n = noise(len(t))
    out = np.zeros_like(t)
    chunk = 512
    for i in range(0, len(t), chunk):
        frac = i / len(t)
        fc = f0 * (f1 / f0) ** frac
        seg = n[i:i + chunk]
        out[i:i + chunk] = lowpass(highpass(np.pad(seg, 256), fc * 0.5), fc * 1.5)[256:256 + len(seg)]
    return out * np.sin(np.pi * np.minimum(1, t / dur)) ** 0.5 * np.exp(-t * decay)


def make_sfx():
    sfx("ui_move.wav", bell(hz("E7"), 0.02)[: int(0.12 * SR)], 0.35)
    sfx("ui_confirm.wav", seq([(0, pluck(hz("C6"), 0.05, bright=2), 1), (0.06, pluck(hz("G6"), 0.1, bright=2), 1)], 0.4), 0.55)
    sfx("ui_cancel.wav", seq([(0, pluck(hz("G5"), 0.05, bright=2), 1), (0.06, pluck(hz("C5"), 0.1, bright=2), 1)], 0.4), 0.5)
    t = tt(0.03)
    sfx("blip.wav", np.sign(np.sin(TAU * 1100 * t)) * np.exp(-t * 90) * 0.4, 0.22)
    t = tt(0.12)
    sfx("step.wav", lowpass(noise(len(t)), 900) * np.exp(-t * 45), 0.25)
    sfx("swing.wav", sweep_noise(0.25, 600, 4000, 6), 0.5)
    t = tt(0.35)
    thump = np.sin(TAU * np.cumsum(90 + 200 * np.exp(-t * 30)) / SR) * np.exp(-t * 14)
    crack = highpass(noise(len(t)), 2000) * np.exp(-t * 40)
    sfx("hit.wav", thump + 0.6 * crack, 0.8)
    chime = seq([(0, bell(hz("E6"), .1), 1), (0.05, bell(hz("B6"), .1), .8)], 0.9)
    sfx("crit.wav", seq([(0, thump + 0.7 * crack, 1), (0.02, chime, 0.5)], 0.9), 0.85)
    sfx("perfect.wav", seq([(i * 0.045, bell(hz(n), 0.1), 0.7) for i, n in enumerate(["E6", "G#6", "B6", "E7"])], 1.2), 0.6)
    t = tt(0.8)
    ting = sum(a * np.sin(TAU * 1400 * r * t) * np.exp(-t * d) for r, a, d in ((1, 1, 6), (1.52, 0.6, 9), (2.3, 0.4, 12)))
    sfx("guard.wav", seq([(0, ting, 1), (0, thump, 0.5)], 0.8), 0.6)
    t = tt(0.4)
    slide = np.sin(TAU * np.cumsum(500 * np.exp(-t * 4)) / SR) * np.exp(-t * 6)
    sfx("hurt.wav", seq([(0, thump, 1), (0.03, slide, 0.4)], 0.5), 0.75)
    t = tt(0.9)
    crackle = (rng.random(len(t)) > 0.985) * rng.standard_normal(len(t)) * 3
    fire = sweep_noise(0.9, 300, 2500, 2.5) + 0.08 * crackle * np.exp(-t * 3) + 0.6 * np.pad(thump, (0, len(t) - len(thump)))
    sfx("fire.wav", fire, 0.7)
    ice = seq([(i * 0.05, bell(hz(n), 0.2), 0.7) for i, n in enumerate(["B7", "F#7", "D7", "B6", "F#6"])], 1.4)
    sfx("ice.wav", ice + 0.3 * np.pad(highpass(noise(int(0.5 * SR)), 6000) * np.exp(-tt(0.5) * 8), (0, len(ice) - int(0.5 * SR))), 0.6)
    sfx("sparkle.wav", seq([(i * 0.035, bell(hz(n), 0.15), 0.6) for i, n in enumerate(["C6", "E6", "G6", "C7", "E7", "G7"])], 1.2), 0.55)
    heal = seq([(i * 0.09, pad(hz(n), 0.5, bright=3), 0.8) for i, n in enumerate(["C5", "E5", "G5", "C6"])], 1.4)
    heal += seq([(0.3 + i * 0.06, bell(hz(n), 0.1), 0.25) for i, n in enumerate(["G6", "C7", "E7"])], 1.4)
    sfx("heal.wav", heal, 0.55)
    star = seq([(i * 0.03, bell(hz(n), 0.2), 0.5) for i, n in enumerate(
        ["C6", "D6", "E6", "G6", "A6", "C7", "D7", "E7", "G7", "A7"])], 2.0)
    star += seq([(0.35, thump, 0.8), (0.55, thump, 0.6)], 2.0)
    sfx("starfall.wav", star, 0.7)
    t = tt(0.25)
    poof = lowpass(noise(len(t)), 2500) * np.exp(-t * 18)
    chirp = np.sin(TAU * np.cumsum(700 + 900 * t / t[-1]) / SR) * np.exp(-t * 10)
    sfx("calm.wav", seq([(0, poof, 0.8), (0.08, chirp, 0.5), (0.18, bell(hz("E7"), 0.1), 0.3)], 0.9), 0.6)
    lvl = seq([(i * 0.1, lead(hz(n), 0.12), 0.8) for i, n in enumerate(["C6", "E6", "G6"])] +
              [(0.3, lead(hz("C7"), 0.5), 0.9)] +
              [(0.3 + i * 0.05, bell(hz(n), 0.2), 0.3) for i, n in enumerate(["C7", "E7", "G7", "C8"])], 1.8)
    sfx("level_up.wav", lvl, 0.7)
    stinger = seq([(0.25 + i * 0.01, pad(hz(n), 0.4, bright=6), 0.8) for i, n in enumerate(["A4", "C5", "E5", "A5"])], 1.2)
    sfx("encounter.wav", seq([(0, sweep_noise(0.35, 300, 5000, 2), 1), (0, stinger, 1)], 1.2), 0.7)
    t = tt(0.35)
    door = lowpass(noise(len(t)), 500) * np.exp(-t * 12) + 0.6 * np.sin(TAU * 120 * t) * np.exp(-t * 15)
    sfx("door.wav", seq([(0, door, 1), (0.15, bell(hz("G5"), 0.1), 0.15)], 0.8), 0.6)
    sfx("coin.wav", seq([(0, bell(hz("B6"), .05), 0.8), (0.07, bell(hz("E7"), .2), 1)], 0.8), 0.45)
    shard = seq([(i * 0.04, bell(hz(n), 0.3), 0.5) for i, n in enumerate(["E6", "A6", "B6", "E7", "A7", "B7", "E8"])], 2.2)
    sfx("shard.wav", shard, 0.6)
    t = tt(0.35)
    whiff = sweep_noise(0.35, 2500, 400, 4)
    sfx("miss.wav", whiff, 0.45)
    t = tt(0.9)
    purr = lowpass(noise(len(t)), 250) * (0.6 + 0.4 * np.sin(TAU * 24 * t)) * np.sin(np.pi * t / t[-1])
    sfx("purr.wav", purr, 0.5)
    t = tt(0.55)
    pitch = 620 + 330 * np.sin(np.pi * np.minimum(1, t / 0.4)) - 200 * t
    ph = TAU * np.cumsum(pitch) / SR
    meow = (np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.3 * np.sin(3 * ph) + 0.15 * np.sin(4 * ph))
    meow *= attack(t, 0.03) * np.exp(-np.maximum(0, t - 0.35) * 12)
    sfx("meow.wav", lowpass(meow, 2500), 0.5)
    t = tt(1.0)
    ring = np.sin(TAU * 1250 * t) * (0.5 + 0.5 * np.sign(np.sin(TAU * 16 * t))) + 0.4 * np.sin(TAU * 3100 * t)
    sfx("alarm.wav", ring * np.exp(-t * 2), 0.45)
    sfx("menu.wav", seq([(0, bell(hz("A6"), 0.05), 0.6), (0.04, bell(hz("E7"), 0.1), 0.6)], 0.6), 0.4)
    t = tt(0.5)
    sfx("buff.wav", seq([(i * 0.06, pluck(hz(n), 0.1, bright=2), 0.7) for i, n in enumerate(["G5", "B5", "D6", "G6"])], 0.8), 0.5)


if __name__ == "__main__":
    print("music:")
    make_town()
    make_town("ending.wav", bpm=84, solo=True)
    make_tower()
    make_battle()
    make_boss()
    make_victory()
    print("sfx:")
    make_sfx()
