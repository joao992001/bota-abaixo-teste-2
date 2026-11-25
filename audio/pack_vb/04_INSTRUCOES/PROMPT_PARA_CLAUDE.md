# BOTA-ABAIXO — ORDEM DE MODIFICAÇÃO: ÁUDIO APROVADO (PACK VB)

## Contexto, escopo e objetivo
Você (Claude) receberá este ZIP junto com a **versão atual do projeto Godot BOTA-ABAIXO**. Trata-se de MODIFICAR a sonoplastia e a trilha do projeto existente, NÃO reconstruir o jogo nem reimplementar combate, movimentação, câmera, mapas, spells ou eventos. Os efeitos presentes são as REFERÊNCIAS APPROVADAS para a camada de áudio dos movimentos básicos, golpes e eliminações. Não afirme que já estão integrados antes de fazê-lo.

**Critério principal:** a experiência audível deve corresponder à faixa `01_REFERENCIAS/REFERENCIA_APROVADA_GAMEPLAY_B_MUSICA_DISCRETA.mp3`, com todos os efeitos da demonstração e a música **Rock Cartoon Divertido** em segundo plano. A faixa `REFERENCIA_APROVADA_SOMENTE_SFX.mp3` é a referência para o equilíbrio entre os efeitos. As duas são a MESMA timeline simulada; apenas a música foi adicionada em B.

## NÃO alterar sem necessidade
- Preservar o controlador, animações, input bindings, física, Amassômetro, combate, cenários, spells, bots e multiplayer local que existem no projeto atual.
- Antes de substituir arquivos existentes, identificar onde são chamados, seus IDs de eventos, caminhos, volumes e buses; manter backup/possibilidade de reversão.
- Não adicionar nenhum efeito de sopro, vento artificial contínuo ou um som independente no voo de arremesso. Os antigos packs de arremesso foram REPROVADOS.
- Não usar o MP3 de gameplay como música de fundo: **é apenas demonstração composta de gameplay**.
- Não inventar SFX novos para as 26 spells ou 12 eventos nesta tarefa. Eles terão pacotes próprios futuramente; manter seus sons existentes se não forem do escopo aprovado.

## Arquivos
- `02_SFX/movimento/`: passos 01-04; salto 01-02; salto duplo 01-02; aterrissagem leve/pesada; dash solo/aéreo; esquiva solo/aérea.
- `02_SFX/combate/`: marreta rápida/pesada sobre estrutura; 5 impactos rápidos e 4 pesados contra robôs.
- `02_SFX/eliminacao/explosao_fora_arena_padrao.wav`: usar apenas na eliminação por saída definitiva da arena. Há uma versão longa OPCIONAL; não tocar ambas.
- `03_MUSICA/rock_cartoon_divertido_BG_APROVADO.ogg`: loop de música já reduzido ao volume aproximado da referência B, ponto de partida para uso no jogo.
- `03_MUSICA/rock_cartoon_divertido_BG_APROVADO.wav`: equivalente WAV.
- `03_MUSICA/rock_cartoon_divertido_loop_FONTE.wav`: fonte sem atenuação, apenas para eventual retrabalho; NÃO inserir diretamente em volume normal como música de gameplay.
- `04_INSTRUCOES/manifest.json`: mapeamento de origem, eventos e notas para cada arquivo.

