@echo off
rem Gera o Bota-Abaixo.exe no Windows com a SUA Godot (4.5 ou mais nova: controles via SDL3, DualShock/DualSense funcionam).
rem 1) Na Godot: Editor > Gerenciar Modelos de Exportacao > Baixar e Instalar (uma vez so).
rem 2) Ajuste a linha GODOT abaixo para o caminho do seu Godot .exe e de dois cliques neste arquivo.
set GODOT=C:\Godot\Godot_v4.7.1-stable_win64.exe
cd /d "%~dp0"
if not exist "%GODOT%" (
  echo Nao achei a Godot em %GODOT% - edite a linha GODOT deste arquivo.
  pause
  exit /b 1
)
rem mapas e regras ficam fora do projeto: copia para dentro so durante a exportacao
if exist game\data rmdir /s /q game\data
if exist game\levels rmdir /s /q game\levels
xcopy /e /i /q data game\data > nul
xcopy /e /i /q levels game\levels > nul
if not exist out\build\windows mkdir out\build\windows
"%GODOT%" --headless --path game --import
"%GODOT%" --headless --path game --export-release "Windows" ..\out\build\windows\Bota-Abaixo.exe
rmdir /s /q game\data
rmdir /s /q game\levels
echo.
echo Pronto: out\build\windows\Bota-Abaixo.exe
pause
