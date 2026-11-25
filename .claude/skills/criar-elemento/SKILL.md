---
name: criar-elemento
description: "Criar ou corrigir um ELEMENTO do jogo — spell, evento especial, perigo/mecanismo/armadilha ou skin — e autorizá-lo nos mapas/cenas certos. Use quando o usuário pedir spell nova, evento novo, máquina/armadilha nova, skin, ou levar um elemento de um mapa para outro."
---

# Criar elemento — roteamento

1. Abra `docs/manuais/README.md` §1 e siga a linha do pedido:
   spell → `spells.md` + `derruba/spell.md` · evento → `eventos.md` + `derruba/evento.md` ·
   perigo/mecanismo → `perigos_mecanismos.md` + `derruba/perigos_mecanismos.md` · skin → `skins.md` (só documentar: o recurso
   ainda não está autorizado) · robô → `personagem.md`.
2. Leia `docs/manuais/sistema_criacao.md` (definição × origem × autorização × instância; estados).
3. Classes de spell são do MODO; disponibilidade é do MAPA (`spells_permitidas`); eventos por mapa E cena
   (`cenas[].eventos`); perigos/mecanismos são instâncias da cena (`cenas[].mecanismos`) e nascem no desenho da cena.
4. Fluxo: ficha → arte estática (aprovação) → animação em movimento (aprovação) → código → testes (`--so=spells|eventos|
   mecanismos|mapa`) → aprovação final → registrar o estado na biblioteca do mapa e as lições no manual.
