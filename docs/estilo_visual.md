# Estilo visual — cartoon vetorial próximo das referências

> **Atual (2026-11-24) — vale por cima do resto deste arquivo:** personagens e cenário são **papel e giz** (formas recortadas
> sem contorno preto, textura de giz/rabisco, bordas tremidas, sombra de um lado), decidido com o usuário em 2026-11-20 a partir
> das refs 2–4. **Contorno grosso só na interface** (`game/ui/kit.gd`). Robôs: 8 modelos só de aparência, sem acessórios
> (`.claude/skills/personagens-e-acessorios`). Não há mais peças com dono nem "cor do dono"; os mapas Andaimes/Cais Noturno
> viraram 12 temas (`art/src/cenarios/temas*.py`). O resto abaixo é a v2 original, para consulta das referências.

**Meta:** quem olhar uma captura de Bota-Abaixo ao lado das referências deve achar que é "da mesma família": mesmo traço, mesmas formas gordinhas, mesma vivacidade. **Personagens, emblemas e nomes são nossos.**

## O que tirar de cada referência (`docs/referencias/`)
| Referência | Pegar | Onde usar |
|---|---|---|
| `ref1_battleblock_theater.png` | blocos-cubo gordinhos com **bisel** (topo claro, lateral escura, frente na cor base), contorno escuro grosso; cores saturadas laranja/magenta/dourado; fundo turquesa com formas brancas grandes e suaves; **silhuetas escuras de plateia** na borda inferior; nuvens de poeira marrons e arredondadas; estrelinhas de brilho; "+1" flutuante na cor do jogador; personagens de cabeça grande e corpo pequeno | mapa Canteiro, poeira, pontuação flutuante, proporção dos robôs |
| `ref2_cartoon_gelo_explosao.png` | blocos de vidro/gelo com **miolo em células** e **aro branco grosso**; plataformas em pílula; **explosões cartoon** (nuvem amarela e laranja com fumaça escura contornada em camadas); céu noturno com aurora verde; reflexo na água | mapa Cais Noturno, explosões (dinamite, eliminação, bola de demolição) |
| `ref3_heave_ho.png` | céu ciano pastel, nuvens brancas fofas, montanhas nevadas em silhueta, plataformas chapadas com **textura de manchas de tinta**, **espinhos cinza triangulares**, bandeira quadriculada | mapa Andaimes, linguagem dos espinhos e perigos fixos |
| `ref4_ultimate_chicken_horse.png` | personagens fofos de contorno fino, expressões exageradas, **acessórios divertidos**, fundos em tons quentes dessaturados, peças de cenário cheias de personalidade | carisma dos robôs, acessórios, tela de título e de escolha |

## Regras gerais
- **Contorno escuro** em tudo que é jogável: 6 px em personagens, 5 px em blocos e peças (a 1080p); fundo sem contorno ou com contorno fino e claro.
- **Formas gordinhas e arredondadas**; cantos com raio de ~10–20% do tamanho.
- **Sombra chapada** de 1 tom (sem degradê); **brilho** chapado branco em semicírculo/risco. Degradê só no céu.
- **Primeiro plano saturado, fundo dessaturado e mais claro** (o jogável sempre salta).
- **Perigo** = forma serrilhada/espinhos cinza-escuro com detalhe vermelho; nunca usar o vermelho de perigo em outra coisa.
- **Cor do dono** em toda peça: faixa grossa + ícone do símbolo do jogador.

## Robôs
- Corpo em formato de feijão/cápsula, **inteiro na cor do jogador** (como os personagens da ref. 1), cabeça grande (≈ 60% da altura), olhos ovais brancos enormes com pupila preta, boca/visor expressivo, braços curtos, pés redondos, marreta exagerada.
- Cores de jogador: P1 azul `#2f8ff0`, P2 verde `#5fd35f`, P3 rosa `#ff6fb5`, P4 amarelo `#ffd23f` + símbolo no peito (● ▲ ■ ◆). Perigo: `#d42035` (verificado contra as 4 cores na v1).
- **Expressões** (trocar olhos/boca): normal, esforço (pulo), susto (queda/perto de perigo), vitória, eliminado (olhos em X).
- **Acessórios** (8 na demo, escolhidos na entrada): capacete de obra, boné virado, gorro com pompom, chapéu de cowboy, coroa de papel, óculos de solda, bigode, cone de trânsito na cabeça. Presos ao ponto da cabeça; acompanham squash/stretch.
- **Animação cut-out** (partes separadas animadas na Godot): idle (balanço), corrida (pés + squash), pulo (stretch), queda, aterrissagem (squash), parede, marretada, eliminação (desmonta em peças), vitória.

## Mapas
- **Canteiro (ref. 1):** céu turquesa `#3aa7a3` com formas brancas grandes e suaves; blocos laranja `#e0894a` e magenta `#d9567f` com bisel; blocos dourados especiais com emblema **próprio** (capacete de obra); plateia de operários em silhueta escura na base; chão de "lama roxa" ondulada.
- **Andaimes (ref. 3):** céu `#a6ecfa`, nuvens brancas, montanhas nevadas, pilares rosa/vinho chapados com manchas de tinta, espinhos cinza.
- **Cais Noturno (ref. 2):** céu azul-escuro com aurora verde; blocos de vidro/gelo em células com aro branco; plataformas em pílula; água com reflexo espelhado e ondulações.

## Efeitos
Poeira marrom arredondada (pulo, aterrissagem) · estrelinhas brancas (marretada, coleta) · **explosão cartoon** amarela/laranja com fumaça escura contornada (dinamite, eliminação) · "+3" e "+10" flutuantes na cor do jogador · confete na vitória · tremor de tela leve (desligável).

## Processo (para os artistas)
1. Fonte em **SVG** (escrito à mão ou gerado por script Python) em `art/src/`. A Godot importa SVG direto.
2. Para olhar: rasterize com o que existir (`rsvg-convert`, Inkscape, `cairosvg`); se não houver nada, gere também uma versão com Pillow em 4× e reduza (antisserrilhado). **Abra e olhe sempre.**
3. **Comparação lado a lado:** monte `art/out/comparacao_<item>.png` com a referência à esquerda e o nosso à direita; anote 3–5 diferenças de estilo e corrija. Até 3 rodadas.
4. Teste em contexto: robôs sobre o cenário do mapa, nunca só em fundo neutro.
