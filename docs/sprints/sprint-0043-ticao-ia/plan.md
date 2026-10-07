# Sprint 0043 — Tição: teste de IA 3D e versão por script

## Objetivo

Item 3 da ordem do facelift ([spec §9](../../superpowers/specs/2026-10-06-modelo-novo-design.md#9-facelift-dos-monstros)):
uma peça 3D do Tição gerada por um modelo de IA aberto (Hunyuan3D-2 mini ou Stable Fast 3D, na RTX
4070 de 12 GB), comparada com a versão por script. A regra da spec: IA só entra com ADR nova e licença
conferida.

O que a peça conta: "brasa viva que a luz apaga". Hoje o Tição veste o véu de fumaça do Eco.

## Passos

1. **Licença primeiro.** Ler a licença dos dois modelos no Hugging Face e escrever a ADR-020 (proposta).
   Nada de IA entra no mod sem o Johan aceitar.
2. **Versão por script** (`TicaoCrosta` em `scripts/gen_models.py`), que vale como base da comparação e
   já entra no jogo:
   - crosta: a casca do Sem-rosto um pouco mais grossa (10 mm), em placas de alturas diferentes (até
     5 mm), com textura de carvão e rachaduras de brasa;
   - dois olhos de brasa saindo da frente, na altura dos olhos;
   - lascas de carvão no alto e atrás, longe do rosto;
   - três fitas de fumaça clara subindo do alto.
3. **Teste de IA** fora do repo, se der (licença, download e ambiente). O resultado e a prévia ficam
   fora do repo.
4. O Tição passa a vestir a crosta (`LOOKS.ticao` com item e gêmeo `Fx` novos, em `base:zeddmg` como as
   peças das variantes, `nohairnobeard`).

## TDD

1. `tests/test_models.py` (vale tudo da 0041–0042: formato, winding, fechado, pra fora, determinístico,
   ≤ 2500 vértices, textura espelhada, cor por parte):
   - os onze pontos da cabeça dentro da crosta com folga; a crosta perto do capacete fechado;
   - dois olhos, um de cada lado, na altura dos olhos e na frente do rosto;
   - pelo menos três fumaças, saindo do alto e subindo ≥ 6 cm acima do capacete, sem se afastar da
     cabeça;
   - pelo menos dez lascas, nenhuma no rosto;
   - cores: lasca escura, olho em brasa (laranja claro), fumaça clara sem cor.
2. `test_variant_look.lua`: o Tição veste `Base.NOM_TicaoCrosta` (e o gêmeo `Fx`).
3. `test_look_assets.lua`: 15 itens; os modelos próprios novos no caminho que o jogo monta; gêmeo `Fx`.
4. `test_look_contrast.py`: limites da textura nova (os da casca de brasa).
5. `test_credits.lua`: modelo e textura citados.
