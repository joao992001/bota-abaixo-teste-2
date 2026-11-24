---
name: multiplayer-local
description: "Entrada de 2–4 jogadores locais em Bota-Abaixo na Godot 4: tela de entrada, um dispositivo por jogador, teclado dividido, cursores simultâneos na construção, escolha de cor e acessório. Use para qualquer coisa de input e entrada de jogadores."
---

# Multiplayer local

- Autoload `PlayerInput`: cada jogador tem um `device` (índice do controle ou `TECLADO_A`/`TECLADO_B`). O jogo pergunta sempre `PlayerInput.pressed(jogador, acao)`; nunca lê o dispositivo direto.
- Teclado A: WASD + Espaço (pular) + F ou E (marreta). Teclado B: setas + Ctrl dir. (pular) + ponto, / ou Enter do numérico (marreta). **Nunca usar Shift**: no Windows, com NumLock ligado, as setas mandam Shift "fantasma". Teclas lidas por evento, separando esquerda/direita.
- Ações: `mover_x`, `mover_y`, `pular`, `marreta`, `girar`, `confirmar`, `voltar`, `pausa`.
- **Entrada:** qualquer botão de um dispositivo livre ocupa o próximo slot; cada jogador escolhe **cor** (4) e **modelo de robô** (8); Start com 2+ começa.
- **Construção:** cursores simultâneos com a cor e o símbolo de cada jogador; movimento na grade com repetição ao segurar.
- Controle desconectado: pausa com aviso; reconectar retoma.
- Teste: simular eventos de 2 dispositivos diferentes e conferir que cada robô só responde ao seu.
