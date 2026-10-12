# Próximos passos — refinamento de produto (pós-v1.0.0)

| Campo | Valor |
|-------|-------|
| Status | **Implementação autorizada** — go Johan 2026-10-08; design P0 fechado; sprint [0047 fog clímax](sprints/sprint-0047-fog-climax/README.md) |
| Data | 2026-10-08 |
| Autor | PO/criativo (agente), a pedido do Johan |
| Escopo | Produto e direção; implementação na sprint 0047 (FOG P0). After-P0 (Sons II, almas, transform, Carpideira…) só documentado aqui |
| Âncoras | `docs/HANDOFF.md`, `docs/gdd/*`, `NOM_VariantRules.lua`, ADR-006/010/012/013/016, sprints 0024–0032 / 0034–0046 |
| Mídia | [`sprints/sprint-0047-fog-climax/ref-nevoa-pratica-baixa.png`](sprints/sprint-0047-fog-climax/ref-nevoa-pratica-baixa.png) — alvo visual da **base** P0 |

> Fonte de verdade do design P0 no **git do mod**. Trazido do Agent Store em 2026-10-08 (go do Johan).

---

## 1. Visão

**O clímax de Noise of Mist é a névoa.** Decisão do Johan (2026-10-08): **definir e fechar o design da fog antes de qualquer outra coisa** — Sons II, Estalador, Carpideira, look, preta, etc. só entram **depois**.

A névoa deixa de ser “sopa volumétrica o tempo todo” e vira um **mapa de tensão**:

