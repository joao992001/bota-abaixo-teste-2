#!/usr/bin/env python3
"""
SfxForge — efeitos sonoros e música chiptune gerados por código (estilo sfxr).

Nada de samples nem IA de áudio: cada som é um JSON com parâmetros de síntese,
editável e versionável. Gera .wav (16-bit mono, 44.1 kHz) que a Godot importa direto.

Uso:
  python tools/sfxforge.py build                 # gera tudo de audio/sfx e audio/music
  python tools/sfxforge.py new jump pulo         # cria audio/sfx/pulo.json a partir de um modelo
  python tools/sfxforge.py new jump pulo --seed 7
  modelos: jump, land, dash, death, pickup, blip, spring, wind, hit

Formato de efeito (audio/sfx/*.json) — todos os campos são opcionais:
  {
    "wave": "square",        square | saw | triangle | sine | noise
    "duty": 0.5,             largura do pulso (square)
    "freq_start": 440,       Hz
    "freq_end": 880,         Hz (glide linear em escala log)
    "duration": 0.2,         segundos (sem contar o release)
    "attack": 0.005, "decay": 0.05, "sustain": 0.6, "release": 0.08,
    "vibrato_depth": 0.0,    em semitons
    "vibrato_rate": 6.0,     Hz
    "arpeggio": [0, 7],      semitons em sequência (opcional)
    "arp_speed": 0.05,       segundos por nota do arpejo
    "lowpass": 1.0,          0..1 (1 = sem filtro)
    "highpass": 0.0,         0..1
    "volume": 0.5,
    "variations": 3,         gera nome_1.wav .. nome_3.wav com leve variação
    "pitch_jitter": 0.04     variação de tom entre variações (fração)
  }

Formato de música (audio/music/*.json):
  {
    "bpm": 96, "steps_per_beat": 4, "loops": 2,
    "tracks": [
      {"wave": "triangle", "volume": 0.35, "notes": "C3 . . . G2 . . . A2 . . . F2 . . ."},
      {"wave": "square", "duty": 0.25, "volume": 0.18, "release": 0.05,
       "notes": "E4 . G4 . C5 . G4 . | A4 . C5 . F4 . A4 ."},
      {"wave": "noise", "volume": 0.12, "decay": 0.04, "sustain": 0,
       "notes": "x . . . x . . . x . . . x . x ."}
    ]
  }
  '.' = pausa/continua, '-' = segura a nota anterior, '|' é só separador visual.
  Na trilha de noise, qualquer token não-'.' toca uma batida.
"""
import argparse
import json
import random
import sys
import wave
import zlib
from pathlib import Path

try:
    import numpy as np
except ImportError:
    sys.exit("SfxForge precisa do numpy: pip install numpy")

SR = 44100
ROOT = Path(__file__).resolve().parent.parent
AUDIO = ROOT / "audio"
OUT = ROOT / "out" / "audio"

NOTE_INDEX = {"C": 0, "C#": 1, "DB": 1, "D": 2, "D#": 3, "EB": 3, "E": 4, "F": 5, "F#": 6,
              "GB": 6, "G": 7, "G#": 8, "AB": 8, "A": 9, "A#": 10, "BB": 10, "B": 11}


def note_freq(tok):
    tok = tok.upper()
    name, octave = tok[:-1], int(tok[-1])
    midi = 12 * (octave + 1) + NOTE_INDEX[name]
    return 440.0 * 2 ** ((midi - 69) / 12)


# ------------------------------------------------------------- síntese
def osc(wave_type, phase, duty=0.5, rng=None, freq=None):
    p = phase % 1.0
    if wave_type == "square":
        return np.where(p < duty, 1.0, -1.0)
    if wave_type == "saw":
        return 2.0 * p - 1.0
    if wave_type == "triangle":
        return 1.0 - 4.0 * np.abs(p - 0.5)
    if wave_type == "sine":
        return np.sin(2 * np.pi * p)
    if wave_type == "noise":
        # ruído "sample & hold" que acompanha o tom (soa mais 8-bit que ruído branco)
        rng = rng or np.random.default_rng(0)
        idx = np.floor(phase * 2).astype(np.int64)
        idx -= idx.min() if len(idx) else 0
        table = rng.uniform(-1, 1, int(idx.max()) + 2 if len(idx) else 1)
        return table[idx]
    raise ValueError(f"wave desconhecida: {wave_type}")


