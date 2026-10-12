# Sprint 0070: gritos e almas somados

| Campo | Valor |
|---|---|
| Branch | `sprint/0070-gritos-e-almas` (sai da `staging`) |
| Origem | Johan, 2026-10-12, depois do playtest da [0069](../sprint-0069-almas-silencio/README.md): "todos os gritos, até o de ambiente, coloque como gritos das almas e vice-versa; pode duplicar, não substituir" |

## O que mudou

Só o `media/scripts/NOM_sounds.txt`; o Lua não muda.

- **Cada som de alma** (`NOM_AlmaSpawn`, `Crawl`, `Shamble`, `Group`, `Despawn`) ganhou os 10
  gritos como clips extras: Corredor 1–3, Carpideira 1–3 e ambiente 1–4.
- **Cada grito** (os mesmos 10) ganhou os 5 gemidos das almas como clips extras.
- O jogo sorteia um clip por toque, uniforme
  ([pz-api-notes §36](../../architecture/pz-api-notes.md#36-vários-clip-num-som-o-jogo-sorteia-um-por-toque-sprint-0070)).
  Na alma, 10 em 11 toques são grito; no grito, 5 em 6 são gemido.
- **Volume:** cada clip emprestado fica com o alcance e a categoria do papel, e o volume é
  compensado pela diferença de nível dos arquivos (gritos −14,3 dB de média, gemidos
  −18,3 dB): ×0,63 no grito dentro da alma, ×1,58 no gemido dentro do grito. Com isso a alma
  continua baixa e o grito continua alto. Exceção: no Corredor o volume já é 1,0, então o
  gemido fica 4 dB mais baixo que o grito dele.
- O log `[NOM] scream played ... sound=` continua mostrando o **nome** do som, não o arquivo
  sorteado.

**Voltar atrás:** apagar os clips depois do primeiro em cada um desses 15 sons.

## Roteiro no jogo

1. Reiniciar o jogo depois do `dev-sync` (o script de som só carrega na abertura).
2. Névoa vermelha: as almas, quando gemem, soam como gritos de longe e baixos.
3. Painel → Almas → "Leva de almas agora": o grupo sorteia entre o coro e os gritos.
4. Gritos da Carpideira, do Corredor e de ambiente: às vezes sai um gemido de alma, no volume
   de grito.

## Testes

`./run-tests.sh`: `test_config.lua` (`config_screams_and_almas_share_clips`; e o
`config_sound_scripts_point_to_files` agora confere o arquivo de todos os clips, não só do 1º).
