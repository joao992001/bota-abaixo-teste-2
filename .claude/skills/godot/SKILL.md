---
name: godot
description: "Projeto Godot 4.7 de Bota-Abaixo: configuração 1920x1080, estrutura de pastas e cenas reais, autoloads, animação do robô por código, testes automáticos e capturas, exportação do .exe. Use ao mexer na estrutura do projeto, importar arte, montar animações, testar ou exportar."
---

# Godot

## Configuração
Godot **4.7.1** (a mesma do editor do usuário; exportar em versão menor quebra controles PlayStation). 1920×1080,
`canvas_items`/`keep`, 60 ticks, renderizador Compatibility. Autoloads: `Data` (lê `../data` e `../levels`, texturas),
`PlayerInput`, `Audio`.

## Estrutura real (`game/`)
`main.gd`/`main.tscn` (estados, entrada, partida) · `player/robot.gd` (física e controle) · `player/robot_visual.gd` (desenho e
animação) · `modes/` (demolicao, ferramentas, eventos, arena_fx, bots) · `level/` (level.gd lê o .lvl; background.gd) · `ui/`
(menus, hud, oficina, kit, retrato) · `fx/debris.gd` · `tests/driver.gd` · `assets/` (cópia de `art/out/game`).

## Animação do robô
Toda por código em `robot_visual.gd`: lê o estado do robô a cada quadro e monta uma **pose** (corpo, inclinação, pés, joelhos,
mãos, marreta, antena, expressão); braços e pernas são curvas desenhadas, partes são PNGs 4× (128×128, pés em (64,120)).
Medidas por modelo em `assets/robo/modelos.json`. **Nunca** deixar a animação atrasar o controle; hitbox não muda.

## Testar
- Bateria: `godot --headless --path game --fixed-fps 60 -- --autotest` · só uma parte: `-- --autotest --so=<nomes>`.
- Capturas (com `xvfb-run -a` e `--rendering-driver opengl3`): `--robos=DIR`, `--menus=DIR`, `--arenas=DIR`, `--espiar=DIR,arena,modo,s`,
  `--itens=DIR`, `--parede=DIR`, `--oficina=DIR`, `--intro=DIR`. Ritmo: `--stats=N`.
- Diga sempre o que rodou e o que não rodou.
- Calibrar movimento/combate: menu ▸ LABORATÓRIO (`ui/laboratorio.gd`; painel com os números de `controller.json`/`modos.json`
  ao vivo, medidores, bonecos). Capturas: `--lab=DIR`. Valores mandados pelo usuário (COPIAR) viram o padrão nos JSON.

## Exportar
`GODOT=/caminho/godot-4.7.1 tools/exportar.sh` → `out/build/windows/Bota-Abaixo.exe` (arquivo único) e Linux; instalador só com
`makensis`. Depois rode a bateria no executável Linux.
