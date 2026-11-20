---
name: cenarios-e-pecas
description: "Cenários, blocos, peças e efeitos de Bota-Abaixo em cartoon vetorial: kit de blocos com bisel por mapa, fundos em camadas (Canteiro, Andaimes, Cais Noturno), 12 peças com estado dono/rival e efeitos (poeira, explosão cartoon, +pontos). Use para qualquer arte de cenário, peça ou efeito."
---

# Cenários, peças e efeitos

## Kit de blocos por mapa (módulos de 64 px)
Para cada tema: bloco simples, bloco de borda (topo/lados), canto, bloco especial; one-way; espinho. Encaixe sem emendas quando lado a lado (teste num bloco 6×3 e num "L").
- Canteiro (ref. 1): cubos com bisel laranja/magenta, especial dourado com emblema **próprio** (capacete).
- Andaimes (ref. 3): pilares chapados com manchas de tinta, plataformas planas com grama/neve, espinhos cinza.
- Cais Noturno (ref. 2): blocos de vidro/gelo em células com aro branco grosso; plataformas em pílula.

## Fundos (3 camadas, sem contorno ou com contorno claro)
céu → elementos distantes → elementos médios; contraste menor que o jogável. Canteiro: turquesa com formas brancas + plateia em silhueta na base. Andaimes: céu pastel, nuvens, montanhas nevadas. Cais Noturno: céu escuro com aurora e água refletindo.

## Peças (12, `data/pieces.json`)
Cada uma com: estado rival (perigo exposto ou obstáculo) e estado dono (dentes recolhidos, setas a favor etc.), **faixa grossa na cor do dono** e ícone do símbolo. Perigos com serrilhado cinza-escuro e detalhe vermelho `#d42035`. Comece pelas P01–P04 (Marco 1).

## Efeitos
Poeira marrom arredondada (ref. 1) · estrelinhas · explosão cartoon amarela/laranja com fumaça escura contornada (ref. 2) · "+pontos" na cor do jogador · confete. Desenhe 3–6 quadros por efeito ou partes para animar na Godot.

## Checagem
Tela 1920×1080 com mapa + 4 robôs + todas as peças: comparação com a referência do mapa, perigo óbvio, dono identificável, sem emendas.
