#!/usr/bin/env python3
"""
Compositor de música do Bota-Abaixo (sem samples, sem IA): compõe e sintetiza cada faixa a partir de
audio/music/<nome>.json com "motor": "compositor". Instrumentos suaves (piano elétrico, marimba,
corda dedilhada, baixo redondo, fundo), bateria leve, reverb de sala, estéreo. Loop sem emenda.

Uso:  python tools/musica.py            # gera todas as faixas em game/assets/audio/music/
      python tools/musica.py menu       # só uma
Precisa de numpy e scipy (só para gerar; o jogo não usa).

Formato (audio/music/menu.json):
  {"motor": "compositor", "bpm": 100, "tom": "F", "escala": "maior", "semente": 3,
   "secoes": ["A", "B", "A", "C", "B"],            8 compassos cada (progressão de 4 acordes, 2 vezes)
   "progressoes": {"A": ["I","vi","IV","V"], ...},
   "baixo": "andando|pulsante|longo", "acordes": "epiano|pluck|pad", "comping": "contratempo|longo|arpejo",
   "melodia": "marimba|pluck|epiano|sino", "bateria": "leve|dancante|calma|nenhuma",
   "volume": 1.0, "loop": true}
"""
import json
import sys
import wave
from pathlib import Path

import numpy as np
from scipy import signal

SR = 32000
ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "audio" / "music"
OUT = ROOT / "game" / "assets" / "audio" / "music"

NOTES = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11,
         "DB": 1, "EB": 3, "GB": 6, "AB": 8, "BB": 10}
SCALES = {"maior": [0, 2, 4, 5, 7, 9, 11], "menor": [0, 2, 3, 5, 7, 8, 10], "mixolidio": [0, 2, 4, 5, 7, 9, 10],
          "dorico": [0, 2, 3, 5, 7, 9, 10]}
ROMAN = {"I": 0, "II": 1, "III": 2, "IV": 3, "V": 4, "VI": 5, "VII": 6}


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


# ------------------------------------------------------------------ instrumentos (nota -> sinal mono)
def _t(dur):
    return np.arange(int(dur * SR)) / SR


def _fade(x, rel=0.03):
    n = min(len(x), int(rel * SR))
    if n > 0:
        x[-n:] *= np.linspace(1, 0, n) ** 2
    return x


def lowpass(x, fc, order=2):
    b, a = signal.butter(order, min(fc / (SR / 2), 0.99))
    return signal.lfilter(b, a, x)


def highpass(x, fc, order=2):
    b, a = signal.butter(order, fc / (SR / 2), btype="high")
    return signal.lfilter(b, a, x)


def bandpass(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], btype="band")
    return signal.lfilter(b, a, x)


def epiano(f, dur, vel):
    t = _t(dur + 0.35)
    env = np.exp(-t * 2.2) * np.minimum(1, t / 0.004)
    trem = 1 + 0.06 * np.sin(2 * np.pi * 4.5 * t)
    x = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 5) \
        + 0.12 * np.sin(2 * np.pi * 3 * f * t) * np.exp(-t * 9) + 0.05 * np.sin(2 * np.pi * 7.1 * f * t) * np.exp(-t * 30)
    x = x * env * trem
    rel = np.ones_like(t)
    k = int(dur * SR)
    rel[k:] = np.exp(-(t[k:] - dur) * 14)
    return _fade(x * rel * vel * 0.5)


def marimba(f, dur, vel):
    t = _t(min(dur, 0.6) + 0.25)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t * 7) + 0.35 * np.sin(2 * np.pi * 3.93 * f * t) * np.exp(-t * 22) \
        + 0.08 * np.sin(2 * np.pi * 9.2 * f * t) * np.exp(-t * 45)
    x *= np.minimum(1, t / 0.002)
    return _fade(x * vel * 0.55)


def sino(f, dur, vel):
    t = _t(min(dur, 1.2) + 0.8)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t * 2.4) + 0.4 * np.sin(2 * np.pi * 2.76 * f * t) * np.exp(-t * 4.5) \
        + 0.2 * np.sin(2 * np.pi * 5.4 * f * t) * np.exp(-t * 8)
    return _fade(x * np.minimum(1, t / 0.002) * vel * 0.35)


