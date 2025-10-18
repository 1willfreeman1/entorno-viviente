<#
.SYNOPSIS
    (MAESTRO v5.6 - Bootstrap Autónomo) Resuelve el problema del "huevo y la gallina" al instalar una versión mínima
    de Git antes de cualquier otra operación.
.DESCRIPTION
    Esta es la versión más autónoma. Si 'git' no se encuentra en el sistema, el script ahora realiza un "bootstrap":
    descarga y activa una versión portátil de Git para su propio uso. Esto le permite clonar el repositorio fuente,
    leer la configuración y luego proceder con la instalación normal. El script ahora puede ejecutarse en una
    máquina completamente limpia.
#>

# La declaración de parámetros DEBE ser la primera línea de código ejecutable.
param([int]$RetryCount = 0)

#region --- CONFIGURACIÓN Y VALORES POR DEFECTO ---
$scriptVersion = "5.6 - Bootstrap Autónomo"
$defaultGeminiApiKey = 'AIzaSyCi-syNg5XQFC8KWpD3TwmXkSbqJEEhOc' # <-- ¡¡REEMPLAZA ESTA CLAVE!!

# URLs clave del proyecto (rama 'master')
$gitRepoUrl = "https://github.com/1willfreeman1/entorno-viviente.git"
$rawScriptUrl = "https://raw.githubusercontent.com/1willfreeman1/entorno-viviente/master/Install-Environment-PROD.ps1"

# Definición del paquete de Bootstrap: Git Portable. Esencial para el primer arranque.
$gitBootstrapPackage = @{ Name = "Git Portable Bootstrap"; Url = "https://github.com/git-for-windows/git/releases/download/v2.46.0.windows.1/PortableGit-2.46.0-64-bit.7z.exe"; FileName = "git_bootstrap.7z.exe"; ExePathInZip = "bin/git.exe" }

$theme = @{ Header="White"; Section="Cyan"; Running="Yellow"; Success="Green"; Failure="Red"; Info="Gray"; Warning="Magenta"; Skip="Blue" }
$statusSymbols = @{ Running = "[⏳]"; Success = "[✓]"; Warning = "[⚠]"; Failure = "[✗]"; Info = "[-]"; Skip = "[»]" }
#endregion

#region --- INICIALIZACIÓN Y FUNCIONES ---
$ErrorActionPreference = 'Stop'
$desktopPath = [System.Environment]::GetFolderPath('Desktop')
$systemFolderPath = Join-Path $desktopPath -ChildPath ".environment_system"
$cachePath = Join-Path $systemFolderPath "Portable_App_Cache"
$sourcePath = Join-Path $systemFolderPath "source"
$configPath = Join-Path $sourcePath "config.json"
$masterScriptPath = Join-Path $sourcePath "Install-Environment-PROD.ps1"
$executionLogPath = Join-Path $systemFolderPath "Execution-Log-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
$lockFilePath = Join-Path $systemFolderPath ".lock"

function Log-Task($Message, $Status = 'Info', $IndentLevel = 0) { #... (Sin cambios)
    $indent = " " * ($IndentLevel * 3)
    $symbol = $statusSymbols[$Status]
    $color = if ($theme.ContainsKey($Status)) { $theme[$Status] } else { $theme['Info'] }
    Write-Host "$indent$symbol $Message" -ForegroundColor $color
    Add-Content -Path $executionLogPath -Value ("[$([string](Get-Date -Format 'HH:mm:ss'))] [$Status.ToUpper()] $indent $Message")
}
$geminiApiKey = if ($env:GEMINI_API_KEY) { $env:GEMINI_API_KEY } else { $defaultGeminiApiKey }
# ... (Resto de funciones auxiliares)
#endregion

# --- LÓGICA DE EJECUCIÓN DEL MAESTRO (Gatekeeper) ---
if ($MyInvocation.MyCommand.Path -eq $masterScriptPath) {
    #... (Sin cambios)
}

