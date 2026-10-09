#!/usr/bin/env python3
"""Converte refs ElevenLabs do Johan (MP3) nos oggs de grito da sprint 0048.

Fonte (não versionada no repo do jogo): pasta com os 17 MP3. Exemplos:
  NOM_ELEVENLABS_REFS=/caminho/elevenlabs-refs python3 scripts/import_elevenlabs_screams.py
  python3 scripts/import_elevenlabs_screams.py /caminho/elevenlabs-refs

Saída: mod/42/media/sound/NOM_{Corredor,Carpideira,Ambient}Scream*.ogg (mono 44,1 kHz).
Não toca NOM_EstaladorClick nem NOM_CarpideiraSob. Não copia MP3 pro repo.

Mapa estável por sufixo hex do nome ElevenLabs (ver internal/elevenlabs-sons-ii-mapa.md
no Agent Store, ou o README da pasta de refs).
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

# slot -> (sufixo hex do arquivo, t0_s opcional, t1_s opcional). None = só corta silêncio.
MAP = {
    # Corredor: sudden / fast-moving (primeiro surto) / feral
    "NOM_CorredorScream": ("7628", None, None),
    "NOM_CorredorScream2": ("760e", 0.30, 2.20),
    "NOM_CorredorScream3": ("dd7e", 0.00, 3.10),
    # Carpideira: mysterious female (forte) / mulher distante / mysterious suave
    "NOM_CarpideiraScream": ("102e", None, None),
    "NOM_CarpideiraScream2": ("93bc", None, None),
    "NOM_CarpideiraScream3": ("0912", 2.05, 4.15),
    # Ambiente: grito distante · sofrimento · choro/fraco · vários em desespero
    "NOM_AmbientScream1": ("d8f3", None, None),
    "NOM_AmbientScream2": ("15f9", None, None),
    "NOM_AmbientScream3": ("2e45", None, None),
    "NOM_AmbientScream4": ("57d8", None, None),
}

# Duração máxima após o corte (s). Eventos de jogo não precisam de 8–10 s.
MAX_DUR = {
    "NOM_CorredorScream": 2.4,
    "NOM_CorredorScream2": 2.2,
    "NOM_CorredorScream3": 3.2,
    "NOM_CarpideiraScream": 4.2,
    "NOM_CarpideiraScream2": 4.0,
    "NOM_CarpideiraScream3": 3.6,
    "NOM_AmbientScream1": 2.4,
    "NOM_AmbientScream2": 3.8,
    "NOM_AmbientScream3": 3.2,
    "NOM_AmbientScream4": 4.2,
}


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


def fade(x: np.ndarray, in_s: float = 0.012, out_s: float = 0.08) -> np.ndarray:
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
    x = fade(x)
    # leve compressão de pico pra o finalize do nom_synth não esmagar só um spike
    pk = float(np.max(np.abs(x))) + 1e-12
    x = np.tanh(1.15 * x / pk) * pk
    return x


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "refs",
        nargs="?",
        default=os.environ.get("NOM_ELEVENLABS_REFS", ""),
        help="pasta com os MP3 (ou env NOM_ELEVENLABS_REFS)",
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
        # crest um pouco maior: gritos ElevenLabs já têm dinâmica; mira ~-14 dBFS RMS
        level, pk, dur = ns.write(dst, sig, crest_db=12.5)
        print(f"{slot}: {os.path.basename(src)} -> {dur:.2f}s  RMS {level:.1f} dBFS  pico {pk:.1f} dBFS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