def pluck(f, dur, vel, bright=0.5):
    """Corda dedilhada (Karplus-Strong via filtro IIR)."""
    n = int((min(dur, 1.0) + 0.3) * SR)
    period = max(2, int(SR / f))
    rng = np.random.default_rng(int(f * 100) % 9973)
    exc = np.zeros(n)
    burst = rng.uniform(-1, 1, period)
    exc[:period] = lowpass(burst, 1500 + bright * 5000, 1)
    g = 0.996 - 0.0006 * (f / 440)
    a = np.zeros(period + 2)
    a[0] = 1
    a[period] = -0.5 * g
    a[period + 1] = -0.5 * g
    x = signal.lfilter([1], a, exc)
    return _fade(x * vel * 0.6, 0.06)


def baixo(f, dur, vel):
    t = _t(dur + 0.08)
    env = np.minimum(1, t / 0.006) * (0.55 + 0.45 * np.exp(-t * 6))
    k = int(dur * SR)
    env[k:] *= np.exp(-(t[k:] - dur) * 40)
    x = np.tanh(1.6 * (np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * 2 * f * t)))
    return _fade(lowpass(x * env, 700) * vel * 0.5)


def pad(f, dur, vel):
    t = _t(dur + 0.6)
    k = int(dur * SR)
    env = np.minimum(1, t / 0.35)
    env[k:] *= np.exp(-(t[k:] - dur) * 5)
    x = sum(signal.sawtooth(2 * np.pi * f * (1 + d) * t) for d in (-0.004, 0.0, 0.0045))
    return _fade(lowpass(x * env, 1100, 2) * vel * 0.11)


def chip(f, dur, vel):
    """Pulso retrô (25%) bem filtrado: lembra 8-bit sem o chiado."""
    t = _t(dur + 0.06)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / 0.25)
    ph = np.cumsum(f * vib) / SR
    x = np.where(ph % 1.0 < 0.25, 1.0, -1.0)
    env = np.minimum(1, t / 0.004) * (0.7 + 0.3 * np.exp(-t * 8))
    k = int(dur * SR)
    env[k:] *= np.exp(-(t[k:] - dur) * 50)
    return _fade(lowpass(x * env, 2400, 2) * vel * 0.22)


def chipbaixo(f, dur, vel):
    t = _t(dur + 0.04)
    x = signal.sawtooth(2 * np.pi * f * t, 0.5)   # triângulo
    env = np.minimum(1, t / 0.003)
    k = int(dur * SR)
    env[k:] *= np.exp(-(t[k:] - dur) * 60)
    return _fade(x * env * vel * 0.5)


def metais(f, dur, vel):
    """Naipe de metais: serrotes com o filtro abrindo no ataque (sopro)."""
    t = _t(dur + 0.12)
    x = signal.sawtooth(2 * np.pi * f * t) + signal.sawtooth(2 * np.pi * f * 1.006 * t)
    e = np.exp(-t * 7)
    y = lowpass(x, 800) + (lowpass(x, 3200) - lowpass(x, 800)) * e
    env = np.minimum(1, t / 0.025)
    k = int(dur * SR)
    env[k:] *= np.exp(-(t[k:] - dur) * 25)
    return _fade(y * env * vel * 0.16)


def guitarra(f, dur, vel):
    """Guitarra com distorção (corda dedilhada + saturação + 'caixa' filtrando)."""
    x = pluck(f, max(dur, 0.12), 1.0, bright=0.9)
    n = int((dur + 0.08) * SR)
    x = x[:n] if len(x) > n else np.pad(x, (0, n - len(x)))
    y = np.tanh(5.0 * x)
    y = lowpass(highpass(y, 90), 3200, 2)
    return _fade(y * vel * 0.22, 0.04)


def slap(f, dur, vel):
    t = _t(dur + 0.06)
    x = np.tanh(2.2 * (np.sin(2 * np.pi * f * t) + 0.5 * np.sin(2 * np.pi * 2 * f * t) * np.exp(-t * 12)))
    env = np.minimum(1, t / 0.002) * (0.5 + 0.5 * np.exp(-t * 9))
    k = int(dur * SR)
    env[k:] *= np.exp(-(t[k:] - dur) * 45)
    click = np.zeros_like(t)
    m = min(len(t), int(0.006 * SR))
    click[:m] = np.random.default_rng(3).uniform(-1, 1, m) * np.linspace(1, 0, m) * 0.35
    return _fade(lowpass(x * env + click, 2200) * vel * 0.5)