def envelope(n_main, n_rel, a, d, s, sr=SR):
    total = n_main + n_rel
    env = np.zeros(total)
    na, nd = int(a * sr), int(d * sr)
    t = 0
    if na:
        env[:min(na, total)] = np.linspace(0, 1, na)[:min(na, total)]
        t = na
    if nd and t < n_main:
        seg = min(nd, n_main - t)
        env[t:t + seg] = np.linspace(1, s, nd)[:seg]
        t += seg
    if t < n_main:
        env[t:n_main] = s if (na or nd) else 1.0
    level = env[n_main - 1] if n_main else 0
    if n_rel:
        env[n_main:] = np.linspace(level, 0, n_rel)
    return env


def one_pole(x, amount, high=False):
    """Filtro simples de 1 polo. amount 0..1."""
    if (not high and amount >= 0.999) or (high and amount <= 0.001):
        return x
    alpha = amount
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return x - y if high else y


def synth(p, rng=None, pitch_mul=1.0):
    rng = rng or np.random.default_rng(0)
    wave_type = p.get("wave", "square")
    dur, rel = p.get("duration", 0.2), p.get("release", 0.08)
    n_main, n_rel = int(dur * SR), int(rel * SR)
    n = n_main + n_rel
    t = np.arange(n) / SR
    f0 = p.get("freq_start", 440) * pitch_mul
    f1 = p.get("freq_end", f0 / pitch_mul) * pitch_mul
    k = np.clip(t / max(dur, 1e-6), 0, 1)
    freq = f0 * (f1 / f0) ** k  # glide exponencial
    arp = p.get("arpeggio")
    if arp:
        step = np.floor(t / p.get("arp_speed", 0.05)).astype(int)
        step = np.minimum(step, len(arp) - 1)
        freq = freq * 2 ** (np.array(arp)[step] / 12)
    vd = p.get("vibrato_depth", 0.0)
    if vd:
        freq = freq * 2 ** (vd * np.sin(2 * np.pi * p.get("vibrato_rate", 6) * t) / 12)
    phase = np.cumsum(freq) / SR
    sig = osc(wave_type, phase, p.get("duty", 0.5), rng)
    sig = sig * envelope(n_main, n_rel, p.get("attack", 0.005), p.get("decay", 0.05),
                         p.get("sustain", 0.6))
    sig = one_pole(sig, p.get("lowpass", 1.0))
    sig = one_pole(sig, p.get("highpass", 0.0), high=True)
    return sig * p.get("volume", 0.5)


