@echo off
rem Lanza "El Despacho" con Godot 4.7 (busca el ejecutable en %USERPROFILE%\Godot)
cd /d "%~dp0"
set "GODOT="
for %%F in ("%USERPROFILE%\Godot\Godot_v4*_win64.exe") do set "GODOT=%%~fF"
if defined GODOT (
    start "" "%GODOT%" --path "%~dp0."
) else (
    echo No se encuentra Godot 4.7 en %USERPROFILE%\Godot\
    echo Descargalo de https://godotengine.org, abre project.godot y pulsa F5.
    pause
)
