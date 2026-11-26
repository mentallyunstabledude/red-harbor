#!/usr/bin/env python3
# gen_sfx.py - the sound generator, the audio twin of gen_textures.py.
# Every sound in Red Harbor is synthesized here, under the same
# code-generated law as the textures: no recorded assets, no downloads,
# deterministic seeds. Bare run writes all sounds into audio/; pass a
# comma list of names to repaint only those.
#   python3 assets_src/gen_sfx.py
#   python3 assets_src/gen_sfx.py room_tone,fan_loop
#
# The set (K2 of the rebuild ladder - the silence dies):
#   room_tone       8s seamless loop, the office's low bed
#   fan_loop        6s seamless loop, the extractor fan's blade-pass
#   radio_static    one-shot crackle for the state-radio cues
#   footstep_iron_1..3   one-shots, the PI's shoes on the boards
#   shelf_creak     one-shot for the shelf-drop event

import math
import os
import wave

import numpy as np

SR = 22050
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "audio")
_rng = np.random.default_rng(1947)


# --- small kit ------------------------------------------------------------------------

def _t(seconds: float) -> np.ndarray:
    return np.arange(int(SR * seconds)) / SR


def _lowpass(sig: np.ndarray, hz: float) -> np.ndarray:
    # brickwall with a soft skirt; fine for texture noise, not for music
    spec = np.fft.rfft(sig)
    freqs = np.fft.rfftfreq(sig.size, 1.0 / SR)
    rolloff = np.clip((hz * 1.35 - freqs) / (hz * 0.35), 0.0, 1.0)
    return np.fft.irfft(spec * rolloff, sig.size)


def _band(sig: np.ndarray, lo: float, hi: float) -> np.ndarray:
    spec = np.fft.rfft(sig)
    freqs = np.fft.rfftfreq(sig.size, 1.0 / SR)
    mask = np.clip((freqs - lo) / 120.0, 0.0, 1.0) \
            * np.clip((hi - freqs) / 120.0, 0.0, 1.0)
    return np.fft.irfft(spec * np.clip(mask, 0.0, 1.0), sig.size)


def _brown(seconds: float) -> np.ndarray:
    n = int(SR * seconds)
    w = _rng.standard_normal(n)
    b = np.cumsum(w)
    b -= np.linspace(b[0], b[-1], n)      # detrend so loopify has an easy job
    m = np.max(np.abs(b)) or 1.0
    return b / m


def _fade_edges(sig: np.ndarray, ms: float = 30.0) -> np.ndarray:
    n = int(SR * ms / 1000.0)
    ramp = np.linspace(0.0, 1.0, n)
    sig[:n] *= ramp
    sig[-n:] *= ramp[::-1]
    return sig


def _loopify(sig: np.ndarray, fade_s: float = 0.4) -> np.ndarray:
    # crossfade the tail into the head so the loop point disappears
    n = int(SR * fade_s)
    body = sig[:-n].copy()
    tail = sig[-n:]
    head = sig[:n]
    w = np.linspace(0.0, 1.0, n)
    body[:n] = tail * (1.0 - w) + head * w
    return body


def _write(name: str, sig: np.ndarray, peak: float) -> None:
    m = np.max(np.abs(sig)) or 1.0
    pcm = (sig / m * peak * 32767.0).astype(np.int16)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("%-18s %5.2fs  peak %.2f  %6d bytes" %
          (name, sig.size / SR, peak, pcm.nbytes))


# --- the sounds -----------------------------------------------------------------------

def room_tone() -> None:
    # the office's bed: brown noise under a mains hum, breathing slowly
    t = _t(8.0)
    bed = _brown(8.6)[:t.size] * 0.8
    bed = _lowpass(bed, 340.0)
    hum = np.sin(2 * math.pi * 55.0 * t) * 0.10 \
            + np.sin(2 * math.pi * 110.0 * t) * 0.045
    air = _band(_rng.standard_normal(t.size), 1800.0, 4200.0) * 0.05
    breath = 0.82 + 0.18 * np.sin(2 * math.pi * 0.09 * t)
    sig = (bed + hum + air) * breath
    _write("room_tone", _loopify(sig, 0.5), 0.30)


