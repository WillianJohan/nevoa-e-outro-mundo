# Sprint 0067 — Brasa permanente na névoa preta

| Campo | Valor |
|-------|-------|
| Status | `em curso` |
| Branch | `feature/0067-brasa-nevoa-preta-ca41` |
| Origem | Playtest Johan 2026-10-10 + direção `look-brasa-nevoa-preta` |
| Base | `staging` |

Tições na névoa preta ganham casca **BoilerSuit** (sem hood Hazmat) com fissuras ≥70% transparentes e shader `NOM_Brasa` (pulso 2,4–3,2 s via `TintColour.r`; `Alpha` só visibilidade/`tex.a * Alpha`; treme ≤0,6% no torso). Mutação `NOM_Brasa` também passa a BoilerSuit.

- Efeitos off → `NOM_BrasaCascaStatic` (brasa estática).
- Luz congela o pulso (30–45%); shader `inten = 0.30 + 0.70 * pulse`.
- EmberShell cede a casca permanente pra não empilhar malha.
- Diretor: veredito em store `docs/look-brasa-validacao-0067.md` (itens 1–3 corrigidos; prints pendentes).
