#!/usr/bin/env bash
# Testa a lógica pura do mod (sem o jogo), o contraste das texturas, o build do Workshop e a cópia de staging. Exit code 0 = tudo passou.
cd "$(dirname "$0")" || exit 1
luajit tests/run.lua && python3 tests/test_look_contrast.py && python3 tests/test_om_tiles.py && python3 tests/test_models.py && python3 tests/test_mod3_depth.py && bash tests/test_mod3_flow.sh && bash tests/test_build_workshop.sh && bash tests/test_dev_sync.sh
