# init.ps1 - Script de Inicializacion del Entorno v1.1
# Mision: Instalar herramientas esenciales y configurar el entorno de trabajo.
# Recibe el control del Bootstrapper.

# --- [PARAMETROS DE ENTRADA] ---
param (
    [Parameter(Mandatory=$true)]
    [string]$BaseDirectory # Recibimos la ruta del entorno (ej: ...\Desktop\EntornoViviente)
)

function Write-CoreHeader { param ([string]$Title); Write-Host "`n" ; Write-Host "--- [NÚCLEO] $Title ---" -ForegroundColor Green }

# --- [FASE 2.1: INSTALAR VS CODE PORTÁTIL (PRIORIDAD ALTA)] ---
Write-CoreHeader "FASE 2.1: INSTALANDO VISUAL STUDIO CODE (PORTATIL)"

$portableAppsDir = Join-Path $BaseDirectory "PortableApps"
$vsCodeDir = Join-Path $portableAppsDir "VSCode"
$vsCodeZipPath = Join-Path $portableAppsDir "vscode.zip"
$vsCodeExePath = Join-Path $vsCodeDir "Code.exe"
$launchpadDir = Join-Path $BaseDirectory "_Launchpad"

try {
    # Crear directorios necesarios
    New-Item -Path $portableAppsDir, $launchpadDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    
    if (Test-Path $vsCodeExePath) {
        Write-Host "  └─ ✅ [OK] VS Code Portatil ya existe en la ubicacion correcta."
    } else {
        $vsCodeUrl = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-archive"
        
        Write-Host "  ├─ 📥 Descargando VS Code (portatil)..."
        Invoke-WebRequest -Uri $vsCodeUrl -OutFile $vsCodeZipPath

        Write-Host "  ├─ 📦 Descomprimiendo archivos..."
        Expand-Archive -Path $vsCodeZipPath -DestinationPath $vsCodeDir -Force
        
        Write-Host "  └─ 🧹 Limpiando archivo de descarga..."
        Remove-Item $vsCodeZipPath -Force
    }

    if (Test-Path $vsCodeExePath) {
        Write-Host "  ├─ 🔗 Creando acceso directo en el Launchpad..."
        $wshell = New-Object -ComObject WScript.Shell
        $shortcut = $wshell.CreateShortcut((Join-Path $launchpadDir "VSCode.lnk"))
        $shortcut.TargetPath = $vsCodeExePath
        $shortcut.Save()
        Write-Host "  └─ ✅ [ÉXITO] VS Code Portatil está listo para usar."
    } else {
        throw "No se encontró el ejecutable de VS Code despues de la extraccion."
    }

} catch {
    Write-Host "  └─ ⛔ [ERROR] Fallo la instalacion de VS Code Portatil: $($_.Exception.Message)" -ForegroundColor Red
}

Write-CoreHeader "Inicializacion finalizada. Proximos pasos se añadiran aqui."
