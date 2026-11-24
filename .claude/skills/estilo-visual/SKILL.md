---
name: estilo-visual
description: "Direção de arte de Bota-Abaixo: personagens e cenário em papel e giz (recorte sem contorno, textura de giz, bordas tremidas), interface cartoon com contorno grosso, perigo legível, comparação com docs/referencias/. Use antes de criar ou revisar qualquer arte."
---

# Estilo visual

1. **Personagens e cenário = papel e giz:** formas recortadas **sem contorno preto**, cor chapada com textura de giz/rabisco,
   bordas levemente tremidas, um lado mais escuro dando volume, fundo claro e dessaturado. Helpers prontos em `art/src/papel.py`
   (`shape`, `hatch`, `rough`, `rect_d`, `ellipse_d`) e `art/src/svg.py` (`shade`, `queue`, `render_all`). Use-os; não reinvente.
2. **Interface = cartoon:** cartões e títulos com contorno grosso e sombra dura (`game/ui/kit.gd`).
3. **Legibilidade antes de beleza:** o jogável salta do fundo; perigo sempre óbvio (vermelho `#d42035` só em perigo);
   cada jogador se acha em 1 s (setinha P1–P4 na cor dele).
4. **Referências** em `docs/referencias/`: copie traço, formas, cores e efeitos; nunca personagens, emblemas, logos ou fundos exatos.
5. **Sempre olhe o resultado**, de preferência **dentro do jogo** (`-- --robos=DIR`, `--arenas=DIR`, `--menus=DIR`), não só o PNG solto.
   Compare lado a lado com a referência só quando o estilo estiver em dúvida (custa caro).

Gerar: scripts Python em `art/src/` escrevem SVG e rasterizam com o Chromium (`tools/render_svg.js`, Playwright); depois
`cp -r art/out/game/* game/assets/`. Precisa de `pip install cairosvg` (importado por `svg.py`).