def write_wav(path, sig):
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = np.max(np.abs(sig)) if len(sig) else 0
    if peak > 1:
        sig = sig / peak  # evita clipping
    data = (np.clip(sig, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)


# ------------------------------------------------------------- música
def render_music(m):
    bpm, spb = m.get("bpm", 100), m.get("steps_per_beat", 4)
    step = 60.0 / bpm / spb
    tracks = []
    for tr in m["tracks"]:
        toks = [x for x in tr["notes"].split() if x != "|"]
        tracks.append((tr, toks))
    n_steps = max(len(t) for _, t in tracks)
    total = int(n_steps * step * SR)
    mix = np.zeros(total + SR)
    rng = np.random.default_rng(1)
    for tr, toks in tracks:
        i = 0
        while i < len(toks):
            tok = toks[i]
            if tok in (".", "-"):
                i += 1
                continue
            length = 1
            while i + length < len(toks) and toks[i + length] == "-":
                length += 1
            params = {k: v for k, v in tr.items() if k not in ("notes",)}
            params.setdefault("sustain", 0.7)
            params.setdefault("decay", 0.08)
            params.setdefault("release", 0.06)
            params["duration"] = step * length * 0.92
            if params.get("wave") == "noise":
                params.setdefault("freq_start", 6000)
            else:
                params["freq_start"] = params["freq_end"] = note_freq(tok)
            sig = synth(params, rng)
            start = int(i * step * SR)
            end = min(start + len(sig), len(mix))
            mix[start:end] += sig[:end - start]
            i += length
    mix = mix[:total]
    loops = m.get("loops", 1)
    return np.tile(mix, loops)


# ------------------------------------------------------------- modelos
TEMPLATES = {
    "jump":   lambda r: dict(wave="square", duty=r.choice([0.25, 0.5]), freq_start=r.uniform(260, 360),
                             freq_end=r.uniform(560, 760), duration=r.uniform(0.08, 0.14), attack=0.002,
                             decay=0.04, sustain=0.5, release=0.05, lowpass=0.6, volume=0.35,
                             variations=3, pitch_jitter=0.04),
    "land":   lambda r: dict(wave="noise", freq_start=r.uniform(900, 1400), freq_end=200, duration=0.05,
                             attack=0.001, decay=0.04, sustain=0.0, release=0.03, lowpass=0.35, volume=0.4,
                             variations=3, pitch_jitter=0.08),
    "dash":   lambda r: dict(wave="noise", freq_start=r.uniform(3000, 5000), freq_end=r.uniform(600, 900),
                             duration=0.16, attack=0.003, decay=0.1, sustain=0.3, release=0.08, lowpass=0.5,
                             highpass=0.05, volume=0.45, variations=2, pitch_jitter=0.05),
    "death":  lambda r: dict(wave="square", duty=0.5, freq_start=r.uniform(500, 700), freq_end=60,
                             duration=0.35, attack=0.001, decay=0.2, sustain=0.3, release=0.15,
                             vibrato_depth=1.5, vibrato_rate=18, lowpass=0.5, volume=0.4),
    "pickup": lambda r: dict(wave="square", duty=0.25, freq_start=r.uniform(700, 900), duration=0.18,
                             arpeggio=[0, 4, 7, 12], arp_speed=0.045, attack=0.002, decay=0.05,
                             sustain=0.5, release=0.1, lowpass=0.7, volume=0.3),
    "blip":   lambda r: dict(wave="square", duty=0.5, freq_start=r.uniform(500, 900), duration=0.04,
                             attack=0.001, decay=0.02, sustain=0.4, release=0.02, lowpass=0.6, volume=0.25),
    "spring": lambda r: dict(wave="triangle", freq_start=r.uniform(180, 240), freq_end=r.uniform(900, 1200),
                             duration=0.18, attack=0.002, decay=0.05, sustain=0.6, release=0.08,
                             vibrato_depth=0.6, vibrato_rate=25, volume=0.45),
    "wind":   lambda r: dict(wave="noise", freq_start=r.uniform(1500, 2500), duration=2.0, attack=0.6,
                             decay=0.2, sustain=0.8, release=0.6, lowpass=0.08, vibrato_depth=6,
                             vibrato_rate=0.5, volume=0.35),
    "hit":    lambda r: dict(wave="noise", freq_start=r.uniform(2000, 4000), freq_end=300, duration=0.1,
                             attack=0.001, decay=0.07, sustain=0.1, release=0.05, lowpass=0.5, volume=0.45),
}


def cmd_new(args):
    if args.template not in TEMPLATES:
        sys.exit(f"modelo desconhecido. use: {', '.join(TEMPLATES)}")
    r = random.Random(args.seed)
    params = {k: (round(v, 4) if isinstance(v, float) else v) for k, v in TEMPLATES[args.template](r).items()}
    dest = AUDIO / "sfx" / f"{args.name}.json"
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and not args.force:
        sys.exit(f"{dest} já existe (use --force para sobrescrever)")
    dest.write_text(json.dumps(params, indent=2), encoding="utf-8")
    print(f"criado {dest.relative_to(ROOT)} — rode 'build' e ouça; ajuste os números à mão")


def cmd_build(args):
    count = 0
    for f in sorted((AUDIO / "sfx").glob("*.json")):
        p = json.loads(f.read_text(encoding="utf-8"))
        nvar = int(p.get("variations", 1))
        jit = p.get("pitch_jitter", 0.0)
        rng = np.random.default_rng(zlib.crc32(f.stem.encode()))
        if nvar <= 1:
            write_wav(OUT / "sfx" / f"{f.stem}.wav", synth(p, rng))
            count += 1
        else:
            for i in range(1, nvar + 1):
                mul = 1 + rng.uniform(-jit, jit)
                write_wav(OUT / "sfx" / f"{f.stem}_{i}.wav", synth(p, rng, mul))
                count += 1
    for f in sorted((AUDIO / "music").glob("*.json")):
        m = json.loads(f.read_text(encoding="utf-8"))
        write_wav(OUT / "music" / f"{f.stem}.wav", render_music(m))
        count += 1
    print(f"{count} arquivos .wav em {OUT.relative_to(ROOT)}")
    print("Na Godot: importe a música com Loop Mode = Forward.")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sp = ap.add_subparsers(dest="cmd", required=True)
    b = sp.add_parser("build"); b.set_defaults(fn=cmd_build)
    n = sp.add_parser("new"); n.add_argument("template"); n.add_argument("name")
    n.add_argument("--seed", type=int, default=None); n.add_argument("--force", action="store_true")
    n.set_defaults(fn=cmd_new)
    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
