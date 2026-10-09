# Plano da sprint 0051: aperto da névoa preta

> Para agentes: TDD tarefa a tarefa. Code review só no fim da entrega.

**Origem:** fila overnight item 4; `proximos-passos-refinamento.md` §3.6 (Agent Store) + identidade preta §3.9.

**Objetivo:** a preta deixa de ser “dá pra ficar ok com lanterna + vida” e vira **terror de ilhas de luz** — sem virar “vermelha escura” (sem as quatro variantes agitadas; só Tição).

## Decisões (Johan ausente — fáceis de voltar)

| Tema | Escolha |
|------|---------|
| Sandbox | `BlackFogPressure` = 1 Leve / **2 Padrão** / 3 Pesadelo |
| Padrão vs hoje | Aperto: piscar mais frequente e mais longo; `HOLD_MS` menor; caça mais cedo; caça curta no piscar |
| Reaquecer lanterna | **Não** nesta sprint (pede decisão do Johan) |
| Bateria | **Não** gastar a mais (decisão anterior mantida) |
| Velocidade | Leve/Padrão 50% rápido; Pesadelo ~75% arrastado rápido; **nunca** corredor |
| Postes | Na preta, janelas escuras mais longas e sorteio mais frequente (ilhas instáveis) |
| Transform / vermelha | Intocado |

## Arquitetura

1. **`shared/NOM_BlackPressureRules.lua`** (puro): `level(raw)`, `profile(level)`, `current()` via `NOM_Config.get("BlackFogPressure")`. Perfis com piscar, hold, caça, caça-no-piscar, bias de velocidade, poste.
2. **Consumidores** leem o perfil atual (não constantes mortas):
   - `NOM_LightRules.flicker` / `holdMs` / intervalo de check;
   - `NOM_TicaoLight` (hold, flicker check, **caça no piscar** via `NOM_Night.call`);
   - `NOM_Night.ticaoHunt` (intervalo e alcance);
   - `NOM_TicaoRules.speed` (bias);
   - `NOM_LampFlicker` + `NOM_FlickerRules.lamp` **só na preta** (chance/intervalo/escuro).
3. Sandbox + PTBR/EN; debug `NOM.blackPressure()` + botão no painel.

## Tarefas (TDD)

1. `tests/test_black_pressure_rules.lua` → `NOM_BlackPressureRules`.
2. Sandbox / config / traduções → `BlackFogPressure`.
3. Light + Tição + Night + LampFlicker leem o perfil; testes existentes e novos (caça no piscar, bias Pesadelo).
4. Debug + painel + docs (README, índice, HANDOFF curto, pz-api-notes nota).
5. `./run-tests.sh` + code review.

## Critérios de aceite

- Em Padrão, falha da lanterna é evento (escuro ≥ ~0,9 s + caça perto).
- Leve ainda jogável; Pesadelo aperta mais.
- Preta continua só Tição; sem mecânica de horda/agitação da vermelha.
- Playtest do Johan decide se falta “reaquecer” ou bateria.
