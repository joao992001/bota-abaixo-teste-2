# Bota-Abaixo — estado do projeto (2026-11-20)

Leia isto primeiro ao retomar o projeto numa sessão nova. Histórico de decisões: `docs/decisoes.md`.
Backup: GitHub privado `joao992001/bota-abaixo` (ramo `main`).

## O que é hoje
Party game de briga e plataforma, **2–4 jogadores locais** (teclado e controles), com bots. Modo principal **Demolição**
(o modo antigo de peças/construção ainda existe como "Clássico", mas o GDD.md ainda descreve só ele — desatualizado).
- **Submodos:** Último em Pé, Vidas, Placar, Batata-Dinamite. Fluxo: Modo → Submodo → Arena → Ajustes → Entrada.
- **11 arenas** (`levels/*.lvl`): Canteiro, Esteiras, Guindastes, Maré de Lama, Bola, Paiol, Torre (câmera sobe),
  Ponte (câmera avança), Gangorras, Prensa, Fornalha — e `oficina.lvl` (ambiente de testes).
- **12 itens:** TNT, furadeira, cola, teletransporte, raio laser, bomba de vórtice, soprador, raio congelante (botão ITEM) ·
  martelão, ímã, botas de mola, bota-foguete (automáticos). Ferramentas aparecem na mão ao usar.
- **9 eventos** configuráveis; Amassômetro (dano % aumenta o empurrão); aderência limitada na parede/borda com medidor.
- **Temas de arena (um por arena, sem caixote padrão):** Canteiro→canteiro, Demolição→canteiro, Bola→demolicao,
  Ponte→viaduto, Maré→pantano, Paiol→mina, Gangorras→serraria, Prensa→ferro_velho, Fornalha→fundicao, Esteiras→fabrica,
  Guindastes→porto, Torre→cidade. Arte em `art/src/cenarios/temas*.py`; ambiente animado em `game/level/background.gd`.
  Miniaturas da escolha de arena: `-- --arenas=DIR` e copiar `arena_*.png` para `game/assets/ui/`.
- **Garagem (personalização):** 8 robôs salvos em `user://garagem.cfg` — modelo, cor livre (16), cor 2, padrão (5),
  chapéu (16), rosto (6), ferramenta (6), comemoração (4). Na entrada, ▲▼ passa pelos 4 robôs de fábrica e pelos da Garagem.
  A cor do jogador só identifica (setinha "P1" acima da cabeça, placar). Bots sorteiam um robô. Prancha: `-- --skins=DIR`.
- **Menus:** intro animada, cenário próprio do menu, OFICINA (painel de testes), opções (vibração, testar/configurar controle).
- **Arte:** estilo papel e giz (gerada por código em `art/src`, cópias em `game/assets`). **Som:** `tools/sfxforge.py`.

## Como rodar e testar
- Jogar: `godot --path game` · bateria de testes: `godot --headless --path game --fixed-fps 60 -- --autotest` (213 verificações, 0 falhas).
- Só uma parte: `-- --autotest --so=itens_novos,parede,controle_real` · ritmo com bots: `-- --stats=4`.
- Capturas: `-- --menus=DIR`, `--itens=DIR`, `--parede=DIR`, `--intro=DIR`, `--oficina=DIR` (com xvfb-run e `--rendering-driver opengl3`).

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