## Ordem de trabalho no projeto ATUAL
1. **Auditoria**: localizar e registrar autoload de áudio, AudioStreamPlayer/AudioStreamPlayer2D, Audio Buses, fontes musicais, funções de animação de personagens, sinais de hit/KO, e áudio já existente; conferir versão real do projeto. Preservar as integrações funcionais.
2. **Criar/importar biblioteca** organizada em `res://audio/bota_aprovado/` ou equivalente consistente com as convenções do projeto, mantendo as ações e IDs existentes. Referências MP3 não precisam ser distribuídas como assets de runtime.
3. **Ligar eventos de jogo a áudio verdadeiro**: passos em contato real dos pés com o chão e com limitação por cadência; primeiro salto; salto duplo quando ocorrer a segunda ação; aterrissagem ao pousar; dash/esquiva na ativação; golpe rápido/pesado **somente em impacto confirmado**, com variações conforme alvo; colisão extra com superfície apenas se o robô realmente colidir; off-map KO dispara UMA explosão exatamente ao se confirmar a eliminação e/ou no frame correto da animação.
4. **Separar swing de hit**: erros ou golpes no vazio NÃO tocam um clang de acerto; se o jogo já tiver som de swing discreto adequado, deixar separado e subordinado, nunca criar ruído soprando.
5. **Evitar dupla reprodução**: quando dash e esquiva representam a mesma ação, só um gatilho; quando marreta acerta robô, utilizar efeito `impacto_robo_*`, sem sobrepor no mesmo frame outra marreta cheia. Eventos simultâneos precisam respeitar polifonia e prioridade.
6. **Criar mixagem adaptativa**: Music separado de SFX; prioridade alta para impactos e explosões; passos quase imperceptíveis, mas presentes; música muito discreta. **Importante**: `BG_APROVADO.ogg` JÁ tem aproximadamente −25,6 dB em relação à fonte limpa (automação mediana da prévia + atenuação B de −14 dB). Comece reproduzindo no bus Music em ganho neutro próximo de 0 dB e ajuste AUDITIVAMENTE até coincidir com `REFERENCIA_APROVADA_GAMEPLAY_B_MUSICA_DISCRETA.mp3`; não aplicar mais −14 dB à faixa BG por engano. Se optar pela fonte não atenuada, configurar no bus ganho aproximadamente −25,6 dB como ponto inicial. A redução de −14 dB aprovada foi RELATIVA à mixagem anterior, não um volume absoluto. Fazer breve ducking de música nas explosões, sem mudar o ganho dos golpes.
7. **Loop musical de verdade**: usar arquivo OGG `rock_cartoon_divertido_BG_APROVADO.ogg` em loop contínuo, ajustar eventuais cliques na transição. Nunca tocar a simulação de gameplay de 60 s como loop do jogo.
8. **Configurações**: respeitar controles de volume existentes para Música, SFX e Master, se houver; evitar som duplicado entre cenas/respawns; impedir emissão repetida por frame. Permitir silenciar música sem silenciar SFX.
9. **Testes práticos**: testar 2/3/4 jogadores humanos e bots, combates longos, múltiplos golpes, jump 1 e 2, dash solo e aéreo, steps, colidir após arremesso, KO off-map, reinício da rodada, transição de cenas, com e sem música; nenhum áudio deve clipar, mascarar golpes, perder referência espacial ou tocar duas vezes.

## Critérios de aceitação
- [ ] Sons básicos funcionam exclusivamente nos respectivos eventos reais.
- [ ] Quatro jogadores correndo não deixam passos em primeiro plano.
- [ ] Ataques rápidos/pesados são pancadas metálicas convincentes; variações evitam repetição robótica; hits sobre robôs e estruturas são distinguíveis.
- [ ] Voo depois do arremesso não gera áudio adicional artificial.
- [ ] Explosão soa quando o robô é eliminado fora do mapa; não toca em recuperações bem-sucedidas.
- [ ] O Rock Cartoon Divertido está no fundo como no MP3 B aprovado; permite ouvir golpes, explosões e movimento sem disputar volume.
- [ ] O loop não apresenta cliques ou reinicialização musical indesejada.
- [ ] Os demais sistemas e modos do jogo permanecem funcionais.

## Relatório de execução obrigatório
Ao finalizar, entregue uma compilação/versão testável do projeto modificado, uma lista dos arquivos editados, os gatilhos conectados, os parâmetros de áudio e buses escolhidos, evidência dos testes executados e pendências reais. Não declare testes que não executou; se não tiver a versão atual do projeto, solicite acesso ao projeto atual em vez de editar silenciosamente uma versão antiga.
