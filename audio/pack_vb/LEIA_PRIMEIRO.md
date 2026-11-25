# BOTA-ABAIXO — PACK DE AUDIO APROVADO VB

Arquivo para encaminhar ao Claude junto com a VERSAO ATUAL DO PROJETO GODOT.

**Leia primeiro:** `04_INSTRUCOES/PROMPT_PARA_CLAUDE.md`.

## Aprovação do usuário
- Referência sonora: `01_REFERENCIAS/REFERENCIA_APROVADA_GAMEPLAY_B_MUSICA_DISCRETA.mp3`.
- Música: Rock Cartoon Divertido de fundo, com redução B de −14 dB em relação à mixagem de gameplay anterior.
- Sons básicos: todos os elementos audíveis no gameplay SFX-only aprovado.
- Passos muito baixos; golpes dominam; duplo salto e dash presentes.
- Marreta curta/pesada, impactos metálicos diferenciados por alvo, pequenas variações de cada família.
- Arremessos: voo silencioso, som extra só na colisão real com estrutura.
- Eliminação off-map: explosão padrão, não som genérico de peças caindo.

## Cuidado com ganhos empilhados
- Os 4 WAV de passos JA ESTÃO reduzidos em 14 dB desde a revisão V0.2. NÃO reduzir mais 14 dB automaticamente.
- O arquivo `03_MUSICA/rock_cartoon_divertido_BG_APROVADO.ogg` JA VEM em nível muito baixo, próximo ao aprovado no comparativo B (redução de ~25,6 dB versus a fonte musical WAV). NÃO aplicar novamente −14 dB ao OGG.
- O arquivo `03_MUSICA/rock_cartoon_divertido_loop_FONTE.wav` e a base musical em volume original; use somente para retomar a mixagem do zero.

## O que este ZIP NÃO É
- Não é o projeto Godot alterado: Claude precisará aplicar as mudanças ao projeto ATUAL.
- Não é um pack de efeitos para spells e eventos globais, ainda não aprovado.
- Não é autorização para alterar os sons aprovados ou criar novos efeitos de sopro.

## Formato
- 27 arquivos WAV individualizados para motor de jogo.
- Música OGG em loop + WAVs de música.
- Demonstrações MP3 de 60 s para comparação A/B e tema original.
- Prompt de implementação + manifest JSON.
