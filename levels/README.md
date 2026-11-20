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
