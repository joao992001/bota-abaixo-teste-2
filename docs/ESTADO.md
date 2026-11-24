# Bota-Abaixo — estado do projeto (2026-11-20)

Leia isto primeiro ao retomar o projeto numa sessão nova. Histórico de decisões: `docs/decisoes.md`.
Backup: GitHub privado `joao992001/bota-abaixo` (ramo `main`).

## O que é hoje
Party game de briga e plataforma, **2–4 jogadores locais** (teclado e controles), com bots. Modo principal **Demolição**
(o modo antigo de peças/construção ainda existe como "Clássico", mas o GDD.md ainda descreve só ele — desatualizado).
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
- **Arte:** estilo papel e giz (gerada por código em `art/src`, cópias em `game/assets`). **Som:** `tools/sfxforge.py` (efeitos, com acabamento) e `tools/musica.py` (compositor de músicas longas).

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

## Pendências e próximos passos (combinados com o usuário)
1. Rodada de teste com amigos → lista de ajustes.
2. Fechar o escopo do beta (lista do que precisa ter) e testar ~1 mês.
3. Atualizar o GDD.md para a Demolição; atualizar `CLAUDE.md` (hoje proíbe online, mas online é o objetivo do usuário).
4. Em paralelo: atualizar o documento-base (geral → específico) usado para criar este jogo, para novos jogos.
5. Depois do beta: inglês, página na Steam, demo/Next Fest, online por convite (Steamworks/GodotSteam).
