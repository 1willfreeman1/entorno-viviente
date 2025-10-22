# init.ps1 v1.4 (Modo Verbosidad Nativa)

# --- [PARAMETROS DE ENTRADA] ---
param (
    [Parameter(Mandatory=$true)]
    [string]$BaseDirectory
)

# --- [FASE 1: INSTALAR VS CODE PORTÁTIL] ---
Write-Host "`n--- FASE 1: INSTALANDO VISUAL STUDIO CODE (PORTATIL) ---"

$portableAppsDir = Join-Path $BaseDirectory "PortableApps"
$vsCodeDir = Join-Path $portableAppsDir "VSCode"
$vsCodeZipPath = Join-Path $portableAppsDir "vscode.zip"
$vsCodeExePath = Join-Path $vsCodeDir "Code.exe"
$launchpadDir = Join-Path $BaseDirectory "_Launchpad"

try {
    New-Item -Path $portableAppsDir, $launchpadDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    
    if (Test-Path $vsCodeExePath) {
        Write-Host "  └─ VS Code Portatil ya existe. Omitiendo descarga."
    } else {
        $vsCodeUrl = 'https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-archive'
        
        Write-Host "  ├─ Descargando VS Code (portatil)..."
        Invoke-WebRequest -Uri $vsCodeUrl -OutFile $vsCodeZipPath

        Write-Host "  ├─ Descomprimiendo archivos..."
        Expand-Archive -Path $vsCodeZipPath -DestinationPath $vsCodeDir -Force
        
        Write-Host "  └─ Limpiando archivo de descarga..."
        Remove-Item $vsCodeZipPath -Force
    }

    if (Test-Path $vsCodeExePath) {
        $shortcutPath = Join-Path $launchpadDir "VSCode (Portatil).lnk"
        
        Write-Host "  ├─ Creando acceso directo..."
        $wshell = New-Object -ComObject WScript.Shell
        $shortcut = $wshell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $vsCodeExePath
        $shortcut.Description = "VS Code portatil para el Entorno Viviente"
        $shortcut.Save()
        Write-Host "  └─ ÉXITO: VS Code Portatil está listo para usar."
    } else {
        throw "No se encontró el ejecutable de VS Code despues de la extraccion."
    }

} catch {
    Write-Host "ERROR: Fallo la instalacion de VS Code Portatil: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n--- [NÚCLEO FINALIZADO] ---"
