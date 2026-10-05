#!/usr/bin/env bash
# Testa a lógica pura do mod (sem o jogo) e o build do Workshop. Exit code 0 = tudo passou.
cd "$(dirname "$0")" || exit 1
luajit tests/run.lua && bash tests/test_build_workshop.sh
