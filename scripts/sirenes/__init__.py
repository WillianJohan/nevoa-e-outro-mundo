"""Sirenes oficiais do evento de névoa (sprint 0034): a síntese de cada protótipo aprovado,
um módulo por versão (v1 a v8). Cada módulo expõe `SIRENES`: nome -> () -> (sinal mono a
44,1 kHz, crest_db). Quem encurta, põe o eco de cidade e grava é o `scripts/gen_sounds.py`.
"""
RATE_GEN = 44100
SEED_GEN = 4004  # a SEED do gen_sounds.py: os protótipos sorteavam a partir dela