| Estado | O que o jogador sente | Papel |
|--------|----------------------|--------|
| **Base (default)** | Névoa **pesada e baixa no chão** — “mar” de nuvem rente ao piso (gelo seco / vapor denso); contorna objetos por baixo; **não** engole a câmera. Ref: [vídeo t=478s](https://youtu.be/a-wtJulfhlo?t=478) + [`ref-nevoa-pratica-baixa.png`](sprints/sprint-0047-fog-climax/ref-nevoa-pratica-baixa.png) | Ritmo, identidade, jogabilidade |
| **Bolsão (clímax local)** | Fog **absurda** (a volumétrica de hoje): sobe, abraça tudo, some a visão — **exceção**, não o estado base | Pavor, set-piece, “entrei no Outro Mundo de verdade” |

Frases-guia (ordem importa):

1. **A fog é o jogo** — base navegável + bolsões que matam a visão.
2. **Ouvir / monstro / look** — vêm depois, calibrados *em cima* dessa fog.
3. **O Outro Mundo não anda como Knox** — quando a base e os bolsões existirem.

### Identidade das três cores (fechada em espírito — Johan 2026-10-08)

Toda fog = **100% monstros** (transform universal). A cor muda o **clima emocional**, não se “ainda tem zumbi Knox”.

| Cor | Fantasy | Comportamento | Áudio |
|-----|---------|---------------|--------|
| **Branca** | Outro Mundo **cotidiano** (Silent Hill): ameaça latente + **almas na rua** (§3.9.1) | Variantes 100% em ritual; **esqueléticos negros** em levas (shambler mancando + maioria crawler), **buscam o jogador** lento, TTL curto, só rua | Drone + gritos ambiente; almas **choram/gritam** (variedade); Estalador clicker; gameplay raro |
| **Vermelha** | Mundo em **agitação / caça** — o Outro Mundo te quer morto | Todos **agitados**: correr, sair correndo; ao encontrar → **gritam e vão atrás**; caos de horda | Sirene + **gritos de monstro** frequentes (Corredor/Carpideira e presença); ambiente mais perto/agresivo |
| **Preta** | Terror puro: **luz é tudo** (clímax de sobrevivência) | Só **Tição**; congelar na luz / caçar no escuro — **não** o frenesim da vermelha | Escuridão sonora, crepitar/brasa, tempestade/poste; **sem** catálogo das quatro |

Detalhe branca / esqueléticos: **§3.9–3.9.1**. Gritos monstro + ambiente: **§3.1.1** (Sons II, depois do P0 fog).

---

## 2. Onde estamos (âncora, não backlog antigo)

Já entregue ou na `staging` / `main` (resumo útil pro próximo planejamento):

| Camada | O que já existe | Limitação relevante |
|--------|-----------------|---------------------|
| Monstros | Estalador, Corredor, Sem-rosto, Carpideira, Eco, Tição; IA própria; facelift 3D (0041–0043); sonar (0037); censura TV no Sem-rosto (0044, mod3) | Carpideira hoje = **estátua** + soluço (`useless`, ADR-011); Johan quer Witch (chora, pode andar). Look das variantes: peça na cabeça + pele nua lê “toalha em cima” |
| Som | Sirenes (0034), drone, rádio, estalo do Estalador (`NOM_EstaladorClick`: ~3 “tec” secos), grito Corredor/Carpideira, soluço — `scripts/gen_sounds.py` | Gritos “blehhh”; Estalador: “tec tec tec” esparso + **uma** onda de sonar (0037); gritos ambientais da spec §5 fora da 0034 |
| Visual monstro | Pele + peça; dissolve/`m_Shader` **sem Java** (ADR-016); brasa corpo inteiro (0022); bloom no mod2 | Efeitos por monstro ainda pouco diferenciados além da peça |
| Névoa visual | Clima + overlay + mod2; **mod3** = fluido 2D (`FlowGrid`) + bancos (`FogBanks`) + altura no shader (0032); res 1–3 cél/tile; **ZB**. Qualidade/res no cliente | **Default atual = sopa que abraça tudo** (Johan rejeita como base). Falta **base baixa/fina** + **bolsões densos** (noise no mapa) |
| Preta | Escuridão, Tição, luz congela, lanterna pisca, luz empurra (mod3), tempestade (0045) | Johan: com lanterna + vida ainda “dá pra ficar ok” — falta terror puro |
| Partículas | Lascas/cinza (0035), cinza no ar vermelha (0040) | Boas; evolução “descamando / poros” é experimento |

**Regra de produto:** não inventar API. Onde a proposta depende de algo não evidenciado em `pz-api-notes` / ADR, está marcado **`[HIPÓTESE DE API]`**.

---

## 3. Problemas → hipóteses → propostas

### 3.1 Sons II — gritos (monstro + ambiente) + Estalador (clicker) rítmico

**Lembrete do Johan (2026-10-08):** os **gritos dos bichos** e os **gritos ambiente** da experiência/spec anterior **não foram feitos** — têm de voltar à lista e **não sumir** atrás do Estalador ou da fog visual. Continuam na **onda Sons II** (depois do P0 fog): (1) gritos de monstro com terror de verdade; (2) gritos ambiente distantes; (3) Estalador clicker + névoa em pulsos. Som e sonar do Estalador já são o mesmo evento (sprint 0037).

#### 3.1.1 Gritos — monstro **e** ambiente (obrigatório na onda)

**Problema.** (a) Corredor/Carpideira soam sintéticos (“blehhh”); (b) **gritos ambiente** da spec §5 / experiência anterior **nunca entraram** — a névoa fica muda demais fora do evento de gameplay.

**Hipótese.** Timbre + espaço (ar, corpo, distância, imperfeição humana). Ambiente = presença do Outro Mundo **sem** virar horda; monstro = gatilho de gameplay + assinatura por tipo. Intensidade **por cor** (§3.9): branca = ambiente raro/longe; vermelha = monstro frequente + ambiente mais perto.

**Propostas:**

1. Biblioteca nova 100% em `gen_sounds.py` / `nom_synth.py` (nada de sample de terceiros). Escuta do Johan **antes** de merge, como nas sirenes da 0034.
2. **Corredor (grito de monstro):** menos “serra aguda”, mais *raspagem + ar + eco curto de rua*; antecipação; 3–5 variantes; na **vermelha** dispara caça/horda com mais frequência (agitação).
3. **Carpideira (grito de monstro):** lamento que *desafina e falha*; um grito por névoa (regra atual); na vermelha o acordar/caça lê como caos.
4. **Carpideira (soluço):** calibração fina; na **branca** é a assinatura de presença (Witch quieta).
5. **Gritos ambiente (spec §5 — repor na lista):** “gritos de gente” distantes, intervalo ~1–3 min reais, **só cliente**, **sem** chamar horda / sem comando de servidor. Branca = mais rarefeitos; vermelha = um pouco mais próximos ou frequentes; preta = opcional (gemido/eco fraco) ou silêncio — não competir com Tição.
6. **Mix:** monstro perto/seco; ambiente longe/passa-baixa; nunca mascarar sirene/drone.

**Checklist da onda Sons II (gritos — não esquecer):**

- [ ] **Gritos de monstro (timbre):** Corredor + Carpideira novos; 3 escutas cegas sem “tosco”.
- [ ] **Gritos de monstro (gameplay):** Corredor ainda inicia horda; Carpideira ainda um grito por névoa; na vermelha a frequência/urgência lê **agitação**.
- [ ] **Gritos ambiente:** pelo menos um banco de clips + agenda 1–3 min; só cliente; **zero** horda; audível na branca e na vermelha.
- [ ] **Choro/grito das almas (branca, §3.9.1):** variedade própria; **não** chama horda; mix “fantasma”, distinto de Corredor/Carpideira.
- [ ] **Por cor:** branca = ambiente + almas > monstro gameplay; vermelha = monstro ≥ ambiente; preta = não virar wall of screams.
- [ ] Escuta A/B do Johan **antes** de merge (como 0034).

#### 3.1.2 Estalador — clicker rítmico + névoa em pulsos

**Problema (Johan, 2026-10-08).** Hoje o Estalador faz “tec tec tec” e o sonar da 0037 gera **só uma onda** grande na névoa. Quer: cliques **mais seguidos / rápidos**, quase um **rosnado rítmico** — ainda claramente **instalador / clicker** (TLOU-inspired, não cópia), **sem** virar latido, rosnado de cachorro nem animal. A névoa deve **reagir no ritmo**: **pequenas ondas** acompanhando cada clique (ou cada batida do fraseado), não um único anel isolado.

**Hipótese.** Identidade clicker = *cliques secos de língua/mandíbula em série rápida com micro-variação de timing e intensidade* (acelerando/desacelerando como quem “lê” o espaço), não tom contínuo de garganta animal. A névoa “respeita” o ouvido: cada batida empurra um pouco de volume (mod3) ou desenha um anel curto no chão (sem mod3).

**Propostas concretas (ancoradas na 0037):**

1. **Som (`NOM_EstaladorClick` / variantes):** trocar o fraseado atual (~3 estalos em ~0,5 s, esparsos a cada 5–30 s) por um **burst rítmico**: vários cliques rápidos (alvo de playtest: ~6–12 batidas em ~1–2 s), com intervalo interno curto e irregular (humano/monstro, não metrônomo), último um pouco mais forte. Continua gerado em `gen_sounds.py`. Escuta A/B do Johan com regra explícita: se parecer cachorro → rejeitar.
2. **Agenda do burst:** manter o intervalo *entre* bursts no espírito atual (sorteio por Estalador, ordem de grandeza 5–30 s reais) — o que muda é a *textura dentro* do burst, não spam contínuo 24/7. Ajuste fino no playtest.
3. **Névoa reage no ritmo:**
   - **Com mod3:** em vez de um `NOMRender_sonar` / anel único de 8 tiles, **N frentes pequenas** (raio curto por batida, ex. 2–4 tiles cada, ou ripples encadeados que somam presença) sincronizadas aos cliques do burst. Reusar `Sonar.java` / `FlowGrid.sonar` com impulsos menores e mais frequentes — **não** reinventar fluido.
   - **Sem mod3:** `NOM_SonarFx` desenha **vários anéis discretos** curtos no chão, um por batida (alfa menor), em vez de um elipse única até 8 tiles.
4. **Gameplay do “acha” (recomendação do PO — Johan confirma §7):** o burst inteiro continua **um evento de sonar** para regra de achado (em pé/andando, casa protege, janela anti-recegueira), como hoje. As ondas pequenas são **feedback de presença**; o *find* não dispara N vezes por clique (evita injustiça e flood no MP). Alternativa se o Johan quiser mais perigo: cada ripple curto com raio menor também pode achar — só com playtest.
5. **Assinatura ZB-free (liga com §3.3):** overlay/mod2 pode dar um *tick* de distorção por batida perto do jogador — o ritmo se sente mesmo sem volume.

**Critérios de sucesso jogáveis (Estalador):**

- [ ] **Ritmo:** de olhos fechados, o burst soa como série rápida de cliques (quase rosnado rítmico), não três “tec” isolados nem latido.
- [ ] **Identidade clicker:** na escuta do Johan, marca “instalador/clicker” — **nunca** “cachorro / animal / besta latindo”.
- [ ] **Ondas sync:** na névoa, vê-se **várias ondulações pequenas** no tempo dos cliques (mod3: empurrões curtos; sem mod3: anéis curtos no chão) — não uma onda única.
- [ ] **Regra intacta:** agachado e parado ainda passa; casa ainda protege; MP: mesmo burst/anel pra todos (servidor decide, como 0037).
- [ ] **Custo:** com vários Estaladores na cidade, FPS e teto de anéis vivos continuam jogáveis (revisar cap da 0037 se N ripples por burst).

---

### 3.2 Carpideira — Witch (chora / anda) + look penitente

Pedido do Johan (2026-10-08, duas mensagens): (1) não gosta do estado atual da Carpideira — quer tensão tipo **Witch do L4D** (inspirada, não copiada): **chorando**, podendo ficar **parada ou andando** enquanto lamenta; (2) **roupa diferente** — monstras com roupa “muito feia”; busca **penitente / roupa estrupiada** que leia **criatura**, não “zumbi com toalha em cima”.

#### 3.2.1 Comportamento (Witch do Outro Mundo)

**Problema.** Hoje ela é **estátua**: calma = `useless` no dono (ADR-011), soluço baixo (~12 tiles), acorda a 4 tiles / lanterna / tiro, um grito por névoa, depois caça. Funciona como armadilha, mas **não tem presença de lamento vivo** — parece prop, não ameaça que *habita* a névoa.

**Hipótese.** A Witch assusta porque o jogador **gerencia a aproximação**: ouve o choro, vê o corpo mover-se sem “caçar”, sente o volume subir, e decide se contorna ou arrisca. Parada total mata essa leitura; perseguir antes do grito também (vira Corredor).

**Propostas concretas (APIs já usadas no mod — sem inventar):**

1. **Calma = lamento, não estátua.** Mantém os gatilhos de acordar (raio 4 mesmo agachado, lanterna, barulho alto) e o **um grito por névoa**. O que muda é o *estado calmo*.
2. **Andar chorando:** em intervalos (ex. a cada 20–60 s reais), a Carpideira calma faz um **deslocamento curto** (2–6 tiles) para um ponto aleatório perto, **sem** ir na direção do jogador — mesmo espírito do `NOM_Wander` / `pathToLocationF` (0036), só dela. Entre caminhadas, fica parada soluçando.  
   - Técnica: hoje calma = `useless` o tempo todo. Andar exige **soltar useless só na caminhada** e reaplicar ao parar (padrão já conhecido: sirene/Tição/Carpideira ligam e desligam useless). Caminhada em andamento não deve virar caça (`setTarget` continua nil até o grito). Evidência: ADR-011 / pz-api-notes §3.2 / §13.
3. **Tensão na aproximação (sem API nova de “startle”):**
   - **Áudio:** volume/ritmo do soluço sobe com a distância (mesma curva de proximidade do rádio do Sem-rosto / crepitar da spec §5) — perto, o choro *enche* a cabeça; longe, é presença na névoa.
   - **Visual ZB-free (§3.3):** escurecimento das bordas / vinheta no soluço perto (já esboçado); no grito, pulso vermelho atual.
   - **Não acordar por olhar** (diferente da Witch L4D literal): o mod já acordou por **proximo / luz / tiro** — manter; olhar sem luz não acorda (isometria + Sem-rosto já usam “visto”). Evita briga de regras.
4. **Sons II (§3.1.1):** o soluço/choro deixa de ser “loop de fundo fraco” e vira **lamento contínuo legível** (variantes de fraseado); o grito de acordar continua o evento único de horda.
5. **MP:** servidor decide caminhada e acordar (como hoje); clientes ouvem o choro local. Mesma Carpideira não grita duas vezes na névoa.

**Critérios de sucesso jogáveis (comportamento):**

- [ ] De longe: ouve-se **choro/lamento**, não silêncio com monstro parado “morto”.
- [ ] Em 1–2 min na névoa: vê-se ela **andar pelo menos uma vez** chorando, sem virar na direção do jogador.
- [ ] Aproximar / lanterna / tiro ainda acordam; agachar **não** protege no raio (regra atual).
- [ ] Depois do grito: caça quem acordou; um grito por névoa; sem flood de horda.
- [ ] Sensação: “preciso **contornar** essa coisa” — não “é um poste que grita”.

#### 3.2.2 Look — penitente / criatura (Carpideira + monstras)

**Problema.** Com a 0016 a roupa vanilla some; ficam pele + peça de cabeça (mechas, véu, etc.). No zoom isométrico isso lê **“zumbi nu com toalha/cabelo em cima”** — Johan: monstras com roupa **muito feia**; quer **penitente / estrupiada**, silhueta de **criatura**.

**Hipótese.** Falta **volume de corpo** (traje rasgado, manto, cilício visual), não só face. O caminho certo já existe: itens de roupa do mod (ADR-012/016), texturas/`gen_models.py`, malha vanilla **citada por nome** (nunca arquivo do jogo no repo). Lista `KEEP` da 0016 estava reservada a “saia estranha”; aqui o traje é **peça do mod**, não keep de outfit vanilla aleatório.

**Propostas:**

1. **Carpideira primeiro (hero look):** item(s) de corpo do mod — manto/penitente rasgado, tecido escuro sujo de fuligem, volume que muda a silhueta; mechas 3D da 0042 ficam; pele pálida+fuligem ficam. Direção: *luto que virou praga*, não noiva, não Witch L4D copiada, não freira de SH.
2. **Monstras em geral:** mesma linguagem “roupa estrupiada / criatura” na relistagem (§3.3) — prioridade Carpideira; depois Estalador/Corredor/Sem-rosto se o Johan confirmar que o “feio” é de todas, não só dela. Eco/Tição já têm casca/véu próprios.
3. **Pipeline:** `scripts/gen_textures.py` + `gen_models.py` (ou malha vanilla por nome + textura nossa); gêmeo `*Fx` com `m_Shader` se entrar no dissolve. **Proibido:** copiar mesh/textura de outro mod ou do jogo para o repo — só referência por nome + arte gerada.
4. **Encaixe com ondas:** isto é **os dois**: (a) parte da **relistagem visual** dos monstros; (b) **onda de look** dentro da C ampliada (§4) — não só shader de tela. Efeitos ZB-free (vinheta no choro) completam; **não substituem** a roupa.

**Critérios de sucesso jogáveis (look):**

- [ ] A 20–40 tiles / zoom normal: lê **criatura de luto**, não “zumbi com pano na cabeça”.
- [ ] Contraste sob névoa (teste 0014 / preview 64 px) ainda passa.
- [ ] Fim da variante: roupa comum do zumbi volta; loot inalterado.
- [ ] Sem asset de terceiro no repo; Workshop limpo.

**Riscos (IA / áudio / outfit):**

| Risco | Mitigação |
|-------|-----------|
| Soltar `useless` pra andar → ela reage a som/caça cedo demais | Caminhada sem `setTarget`; re-`useless` ao parar; testes ADR-011 |
| Caminhada herdada atravessa o grito / posse MP | Servidor manda “walk to” como wander; dono aplica; IDs como sonar |
| Choro alto demais = spam / localizar fácil demais | Curva por distância; Opções > Mods intensidade; sandbox raio do soluço se precisar |
| Malha vanilla “vestido” + nossa textura ainda lê toalha | Volume 3D (gen_models) na Carpideira; A/B no jogo |
| Outfit/`KEEP` quebrar sorteio ADR-006 | **Não** trocar `persistentOutfitID`; só `ItemVisual` do mod (ADR-012) |
| “Penitente” soar cópia de outro horror | Briefing de arte: fuligem NOM, sem cruz/ícone de franquia |

---

### 3.3 Roupa + shader em cima — efeitos por monstro **sem ZombieBuddy** (+ look)

**Problema.** Queremos fogo, névoa escura, blur etc. *no monstro*, e isso tem de funcionar sem o javaagent (a maioria do Workshop joga só o mod principal ± Shader). **Emenda Johan:** a “roupa” não é só efeito — a silhueta base das monstras precisa de **traje criatura** (§3.2.2).

**O que já está provado (não é hipótese):**

| Caminho | Precisa ZB? | Evidência |
|---------|-------------|-----------|
| Peça de roupa com `<m_Shader>` + canal `Alpha` | Não | ADR-016, dissolve / brasa |
| Overlay de tela (Lua) | Não | ADR-013 |
| `screen.frag` do mod2 | Não (incompatível com ShadowZ) | ADR-013 |
| Passe por cabeça / névoa fluida / censura | Sim (mod3) | HANDOFF, 0044 |

**Hipótese.** Dá pra construir uma *linguagem visual por monstro* empilhando: **traje/peça de corpo** (look) + peça 3D + shader de peça + overlay/shader de tela — mod3 como *upgrade*.

**Relistagem — estilo + efeito desejado**

| Monstro | Função no jogo | Estilo visual (já / desejado) | Efeito “em cima” sem ZB (proposta) | Upgrade com mod3 (opcional) |
|---------|----------------|------------------------------|------------------------------------|-----------------------------|
| **Estalador** | Cego; som; sonar | Venda+arame 3D, pele porcelana; (+ volume de corpo se “monstras todas”) | **Tick de distorção no ritmo do burst** (overlay/mod2) | **Pequenas ondas no ritmo** (§3.1.2) |
| **Corredor** | Sprint + grito = horda | Boca 3D rasgada; (+ traje rasgado se look geral) | **Vinheta / aberração no grito** + tremor leve no overlay | — |
| **Sem-rosto** | Sumir / chiado | Casca TV; censura no mod3 | **Linhas de chiado** + “rosto que não foca” | Censura mosaico (0044) |
| **Carpideira** | Lamento → grito → caça (**Witch**, §3.2) | Mechas 3D + **manto penitente estrupiado** (criatura, não toalha) | **Vinheta que respira com o choro** (proximo); pulso vermelho no grito | — |
| **Eco** | Alma fraca à noite | Cinza + véu; dissolve morte | Opcional fumaça no shader da peça | — |
| **Tição** | Luz congela; caça no escuro | Crosta carvão 3D / brasa | **Brasa viva** + faíscas (`NOM_Embers`) | Luz empurrando névoa preta |
| **Zumbi comum na névoa** | Visão curta + perambular | Visual vanilla | Sem efeito de monstro | — |

**Proposta de sprint “Look + efeitos ZB-free” (onda C ampliada):**

1. Inventário fechado (tabela) aprovado pelo Johan — **Carpideira penitente é o piloto**.
2. Spike look: um traje de corpo Carpideira no jogo (silhueta) **antes** de espalhar pras outras.
3. Spike efeito: um efeito novo só na peça (`m_Shader`) **ou** só no overlay — FPS / 64 px.
4. Um efeito assinatura por monstro da névoa + traje onde o look exigir.
5. Fallback: sem mod2 = overlay; efeitos desligados = som/IA/look de peça ainda valem.

**`[HIPÓTESE DE API]`** — blur *só na silhueta do monstro* sem mod3: **não prometido**. Caminho seguro = tela suave ou malha da peça.

**Critério de sucesso.** Mod principal só: cada monstro da névoa tem *um* sinal visual além da cabeça; Carpideira lê criatura a distância; desligável nas Opções > Mods (efeitos). ShadowZ: overlay + look de peça.

---

### 3.4 Clímax da fog — base baixa/fina + bolsões densos (**prioridade zero**)

**Decisão do Johan (2026-10-08).** Isto é o **clímax do jogo**. Fecha **antes** de Sons II, Estalador, Carpideira, look, preta, etc. Pode (e deve) ser **sprint própria**.

#### 3.4.0 Problema → hipótese

**Problema.** A fog volumétrica de hoje (mod3: rolos altos, véu, densidade que abraça jogador / casa / muro) **funciona como espetáculo**, mas como *default* atrapalha andar, ver e jogar. O Johan não quer isso como estado base.

**Hipótese.** Dois regimes no **mesmo evento de névoa**:

1. **Campo base** — névoa **pesada e baixa no chão** (look de gelo seco / vapor denso): “mar” opaco no miolo, fiapos nas bordas, cascata nas arestas; abraça/contorna o **pé** dos objetos; **não** sobe e engole a câmera. (Johan: ref prática — §3.4.3a.)
2. **Bolsões** — regiões onde densidade/altura sobe ao absurdo atual (abraça tudo, some a visão). Forma orgânica (noise / Perlin); **movimento = viajantes** (**fechado Johan, 2026-10-08**): derivam com vento/`FogBanks` (espírito 0026), **não** âncoras fixas no mapa.

Equilíbrio: cidade **jogável** com mar baixo; de vez em quando um bolsão **passa por você** (ou você entra nele) e o clímax acontece — e depois segue embora.

> **Nota de linguagem:** “fina” no plano antigo = **baixa/rala na altura do peito** (não engole a câmera), **não** = névoa transparente/leve. A ref visual exige **densidade opaca no chão** + **perfil de altura baixo**.

#### 3.4.1 Âncoras técnicas (sem inventar API)

| Peça | Já existe | Como serve ao design |
|------|-----------|----------------------|
| Evento de névoa + clima | ADR-009, `NOM_FogEvent` | Continua o *quando* da névoa |
| Fluido 2D + shader de volume | mod3 `FlowGrid`, `NOM_VolFog` (ZB) | Onde se baixa a **altura/densidade base** e se sobe nos bolsões |
| Bancos / vento | `FogBanks`, sprint 0026 | **Bolsões viajantes** (fechado): reusar/estender bancos+vento pra carregar os bolsões densos |
| Altura / obstáculos | sprint 0032, param 2 | Base = **perfil baixo** (mar no piso, ~tornozelo/joelho visual); bolsão = altura absurda atual |
| Véu de fundo | param 7 (0028) | Base: véu **fraco/quase off** (senão vira sopa no ar); bolsão: véu+rolos fortes |
| Densidade forçada | param 0 | Debug / calibração A/B; na base a densidade no **chão** pode ser alta — o que baixa é a *altura* |
| Resolução da grade | param 9, 1–3 cél/tile (0030), Opções > Mods | Ondulações melhores **dentro** desta sprint de fog (apoio, não sprint separada) |
| Sem mod3 | clima + overlay | Precisa de **fallback legível**: base = vinheta/clima **baixa** (presença no chão, não sopa); bolsão ≈ overlay+vinheta mais fortes — sem fingir mar/cascata de volume |

**`[HIPÓTESE]`** — campo de densidade espacial (Perlin/noise em world XZ) amostrado no fluido/shader: caminho natural (ruído já aparece em Wind/`uDrift`), mas **forma exata** (CPU na grade vs uniform/texture no shader vs bancos densos) = spike da sprint de fog, com evidência antes de prometer MP idêntico.

#### 3.4.2 Escopo da sprint de produto/fog (só isto)

**Dentro:**

1. **Defaults novos (recomendados pós-ref visual):** base = **altura baixa + densidade alta no chão** (mar opaco rente ao piso; não engole câmera). Véu de fundo **baixo**. Documentar números-alvo (altura em “andares”, densidade no piso, véu) depois do A/B in-game mirando a foto/vídeo.
2. **Bolsões densos viajantes:** campo de noise + **deriva com vento/bancos** (não estáticos); seed mundo/período (ADR-006/0033) pra MP concordar *onde* o bolsão está a cada instante; tamanho, frequência, intensidade e velocidade no **sandbox**.
3. **Parametrização clara:**

| Eixo | Onde | Quem manda | Exemplos |
|------|------|------------|----------|
| **Regra do mundo** (base baixa vs bolsão viajante) | **Sandbox** | Servidor | **Altura** da base; **densidade no chão** da base; chance/tamanho/intensidade/**velocidade** dos bolsões; desligar bolsões |
| **FPS / fidelidade** | **Opções > Mods** | Cliente | `FogQuality`, **resolução da grade** (`flowResolution` / param 9) |
| **`FogThickness` (plano antigo)** | Reinterpretar | Servidor | **Não** = “engrossar tudo até sopa”. Preferir eixos separados: **altura da base** + **densidade no piso** + **agressividade dos bolsões** (nomes finais na sprint) |

4. **Pipeline técnico:** ver §3.4.4 (caminhos A/B/C). A sprint **entrega o produto** (base + bolsões) pelo caminho recomendado; multi-camada 3D só se o spike mandar. **Alvo visual da base = §3.4.3a.**
5. **Resolução da grade / ondulações:** alavanca de **cliente** calibrada junto — ondulações no *topo* do mar baixo (fiapos/cascata) pedem res ≥2; não sprint separada de mesh.
6. **Roteiro A/B no jogo:** mesma rua, base só (bater foto/vídeo vs ref) → base + bolsão → (opcional) “modo antigo absurdo” via debug.
7. **Presets Leve / Pesadelo:** Leve = mar mais baixo + bolsões **raros**, menores, mais lentos; Pesadelo = mar um pouco mais alto + bolsões **maiores/mais densos**, ainda preferencialmente **raros e brutais** (viajantes castigam mais se forem comuns) — **nunca** sopa 100% do mapa no ar.

**Fora desta sprint (explícito):** Sons II, Estalador rítmico, Carpideira Witch/look, **transform universal (§3.9)**, aperto da preta, partículas, rastejante. **Sim 3D GPU cheia** (N andares / textura 3D completa) só se o spike §3.4.4 **adotar B** — senão fica later. A sprint fog **respeita** o fantasy “na névoa é monstro” nos roteiros, mas **não implementa** a regra de transform.

#### 3.4.3 Critérios de sucesso jogáveis (fog)

- [ ] **Base:** fog **não engole a câmera** o tempo todo; fachada/rosto do jogador legíveis; lê-se **mar baixo no chão**.
- [ ] **Bolsão:** ao entrar (ou ser alcançado), visão some / volume abraça; ao sair / ele passar, volta a base — contraste &lt; 5 s.
- [ ] **Viajante:** em 1–2 min na névoa, vê-se bolsão **se mover** (aproximar/afastar); não é mancha fixa no mesmo tile.
- [ ] **Mapa:** poucos bolsões vivos (raros); não cobrem 100% do chunk o tempo todo.
- [ ] **MP:** *onde* está denso é igual pra todos (sandbox); qualidade/res por cliente.
- [ ] **Sem ZB/mod3:** ainda há base vs “zona pior” (clima/overlay).
- [ ] **FPS:** jogável no `scale` padrão; cliente pode baixar res/qualidade.

#### 3.4.3a Critério de sucesso **visual** da base (ref Johan, 2026-10-08)

**Referências (alvo da base — não do bolsão):**

| Tipo | Link |
|------|------|
| Vídeo (efeito prático, t=478s) | [youtu.be/a-wtJulfhlo?t=478](https://youtu.be/a-wtJulfhlo?t=478) |
| Foto (repo) | [`sprints/sprint-0047-fog-climax/ref-nevoa-pratica-baixa.png`](sprints/sprint-0047-fog-climax/ref-nevoa-pratica-baixa.png) |

**Checklist visual (print/clipla do jogo vs ref):**

- [ ] **Mar no piso:** camada densa, tipo gelo seco / vapor pesado, **rente ao chão** — não névoa de ar cheio.
- [ ] **Altura:** objetos altos (poste, muro, personagem) **furam** o mar; a câmera isométrica **não** fica dentro de sopa o tempo todo.
- [ ] **Contorno:** névoa **abraça/contorna por baixo** a base dos objetos (cascata nas bordas de mesa/degrau no ref = fluido “pesado”).
- [ ] **Miolo vs borda:** miolo **opaco**; bordas em **fiapos** / tendrils (não disco duro cortado).
- [ ] **Topo do mar:** ondulação suave (nuvem vista de cima), não placa flat.
- [ ] **Bolsão ≠ base:** o look absurdo atual (sobe, abraça câmera) fica **só** no bolsão — contraste imediato ao sair.

#### 3.4.4 Caminhos técnicos + pesquisa GPU (ideia “mesh → textura de tela”)

Notas longas da web (quando existirem no Agent Store): pesquisa GPU PZ fog — o veredito útil está resumido nesta seção.

**O que o mod3/ZB já faz (fato — e responde boa parte da ideia nova):**

| Passo | Implementação NOM | Ideia do Johan |
|-------|-------------------|----------------|
| Hook no fim do mundo | `@Patch` `Core.EndFrame` → `GenericDrawer` **antes** do `screen.frag` (HANDOFF) | “camada de reconstrução” no pipeline |
| Ler a cena na GPU | Blit da **profundidade** (e, na censura, da **cor**) pra textura nossa | “amostrar o framebuffer” |
| Desenhar volume | `NOM_VolFog`: raymarch com depth + densidade do fluido → **fullscreen** | “reconstrói na tela via shader” (como material/normal map) |
| Simulação | Ainda **2D CPU** (`FlowGrid` 20 Hz); altura = **perfil no shader**, não voxels | Ele **não** pediu fluido 3D completo na CPU — pediu render/reconstrução GPU |

**Pesquisa web 2024–2026 (resumo):** no PZ, GPU/custom shader existe de três jeitos públicos — (1) **trocar** `media/shaders/*` ([ShaderZ](https://steamcommunity.com/sharedfiles/filedetails/?id=3419026942), TreeZ); (2) **Java agent** ([ZombieBuddy](https://steamcommunity.com/workshop/filedetails/?id=3619862853) / [GitHub](https://github.com/zed-0xff/ZombieBuddy), [ShadowZ](https://steamcommunity.com/sharedfiles/filedetails/?id=3800671550) standalone ou ZB, Peek a View); (3) API `ShaderProgram` ([docs oficiais](https://projectzomboid.com/modding/zombie/core/opengl/ShaderProgram.html)). Pós-processo clássico = FBO → textura → quad ([LearnOpenGL](https://learnopengl.com/Advanced-OpenGL/Framebuffers)). **Nada** na net descreve “mesh 3D de névoa PZ → normal map” como API vanilla; o padrão é o que o NOM/ShadowZ já exploram. ShadowZ avisa conflito com quem troca `screen.frag` (nosso mod2).

**Ideias do Johan (duas, mesmo tema):**

1. Camadas (chão + alto) — § anterior.
2. **B' (esta emenda):** volume/“mesh” na **GPU** → **reconstrói** como textura/camada fullscreen no shader (não necessariamente sim fluid 3D completa na CPU).

| Caminho | O que é | Facilidade | Base + bolsão? | Status |
|---------|---------|------------|----------------|--------|
| **A** | Defaults baixos + bolsões **noise** + params existentes | Mais fácil | Sim (produto) | Extensão natural; noise = **`[HIPÓTESE]`** de plug |
| **B** | Sim **3D** multi-camada / textura 3D (GPU Gems; pesquisa NOM §2; HANDOFF 0025) | Mais difícil | Sim se fechar | Spike **grande**; não começar aqui |
| **B'** | Refino do pass GPU **já existente**: RT intermediário de fog e/ou 2+ texturas de densidade (chão/alto) amostradas no raymarch; composição fullscreen — **sem** fluido 3D CPU | Médio-baixo (mesmo hook EndFrame/blit) | Sim; melhora “camadas” | **Extensão natural do mod3**; **`[HIPÓTESE]`** só no custo do FBO extra / ordem GL |
| **C** | **A** + spike **C-lite** (2 perfis no `fogLook`) + opcional **B'** se C-lite precisar de RT | Produto primeiro | Sim | Ordem adotada (abaixo) |

**Veredito pra ideia “GPU → textura de tela → shader”:**  
**Viável e alinhada ao que já fazemos** — não é atalho mágico nem API nova do jogo. É **nomear/refinar o pass do mod3** (B'). **Não** substitui A (base + bolsões). **Não** exige B (sim 3D). Continua **ZB/mod3** pro volume; sem ZB = clima/overlay.

**Decisão fechada (Johan, 2026-10-08) — “vamos tentar assim”:**

Ordem oficial da sprint fog: **A → C-lite → B'? → B** (produto **A-first**; **B** só se A+C-lite+B' falharem).

**Como cada passo mira o look da ref (§3.4.3a):**

| Passo | O que faz pro look “mar baixo” | Defaults / alavanca |
|-------|--------------------------------|---------------------|
| **A** | Baixa **altura da camada** (param 2) + sobe **densidade no chão** onde o fluido tem massa; véu (param 7) fraco; bolsões = height/density absurdo local (noise). Entrega o produto mesmo sem camadas extras. | Default base: altura bem abaixo do atual (~&lt; 0,5–0,8 andar — calibrar no A/B vs foto); densidade no piso **alta** o bastante pra opacidade no miolo; véu ~0–0,3. **Não** baixar densidade global até “névoa transparente”. |
| **C-lite** | Dois perfis no `fogLook`: **chão** (denso, corta alto) + **alto** (quase zero na base; só no bolsão). Reforça cascata/fiapos sem sopa no ar. | Adotar se A sozinho ainda “enche” o peito/câmera ou falta contraste chão vs ar. |
| **B'** | RT/composite se precisar separar mar do piso vs véu/bolsão com menos artefato. | Só se C-lite pedir. |
| **B** | Fluido 3D de verdade. | Só se ainda falhar “passar por cima do muro” / física 3D. |

1. **A** — base baixa+densa no chão + bolsões; sandbox/cliente — §3.4.3 + §3.4.3a.
2. **C-lite** — dois perfis chão/alto no shader atual (**reforçado** pela ref: perfil baixo é o núcleo do look).
3. **B'** — só se C-lite pedir buffer intermediário / camadas mais limpas (mesmo sprint, spike curto medindo FPS).
4. **B** — só se ainda falhar “passar por cima do muro” / física 3D de verdade.

**Critérios adotar/matar:**

| | Adotar | Matar |
|---|--------|-------|
| **A** | Print bate §3.4.3a (mar no piso, câmera livre); bolsão contraste ok | Densidade baixou e virou “névoa transparente”; ou altura ainda engole câmera |
| **C-lite** | Base no chão óbvia vs ar limpo; bolsão sobe sem sopa global; FPS ok; fiapos/cascata melhores que A só | Sem ganho vs baixar `layer` / densificar piso |
| **B'** | Composição mais estável / camadas legíveis; ms extras aceitáveis | FBO bagunça estado GL do PZ; ou A+C-lite bastam |
| **B** | Johan ainda exige física 3D de verdade pós A+C'+B'; spike com qualidade L/M/H | Estoura GPU; clímax já fechou |

**Veredito PO (ref visual):** a foto/vídeo **reforçam A e C-lite** — o núcleo é **perfil de altura baixo + densidade no chão**, não sim 3D. B'/B continuam contingência.

**Riscos:** ZB obrigatório pro volume; conflito ShadowZ↔mod2 intacto; mexer FBO no meio do frame (pesquisa NOM já alerta); sem ZB só fallback flat.

---


### 3.5 Novos monstros estilo Silent Hill / ILL (rastejando, 4 patas)

**Relação com §3.9.1:** as **almas esqueléticas da branca** (efêmeras, rua, FX negro) são a *primeira* fatia jogável de “rastejar no chão” — assinatura de cor, não monstro novo permanente. Este §3.5 continua sendo o spike de **criatura** (talvez vermelha/preta / 4 patas). Spike de crawler/`setSkeleton` pode servir aos dois.

**Problema.** Queremos presença que não é “zumbi em pé com máscara” — rastejar, quatro patas, corpo errado. ILL ainda não lançou; B42 pode ganhar animais.

**Realidade do GDD hoje.** Overview marca *criaturas com esqueleto e animação próprios* e *modelos 3D próprios de corpo inteiro* como **`later`**, só por promoção explícita. Monstro atual = zumbi + outfit/peça + Lua (ADR-001/012).

**Hipótese de produto (três caminhos, recomendação no fim):**

| Caminho | O que é | Dependência | Risco |
|---------|---------|-------------|-------|
| **A. Variante “baixa” no zumbi** | Mesmo esqueleto; peça/crouch visual; IA que *só* se move agachada / lenta / pelo chão (path + `setUseless` patterns) | APIs de movimento já usadas | Continua silhueta humana; “rastejar” é *comportamento*, não malha |
| **B. Animal vanilla como casca** | Outfit/IA em criatura animal do jogo | **`[HIPÓTESE DE API]`** B42 animais: spawn, ModData, path, som, MP | Pode não existir ou mudar; spike obrigatório |
| **C. Modelo/animação próprios** | Corpo novo | Pipeline 3D + evidência de animação no B42 | Escopo grande; conflito com “nada copiado”; Workshop/licença |

**Proposta criativa (sem lançar monstro ainda):**

1. **Spike de produto “Rastejante” (só pesquisa + 1 protótipo visual/IA no zumbi — caminho A)** antes de qualquer ILL/animal.
   - Nome de trabalho: **Arrasto** (ou **Ventre**): só na vermelha ou preta; fica *baixo* (agachado permanente se a API permitir — **`[HIPÓTESE]`**); quase não é visto de frente na névoa; ataca perto; som = arrastar de carne/pano, não grito.
   - Se o spike falhar (não dá pra forçar pose), o monstro vira **presença sonora + peça no chão** (anexo Outro Mundo) sem entity — horror ambiental, não combatente.
2. **Animais:** item de backlog explícito “aguardar evidência B42 / patch notes”; **não** desenhar sprint de conteúdo em cima.
3. **ILL:** inspiração de *tom* (corpo errado, proximidade íntima), **zero** cópia de criatura ou asset.

**Critério de sucesso do spike.** Em 1 sessão: “isso não parece um zumbi andando na minha direção” — mesmo que ainda seja `IsoZombie` por baixo.

---

### 3.6 Névoa preta fraca demais (lanterna + vida = ok)

**Papel na tríade (§3.9):** preta = clímax de **luz/escuridão**, não de horda. Não herdar a “agitação” da vermelha.

**Problema.** A regra central (“luz é tudo”) está clara, mas o loop atual permite *tankar* com lanterna e HP: congelar, andar, piscar é só susto.

**Hipótese.** Falta **custo da luz** e **pressão quando a luz falha** — não falta mais HP no Tição.

**Propostas (alavancas já no código / regras documentadas):**

| Alavanca | Onde hoje | Aperto sugerido (playtest) |
|----------|-----------|----------------------------|
| Piscar da lanterna | `NOM_LightRules` — longo de propósito (0,7–1,6 s) | Mais frequente **ou** apagão em sequência; às vezes exige **reaquecer** (jogador reclica) — decisão de Johan |
| Caça do Tição | 20 min / 40 tiles | Mais perto do jogador em Pesadelo; “ondas” de caça quando a lanterna pisca |
| Velocidade | Metade arrastado / arrastado rápido | Em Pesadelo: mais arrastado rápido; **nunca** corredor (mantém identidade) |
| Farol / poste | 0039 congela com luz fixa | Casas com luz viram **ilhas** — ok; fora delas, a rua é morte. Reforçar: **tempestade apaga poste** (0045 já pisca) com janelas longas o bastante pra o Tição fechar distância |
| Recursos | Bateria da lanterna | **Não gastar bateria a mais** foi decisão anterior; rever só se o terror continuar fraco — custo de item muda o loop de loot |
| Eco / outros | Sumidos na preta | Manter: a preta é *só* Tição |

**Proposta de design da “preta pura”:**

1. **Contrato do jogador:** na preta você *não explora* — você *escapa entre ilhas de luz*.
2. **Falha da lanterna = evento:** 1–2 s sem luz + caça perto = quase morte, não “ele andou um passo”.
3. **Sandbox:** `BlackFogPressure` leve/padrão/pesadelo mexendo só em piscar + caça + duração do freeze ao sair da luz (hoje ~0,5 s — encurtar = mais perigo).
4. **Feedback:** quando a luz congela, o Tição precisa *mostrar* (brasa apaga / fumaça — efeito peça ZB-free da §3.3).

**Critério de sucesso.** Em 3 pretas com build “lanterna + comida”: pelo menos 1 morte ou fuga desesperada sem cheats; o Johan não descreve a preta como “ok”. Em Leve, ainda jogável.

---

### 3.7 Experiência na névoa ≠ Zomboid genérico

**Problema.** Mesmo com visão ~4 tiles e perambular (0036), a névoa pode *ler* como “zumbis + fog”. Com transform 100% (§3.9), o risco vira **as três cores iguais**.

**Hipótese.** Unicidade = **ritmo por cor** + regra de engajamento:

- **Branca:** presença / ritual (encontrar, perambular errado) — Silent Hill cotidiano.
- **Vermelha:** agitação / caça / grito — caos.
- **Preta:** luz — uma regra.
- Variante: **uma regra que muda o input** (agachar, não olhar, apagar luz, não acordar).

**Propostas concretas (incrementais sobre 0036 + spec §5 + §3.9):**

1. **Perambular mais “errado” (branca):** grupos param, olham pra parede, voltam; nunca formam fila até o player. Ajustar `NOM_WanderRules` depois do playtest da 0036.
2. **Gritos monstro + ambiente** — **repor** (§3.1.1 / Sons II): monstro = gameplay; ambiente = presença sem horda. Não deixar cair da lista.
3. **Vermelha agitada:** agenda/IA de correr + gritar ao achar (§3.9) — velocidade aqui é *da cor*, não monstro novo.
4. **Crepitar por proximidade** (spec §5, ainda fora): chiado sob o drone perto do monstro — “radiação do Outro Mundo”.
5. **Regra de ouro:** clipe de 10 s — se não dá pra dizer se é branca ou vermelha de olhos fechados (áudio/comportamento), falhou.
6. **Não fazer:** mais tipos que só correm mais rápido na branca. Velocidade de *noite* ≠ frenesim da vermelha.

**Critério de sucesso.** Clipes lado a lado (vanilla vs NOM; branca vs vermelha vs preta): o Johan identifica NOM e a **cor** em &lt; 3 s por *comportamento/áudio*, não só pelo tint.

---

### 3.8 Partículas: cinzas boas → experimento “descamando / poros”

**Problema.** Lascas/cinza funcionam; quer-se evolução mais crível — parede descamando, “poros no ar”. Explicitamente **experimento**, não certeza.

**Hipótese.** Crivez = *origem* + *física leve*: nascer *da* parede vestida (já quase), viver pouco, deixar “buraco” visual implícito (mais tinta descascada no dressing), não só neve pra cima.

**Propostas (onda E, baixa prioridade):**

1. **A/B no jogo** com três presets em `NOM_FlakeRules` (debug/`NOM.panel`): atual · “descamando” (mais parede, menos cinza, vida mais curta, rajada na transição) · “poros” (pontos miúdos no ar, drift baixo, fade longo — evoluir o `AIR_*` da vermelha pra branca/preta com densidade baixa).
2. **Sem novo sistema de partículas** até o A/B: só números + texturas `gen_textures` / sheet.
3. **Critério de matar o experimento:** se FPS cair ou virar “neve chata”, reverter; se o Johan disser “parede viva”, promover pra sprint.

---

### 3.9 Identidade das cores + transform universal (**confirmado Johan**)

**Confirmado (Johan, 2026-10-08):** “essa é a ideia mesmo” — **todos** se transformam em **toda** fog. Tabela curta na §1; aqui o detalhe de produto.

#### O que o jogo faz hoje (âncora)

| Cor | Transform hoje | Comportamento hoje |
|-----|----------------|--------------------|
| **Branca** | **~14%** variantes (5/3/3/3); resto zumbi comum | Visão ~4 + perambular (0036); sem frenesim dedicado |
| **Vermelha** | **100%** split 1/4 | Look/sangue/horda; ainda **não** é “todos agitados” de propósito |
| **Preta** | **100% Tição** | Luz congela / caça no escuro — já é identidade própria |

Âncoras: `gdd/monsters.md`, `sandbox.md`, `NOM_VariantRules.variant` (red / black → ticao).

#### Fechado

| Decisão | Valor |
|---------|--------|
| Transform | **100% em branca, vermelha e preta** |
| Preta | Continua **só Tição** (não as quatro) |
| Vermelha | Continua 100% das quatro + **agitação** (abaixo) |
| Branca | 100% das quatro + tom Silent Hill + **almas esqueléticas na rua** (§3.9.1, *além* das variantes) |
| Implementação | **Depois** do P0 fog (fila 1b / equilíbrio); sprint fog só respeita fantasy nos roteiros |

#### Sugestão PO — branca = “Outro Mundo cotidiano” (Silent Hill)

Johan: branca talvez mais tranquila / “dia a dia”. **Leitura PO (fechada):**

> **Branca = o dia a dia do Outro Mundo.** Você *habita* a névoa: monstro em cada esquina, mas o mundo **não está em frenesim**. Tensão por **presença, som e ritual** — e, na rua, **almas que se arrastam e somem** (§3.9.1). Não é apocalipse em chase.

**Comportamento concreto (pós-FOG, junto do transform):**

- Perambular / “errado” (0036+) manda; **sem** buff geral de sprint/caça.
- Corredor **existe** mas não dispara a cada esquina; Carpideira = lamento/Witch (§3.2); Estalador = clicker (§3.1.2).
- Áudio: drone + **gritos ambiente** (§3.1.1); gritos de gameplay **esparsos**.
- Camada rua: almas esqueléticas negras em levas, seek **lento**, TTL curto (§3.9.1) — **além** das quatro variantes.

#### 3.9.1 Almas esqueléticas (**regras Johan** + emenda 2026-10-09)

**Emenda (Johan, 2026-10-09 — prevalece):** ciclo **constante** com população viva **4–20** (repor abaixo de 4; teto 20); mix **68% crawler / 32% shambler**; aparece em **branca e vermelha e preta**; params no `NOM.panel()` (sprint **0055**). Gap 45–120 s, levas ~10/15/20 e “só branca” / ~70% crawler da 0050 **ficam obsoletos**.

**Confirmado (Johan, 2026-10-08; look/TTL/rua mantidos):** look **esqueletos negros / corpo totalmente decomposto**; locomoção **sempre mancando** + maioria rasteja; **buscam o jogador**; TTL variável; podem **chorar/gritar**; só rua; FX **partícula negra**; modelo vanilla **por nome**.

##### Veredito PO (atualizado)

**Ainda encaixa** no cotidiano Silent Hill — mas não é mais “FX quase inerte”. É **pressão lenta de rua**: mortos-vivos que **vêm mancando / rastejando** até você e dissolvem. Ameaça latente ≠ frenesim da vermelha:

| | **Almas (branca)** | **Agitação (vermelha)** |
|--|--------------------|-------------------------|
| Velocidade | Só **shambler mancando** + **crawler** | Correr, sair correndo, sprint |
| Contato | Buscam o jogador; TTL acaba → somem | Gritam e **vão atrás** em caça/horda |
| Ritmo | Levas orgânicas que sobem e baixam | Caos contínuo enquanto a névoa dura |
| Sensação | “Eles estão vindo… devagar” | “O mundo te quer morto agora” |

**Convívio com transform 100%:** continuam **além** das quatro variantes (atmosfera/ameaça de rua), **não** substituem o cast. Não iniciam horda de Corredor; não contam no `VariantRules`.

**Recomendação:** **aceitar com limites** (Johan confirmou) + **spike depois do P0 fog**.

##### Regras fechadas (Johan: “perfeito”, 2026-10-08)

| Regra | Valor |
|-------|--------|
| Look | Esqueleto **negro** / corpo **totalmente decomposto** (vanilla por nome) |
| Mix loco | **Sempre** shambler mancando; **~68% crawler** (resto shambler em pé mancando); ajustável no painel |
| Seek | **Sim** — path/IA em direção ao jogador; **nunca** sprint / corredor |
| TTL | Variável por indivíduo: ordem **~10 s / ~30 s / ~1 min** (sorteio orgânico) |
| População | **Ciclo constante 4–20** vivos (repor abaixo de 4; teto 20); sem gap de levas |
| Vida | **Baixa** — pressão / susto, **não** tank |
| Áudio | Podem **chorar** e **gritar** com variedade — banco na **Sons II** (§3.1.1), distinto de Corredor/Carpideira gameplay |
| Espaço | **Só rua** (`isOutside`); **nunca** interior; na soleira → não entram / despawn |
| FX | Partícula **negra** no spawn **e** no despawn |
| Escopo de cor | **Branca + vermelha + preta** (cada uma on/off no debug) |
| Cast | **Além** das variantes 100%; sandbox `AlmaEnabled` desliga |

##### Critérios jogáveis

- [ ] **Look:** na rua, lê-se corpo negro decomposto/esqueleto — não zumbi Knox vestido.
- [ ] **Mix:** ~**70% crawlers** + shamblers mancando; **zero** sprinter entre almas.
- [ ] **Seek lento:** avançam ao jogador; dá pra contornar / casa / distância — sem chase de sprint.
- [ ] **≠ vermelha:** ritmo = arrasto/lamento, não corrida + horda.
- [ ] **TTL:** somem com FX negro em ~10 s / ~30 s / ~1 min (mistura na leva).
- [ ] **Levas + gap:** 2+ ondas ~10–20 com jitter; **intervalo 45–120 s** entre levas; sem spam 24/7.
- [ ] **Vida baixa:** morrem fácil / pouco HP — pressão, não esponja.
- [ ] **Áudio:** choro/grito de alma; não chama horda.
- [ ] **Interior:** nunca dentro; casa corta o seek.
- [ ] Variantes 100% seguem; almas fora do split.
- [ ] FPS/MP ok com leva ~20 perto; sandbox corta.

##### Riscos / API

| Risco | Mitigação |
|-------|-----------|
| Look “esqueleto negro / decomposto total” | **`[HIPÓTESE DE API]`** — nomes vanilla B42 (mesh/outfit/`setSkeleton` + tint preto): spike in-game. `setSkeleton` só citado p/ queimado em pz-api-notes — **não** asumir look final |
| Shambler mancando estável | `doZombieSpeed` / speedType arrastado = EXISTS; sandbox lore pode vencer — spike (`[HIPÓTESE]` se precisa truque DoZombieStats) |
| Crawler na maioria | Flag `crawler` no `addZombiesInOutfit` longa = **CONFIRMED**; manter crawler pós-stats = spike |
| Seek + TTL + despawn | Servidor agenda leva + TTL; dono aplica path; despawn com FX — padrão ADR-002/005; **`[HIPÓTESE]`** se removeFromWorld + partícula sync MP limpo |
| Leva 10–20 perto = FPS | Cap por cliente/área; jitter de spawn; medir; sandbox Leve menor |
| Áudio alma vs monstro gameplay | Clips próprios Sons II; **não** disparam horda; mix mais “fantasma” que garganta de Corredor |
| Overlap Eco / Sem-rosto / §3.5 | Eco = noite/véu; Sem-rosto = em pé/TV; §3.5 = monstro permanente; almas = **leva efêmera negra na branca** |
| Poluição / “horda de ossos” | TTL curto + gaps entre levas + só rua + sem sprint |
| Partícula negra | `gen_textures` / sheet nosso |

##### Ordem

1. **P0 FOG** — sem isto.
2. **Sons II** (inclui banco choro/grito de alma + ambiente) / transform 100%.
3. **Spike “Alma de rua”** (pós-P0): look negro/decomposto + **70% crawler** + seek + TTL + levas/gap 45–120 s + vida baixa + `isOutside` + FX.
4. Sprint curta se spike verde; fallback se look falhar: tint/peça preta + crawler/shambler + mesmas regras de leva/TTL/seek.

#### Vermelha = agitação / caça (pedido Johan)

**Fantasy:** caos — “todos os bichos bem agitados”. Experiência de **caça**, não de passeio.

**Comportamento alvo (pós-FOG; alavanca IA/agenda, não taxa de transform):**

- Mais movimento rápido: correr, sair correndo, grupos que se agitam.
- Ao **encontrar** o jogador: gritam e **vão atrás** (Corredor/Carpideira e pressão de horda).
- Visual/look vermelho + sangue/tentáculos já empurram o “mundo errado”; a IA fecha o loop.

**Não colidir com a preta:** vermelha = **barulho e perseguição em massa**; preta = **silêncio/escuridão e uma regra** (luz). Na vermelha você corre da horda; na preta você gerencia a lanterna contra o Tição.

#### Preta = terror / clímax (sem virar vermelha escura)

Mantém §3.6: luz é tudo, aperto de piscar/caça, só Tição. **Não** colocar as quatro variantes agitadas na preta — mataria as duas identidades. Áudio: crepitar/brasa/tempestade; gritos ambiente no máximo **muito** rarefeitos ou off.

#### Encaixe na ordem

1. **P0 FOG** visual (base/bolsões) — sem mudar taxas/IA de cor / almas.
2. **Sons II** — gritos monstro + ambiente (§3.1.1) + Estalador; calibração **por cor**.
3. **Transform + identidade** — branca 100% variantes + tom cotidiano; vermelha agitação; preta intacta.
4. **Spike / sprint almas esqueléticas** (§3.9.1) — só branca, além das variantes.
5. Look / Carpideira Witch / aperto preta — em cima disso.

#### Ainda aberto (pós-FOG — não bloqueia P0)

1. Branca 100%: **split igual** vs **pesos sandbox** como mix? *(PO: pesos sandbox renormalizados.)*
2. Eco na branca/vermelha: inalterado (só noite)? *(PO: sim.)*
3. Nome(s) vanilla do look esqueleto/decomposto negro no B42 — **spike** (`[HIPÓTESE DE API]`).

*(Defaults almas ~70% crawler / gap 45–120 s / vida baixa: **fechados** com o Johan, 2026-10-08.)*

---

## 4. Priorização (decisão Johan: **fog = prioridade zero**)

| Ordem | Onda | Foco | Nota |
|-------|------|------|------|
| **P0** | **FOG — clímax** | Sprint §3.4: base+bolsões; pipeline + alvo visual fechados | Sem Sons/IA de cor/look até fechar |
| 0b | Workshop / playtest legado | v1.0.0, 0035–0046 | Paralelo operacional |
| **Depois do clímax** | Fila pós-FOG | **1 Sons II:** gritos monstro + ambiente + **choro/grito almas** (§3.1.1) + Estalador · **1b** Transform 100% + identidade por cor · **1c** spike/sprint **almas** (§3.9.1: seek lento, levas, TTL) · **1d** aperto preta · **2** Look · **3** Carpideira andar · depois §3.5 | 1c pós-P0; look negro = `[HIPÓTESE]` |

**Top 1:** sprint **FOG**. Identidade 3 cores + transform: **confirmados** (Johan); implementação pós-P0.

---

## 5. Riscos e dependências (fog em destaque)

| Risco | Impacto | Mitigação |
|-------|---------|-----------|
| **Começar por B (sim 3D)** | Atrasa o clímax | Ordem: **A → C-lite → B' → B só se falhar** |
| **Ler “fina” como transparente** | Base sem presença; não bate a ref | Densidade **alta no chão** + altura **baixa**; A/B vs §3.4.3a |
| **B' FBO bagunçar GL do PZ** | Artefato/crash | Medir; capturar `Throwable` (regra mod3); matar B' se sujo |
| **ZB obrigatório pro volume** | Sem Volumétrica, sem mar/cascata | Fallback clima/overlay; bolsão ainda “pior” sem volume |
| **Bolsão viajante divergente no MP** | Um vê sopa, outro não | Campo + **deriva** determinísticos (seed mundo + período + tempo); servidor manda regra |
| **Bolsões viajantes demais** | Cidade em sopa itinerante | Defaults **raros/brutais**; sandbox velocidade/frequência |
| **Sandbox vs cliente** | Host força GPU alheia | Regime base/bolsão no **sandbox**; quality/res no **cliente** |
| **Subir `scale` / N camadas sem medir** | Thread fluido / FPS | Medir ms/passo; opção de qualidade |
| **Branca 100% diluir vermelha** | Cores iguais | Branca = cotidiano/presença; vermelha = **agitação/caça**; preta = luz/Tição (§3.9) |
| **Gritos ambiente caírem da sprint** | Névoa muda de novo | Checklist §3.1.1 obrigatório na onda Sons II |
| **Almas virarem vermelha lenta** | Cores iguais | Só shambler/crawler; TTL+gaps; sem sprint/horda; §3.9.1 |
| **Leva ~20 + seek = FPS/MP** | Travada na branca | Cap área; medir; sandbox Leve |
| **Look decomposto negro B42** | Fallback ou atraso | Spike pós-P0; vanilla por nome; tint/peça se preciso |
| Demais riscos (Carpideira, clicker, etc.) | — | **Depois** da FOG; ver §§3.1–3.3, 3.9 |

---

## 6. Critérios de sucesso (checklist — fog primeiro)

**Sprint FOG (obrigatório agora):**

- [ ] Base = mar baixo no chão (ref §3.4.3a): não engole câmera; jogável; print bate foto/vídeo.
- [ ] Bolsões **viajantes**: clímax ao entrar/ser alcançado; contraste ao sair; movem com vento; raros.
- [ ] Sandbox controla regime (base + bolsão/velocidade); cliente controla FPS/res.
- [ ] Sem ZB: ainda dá pra sentir base vs zona pior.
- [x] Pipeline A→C-lite→B'?→B **fechado** (2026-10-08).
- [x] Alvo visual da base **fechado** (vídeo t=478 + foto).
- [x] Bolsões **viajantes + raros/brutais** **fechado** (Johan “ok”, 2026-10-08).
- [x] Sandbox 2 eixos + fallback sem mod3 = visual fino (default PO).
- [ ] Critérios §3.4.3 + §3.4.3a verdes no playtest *(após go / implementação)*.

**Depois da FOG — Sons II (gritos, não esquecer):**

- [ ] Gritos de **monstro** (Corredor + Carpideira) — timbre + gameplay (§3.1.1).
- [ ] Gritos **ambiente** (spec §5) — 1–3 min, só cliente, sem horda (§3.1.1).
- [ ] Estalador clicker + ripples (§3.1.2).
- [ ] Calibração por cor (branca quieta / vermelha agitada / preta sem wall of screams).

**Depois da FOG — resto:** transform 100% + identidade IA por cor (§3.9); spike **almas esqueléticas** branca (§3.9.1); Carpideira Witch/look; aperto preta; partículas; rastejante §3.5.

---

## 7. Decisões fog — fechadas vs abertas

### Fechadas (2026-10-08)

| Decisão | Valor |
|---------|--------|
| Prioridade | **FOG = P0** (clímax antes de Sons/monstros/look/preta/transform) |
| Pipeline técnico | **A → C-lite → B'? → B** (“vamos tentar assim”; produto A-first; B só se falhar) |
| Alvo visual da **base** | Mar baixo / gelo seco — [vídeo t=478](https://youtu.be/a-wtJulfhlo?t=478) + [`ref-nevoa-pratica-baixa.png`](sprints/sprint-0047-fog-climax/ref-nevoa-pratica-baixa.png); bolsão = absurdo atual |
| **Bolsões** | **Viajantes + raros/brutais** — **fechado** (Johan “ok”, 2026-10-08): poucos e pesados = fog absurda de hoje quando chegam; vento/`FogBanks` |
| Defaults base | Altura **baixa**; densidade **alta no chão**; véu **fraco** — **fechado** |
| Sandbox fog | **2 eixos** (base + bolsão) + presets Leve/Pesadelo — **fechado** (default PO, 2026-10-08); nomes finais na spec |
| Sem mod3 | Fallback = **visual fino sem volume** (clima/overlay/vinheta) — **fechado** (default PO, 2026-10-08) |
| Res. da grade | **Só cliente** (Opções > Mods) — **fechado** |
| Workshop v1 | **Enviar** quando fizer sentido operacional; FOG segue na `staging` |
| Transform universal (§3.9) | **Confirmado Johan** — 100% em toda fog; preta só Tição; impl. depois da FOG |
| Identidade das cores | **Branca** = cotidiano + almas de rua (§3.9.1); **vermelha** = agitação/caça; **preta** = luz/Tição |
| Almas esqueléticas (branca) | **Fechado (Johan “perfeito”, 2026-10-08)** — look negro/decomposto; ~**70% crawler**; seek lento; TTL ~10s/30s/1min; levas ~10/15/20; **gap 45–120 s**; **vida baixa**; choro/grito; rua only; FX negro; *além* das variantes; spike **depois** P0 |
| Sons II — gritos | **Monstro + ambiente** obrigatórios na onda (Johan: não foram feitos; não esquecer) |

### Fog P0 — bloqueios

**Nenhuma decisão de design aberta.** Viajantes, raros/brutais, sandbox 2 eixos e fallback sem mod3 estão na tabela **Fechadas** acima.

| Item | Status |
|------|--------|
| **Go explícito** do Johan pra sprint | **Fechado (2026-10-08)** — implementação autorizada; código no worker bluefin (§8) |

### Ainda abertas (pós-FOG — não bloqueiam P0)

1. Branca 100%: split igual vs **pesos sandbox**? *(PO: pesos renormalizados.)*
2. Eco inalterado (só noite)? *(PO: sim.)*
3. Nome(s) vanilla look esqueleto/decomposto **negro** B42 — spike (`[HIPÓTESE DE API]`).

*(Almas: % crawler / gap / vida — **fechados** 2026-10-08. Resto pós-FOG adiado.)*

---

## 8. Próximo passo

**Go fechado (Johan, 2026-10-08).** Design P0 + autorização de implementação.

| Onde | O quê |
|------|--------|
| **Este arquivo (repo)** | Fonte de produto; after-P0 documentado, não implementado |
| **Sprint 0047** | [`sprints/sprint-0047-fog-climax/`](sprints/sprint-0047-fog-climax/README.md) — branch `sprint/0047-fog-climax`; A→C-lite→B'?→B; bolsões viajantes raros/brutais; sandbox 2 eixos; fallback sem mod3 |

---

## 9. Fora de escopo deste documento / da sprint FOG

- Sons II, almas, transform 100%, Carpideira Witch/look, aperto da preta, rastejante (§3.5) — **depois** do P0.
- Tratar Sons/monstros/look/preta como paralelos à FOG (Johan: **não**).
- Prometer mesh 3D multi-camada como se já existisse — hoje é **grade 2D + perfil no shader**.
- Rádio de bolso / sinalizador; cópia de Witch/SH/ILL/TLOU; assets de terceiros.
