#!/usr/bin/env python3
"""Converte refs ElevenLabs em gemidos sutis das almas (sprint 0050→0053).

Sprint 0053: ossos/esqueleto ensurdecedores saem; entram gemidos de sofrimento
(exhausted / faint / distant) com amplitude bem baixa. Fonte: pasta elevenlabs-refs
do Johan (não versionada no repo do jogo).

  NOM_ELEVENLABS_REFS=/caminho/elevenlabs-refs \\
    python3 scripts/import_elevenlabs_almas.py
  python3 scripts/import_elevenlabs_almas.py /caminho/elevenlabs-refs

Saída: mod/42/media/sound/NOM_Alma{Spawn,Crawl,Shamble,Group,Despawn}.ogg
(mono 44,1 kHz). Não copia MP3 pro repo. Volume relativo também em NOM_sounds.txt.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys

import numpy as np

import nom_synth as ns

RATE = ns.RATE
OUT = os.path.join(os.path.dirname(__file__), "..", "mod", "42", "media", "sound")

# slot -> (sufixo hex, t0, t1). Gemidos de sofrimento (não skeletal undead).
MAP = {
    "NOM_AlmaSpawn": ("15f9", None, None),      # exhausted adult
    "NOM_AlmaCrawl": ("2e45", None, None),      # faint distant
    "NOM_AlmaShamble": ("93bc", None, None),    # distant woman
    "NOM_AlmaGroup": ("57d8", None, None),      # several distant
    "NOM_AlmaDespawn": ("081d", None, None),    # very distant
}

MAX_DUR = {
    "NOM_AlmaSpawn": 3.5,
    "NOM_AlmaCrawl": 4.0,
    "NOM_AlmaShamble": 4.0,
    "NOM_AlmaGroup": 4.5,
    "NOM_AlmaDespawn": 3.2,
}

# Amplitude pós-processamento (antes do finalize): bem baixo / sutil.
GAIN = 0.28
# crest alto → RMS mais baixo com o mesmo pico (nom_synth.finalize).
CREST_DB = 16.5


def find_by_suffix(refs_dir: str, suffix: str) -> str:
    hits = [n for n in os.listdir(refs_dir) if n.endswith(f"_{suffix}.mp3")]
    if len(hits) != 1:
        raise SystemExit(f"sufixo _{suffix}.mp3: esperava 1 arquivo em {refs_dir}, achei {hits!r}")
    return os.path.join(refs_dir, hits[0])


def load_mono(path: str) -> np.ndarray:
    raw = subprocess.check_output(
        ["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(RATE), "-"]
    )
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def trim_silence(x: np.ndarray, thr_rel: float = 0.028, pad_s: float = 0.04) -> np.ndarray:
    peak = float(np.max(np.abs(x))) + 1e-12
    thr = thr_rel * peak
    idx = np.where(np.abs(x) > thr)[0]
    if idx.size == 0:
        return x
    pad = int(pad_s * RATE)
    a = max(0, int(idx[0]) - pad)
    b = min(len(x), int(idx[-1]) + pad + 1)
    return x[a:b]


def fade(x: np.ndarray, in_s: float = 0.04, out_s: float = 0.12) -> np.ndarray:
    y = x.copy()
    n_in = min(len(y), int(in_s * RATE))
    n_out = min(len(y), int(out_s * RATE))
    if n_in > 0:
        y[:n_in] *= np.linspace(0.0, 1.0, n_in)
    if n_out > 0:
        y[-n_out:] *= np.linspace(1.0, 0.0, n_out)
    return y


def process(path: str, t0, t1, max_dur: float) -> np.ndarray:
    x = load_mono(path)
    if t0 is not None or t1 is not None:
        a = 0 if t0 is None else max(0, int(t0 * RATE))
        b = len(x) if t1 is None else min(len(x), int(t1 * RATE))
        x = x[a:b]
    x = trim_silence(x)
    max_n = int(max_dur * RATE)
    if len(x) > max_n:
        x = x[:max_n]
    # passa-baixa leve: gemido longe, sem clique de osso
    x = ns.lowpass(x, 2800, 2)
    x = fade(x)
    pk = float(np.max(np.abs(x))) + 1e-12
    x = np.tanh(1.05 * x / pk) * pk * GAIN
    return x


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "refs",
        nargs="?",
        default=os.environ.get("NOM_ELEVENLABS_REFS", ""),
        help="pasta com os MP3 (elevenlabs-refs) ou env NOM_ELEVENLABS_REFS",
    )
    ap.add_argument("only", nargs="*", help="opcional: só estes NOM_*")
    args = ap.parse_args(argv)
    if not args.refs or not os.path.isdir(args.refs):
        print("informe a pasta dos MP3 (arg ou NOM_ELEVENLABS_REFS)", file=sys.stderr)
        return 2
    only = set(args.only)
    os.makedirs(OUT, exist_ok=True)
    for slot, (suffix, t0, t1) in MAP.items():
        if only and slot not in only:
            continue
        src = find_by_suffix(args.refs, suffix)
        sig = process(src, t0, t1, MAX_DUR[slot])
        dst = os.path.join(OUT, slot + ".ogg")
        level, pk, dur = ns.write(dst, sig, crest_db=CREST_DB)
        print(f"{slot}: {os.path.basename(src)} -> {dur:.2f}s  RMS {level:.1f} dBFS  pico {pk:.1f} dBFS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
