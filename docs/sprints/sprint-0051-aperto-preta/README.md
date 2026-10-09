# Sprint 0051: aperto da névoa preta

| Campo | Valor |
|-------|-------|
| Status | `em andamento` |
| Branch | `sprint/0051-aperto-preta` (saiu da `staging`) |
| Origem | §3.6 do refinamento (preta fraca demais); fila overnight item 4 |
| Plano | [plan.md](plan.md) |

## O que entra

- **Pressão sandbox `BlackFogPressure`:** 1 = Leve, 2 = Padrão (default), 3 = Pesadelo. Mexe só em piscar, hold ao sair da luz, caça do Tição, bias de velocidade e postes na preta.
- **Padrão mais apertado que a 0038/0045:** lanterna pisca mais cedo e com escuro mais longo; ao sair da luz o Tição solta mais rápido; caça periódica mais frequente; **no piscar**, um chamado de caça curto perto do jogador.
- **Postes na preta:** sorteio mais frequente e escuro mais longo — as “ilhas de luz” da rua ficam instáveis.
- **Identidade:** continua **só Tição**; sem Corredor/horda/agitação da vermelha.
- **Debug:** `NOM.blackPressure()` (botão no painel) imprime o nível e os números ativos.

## Fora desta sprint

- Obrigar reclicar a lanterna depois do apagão (decisão do Johan).
- Gastar bateria a mais.
- Transform 100% / almas / Carpideira Witch.

## Como voltar

- `BlackFogPressure = 1` (Leve) aproxima o ritmo antigo.
- Remover o módulo e os getters volta os constantes da 0038/0045 (números documentados no plan).

## Roteiro de teste no jogo

1. Staging ativo; sandbox pressão **Padrão** (2). `NOM.setBlackFog(true)`.
2. Lanterna acesa: em ~7 s reais deve piscar com mais frequência; no apagão, Tições perto avançam (caça do piscar).
3. Apague a lanterna / vire o facho: o Tição solto volta a andar mais cedo que o “meio segundo” antigo.
4. Na rua com postes: mais apagões longos — fuga entre ilhas.
5. `NOM.blackPressure()` confere o perfil. Mude sandbox pra 1 e 3 e repita o feeling.
6. Confirme: **nenhum** Estalador/Corredor/Carpideira na preta.
