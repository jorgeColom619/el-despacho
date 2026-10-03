@echo off
rem Lanza "El Despacho" con Godot 4.7.
rem Busca el ejecutable en %USERPROFILE%\Godot y, si no esta, en la carpeta de Descargas.
cd /d "%~dp0"
set "GODOT="
for %%F in ("%USERPROFILE%\Godot\Godot_v4*_win64.exe") do set "GODOT=%%~fF"
if not defined GODOT (
    for /r "%USERPROFILE%\Downloads" %%F in (Godot_v4*_win64.exe) do if not defined GODOT set "GODOT=%%~fF"
)
if defined GODOT (
    start "" "%GODOT%" --path "%~dp0."
) else (
    echo No se encuentra Godot 4.7 ni en %USERPROFILE%\Godot\ ni en Descargas.
    echo Descargalo de https://godotengine.org, abre project.godot y pulsa F5.
    pause
)
