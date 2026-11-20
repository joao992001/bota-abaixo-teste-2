#!/bin/bash
# Gera o jogo para quem não tem Godot: out/build/windows/Bota-Abaixo.exe (um arquivo só),
# out/build/linux/Bota-Abaixo.x86_64 e o instalador out/Instalar-Bota-Abaixo.exe (NSIS).
# Requer: Godot 4.3 com os modelos de exportação (Windows e Linux) e makensis.
set -e
cd "$(dirname "$0")/.."
# mapas e regras ficam fora do projeto Godot: copia para dentro só durante a exportação
rm -rf game/data game/levels
cp -r data game/data
cp -r levels game/levels
trap 'rm -rf game/data game/levels' EXIT
mkdir -p out/build/windows out/build/linux
godot --headless --path game --import > /dev/null 2>&1 || true
godot --headless --path game --export-release "Windows" ../out/build/windows/Bota-Abaixo.exe
godot --headless --path game --export-release "Linux" ../out/build/linux/Bota-Abaixo.x86_64
if command -v makensis > /dev/null; then
	makensis -V2 tools/instalador.nsi
fi
ls -la out/build/windows out/build/linux out/*.exe 2>/dev/null || true
