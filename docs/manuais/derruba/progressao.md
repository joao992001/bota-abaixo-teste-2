# Progressão, desbloqueios e online — Derruba (DOCUMENTAÇÃO PARA O FUTURO)

> **Estado:** conceito `APROVADO` pelo usuário em 2026-11-25 **como trava futura**. **Não implementar** contas, travas,
> anfitrião ou online sem nova autorização (o `CLAUDE.md` proíbe online). Hoje: tudo liberado; as telas de seleção podem
> já ter o visual do item bloqueado (prancha), sem usar. Parâmetros com `PROVISÓRIO` ainda serão calibrados.

## 1. Gangorra de recompensas (uma por conta)
- Medidor bipolar único, começa no centro (−100 … +100). Extremo **verde** (destruição baixa) e extremo **vermelho**
  (destruição alta), cada um com uma recompensa surpresa conhecida só pela **categoria**: skin, spell ou
  modificação/evento. **Mapas não entram** neste sorteio.
- A agulha anda nos dois sentidos (não são duas barras). Ao chegar a um extremo: revela um item ainda bloqueado daquela
  categoria, grava na conta, marca **NEW** e sorteia novas categorias.
- Movimento por faixa de destruição (PROVISÓRIO, faixas % a definir): −75 / −35 / −15 / +15 / +35 / +75.
- Apuração: **uma vez por partida** (partida = uma luta). Regras para KO muito cedo e partida "válida": PENDENTE.
- Mostra **só na tela de resultados**, abaixo do vencedor (animação da agulha antes → depois). Nunca no HUD de combate.

## 2. Projetos de Demolição (desbloqueio de MAPAS)
- Pontos de exploração por conta: **+1** por partida válida · **+2** por cena inédita visitada (uma vez por cena).
  Revisitar não dá bônus. (Princípio aprovado; pontos por mapa e anti-farming: PENDENTE.)
- Com pontos suficientes, a conta **escolhe** qual mapa liberar (sem sorteio).
- Cena interna é "descoberta" ao ser visitada (diferente de liberar um mapa).
- Mostra na **seleção de mapas** e na **tela de resultados** (abaixo da gangorra). Nunca no HUD.

## 3. Quem decide o quê (contrato para o online futuro)
| Conteúdo | Online (futuro) | Local (hoje: tudo liberado) |
|---|---|---|
| Mapa da sala | desbloqueios do **anfitrião** | conta responsável pela sessão |
| Spells oferecidas | biblioteca do mapa ∩ desbloqueios do anfitrião ∩ seleção dele | conta responsável |
| Eventos/modificações | idem | conta responsável |
| Regras (vidas etc.) | anfitrião | conta responsável |
| Robô e skin | **cada jogador**, com as skins da **própria** conta | jogadores escolhem; skins da conta responsável |
| Gangorra e exploração | individual por conta | conta responsável |
Usar uma spell do anfitrião **não** a desbloqueia para o convidado.

## 4. Dados a preparar (sem implementar rede/contas)
Perfil local futuro (`user://perfil.json`, versão de esquema): `gangorra` (valor, categorias dos extremos), `desbloqueados`
{spells, eventos, skins, mapas}, `cenas_visitadas` {mapa: [ids]}, `pontos_exploracao`, `ultima_config` {mapa, spells,
eventos, vidas, robôs/skins} (para "Jogar de novo"/"Configurar mapa"). Identificadores estáveis = os ids do manifesto
(`map_id`, `id` das cenas, códigos A##/C##/E##/T##, G##/V##, K#).