# --- LÓGICA DE EJECUCIÓN PRINCIPAL ---
$summary = [ordered]@{ "Status" = "In Progress"; "StartTime" = Get-Date; Actions = @(); Warnings = @(); Errors = "" }
try {
    #region --- FASE 1: VERIFICACIÓN, BOOTSTRAP Y CONFIGURACIÓN ---
    @($systemFolderPath, $cachePath) | ForEach-Object { New-Item $_ -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }
    Write-Host ("-" * 70); Write-Host " ORGANISMO DE INSTALACIÓN v$scriptVersion" -ForegroundColor $theme['Header']; Write-Host ("-" * 70)
    
    if (Test-Path $lockFilePath) { throw "Ya hay una instancia del script en ejecución." }
    New-Item $lockFilePath -ItemType File | Out-Null

    Write-Host "`n--- FASE 1: VERIFICACIÓN, BOOTSTRAP Y CONFIGURACIÓN ---" -ForegroundColor $theme['Section']
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw "Winget no está instalado." }
    if (-not (Test-Connection "github.com" -Count 1 -Quiet)) { throw "No hay conexión a internet." }
    Log-Task "Verificaciones de prerrequisitos superadas." 'Success' 1
    
    # --- MECANISMO DE BOOTSTRAP ---
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Log-Task "El comando 'git' no se encuentra." 'Warning' 1
        Log-Task "Iniciando bootstrap para instalar una versión portátil de Git..." 'Running' 2
        $bootstrapDir = Join-Path $systemFolderPath "git_bootstrap"
        $bootstrapGitExe = Join-Path $bootstrapDir "bin"
        
        if (-not (Test-Path $bootstrapGitExe)) {
            $bootstrapCacheFile = Join-Path $cachePath $gitBootstrapPackage.FileName
            if (-not (Test-Path $bootstrapCacheFile)) {
                Log-Task "Descargando Git Portable..." 'Running' 3
                Invoke-WebRequest -Uri $gitBootstrapPackage.Url -OutFile $bootstrapCacheFile
            }
            Log-Task "Extrayendo Git Portable..." 'Running' 3
            Start-Process -FilePath $bootstrapCacheFile -ArgumentList "-o`"$bootstrapDir`" -y" -Wait
        }
        
        Log-Task "Añadiendo Git al PATH para la sesión actual..." 'Action' 3
        $env:PATH = "$bootstrapGitExe;" + $env:PATH
        Log-Task "Bootstrap de Git completado. El comando 'git' ya está disponible." 'Success' 2
    } else {
        Log-Task "El comando 'git' ya está disponible en el sistema." 'Success' 1
    }

    # --- LÓGICA DE CONFIGURACIÓN (AHORA SEGURA) ---
    if (-not (Test-Path (Join-Path $sourcePath ".git"))) {
        Log-Task "Clonando repositorio fuente..." 'Running' 1
        git clone $gitRepoUrl $sourcePath
    }
    
    try { # Cargar config desde archivo, con fallback a interna
        if (Test-Path $configPath) { $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json; Log-Task "Configuración cargada desde 'config.json'." 'Success' 1 } 
        else { throw "No se encontró 'config.json'." }
    } catch {
        # ... (Lógica de fallback a config interna sin cambios)
    }
    $workspacePath = Join-Path $desktopPath $config.workspaceName
    New-Item $workspacePath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    #endregion

    #region --- FASE 2, 3 Y 4 (Sin Cambios) ---
    # La lógica de descargas paralelas, sincronización idempotente y creación del lanzador
    # funcionará correctamente ahora que la configuración se carga de forma fiable.
    # ...
    #endregion
    
    $summary.Status = "Éxito"
}
catch {
    # --- PROTOCOLO DE REPARACIÓN ADAPTATIVA ---
    $summary.Status = "FALLO"; $summary.Errors = $_.Exception.Message
    Log-Task "¡ERROR CRÍTICO! La sesión ha fallado." 'Failure'; Log-Task "Razón: $($summary.Errors)" 'Info' 1
    # ... (Lógica de auto-reparación sin cambios)
}
finally {
    # --- RESUMEN Y LIMPIEZA ---
    if (Test-Path $lockFilePath) { Remove-Item $lockFilePath }
    # ... (Lógica de resumen final sin cambios)
}