def piano(f, dur, vel):
    t = _t(dur + 0.4)
    env = np.exp(-t * 1.8) * np.minimum(1, t / 0.003)
    x = sum(a * np.sin(2 * np.pi * f * h * (1 + 0.0004 * h * h) * t) * np.exp(-t * (1 + h * 1.5))
            for h, a in ((1, 1.0), (2, 0.5), (3, 0.25), (4, 0.12), (5, 0.06)))
    k = int(dur * SR)
    rel = np.ones_like(t)
    rel[k:] = np.exp(-(t[k:] - dur) * 10)
    return _fade(x * env * rel * vel * 0.4)


INSTR = {"epiano": epiano, "marimba": marimba, "sino": sino, "pluck": pluck, "baixo": baixo, "pad": pad,
         "chip": chip, "chipbaixo": chipbaixo, "metais": metais, "guitarra": guitarra, "slap": slap, "piano": piano}


def kick(vel):
    t = _t(0.35)
    f = 48 + 75 * np.exp(-t * 32)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 8)
    x[:60] += np.linspace(0.4, 0, 60)
    return x * vel * 0.75


def snare(vel, rng):
    t = _t(0.22)
    nz = bandpass(rng.uniform(-1, 1, len(t)), 900, 6000) * np.exp(-t * 20)
    tone = np.sin(2 * np.pi * 185 * t) * np.exp(-t * 28) * 0.5
    return (nz * 0.9 + tone) * vel * 0.45


def hat(vel, rng, open_=False):
    t = _t(0.25 if open_ else 0.05)
    x = highpass(rng.uniform(-1, 1, len(t)), 7000) * np.exp(-t * (12 if open_ else 70))
    return x * vel * 0.16


def crash(vel, rng):
    t = _t(1.4)
    return highpass(rng.uniform(-1, 1, len(t)), 5000) * np.exp(-t * 3.2) * vel * 0.1


def ride(vel, rng):
    t = _t(0.5)
    x = highpass(rng.uniform(-1, 1, len(t)), 6000) * np.exp(-t * 9) * 0.6 + np.sin(2 * np.pi * 3100 * t) * np.exp(-t * 6) * 0.15
    return x * vel * 0.12


def vassoura(vel, rng):
    t = _t(0.18)
    x = bandpass(rng.uniform(-1, 1, len(t)), 1500, 7000) * np.sin(np.pi * np.minimum(1, t / 0.18)) ** 0.7
    return x * vel * 0.2


def shaker(vel, rng):
    t = _t(0.09)
    x = bandpass(rng.uniform(-1, 1, len(t)), 4000, 9000) * np.sin(np.pi * np.minimum(1, t / 0.09))
    return x * vel * 0.12


