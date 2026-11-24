# Manuais de criação — Bota-Abaixo

Passo a passo **obrigatório** para criar coisas novas no jogo. Toda sessão (inclusive outro Claude ou outra conta) que for
criar um destes itens **lê o manual antes de começar** e segue a ordem dele. Os manuais saíram do que deu certo (e do que
o usuário reprovou) nas entregas de 2026-11-24.

| Vai criar… | Manual | Vale para |
|---|---|---|
| Um robô (personagem jogável) | [`personagem.md`](personagem.md) | o jogo todo (todos os modos) |
| Uma spell (item da caixa) | [`derruba/spell.md`](derruba/spell.md) | modo **Derruba** |
| Um evento global | [`derruba/evento.md`](derruba/evento.md) | modo **Derruba** |
| Uma fase (mapa) | [`derruba/mapa.md`](derruba/mapa.md) (passo a passo) + [`derruba/mapa_cartilha.md`](derruba/mapa_cartilha.md) (regras: cena viva em etapas, C0–C4, Z1–Z8). Catálogos: `docs/fases/derruba/`. Skill: `criar-fase` | modo **Derruba** |

## Regras que valem para os três
1. **Aprovação antes de código grande.** Arte e comportamento novos começam por uma prancha (imagem) ou descrição curta
   para o usuário aprovar. Retrabalho custa mais do que uma pergunta.
2. **Números no `data/*.json`**, nunca fixos no código (CLAUDE.md).
3. **Arte em papel e giz** gerada por Python/SVG (`art/src/…`), sem IA de imagem. Gere, **abra a imagem e olhe** antes de seguir.
4. **Teste só a parte mexida** (`--autotest --so=<nome>`) durante o trabalho; bateria completa 1× no fim.
5. **Entrega:** GIF curto do que mudou + `.exe` (`GODOT=… tools/exportar.sh`, zip em `out/`) + relatório de até 15 linhas.
6. **Commit e push** no fim de cada etapa que funciona; atualize "Retomar aqui" em `docs/ESTADO.md`.
7. **Manual é vivo:** se o usuário aprovar um jeito novo ou reprovar algo, **atualize o manual no mesmo commit**
   (seção "Lições" de cada um).

## Comandos de referência
```
G=/caminho/Godot_v4.7.1-stable_linux.x86_64
$G --headless --path game --import                                   # depois de PNG novo
$G --headless --path game --fixed-fps 60 -- --autotest --so=robos     # testes de uma parte
xvfb-run -a -s "-screen 0 1920x1080x24" $G --path game --fixed-fps 60 --resolution 1920x1080 -- --elenco=DIR   # vitrines
```