def fan_loop() -> None:
    # the extractor: nine heavy blade-passes a minute and a half... no,
    # 1.5 blade-passes a second, motor hum under, air above
    t = _t(6.0)
    passes = 9.0                       # whole passes so the loop is honest
    phase = (t * passes) % 1.0
    burst = (1.0 - np.cos(2 * math.pi * np.clip(phase / 0.62, 0.0, 1.0))) * 0.5
    burst *= phase < 0.62
    gust = _band(_rng.standard_normal(t.size), 140.0, 900.0)
    wob = 1.0 + 0.25 * np.sin(2 * math.pi * passes * t * 0.5)
    motor = np.sin(2 * math.pi * 100.0 * t) * 0.16 \
            + np.sin(2 * math.pi * 200.0 * t) * 0.06
    air = _lowpass(_rng.standard_normal(t.size), 800.0) * 0.22
    sig = gust * burst * 0.85 * wob + motor + air
    _write("fan_loop", _loopify(sig, 0.35), 0.50)


def radio_static() -> None:
    # state radio: hiss, dropouts, crackle, and a squelch tail
    t = _t(2.8)
    hiss = _rng.standard_normal(t.size) * 0.4
    gate = (_rng.random(t.size) > 0.12).astype(float)
    gate = _lowpass(gate, 900.0)
    hiss *= 0.35 + 0.65 * gate
    crackle = np.zeros_like(t)
    for at in _rng.uniform(0.05, 2.5, 14):
        i = int(at * SR)
        n = int(0.008 * SR)
        if i + n < crackle.size:
            crackle[i:i + n] += _rng.standard_normal(n) \
                    * np.exp(-np.arange(n) / (0.002 * SR))
    tail_n = int(0.38 * SR)
    tail = _band(_rng.standard_normal(tail_n), 280.0, 1300.0)
    tail *= np.linspace(1.0, 0.0, tail_n) ** 1.5
    sig = hiss * 0.9 + crackle * 2.4
    sig[-tail_n:] += tail * 0.8
    _write("radio_static", _fade_edges(sig, 25.0), 0.70)


def footstep_iron_1() -> None:
    _footstep("footstep_iron_1", 1.00)


def footstep_iron_2() -> None:
    _footstep("footstep_iron_2", 1.043)


def footstep_iron_3() -> None:
    _footstep("footstep_iron_3", 0.958)


def _footstep(name: str, tune: float) -> None:
    # a shoe on old boards over iron: thud, ring, scrape
    t = _t(0.34)
    thud = np.sin(2 * math.pi * 72.0 * tune * t) * np.exp(-t * 26.0)
    ring = np.zeros_like(t)
    for hz, decay, amp in [(178.0, 16.0, 0.30), (419.0, 21.0, 0.22),
                           (996.0, 29.0, 0.12), (1510.0, 38.0, 0.07)]:
        ring += np.sin(2 * math.pi * hz * tune * t) * np.exp(-t * decay) * amp
    click_n = int(0.0022 * SR)
    click = np.zeros_like(t)
    click[:click_n] = _rng.standard_normal(click_n)
    scrape = _band(_rng.standard_normal(t.size), 700.0, 2500.0) \
            * np.exp(-t * 34.0) * 0.30
    sig = thud * 0.95 + ring + click * 0.5 + scrape
    _write(name, _fade_edges(sig, 4.0), 0.65)


def shelf_creak() -> None:
    # the shelf lets go a little: a dry stick-slip groan
    t = _t(1.1)
    glide = 66.0 - 14.0 * (t / t[-1])
    carrier = np.sin(2 * math.pi * np.cumsum(glide) / SR)
    steps = np.random.default_rng(31).random(int(t.size / (0.05 * SR)) + 1)
    gate = np.repeat(steps, int(0.05 * SR))[:t.size]
    gate = _lowpass(gate.astype(float), 300.0)
    grit = _band(_rng.standard_normal(t.size), 260.0, 900.0) * 0.20
    sig = carrier * (0.35 + 0.65 * gate) * 0.8 + grit * gate
    sig *= np.linspace(1.0, 0.0, t.size) ** 0.8
    _write("shelf_creak", _fade_edges(sig, 12.0), 0.60)


SOUNDS = {
    "room_tone": room_tone,
    "fan_loop": fan_loop,
    "radio_static": radio_static,
    "footstep_iron_1": footstep_iron_1,
    "footstep_iron_2": footstep_iron_2,
    "footstep_iron_3": footstep_iron_3,
    "shelf_creak": shelf_creak,
}


def main():
    import sys
    os.makedirs(OUT, exist_ok=True)
    names = sys.argv[1].split(",") if len(sys.argv) > 1 else SOUNDS
    for name in names:
        SOUNDS[name]()
    print("wrote", len(os.listdir(OUT)), "files to", OUT)


if __name__ == "__main__":
    main()
