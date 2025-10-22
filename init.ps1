# init.ps1 - Script de Inicialización del Entorno v1.0
# Misión: Instalar herramientas esenciales y configurar el entorno de trabajo.
# Recibe el control del Bootstrapper.

param (
    [Parameter(Mandatory=$true)]
    [string]$BaseDirectory # Recibimos la ruta del entorno (ej: ...\Desktop\EntornoViviente)
)

# --- FASE 2.1: INSTALAR VS CODE PORTÁTIL (PRIORIDAD ALTA) ---
Write-Host "`n--- [NÚCLEO] FASE 2.1: INSTALANDO VS CODE PORTÁTIL ---"

$portableAppsDir = Join-Path $BaseDirectory "PortableApps"
$vsCodeDir = Join-Path $portableAppsDir "VSCode"
$vsCodeZipPath = Join-Path $portableAppsDir "vscode.zip"
$vsCodeExePath = Join-Path $vsCodeDir "Code.exe"
$launchpadDir = Join-Path $BaseDirectory "_Launchpad"

try {
    Write-Host "  ├─ Creando directorios necesarios..."
    New-Item -Path $portableAppsDir -ItemType Directory -Force | Out-Null
    New-Item -Path $launchpadDir -ItemType Directory -Force | Out-Null

    $vsCodeUrl = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-archive"
    Write-Host "  ├─ Descargando VS Code (portátil)..."
    Invoke-WebRequest -Uri $vsCodeUrl -OutFile $vsCodeZipPath

    Write-Host "  ├─ Descomprimiendo archivos..."
    Expand-Archive -Path $vsCodeZipPath -DestinationPath $vsCodeDir -Force
    
    Write-Host "  ├─ Limpiando archivo de descarga..."
    Remove-Item $vsCodeZipPath -Force

    if (Test-Path $vsCodeExePath) {
        Write-Host "  ├─ Creando acceso directo en el Launchpad..."
        $wshell = New-Object -ComObject WScript.Shell
        $shortcut = $wshell.CreateShortcut((Join-Path $launchpadDir "VSCode.lnk"))
        $shortcut.TargetPath = $vsCodeExePath
        $shortcut.Save()
        Write-Host "  └─ ✅ [ÉXITO] VS Code Portátil está listo para usar." -ForegroundColor Green
    } else {
        throw "No se encontró el ejecutable de VS Code después de la extracción."
    }

} catch {
    Write-Host "  └─ ⛔ [ERROR] Falló la instalación de VS Code Portátil: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n--- [NÚCLEO] Inicialización finalizada. Próximos pasos se añadirán aquí. ---"
