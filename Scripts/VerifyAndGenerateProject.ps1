# Verifica el entorno de compilacion y, si es posible, genera la solucion .sln de Astronauta.
# Uso: Scripts\VerifyAndGenerateProject.bat   (o: powershell -ExecutionPolicy Bypass -File Scripts\VerifyAndGenerateProject.ps1)
$ErrorActionPreference = 'Continue'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$UProject = Join-Path $ProjectRoot 'Astronauta.uproject'
$ok = $true

function Pass($m) { Write-Host "[OK]    $m" -ForegroundColor Green }
function Fail($m) { Write-Host "[FALTA] $m" -ForegroundColor Red; $script:ok = $false }
function Info($m) { Write-Host "        $m" }

Write-Host "=== Astronauta: verificacion del entorno ===`n"

# 1. Visual Studio 2022 + MSVC (vswhere)
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$vsPath = $null
if (Test-Path $vswhere) {
    $vsPath = & $vswhere -latest -version '[17.0,18.0)' -products * `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
}
if ($vsPath) {
    Pass "Visual Studio 2022 con MSVC: $vsPath"
    $msvc = Get-ChildItem (Join-Path $vsPath 'VC\Tools\MSVC') -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
    if ($msvc) { Pass "Toolchain MSVC $($msvc.Name)" } else { Fail "No se encontro VC\Tools\MSVC" }
} else {
    Fail "Visual Studio 2022 con el componente C++ (MSVC x64) no esta instalado."
    Info "Instalar con la carga 'Desarrollo de juegos con C++' y 'Desarrollo para el escritorio con C++'."
}

# 2. Windows SDK
$sdk = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\Include" -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
if ($sdk) { Pass "Windows SDK $($sdk.Name)" } else { Fail "Windows 10/11 SDK no encontrado" }

# 3. Unreal Engine 5.4 (registro del Launcher)
$ueRoot = $null
$key = 'HKLM:\SOFTWARE\EpicGames\Unreal Engine\5.4'
if (Test-Path $key) { $ueRoot = (Get-ItemProperty $key -ErrorAction SilentlyContinue).InstalledDirectory }
if (-not $ueRoot) {
    foreach ($c in @("$env:ProgramFiles\Epic Games\UE_5.4", 'D:\Epic Games\UE_5.4', 'E:\Epic Games\UE_5.4')) {
        if (Test-Path $c) { $ueRoot = $c; break }
    }
}
$ubt = if ($ueRoot) { Join-Path $ueRoot 'Engine\Binaries\DotNET\UnrealBuildTool\UnrealBuildTool.exe' }
if ($ubt -and (Test-Path $ubt)) {
    Pass "Unreal Engine 5.4: $ueRoot"
} else {
    Fail "Unreal Engine 5.4 no encontrado."
    Info "Epic Games Launcher -> Unreal Engine -> Biblioteca -> '+' -> 5.4 -> Instalar (~60 GB libres)."
}

# 4. Espacio en disco
$free = [math]::Round((Get-PSDrive (Split-Path -Qualifier $ProjectRoot).TrimEnd(':')).Free / 1GB, 1)
if ($free -ge 20) { Pass "Espacio libre en la unidad del proyecto: $free GB" } else { Fail "Solo $free GB libres (recomendado >= 20 GB para Intermediate/DerivedDataCache)" }

Write-Host ""
if (-not $ok) {
    Write-Host "Faltan requisitos. Corrigelos y vuelve a ejecutar este script." -ForegroundColor Yellow
    exit 1
}

# 5. Generar la solucion y compilar el editor
Write-Host "Generando Astronauta.sln ..."
& $ubt -projectfiles -project="$UProject" -game -engine -progress
if ($LASTEXITCODE -ne 0) { Write-Host "Fallo al generar la solucion (codigo $LASTEXITCODE)." -ForegroundColor Red; exit $LASTEXITCODE }
Pass "Solucion generada: $(Join-Path $ProjectRoot 'Astronauta.sln')"

$build = Join-Path $ueRoot 'Engine\Build\BatchFiles\Build.bat'
Write-Host "`nCompilando AstronautaEditor (Win64 Development) ..."
$log = Join-Path $ProjectRoot 'Saved\Logs\FirstBuild.log'
New-Item -ItemType Directory -Force (Split-Path $log) | Out-Null
& $build AstronautaEditor Win64 Development -Project="$UProject" -WaitMutex 2>&1 | Tee-Object -FilePath $log
if ($LASTEXITCODE -eq 0) {
    Pass "Compilacion correcta. Abre Astronauta.uproject."
} else {
    Write-Host "La compilacion fallo. Pasale a Claude el log: $log" -ForegroundColor Red
    exit $LASTEXITCODE
}
