#!/bin/bash
# Gera o jogo para quem não tem Godot: out/build/windows/Bota-Abaixo.exe (um arquivo só, com ícone),
# out/build/linux/Bota-Abaixo.x86_64 e o instalador out/Instalar-Bota-Abaixo.exe (NSIS).
# Use a MESMA versão da Godot do editor (4.5+: controles via SDL3; DualShock/DualSense funcionam):
#   GODOT=/caminho/do/godot-4.7.1 tools/exportar.sh
# Exporta numa cópia temporária do projeto (a Godot não reescreve os arquivos do repositório).
set -e
GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$ROOT"
tar --exclude=./game/.godot --exclude=./out --exclude=./.git --exclude='*.zip' --exclude=./art/out -cf - . | tar -xf - -C "$TMP"
# mapas e regras ficam fora do projeto Godot: vão para dentro só na cópia
cp -r data "$TMP/game/data"
cp -r levels "$TMP/game/levels"
mkdir -p out/build/windows out/build/linux
"$GODOT" --headless --path "$TMP/game" --import > /dev/null 2>&1 || true
"$GODOT" --headless --path "$TMP/game" --import > /dev/null 2>&1 || true
"$GODOT" --headless --path "$TMP/game" --export-release "Windows" "$ROOT/out/build/windows/Bota-Abaixo.exe"
"$GODOT" --headless --path "$TMP/game" --export-release "Linux" "$ROOT/out/build/linux/Bota-Abaixo.x86_64"
if command -v makensis > /dev/null; then
	makensis -V2 tools/instalador.nsi
fi
ls -la out/build/windows out/build/linux out/*.exe 2>/dev/null || true
