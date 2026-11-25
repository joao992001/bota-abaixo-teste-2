# Manual geral — PERIGOS e MECANISMOS (princípios de produção, todos os modos)

**Escopo:** máquinas, armadilhas e pontos de risco das cenas. Implementação no Derruba:
[`derruba/perigos_mecanismos.md`](derruba/perigos_mecanismos.md).

## Definições
- **Mecanismo:** objeto interativo/funcional (pode não oferecer risco). Ex.: elevador de obra.
- **Perigo:** ameaça os personagens, fixo ou acionável. Ex.: vão do piso, água com choque.
- **Mecanismo perigoso:** os dois. Ex.: serra, bate-estaca, vagonete.

## Regras
1. **Nascem no desenho da cena:** os principais já aparecem na **fotografia conceitual** de cada cena (posição e suporte
   físico), antes de codificar. Depois cada um tem arte detalhada, animação, operação, aviso, dano, colisão, interação com
   estruturas, destrutibilidade, estados e testes próprios.
2. **Fisicamente ligados à arquitetura:** apoiados no piso, presos em parede/teto/cano. Nada flutuando no vazio.
3. **O mapa autoriza o tipo e a cena dá a instância** (posição e parâmetros no manifesto). Um tipo existir na biblioteca
   de código não faz ele aparecer em lugar nenhum.
4. Protegem rotas mínimas, áreas de nascimento e legibilidade (perigo lido em 1 s).
5. Não é obrigatório o mesmo número ou o mesmo comportamento em todos os mapas: o conteúdo é artesanal.

## Histórico
- 2026-11-25 — `APROVADO`: instâncias por cena no manifesto do mapa (antes: `demolicao.mecanismos.<cena>` com campo etapa).
