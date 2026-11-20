# Mapas em texto

A Godot monta o mapa a partir destes arquivos: assim, mudar um mapa é editar texto. Grade de 30×16 tiles de 64 px.

```
id: canteiro
size: 30x16
spawns: 1,2,3,4
legend: "# = sólido, = = one-way, ^ = espinho, o = andaime (sólido), I = parede invisível, 1-4 = spawn, E = elevador, x = proibido construir, . = vazio"
tema: canteiro
=== map
(16 linhas de 30 caracteres)
```
Regras: spawns e elevador sobre sólido; `x` em volta (2 tiles) de spawns e do elevador; a rota sem peças deve ser fácil. Exemplo completo: `levels/exemplo.lvl`.

## Arenas da Demolição (cabeçalho "chave: valor" antes de `=== map`)
- Novos caracteres: `d` caixote destrutível · `T` TNT (explode em cadeia) · `<` `>` esteira (sólida, carrega quem está em cima).
- `terremoto: 30` (0 desliga) · `fundo: #rrggbb` (tom do céu)
- `esteira_vel: 3.2` (tiles/s) · `esteira_inverte: 7` (s; pisca 1,2 s antes)
- `plataformas: x,y,largura,dx,dy,periodo; ...` (tiles; vão e voltam)
- `mare_inicio: 6` · `mare_vel: 0.24` · `mare_topo: 2.6` (lama sobe)
- `bola: pivo_x,pivo_y,comprimento,amplitude_graus,periodo`
Nome e dica de cada arena: `data/modos.json` → `demolicao.arenas`.