# ------------------------------------------------------------------ composição
class Song:
    def __init__(self, spec):
        self.s = spec
        self.bpm = float(spec["bpm"])
        self.beat = 60.0 / self.bpm
        self.root = 60 + NOTES[spec.get("tom", "C").upper()] - 12   # tônica perto do C4
        if self.root < 55:
            self.root += 12
        self.scale = SCALES[spec.get("escala", "maior")]
        self.rng = np.random.default_rng(int(spec.get("semente", 1)))
        self.sections = spec.get("secoes", ["A", "B", "A", "C"])
        self.bars = 8 * len(self.sections)
        self.total = int(self.bars * 4 * self.beat * SR)
        self.tracks = {k: np.zeros(self.total + SR * 3) for k in ("baixo", "acordes", "melodia", "pad", "bateria")}

    def deg(self, d, octave=0):
        """Grau da escala (0 = tônica; pode passar de 7) -> midi."""
        o, i = divmod(d, 7)
        return self.root + self.scale[i] + 12 * (o + octave)

    def chord(self, roman):
        r = roman.lower().strip("°")
        d = ROMAN[r.upper()]
        return [d, d + 2, d + 4]   # tríade da escala

    def sw(self, t0, pos):
        """Tempo (s) de uma posição em tempos dentro do compasso, com balanço nas colcheias do contratempo."""
        frac = pos % 1.0
        if abs(frac - 0.5) < 1e-6:
            pos += float(self.s.get("swing", 0.0))
        return t0 + pos * self.beat

    def put(self, track, x, t0):
        i = int(t0 * SR)
        j = min(i + len(x), len(self.tracks[track]))
        self.tracks[track][i:j] += x[:j - i]

    def prog_for(self, name):
        progs = self.s["progressoes"]
        return progs.get(name, progs.get(name.rstrip("0123456789"), list(progs.values())[0]))

    def compose(self):
        motif = None
        for si, name in enumerate(self.sections):
            prog = self.prog_for(name)
            calm = name.startswith("C")
            if name.rstrip("0123456789") not in getattr(self, "_motifs", {}):
                self._motifs = getattr(self, "_motifs", {})
                self._motifs[name.rstrip("0123456789")] = self.make_motif()
            motif = self._motifs[name.rstrip("0123456789")]
            for b in range(8):
                bar = si * 8 + b
                t0 = bar * 4 * self.beat
                ch = self.chord(prog[b % len(prog)])
                nxt = self.chord(prog[(b + 1) % len(prog)])
                self.bass_bar(t0, ch, nxt, calm, b)
                self.comp_bar(t0, ch, calm)
                if self.s.get("pad", True):
                    if b % 2 == 0 or calm:
                        for d in ch:
                            self.put("pad", pad(hz(self.deg(d, 0)), self.beat * (4 if calm else 8) * 0.98, 0.8), t0)
                if not calm or b >= 4:
                    self.melody_bar(t0, ch, motif, b, calm, final=(b == 7))
                self.drum_bar(t0, calm, fill=(b == 7), first=(b == 0))

    # --- partes
    def bass_bar(self, t0, ch, nxt, calm, b):
        style = self.s.get("baixo", "pulsante")
        r = self.deg(ch[0], -2)
        v = 0.9
        bt = self.beat
        baixo = INSTR[self.s.get("baixo_inst", "baixo")]
        if style == "slap" and not calm:
            pat = [(0, 0, 1.0, 0.35), (0.75, 0, 0.6, 0.2), (1.5, 12, 0.8, 0.15), (2, 0, 0.9, 0.3), (2.75, 7, 0.6, 0.2),
                   (3.25, 12, 0.8, 0.15), (3.5, 10, 0.6, 0.2)]
            for pos, off, vv, d in pat:
                self.put("baixo", baixo(hz(r + off), bt * d * 2, v * vv), t0 + pos * bt)
            return
        if style == "oitavas" and not calm:
            for k in range(8):
                self.put("baixo", baixo(hz(r + (12 if k % 2 else 0)), bt * 0.42, v * (1.0 if k % 2 == 0 else 0.7)), t0 + k * bt / 2)
            return
        if calm or style == "longo":
            self.put("baixo", baixo(hz(r), bt * 3.8, v), t0)
            return
        if style == "andando":
            seq = [ch[0], ch[2], ch[1] + 7 if ch[1] < 3 else ch[1], nxt[0] - 1]
            for k, d in enumerate(seq):
                self.put("baixo", baixo(hz(self.deg(d, -2)), bt * 0.9, v * (1 if k == 0 else 0.8)), t0 + k * bt)
            return
        # pulsante: tônica nas colcheias com quinta e oitava
        pat = [(0, 0, 1.0), (1, 0, 0.6), (1.5, 0, 0.7), (2, 4, 0.9), (3, 0, 0.6), (3.5, 7, 0.7)]
        for pos, off, vv in pat:
            midi = r + {0: 0, 4: 7, 7: 12}[off]
            self.put("baixo", baixo(hz(midi), bt * 0.45, v * vv), t0 + pos * bt)

    def comp_bar(self, t0, ch, calm):
        inst = INSTR[self.s.get("acordes", "epiano")]
        style = "longo" if calm else self.s.get("comping", "contratempo")
        notes = [self.deg(d, 0) for d in ch]
        bt = self.beat
        if style == "power":   # acordes de força em colcheias (tônica, quinta, oitava), abafados
            r = self.deg(ch[0], -1)
            for k in range(8):
                acc = 1.0 if k in (0, 3, 6) else 0.6
                for m in (r, r + 7, r + 12):
                    self.put("acordes", inst(hz(m), bt * (0.45 if acc < 1 else 0.6), 0.45 * acc), t0 + k * bt / 2)
            return
        if style == "stabs":   # golpes de metais sincopados
            for pos in (0.5, 1.75, 2.5, 3.75):
                for i, m in enumerate(notes):
                    self.put("acordes", inst(hz(m), bt * 0.3, 0.5), self.sw(t0, pos) + i * 0.006)
            return
        if style == "charleston":   # piano com balanço: no 1 e no "e" do 2
            for pos, d in ((0.0, 0.8), (1.5, 0.5), (2.0, 0.8), (3.5, 0.4)):
                for i, m in enumerate(notes):
                    self.put("acordes", inst(hz(m), bt * d, 0.42), self.sw(t0, pos) + i * 0.01)
            return
        if style == "longo":
            for i, m in enumerate(notes):
                self.put("acordes", inst(hz(m), bt * 3.6, 0.5), t0 + i * 0.012)
        elif style == "arpejo":
            seq = notes + [notes[1] + 12, notes[2], notes[1], notes[0] + 12, notes[1]]
            for k in range(8):
                self.put("acordes", inst(hz(seq[k % len(seq)]), bt * 0.45, 0.42 + 0.1 * (k % 2 == 0)), t0 + k * bt / 2)
        else:   # contratempo: acorde curto nos "e" do tempo (balanço)
            for k in range(4):
                for i, m in enumerate(notes):
                    self.put("acordes", inst(hz(m), bt * 0.32, 0.38), self.sw(t0, k + 0.5) + i * 0.008)

    def make_motif(self):
        """Motivo de 2 compassos: ritmo de uma lista e alturas por passos (sobe/desce), terminando em nota de acorde."""
        rhythms = [[1, 0.5, 0.5, 1, 1], [0.5, 0.5, 1, 0.5, 0.5, 1], [1.5, 0.5, 1, 1], [0.5, 0.5, 0.5, 0.5, 2],
                   [1, 1, 0.5, 0.5, 1], [0.75, 0.25, 1, 1, 1]]
        r1 = rhythms[self.rng.integers(len(rhythms))]
        r2 = rhythms[self.rng.integers(len(rhythms))]
        steps = []
        cur = 0
        for _ in range(len(r1) + len(r2)):
            cur += int(self.rng.choice([-2, -1, -1, 1, 1, 2, 0]))
            cur = int(np.clip(cur, -3, 5))
            steps.append(cur)
        return {"r": [r1, r2], "s": steps}

    def melody_bar(self, t0, ch, motif, b, calm, final=False):
        inst = INSTR[self.s.get("melodia", "marimba")]
        half = b % 2
        rh = motif["r"][half]
        off = 0 if half == 0 else len(motif["r"][0])
        # resposta: compassos 4–7 variam o motivo (sobe um grau e embaralha um pouco)
        lift = 0 if b < 4 else (2 if b in (4, 5) else -1)
        pos = 0.0
        vel = 0.42 if calm else 0.5
        for k, d in enumerate(rh):
            st = motif["s"][(off + k) % len(motif["s"])] + lift
            # puxa para nota do acorde no tempo forte
            deg = ch[0] + st
            if pos in (0.0, 2.0):
                deg = min(ch, key=lambda c: abs(c + 7 * round((deg - c) / 7) - deg))
                deg = deg + 7 * round((ch[0] + st - deg) / 7)
            if final and k == len(rh) - 1:
                deg = ch[0]
            if not (b in (3, 7) and pos >= 3.0) or final:
                m = self.deg(deg, 1)
                oc = int(self.s.get("oitava_melodia", 1))
                m = self.deg(deg, oc)
                self.put("melodia", inst(hz(m), d * self.beat * 0.9, vel * (1.0 if pos in (0.0, 2.0) else 0.8)), self.sw(t0, pos))
            pos += d
            if pos >= 4:
                break

    def drum_bar(self, t0, calm, fill, first):
        style = self.s.get("bateria", "leve")
        if style == "nenhuma":
            return
        bt = self.beat
        rng = self.rng
        if calm:
            for k in range(8):
                self.put("bateria", shaker(0.7 if k % 2 == 0 else 0.45, rng), t0 + k * bt / 2)
            if first:
                self.put("bateria", kick(0.6), t0)
            return
        if style == "funk":
            for k in (0, 1.75, 2.5):
                self.put("bateria", kick(0.85), t0 + k * bt)
            for k in (1, 3):
                self.put("bateria", snare(0.75, rng), t0 + k * bt)
            for k in (1.75, 2.75, 3.25):
                self.put("bateria", snare(0.18, rng), t0 + k * bt)   # notas fantasma
            for k in range(16):
                self.put("bateria", hat(0.6 if k % 4 == 2 else 0.3, rng), t0 + k * bt / 4)
            return
        if style == "rock":
            if first:
                self.put("bateria", crash(0.9, rng), t0)
            for k in (0, 1.5, 2, 2.5):
                self.put("bateria", kick(0.9), t0 + k * bt)
            for k in (1, 3):
                self.put("bateria", snare(0.95, rng), t0 + k * bt)
            for k in range(8):
                self.put("bateria", hat(0.7, rng), t0 + k * bt / 2)
            if fill:
                for k, p in enumerate((3.0, 3.25, 3.5, 3.75)):
                    self.put("bateria", snare(0.5 + 0.12 * k, rng), t0 + p * bt)
            return
        if style == "vassourinha":   # jazz: prato de condução com balanço + vassoura no 2 e 4
            for pos in (0, 1, 1.5, 2, 3, 3.5):
                self.put("bateria", ride(0.8 if pos % 1 == 0 else 0.5, rng), self.sw(t0, pos))
            for k in (1, 3):
                self.put("bateria", vassoura(0.8, rng), t0 + k * bt)
            self.put("bateria", kick(0.35), t0)
            return
        if style == "chip":
            for k in (0, 2):
                self.put("bateria", kick(0.6), t0 + k * bt)
            for k in (1, 3):
                self.put("bateria", snare(0.4, rng), t0 + k * bt)
            for k in range(8):
                self.put("bateria", hat(0.35, rng), t0 + k * bt / 2)
            return
        kicks = [0, 2] if style in ("leve", "calma") else [0, 1, 2, 3]
        if style == "leve" and rng.random() < 0.4:
            kicks = [0, 2, 2.5]
        for k in kicks:
            self.put("bateria", kick(0.85), t0 + k * bt)
        if style != "calma":
            for k in (1, 3):
                self.put("bateria", snare(0.7, rng), t0 + k * bt)
        for k in range(8):
            if fill and k >= 6:
                continue
            self.put("bateria", hat(0.8 if k % 2 == 1 else 0.45, rng, open_=(style == "dancante" and k % 2 == 1)), t0 + k * bt / 2)
        if fill:
            for k, p in enumerate((3.0, 3.25, 3.5, 3.75)):
                self.put("bateria", snare(0.35 + 0.12 * k, rng), t0 + p * bt)

    # --- mixagem
    def mix(self):
        L = np.zeros(self.total + SR * 3)
        R = np.zeros_like(L)
        pans = {"baixo": 0.0, "acordes": -0.35, "melodia": 0.3, "pad": 0.0, "bateria": 0.1}
        gains = {"baixo": 0.9, "acordes": 0.55, "melodia": 0.6, "pad": 0.7, "bateria": 0.65}
        gains.update(self.s.get("ganhos", {}))
        for k, x in self.tracks.items():
            g = gains[k]
            p = pans[k]
            if k == "pad":   # fundo largo: um lado levemente atrasado
                d = int(0.012 * SR)
                L += x * g
                R[d:] += x[:-d] * g
                continue
            L += x * g * np.sqrt((1 - p) / 2) * 1.414
            R += x * g * np.sqrt((1 + p) / 2) * 1.414
        # reverb de sala (convolução com cauda de ruído que decai) — mesma sala para tudo, leve
        rng = np.random.default_rng(7)
        n = int(1.6 * SR)
        tt = np.arange(n) / SR
        irs = []
        for _ in range(2):
            ir = rng.normal(0, 1, n) * np.exp(-tt * 3.6)
            ir = lowpass(ir, 5000)
            ir[: int(0.012 * SR)] = 0
            irs.append(ir / np.sqrt(np.sum(ir ** 2)))
        wet = float(self.s.get("reverb", 0.22))
        L = L + wet * signal.fftconvolve(L, irs[0])[: len(L)]
        R = R + wet * signal.fftconvolve(R, irs[1])[: len(R)]
        # loop sem emenda: o que passa do fim (caudas) volta para o começo
        if self.s.get("loop", True):
            tail = len(L) - self.total
            L[:tail] += L[self.total:]
            R[:tail] += R[self.total:]
            L, R = L[: self.total], R[: self.total]
        st = np.stack([L, R], axis=1)
        st = lowpass(st.T, 12000).T
        peak = np.max(np.abs(st))
        st = st / peak * 0.7 * float(self.s.get("volume", 1.0))   # pico em -3 dB, sem estourar
        return st


def write_wav(path, st):
    path.parent.mkdir(parents=True, exist_ok=True)
    data = (np.clip(st, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def build(name):
    spec = json.loads((SRC / f"{name}.json").read_text(encoding="utf-8"))
    if spec.get("motor") != "compositor":
        return None
    s = Song(spec)
    s.compose()
    st = s.mix()
    write_wav(OUT / f"{name}.wav", st)
    rms = 20 * np.log10(np.sqrt(np.mean(st ** 2)) + 1e-9)
    return len(st) / SR, rms


def main():
    names = sys.argv[1:] or [p.stem for p in sorted(SRC.glob("*.json"))]
    for n in names:
        r = build(n)
        if r:
            print(f"{n}: {r[0]:.1f} s, volume médio {r[1]:.1f} dB")


if __name__ == "__main__":
    main()
