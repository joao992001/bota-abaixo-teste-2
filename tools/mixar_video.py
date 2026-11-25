#!/usr/bin/env python3
"""Prévia para OUVIR: mistura o áudio de uma captura --video=DIR (DIR/sons.json + quadros v_*.jpg) num MP4, com a mesma
polifonia (cópia mais antiga cortada) e o limitador do Master do jogo. Uso: python3 tools/mixar_video.py DIR saida.mp4"""
import json, sys, subprocess, numpy as np
D = sys.argv[1]; SR = 48000
STEM = sys.argv[3] if len(sys.argv) > 3 else ""   # "musica" ou "efeitos": só uma parte (para medir o equilíbrio)
j = json.load(open(f"{D}/sons.json")); root = j["root"]
dur = j["frames"] / j["fps"] + 1.0
out = np.zeros((int(dur * SR), 2), np.float32)
cache = {}
def load(path):
    if path not in cache:
        p = root + path.replace("res://", "")
        raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", p, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"], capture_output=True).stdout
        cache[path] = np.frombuffer(raw, np.float32).reshape(-1, 2)
    return cache[path]
ducks = [e["t"] for e in j["log"] if e.get("duck")]
music = [e for e in j["log"] if e.get("music")]
import re
MAXV = {"impacto_robo_rapido": 3, "impacto_robo_pesado": 2, "marreta_rapida_metal": 2, "marreta_pesada_metal": 2, "passo_metal": 2,
        "aterrissagem_leve": 2, "aterrissagem_pesada": 2, "salto": 2, "salto_duplo": 2, "explosao_fora_arena_padrao": 2}
ev = [e for e in j["log"] if not e.get("duck") and not e.get("music")]
for k, e in enumerate(ev):   # mesma polifonia do jogo: a cópia mais antiga é cortada quando chega uma nova além do limite
    g = re.sub(r"_?\d+$", "", e["path"].split("/")[-1].rsplit(".", 1)[0]); e["g"] = g; e["end"] = 1e9
    act = [f for f in ev[:k] if f.get("g") == g and f["end"] > e["t"] and f["t"] + len(load(f["path"])) / SR > e["t"]]
    if len(act) >= MAXV.get(g, 99): min(act, key=lambda f: f["t"])["end"] = e["t"]
for e in (ev if STEM != "musica" else []):
    x = load(e["path"]); pitch = e["pitch"]
    if e["end"] < 1e9: x = x[:max(int((e["end"] - e["t"]) * SR / pitch), 0)].copy(); fade = min(len(x), 240); x[len(x) - fade:] *= np.linspace(1, 0, fade)[:, None]
    if abs(pitch - 1) > 1e-3:
        idx = np.arange(0, len(x) - 1, pitch); x = np.stack([np.interp(idx, np.arange(len(x)), x[:, c]) for c in (0, 1)], 1)
    g = 10 ** (e["db"] / 20); i0 = int(e["t"] * SR); n = min(len(x), len(out) - i0)
    if n > 0: out[i0:i0 + n] += x[:n] * g
if music and STEM != "efeitos":
    m = music[-1]; x = load(m["path"]); i0 = int(m["t"] * SR)
    env = np.ones(len(out) - i0, np.float32)
    t = np.arange(len(env)) / SR + m["t"]
    for d in ducks:   # 0,43 e volta linear em 0,48 s
        k = (t >= d) & (t < d + 0.48); env[k] = np.minimum(env[k], 0.43 + 0.57 * (t[k] - d) / 0.48)
    reps = int(np.ceil(len(env) / len(x))) + 1
    mm = np.tile(x, (reps, 1))[:len(env)] * (10 ** (m["db"] / 20)) * env[:, None]
    out[i0:] += mm
pk = np.max(np.abs(out)); rms = np.sqrt(np.mean(out[int(SR):] ** 2))
print("pico %.1f dB · RMS %.1f dB" % (20 * np.log10(pk + 1e-9), 20 * np.log10(rms + 1e-9)))
# o jogo tem limitador no Master (−0,5 dB): o mesmo aqui, via ffmpeg
(out.astype(np.float32)).tofile(f"{D}/mix.f32")
subprocess.run(["ffmpeg", "-v", "quiet", "-y", "-framerate", str(j["fps"]), "-i", f"{D}/v_%05d.jpg", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", f"{D}/mix.f32",
                "-af", "alimiter=limit=0.944:attack=1:release=50:level=disabled", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "26", "-c:a", "aac", "-b:a", "160k", "-shortest", sys.argv[2]], check=True)
