# Bota-Abaixo — estado do projeto (2026-11-24)

Leia isto primeiro ao retomar o projeto numa sessão nova. Histórico de decisões: `docs/decisoes.md`.
Repositórios (GitHub privado, ramo `main`): `joao992001/bota-abaixo` = versão estável (não mexer) ·
**`joao992001/bota-abaixo-teste-2` = cópia para as mudanças estruturais grandes (trabalhe aqui).**

## ▶ Retomar aqui (sessão nova)
Reforma grande em andamento no `teste-2`, pedida pelo usuário em 2026-11-23, nesta ordem:
1. **Robôs: 8 modelos só de aparência** no lugar da Garagem — **FEITO** (commit 6b089e1).
2. **Movimento, combate e animação** — FEITO (2026-11-24), relatório em `docs/relatorio_personagem_combate.md`.
   Golpe rápido (X/□) × marretada pesada (Y/△, preparo/impacto/recuperação, só ela quebra caixote/chão/barril);
   esquiva (RB/RT) no chão e 1× no ar (volta só ao pousar; protege só de golpe/pisão de robô); arremesso com perda de controle
   curta e retorno gradual; hitstop. Animação por molas em tudo (idle com tique, corrida, derrapagem, pivô na virada, pulo,
   mortal no pulo duplo, esquiva com rastro, golpes com arco, atingido com clarão, giro no arremesso, pouso amortecido) e dano
   no corpo em 3 estágios (`dano1..3_<modelo>.png`, faísca, fumaça, plaquinha solta, parafuso voando). Números: `data/controller.json`
   (`ataque_rapido`, `ataque_pesado`, `esquiva`, `arremesso`, `hitstop`) e `modos.json` (`amassometro.rapido/pesado`) —
   VALORES INICIAIS, a calibrar jogando. Vitrine: `-- --combate=DIR` (quadros → GIF). Testes: `--autotest --so=combate`.
2b. **LABORATÓRIO** (menu principal) — FEITO (2026-11-24): `game/ui/laboratorio.gd` + `levels/laboratorio.lvl`. Medidores,
   bonecos com comportamento, 32 números ajustáveis ao vivo; o usuário calibra jogando e manda os valores (COPIAR) para virar
   o padrão nos JSON. Ajustes salvos ficam em `user://laboratorio.json` e valem no jogo todo (PADRÃO apaga). Testes: `--so=lab`.
3. **Fases e câmera** — DEPOIS do movimento (as medidas do pulo/golpe definem as fases). Retirar as 24 arenas atuais
   (+ antigas, `tools/mapas/`, prévias `game/assets/ui/arena_*.png`), deixando 1 arena-base provisória por modo para o jogo
   abrir e os testes rodarem; depois criar um modelo de fase padrão, com câmera e regras próprias por modo.
**Economia (pedido do usuário):** uma sessão nova por mudança grande; sessão principal faz tudo (agentes só para lotes grandes
de arte em paralelo); rodar só a parte dos testes que mudou (`--so=`) e a bateria completa 1× no fim; poucas capturas.
**Ambiente na nuvem:** Godot 4.7.1 + modelos de exportação não vêm instalados; baixe de github.com/godotengine/godot/releases
(`Godot_v4.7.1-stable_linux.x86_64.zip` e `..._export_templates.tpz`, extrair só `windows_release_x86_64.exe`,
`linux_release.x86_64` e `version.txt` para `~/.local/share/godot/export_templates/4.7.1.stable/`). Arte: `pip install cairosvg`.
Falha conhecida na bateria: "Skate: atropela quem está na frente" (Fuga, lote 2c incompleto).

## O que é hoje
Party game de briga e plataforma, **2–4 jogadores locais** (teclado e controles), com bots. Tudo roda no modo interno
`demolicao` (código em `game/modes/demolicao.gd`); o antigo modo de peças com dono foi removido em 2026-11-20.
- **4 modos (sem submodos; o Clássico de peças foi removido):** fluxo Modo → Arena do modo → Ajustes do modo → Entrada.
  - **Derruba** (vidas 1–5, dano %): Canteiro, Guindastes, Gangorras (serraria), Esteiras, Prensa (ferro-velho), Fornalha (fundição).
  - **Batata-Dinamite** (pavio curto/normal/longo; encostar ou marretar passa; 44×24, sem espinho): Obra de Concreto (portas que trocam), Galerias da Mina (túneis e tubos), Prédio Velho (alçapões), Sob o Viaduto (plataformas e ventilador), Palafitas (gangorras), Telhados (trampolins).
  - **Rei da Obra** (capacete de ouro no `K`; 20/30/45 s; golpe derruba; 1,2 s de proteção; 44×24): Trono do Canteiro, Linha de Montagem, Rei do Cais, Mina de Ouro, Serraria Real, Prédio em Demolição.
  - **Fuga** (tela/lama persegue; cair só atrasa; pego pela tela sai; elevador `E` vence): Torre, Obra Subindo, Descida da Fundição (tela desce), Viaduto em Obras, Ferro-Velho, Pântano Subindo.
  - Regras e listas em `data/modos.json` (`demolicao.modos`); bots sabem cada modo (`modes/bots.gd`: `_climb` + busca de caminho `_nav_step`).
  - Fases geradas por `tools/mapas/` (gerar.py, variedade.py, fuga2.py). Antigas (Paiol, Galpão, Andaime, Bola, Laje, Pirâmide, Ponte, Maré) ficam em levels/ mas fora das listas.
