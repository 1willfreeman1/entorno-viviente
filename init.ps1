# init.ps1 - Script de Inicializacion del Entorno v1.2
# Mision: Instalar una version PORTATIL de VS Code en la carpeta del entorno.
# Recibe el control del Bootstrapper.

# --- [PARAMETROS DE ENTRADA] ---
param (
    [Parameter(Mandatory=$true)]
    [string]$BaseDirectory # Recibimos la ruta del entorno (ej: ...\Desktop\EntornoViviente)
)

function Write-CoreHeader { param ([string]$Title); Write-Host "`n" ; Write-Host "--- [NÚCLEO] $Title ---" -ForegroundColor Yellow }

# --- [FASE 1: INSTALAR VS CODE PORTÁTIL (PRIORIDAD ALTA)] ---
Write-CoreHeader "FASE 1: INSTALANDO VISUAL STUDIO CODE (PORTATIL)"

$portableAppsDir = Join-Path $BaseDirectory "PortableApps"
$vsCodeDir = Join-Path $portableAppsDir "VSCode"
$vsCodeZipPath = Join-Path $portableAppsDir "vscode.zip"
$vsCodeExePath = Join-Path $vsCodeDir "Code.exe"
$launchpadDir = Join-Path $BaseDirectory "_Launchpad"

try {
    # Crear directorios necesarios
    New-Item -Path $portableAppsDir, $launchpadDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    
    # Comprobar si ya existe
    if (Test-Path $vsCodeExePath) {
        Write-Host "  └─ [OK] VS Code Portatil ya existe en la ubicacion correcta."
    } else {
        $vsCodeUrl = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-archive"
        
        Write-Host "  ├─ 📥 Descargando VS Code (portatil)..."
        Invoke-WebRequest -Uri $vsCodeUrl -OutFile $vsCodeZipPath

        Write-Host "  ├─ 📦 Descomprimiendo archivos..."
        Expand-Archive -Path $vsCodeZipPath -DestinationPath $vsCodeDir -Force
        
        Write-Host "  └─ 🧹 Limpiando archivo de descarga..."
        Remove-Item $vsCodeZipPath -Force
    }

    # Verificacion final y creacion del acceso directo
    if (Test-Path $vsCodeExePath) {
        $shortcutPath = Join-Path $launchpadDir "VSCode (Portatil).lnk"
        
        Write-Host "  ├─ 🔗 Creando acceso directo en el Launchpad..."
        $wshell = New-Object -ComObject WScript.Shell
        $shortcut = $wshell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $vsCodeExePath
        $shortcut.Description = "VS Code portatil para el Entorno Viviente"
        $shortcut.Save()
        Write-Host "  └─ ✅ [ÉXITO] VS Code Portatil está listo para usar." -ForegroundColor Green
    } else {
        # Si la extraccion falla o el exe no esta donde deberia
        throw "No se encontró el ejecutable de VS Code despues de la extraccion."
    }

} catch {
    Write-Host "  └─ ⛔ [ERROR] Fallo la instalacion de VS Code Portatil: $($_.Exception.Message)" -ForegroundColor Red
}

Write-CoreHeader "Inicializacion finalizada. Proximos pasos se añadiran aqui."
