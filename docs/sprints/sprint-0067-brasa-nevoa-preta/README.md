# Sprint 0067 — Brasa permanente na névoa preta

| Campo | Valor |
|-------|-------|
| Status | `em curso` |
| Branch | `feature/0067-brasa-nevoa-preta-ca41` |
| Origem | Playtest Johan 2026-10-10 + direção `look-brasa-nevoa-preta` |
| Base | `staging` |

Tições na névoa preta ganham casca **BoilerSuit** (sem hood Hazmat) com fissuras ≥70% transparentes e shader `NOM_Brasa` (pulso 2,4–3,2 s via Alpha; treme ≤0,6% no torso). Mutação `NOM_Brasa` também passa a BoilerSuit.

- Efeitos off → `NOM_BrasaCascaStatic` (brasa estática).
- Luz congela o pulso (30–45%).
- EmberShell cede a casca permanente pra não empilhar malha.
