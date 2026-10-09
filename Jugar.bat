@echo off
rem Lanza "El Despacho" con Godot 4.7.
rem Busca el ejecutable en %USERPROFILE%\Godot y, si no esta, en la carpeta de Descargas.
cd /d "%~dp0"
set "GODOT="
for %%F in ("%USERPROFILE%\Godot\Godot_v4*_win64.exe") do set "GODOT=%%~fF"
if not defined GODOT (
    for /r "%USERPROFILE%\Downloads" %%F in (Godot_v4*_win64.exe) do if not defined GODOT set "GODOT=%%~fF"
)
if not defined GODOT (
    echo No se encuentra Godot 4.7 ni en %USERPROFILE%\Godot\ ni en Descargas.
    echo Descargalo de https://godotengine.org, abre project.godot y pulsa F5.
    pause
    exit /b 1
)
rem Sin importar no cargan la musica, los sonidos, las fuentes, los mapas ni los personajes 3D. Se importa la primera
rem vez y tambien cuando hay recursos nuevos o cambiados (por ejemplo, personajes nuevos de Blender en art\characters)
rem o falta alguno importado: si no, el juego usaria los de antes y algunos escenarios no funcionarian bien.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s='.godot\imported\.importado'; if (-not (Test-Path $s)) { exit 1 }; $t=(Get-Item $s).LastWriteTime; $nuevo=Get-ChildItem art,audio,fonts,icon.svg -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -ne '.import' -and $_.LastWriteTime -gt $t } | Select-Object -First 1; if ($nuevo) { exit 1 }; foreach ($f in Get-ChildItem art,audio,fonts -Recurse -File -Filter *.import -ErrorAction SilentlyContinue) { foreach ($m in Select-String -Path $f.FullName -Pattern '^path=.res://(.+).$') { if (-not (Test-Path $m.Matches[0].Groups[1].Value)) { exit 1 } } }; exit 0"
if errorlevel 1 (
    echo Preparando los recursos del juego, un momento...
    start "" /wait "%GODOT%" --headless --path "%~dp0." --import
    if exist ".godot\imported" type nul > ".godot\imported\.importado"
)
start "" "%GODOT%" --path "%~dp0."
