@echo off
set ROJO_PATH=%LOCALAPPDATA%\Microsoft\WinGet\Packages\Rojo.Rojo_Microsoft.Winget.Source_8wekyb3d8bbwe\rojo.exe

if not exist "%ROJO_PATH%" (
    where rojo >nul 2>nul
    if %ERRORLEVEL% EQU 0 (
        set ROJO_PATH=rojo
    ) else (
        echo [ERROR] No se encontro rojo.exe.
        pause
        exit /b 1
    )
)

echo [ASTRONAUTA] Compilando codigo Luau a Astronauta.rbxl...
"%ROJO_PATH%" build -o Astronauta.rbxl
if %ERRORLEVEL% EQU 0 (
    echo [EXITO] Astronauta.rbxl generado correctamente.
    echo Puedes hacer doble clic en Astronauta.rbxl para abrirlo en Roblox Studio.
) else (
    echo [ERROR] Fallo al compilar el place con Rojo.
)