- **Itens por modo** (`itens_lista` em modos.json): Batata 8 (estilingue, patins, escudo, teletransporte, relógio, ímã, soprador, congelador) · Rei 9 (choque, laço, patins, cola, congelador, soprador, mola, foguete, vórtice) · Fuga 9 (barreira, patins, foguete, mola, cola, gancho, teletransporte, congelador, soprador).
- **Derruba, 12 itens:** TNT, furadeira, cola, teletransporte, raio laser, bomba de vórtice, soprador, raio congelante (botão ITEM) ·
  martelão, ímã, botas de mola, bota-foguete (automáticos). Ferramentas aparecem na mão ao usar.
- **9 eventos** configuráveis; Amassômetro (dano % aumenta o empurrão); aderência limitada na parede/borda com medidor.
- **Temas de arena:** Canteiro, Fábrica, Porto e Cidade à noite (blocos, tábuas e fundo animado por tema; `tema:` no .lvl).
- **Robôs: 8 modelos só de aparência** (Lata, TV, Baixinho, Pescoção, Brutamontes, Varapau, Barril, Bolha), na cor do jogador; ▲▼ na entrada.
  Garagem, chapéus, padrões, itens de rosto e ferramentas foram removidos (2026-11-23). Prancha: `-- --robos=DIR`.
  A cor do jogador só identifica (setinha "P1" acima da cabeça, placar). Bots sorteiam um robô.
- **Interface (estilo cartoon, escolhido entre 3 propostas):** kit em `game/ui/kit.gd` (cartões com contorno grosso e
  sombra dura, títulos contornados, estrelas desenhadas). Cartões dos jogadores EMBAIXO na partida (retrato redondo
  `ui/retrato.gd`, estrelas, % grande, item no selo; ficam translúcidos quando um robô passa por trás). Placar em ranking,
  vitória com o nome do robô. Captura de apoio para novas propostas: `-- --maquete=DIR`.
- **Menus:** intro animada, cenário próprio do menu, OFICINA (painel de testes), opções (vibração, testar/configurar controle).
- **Arte:** personagens e cenário em **papel e giz** (recorte sem contorno preto, textura de giz, bordas tremidas; definido no chat
  de 2026-11-20 com versoes.png). Só a **interface** usa contorno grosso e sombra dura (`ui/kit.gd`). Tudo gerado por código em
  `art/src` (SVG → PNG pelo Chromium, `tools/render_svg.js`), cópias em `game/assets`. **Som:** `tools/sfxforge.py` (efeitos, com acabamento) e `tools/musica.py` (compositor de músicas longas).

## Como rodar e testar
- Jogar: `godot --path game` · bateria de testes: `godot --headless --path game --fixed-fps 60 -- --autotest` (199 verificações, 0 falhas).
- Só uma parte: `-- --autotest --so=itens_novos,parede,controle_real` · ritmo com bots: `-- --stats=4`.
- Capturas: `-- --espiar=DIR,arena,modo,segundos` (bots, foto a cada 10 s), `-- --menus=DIR`, `--itens=DIR`, `--parede=DIR`, `--intro=DIR`, `--oficina=DIR` (com xvfb-run e `--rendering-driver opengl3`).

## Como gerar o executável (IMPORTANTE)
- Exportar com a **mesma versão da Godot do editor do usuário: 4.7.1**. Exportado na 4.3, o controle DualShock/DualSense
  não funcionava (a partir da 4.5 os controles usam SDL3). A 4.7 também grava o ícone no `.exe`.
- Linux/cloud: `GODOT=/caminho/godot-4.7.1 tools/exportar.sh` (exporta numa cópia temporária, leva `data/` e `levels/`,
  gera `out/build/windows/Bota-Abaixo.exe`, `out/build/linux/...` e o instalador `out/Instalar-Bota-Abaixo.exe` via makensis).
- Windows: `exportar_windows.bat` (ajustar o caminho da Godot dentro dele).
- Depois de exportar: rodar a bateria no executável Linux numa pasta vazia (`./Bota-Abaixo.x86_64 --headless --fixed-fps 60 -- --autotest`).

## Pendências e próximos passos
1. Reforma do `teste-2` (ver "Retomar aqui").
2. Terminar o lote 2c da Fuga (teste do skate) — ou descartar, se os itens mudarem na reforma.
3. Rodada de teste com amigos → lista de ajustes; fechar o escopo do beta.
4. Atualizar o `docs/plano.md` (ainda descreve os 4 marcos do jogo antigo de peças) e o `docs/estilo_visual.md` (seções de robôs e
   contorno são da v2; a verdade atual está no topo dele e nas skills).
5. Depois do beta: inglês, Steam, demo/Next Fest, online por convite (Steamworks/GodotSteam). Online ainda proibido no `CLAUDE.md`
   até o usuário liberar.
