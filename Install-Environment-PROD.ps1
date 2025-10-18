<#
.SYNOPSIS
    (MAESTRO v4.0 - Autónomo y Sincronizado) Script que instala un entorno, se repara, se actualiza y evoluciona con IA.
.DESCRIPTION
    NO EJECUTAR DIRECTAMENTE. Este es el script de producción que vive en GitHub.
    Al ejecutarse a través del comando de arranque, instala un entorno completo desde un caché local,
    inicia un Guardián en segundo plano para actualizar apps y sincronizarse con Git,
    y se repara a sí mismo de forma autónoma si encuentra errores.
#>

# --- CONFIGURACIÓN ---
$scriptVersion = "4.0 - Autónomo y Sincronizado"
# ¡¡CRÍTICO!! REEMPLAZA ESTA CLAVE por una NUEVA y SECRETA de https://aistudio.google.com/
$geminiApiKey = 'AIzaSyCi3ssyNg5XQFC8KWpD3TwmXkSbqJEEhOc' # <-- REEMPLAZAR!

$workspaceName = "Mi_Entorno_Dev_Portatil"
$gitRepoUrl = "https://github.com/1willfreeman1/entorno-viviente.git" # URL del repositorio que contiene este script

# Tema de colores
$theme = @{ Header="White"; Section="Cyan"; Action="Yellow"; Success="Green"; Error="Red"; Info="Gray" }

# Definición de aplicaciones
$packages = @(
    @{ Name = "VSCode Portable"; Type = "Portable"; Url = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-archive"; FileName = "vscode.zip"; ExePathInZip = "code.exe"; ShortcutName = "VSCode" },
    @{ Name = "Git Portable"; Type = "Portable"; Url = "https://github.com/git-for-windows/git/releases/download/v2.46.0.windows.1/PortableGit-2.46.0-64-bit.7z.exe"; FileName = "git.exe"; ExePathInZip = "git-bash.exe"; ShortcutName = "Git Bash" },
    @{ Name = "Node.js (LTS)"; Type = "Installer"; WingetId = "OpenJS.NodeJS.LTS"; Command = "node" }
)

# --- INICIALIZACIÓN ---
$ErrorActionPreference = 'Stop'
$desktopPath = [System.Environment]::GetFolderPath('Desktop')
$systemFolderPath = Join-Path -Path $desktopPath -ChildPath ".environment_system"
$cachePath = Join-Path $systemFolderPath "Portable_App_Cache"
$sourcePath = Join-Path $systemFolderPath "source" # Donde vivirá el clon de Git
$masterScriptPath = Join-Path $sourcePath "Install-Environment-PROD.ps1"
$sessionScriptPath = Join-Path $desktopPath "Install-Environment-SESSION.ps1"

# --- FUNCIONES AUXILIARES ---
# ... (Log-Action, New-Shortcut, Invoke-GeminiForAnalysis, etc.) ...
function Log-Action($message, $style, $logPath) { Write-Host $message -ForegroundColor $theme[$style]; if ($logPath) { Add-Content -Path $logPath -Value ("[\$(Get-Date -Format 'HH:mm:ss')] [\$style.ToUpper()] \$message") } }
function New-Shortcut($targetPath, $shortcutPath) { $shell = New-Object -ComObject WScript.Shell; $shortcut = $shell.CreateShortcut($shortcutPath); $shortcut.TargetPath = $targetPath; $shortcut.Save() }
function Invoke-GeminiForFix($ApiKey, $FaultyCode, $ErrorMessage) {
    $uri = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$ApiKey"
    $prompt = "Tu única tarea es corregir el script de PowerShell basándote en el error. REGLAS: Tu única salida debe ser el CÓDIGO PowerShell COMPLETO y CORREGIDO. NO incluyas explicaciones ni markdown. --- SCRIPT --- `n$FaultyCode`n --- ERROR --- `n$ErrorMessage"
    $body = @{ contents = @(@{ parts = @(@{ text = $prompt }) }) } | ConvertTo-Json
    try { return (Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json" -TimeoutSec 180).candidates[0].content.parts[0].text }
    catch { return $null }
}

# --- LÓGICA DE EJECUCIÓN DEL MAESTRO (Gatekeeper) ---
# Si se ejecuta el script Maestro directamente, clona a sesión y ejecuta.
if ($MyInvocation.MyCommand.Path -eq $masterScriptPath) {
    Write-Host "Clonando script Maestro (v$scriptVersion) a una nueva sesión de instalación..." -ForegroundColor $theme['Action']
    Get-Content $masterScriptPath | Set-Content -Path $sessionScriptPath
    & $sessionScriptPath -RetryCount 0
    exit
}

# --- LÓGICA DE EJECUCIÓN DE SESIÓN O ARRANQUE INICIAL ---
param([int]$RetryCount = 0) # Parámetro para el bucle de auto-reparación

$timestamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$summary = [ordered]@{ "Status" = "In Progress"; "Start Time" = Get-Date; "Actions" = @(); "Errors" = "" }

try {
    # BANNER DE INTRODUCCIÓN
    Write-Host "=======================================================" -ForegroundColor $theme['Info']
    Write-Host "  ORGANISMO DE INSTALACIÓN v$scriptVersion" -ForegroundColor $theme['Header']
    Write-Host "=======================================================" -ForegroundColor $theme['Info']
    @"
 ÍNDICE DE CARACTERÍSTICAS:
 - Instalación Autónoma y Desatendida sin Elevación de Privilegios.
 - Prioridad a Aplicaciones Portables con gestión de Caché local.
 - Auto-Reparación Autónoma: Si falla, la IA corrige el script y reintenta automáticamente.
 - Guardián en Segundo Plano: Actualiza apps y sincroniza el script con GitHub.
 - Evolución por IA: Comandos 'gem' y 'gemscript' para interactuar y modificar el sistema.
 - Sistema de Registros: Historial de versiones y logs detallados de cada ejecución.
"@ | Write-Host -ForegroundColor $theme['Info']

    @"

 DIAGRAMA DEL SISTEMA DE ARCHIVOS:
 /Escritorio/
 |-- 📂 .environment_system/            (El cerebro del sistema)
 |   |-- 📂 Portable_App_Cache/         (Almacén de instaladores)
 |   |-- 📂 source/                     (Copia local del repositorio de GitHub)
 |   |-- 📂 logs/                       (Registros de ejecución y errores)
 |
 |-- 📂 $workspaceName/    (Tu espacio de trabajo con las apps)
 |
 |-- 📜 Install-Environment-PROD.ps1     (El script Maestro, sincronizado con Git)
"@ | Write-Host -ForegroundColor $theme['Info']

    # Creación de carpetas
    @($systemFolderPath, $cachePath, $sourcePath) | ForEach-Object { if (-not (Test-Path $_)) { New-Item $_ -ItemType Directory | Out-Null } }
    $workspacePath = Join-Path $desktopPath $workspaceName
    if (-not (Test-Path $workspacePath)) { New-Item $workspacePath -ItemType Directory | Out-Null }

    # Bucle de instalación (Lógica de Caché)
    foreach ($pkg in $packages) {
        Log-Action "`n-> Procesando '$($pkg.Name)'..." 'Section' $null
        # ... (Lógica de instalación de Winget y Portable con caché) ...
    }
    
    # POST-INSTALACIÓN: Clonar repo, instalar comandos y lanzar Guardián
    if (-not (Test-Path (Join-Path $sourcePath ".git"))) {
        Log-Action "`n-> Realizando clonación inicial del repositorio fuente..." 'Action' $null
        git clone $gitRepoUrl $sourcePath
        $summary.Actions += "Clonado el repositorio fuente a '$sourcePath'"
    }

    # ... (Instalación de comandos 'gem' y 'gemscript' en $PROFILE) ...

    if (-not (Get-Job -Name "EnvironmentGuardian")) {
        Log-Action "`n-> Lanzando Guardián de Actualizaciones y Sincronización en segundo plano..." 'Action' $null
        Start-Job -Name "EnvironmentGuardian" -ScriptBlock {
            # El código aquí se ejecuta en un proceso separado
            $sourcePathForJob = $using:sourcePath
            while ($true) {
                try {
                    # Sincronizar con Git
                    Set-Location $sourcePathForJob
                    git pull
                    
                    # Lógica de comprobación de versiones de apps (conceptual)
                    # ...
                } catch {}
                Start-Sleep -Hours 6 # Esperar 6 horas
            }
        }
        $summary.Actions += "Lanzado el Guardián en segundo plano."
    }

    $summary.Status = "Éxito"
}
catch {
    # --- BLOQUE DE AUTO-REPARACIÓN AUTÓNOMA ---
    $summary.Status = "FALLO"
    $errorMessage = $_ | Out-String
    $summary.Errors = $errorMessage

    Log-Action "`n=======================================================" 'Error' $null
    Log-Action "❌ ERROR: La sesión falló. Iniciando protocolo de auto-reparación (Intento: $($RetryCount + 1)/3)." 'Action' $null
    
    if ($RetryCount -ge 2) {
        Log-Action "   -> Límite de reintentos alcanzado. Abortando para evitar bucle infinito." 'Error' $null
        throw "Auto-reparación fallida tras 3 intentos. Por favor, revisa el error manualmente."
    }

    $faultyCode = Get-Content $MyInvocation.MyCommand.Path -Raw
    $fixedScriptContent = Invoke-GeminiForFix -ApiKey $geminiApiKey -FaultyCode $faultyCode -ErrorMessage $errorMessage
    
    if ($fixedScriptContent) {
        Log-Action "   -> IA ha generado una solución. Sobrescribiendo script de sesión y reintentando..." 'Action' $null
        $fixedScriptContent | Set-Content -Path $MyInvocation.MyCommand.Path
        Start-Sleep -Seconds 3 # Pequeña pausa
        & $MyInvocation.MyCommand.Path -RetryCount ($RetryCount + 1)
        exit # Salir del script fallido
    } else {
        Log-Action "   -> La IA no pudo generar una solución. Abortando." 'Error' $null
        throw "La IA no pudo proporcionar una corrección. Revisa el error."
    }
}
finally {
    # --- RESUMEN FINAL ---
    # ... (Lógica del resumen final sin cambios, muestra el estado, duración, acciones, etc.) ...
    if ($summary.Status -eq "Éxito") {
        if ($MyInvocation.MyCommand.Path -eq $sessionScriptPath) { Remove-Item $sessionScriptPath -ErrorAction SilentlyContinue }
        Write-Host "`nPara usar los nuevos comandos 'gem' y 'gemscript', ¡CIERRA Y ABRE esta terminal!" -ForegroundColor $theme['Action']
    }
}
