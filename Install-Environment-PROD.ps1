<#
.SYNOPSIS
    Bootstrapper de Entorno Viviente - Version Final Unificada
.DESCRIPTION
    Este es el unico script que gestionaras. Sigue el principio de "Script Masivo".
    Realiza toda la instalacion, crea los archivos de soporte necesarios
    (config.json, sync.ps1), programa la tarea de sincronizacion y ejecuta la primera
    instalacion de software de forma inmediata y visible.
#>

$ErrorActionPreference = 'Stop'
Write-Host "Iniciando despliegue AUTONOMO del Entorno Viviente..."

# --- 1. VERIFICACION E INSTALACION DE GIT ---
Write-Host "[PASO 1/5] Verificando prerrequisito: Git..."
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[INFO] Git no se encuentra. Instalando via winget (puede tardar un minuto)..."
    try {
        winget install --id Git.Git -e --silent --accept-source-agreements --accept-package-agreements
        Write-Host "[SUCCESS] Prerrequisito Git instalado correctamente."
    } catch {
        Write-Host "[FATAL] No se pudo instalar Git. El script no puede continuar."
        exit 1
    }
} else {
    Write-Host "[INFO] Prerrequisito Git ya esta instalado."
}


# --- 2. CREACION DEL ENTORNO PERSISTENTE ---
$baseDir = Join-Path $env:USERPROFILE "Desktop\LivingEnvironment"
$syncRepoDir = Join-Path $baseDir "source" # Donde vivira el script guardian y su config
Write-Host "[PASO 2/5] Creando directorio persistente en: '$baseDir'"

if (-not (Test-Path $syncRepoDir)) {
    New-Item -Path $syncRepoDir -ItemType Directory -Force | Out-Null
}

# --- 3. DEFINICION Y CREACION DE LOS ARCHIVOS DE SOPORTE ---
Write-Host "[PASO 3/5] Generando archivos de configuracion y sincronizacion en disco..."

# --- Archivo 3.1: config.json (El ADN) ---
$configJsonContent = @'
{
  "github_username": "1willfreeman1",
  "github_pat": "github_pat_1willfreeman1/entorno-viviente",
  "gemini_api_key": "AIzaSyCi3ssyNg5XQFC8KWpD3TwmXkSbqJEEhOc",
  "create_shortcuts": true,
  "repositories": {
    "sync_source": "https://github.com/1willfreeman1/entorno-viviente.git",
    "settings_backup": "https://github.com/1willfreeman1/vscode-settings-backup.git",
    "logs": "https://github.com/1willfreeman1/dev-environment-logs.git"
  },
  "apps_to_install": [
    { "name": "Visual Studio Code", "id": "Microsoft.VisualStudioCode" },
    { "name": "Git", "id": "Git.Git" },
    { "name": "Python 3", "id": "Python.Python.3" },
    { "name": "Google Chrome", "id": "Google.Chrome" },
    { "name": "Greenshot", "id": "Greenshot.Greenshot" },
    { "name": "Notepad++", "id": "Notepad++.Notepad++" }
  ],
  "projects_to_clone": [
    { "name": "dotfiles", "repo_url": "https://github.com/1willfreeman1/dotfiles.git" },
    { "name": "project-orion", "repo_url": "https://github.com/1willfreeman1/project-orion.git" }
  ]
}
'@

# --- Archivo 3.2: sync.ps1 (El Guardian) ---
$syncPs1Content = @'
# sync.ps1: Proceso Guardian de Sincronizacion Continua. Se gestiona y actualiza a si mismo.
$ErrorActionPreference = 'SilentlyContinue'; $ProgressPreference = 'SilentlyContinue'
$baseDir = Join-Path $env:USERPROFILE "Desktop\LivingEnvironment"
$syncRepoDir = $PSScriptRoot
$configFile = Join-Path $syncRepoDir "config.json"
$config = Get-Content -Path $configFile -Raw | ConvertFrom-Json
$projectsBaseDir = Join-Path $baseDir "Projects"
$localLogsDir = Join-Path $baseDir "LocalLogs"

if (-not (Test-Path $localLogsDir)) { New-Item -Path $localLogsDir -ItemType Directory -Force | Out-Null }
$logFile = Join-Path $localLogsDir "$(Get-Date -Format 'yyyy-MM-dd').log"

function Write-Log { param ([string]$Message); $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; $logEntry = "[$timestamp] $Message"; Add-Content -Path $logFile -Value $logEntry; Write-Host $logEntry }

function Get-AppExecutablePath {
    param ([string]$appName)
    $startMenuFolders = @((Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"),(Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs"))
    $wshell = New-Object -ComObject WScript.Shell
    foreach ($folder in $startMenuFolders) {
        if (Test-Path $folder) {
            $shortcut = Get-ChildItem -Path $folder -Recurse -Filter "*.lnk" | Where-Object { $_.BaseName -like "*$appName*" } | Select-Object -First 1
            if ($null -ne $shortcut) { return ($wshell.CreateShortcut($shortcut.FullName)).TargetPath }
        }
    }
    return $null
}

function Resolve-NewError {
    param ($errorRecord)
    $errorMessage = $errorRecord.Exception.Message; Write-Log "ERROR NO CATALOGADO: $errorMessage"
    $prompt = "Task: Eres una IA de resolucion de problemas para un script de PowerShell. Instruction: Provee UN UNICO comando de PowerShell para arreglar el problema. Sin explicaciones. Error: '$errorMessage'"
    $apiKey = $config.gemini_api_key; $apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$apiKey"
    $body = @{ contents = @( @{ parts = @( @{ text = $prompt } ) } ) } | ConvertTo-Json
    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 30
        $suggestedCommand = $response.candidates.content.parts.text | Select-Object -First 1
        if ($null -ne $suggestedCommand) { Write-Log "Solucion IA recibida: '$suggestedCommand'"; Write-Log "Ejecutando..."; Invoke-Expression -Command $suggestedCommand } else { Write-Log "La IA no pudo proveer una solucion." }
    } catch { Write-Log "Fallo al contactar API de IA: $($_.Exception.Message)" }
}

Write-Log "--- INICIO DE SINCRONIZACION ---"

Write-Log "Paso 1/4: Auto-actualizacion del script guardian..."
git -C $syncRepoDir config pull.rebase false
git -C $syncRepoDir pull --quiet

Write-Log "Paso 2/4: Verificando aplicaciones de acuerdo a config.json..."
foreach ($app in $config.apps_to_install) {
    try {
        if (-not (winget list --id $app.id -e)) {
            Write-Log "Instalando $($app.name)..."
            winget install --id $app.id -e --accept-source-agreements --accept-package-agreements --silent
            if ($?) {
                Write-Log "$($app.name) instalado."
                if ($config.create_shortcuts -eq $true) {
                    Start-Sleep -Seconds 5 # Esperar a que el sistema registre el nuevo acceso directo del menu inicio
                    $exePath = Get-AppExecutablePath -appName $app.name
                    if ($null -ne $exePath) {
                        $wshell = New-Object -ComObject WScript.Shell
                        $desktopPath = [System.Environment]::GetFolderPath('Desktop'); $persistentShortcutsDir = Join-Path $baseDir "Shortcuts"
                        if (-not (Test-Path $persistentShortcutsDir)) { New-Item -Path $persistentShortcutsDir -ItemType Directory -Force | Out-Null }
                        $shortcutName = "$($app.name).lnk"
                        $shortcut = $wshell.CreateShortcut((Join-Path $desktopPath $shortcutName)); $shortcut.TargetPath = $exePath; $shortcut.Save()
                        $shortcut = $wshell.CreateShortcut((Join-Path $persistentShortcutsDir $shortcutName)); $shortcut.TargetPath = $exePath; $shortcut.Save()
                        Write-Log "Accesos directos para $($app.name) creados."
                    } else { Write-Log "ADVERTENCIA: No se encontro ejecutable para '$($app.name)' para crear acceso directo." }
                }
            } else { throw "Fallo la instalacion de $($app.name)." }
        }
    } catch { Resolve-NewError -errorRecord $_ }
}

if (-not (Test-Path $projectsBaseDir)) { New-Item -Path $projectsBaseDir -ItemType Directory -Force | Out-Null }
Write-Log "Paso 3/4: Sincronizando proyectos de codigo..."
foreach ($project in $config.projects_to_clone) {
    $projectPath = Join-Path $projectsBaseDir $project.name; $authedRepoUrl = $project.repo_url.Replace("https://", "https://$($config.github_pat)@")
    try {
        if (-not (Test-Path $projectPath)) { Write-Log "Clonando '$($project.name)'..."; git clone --quiet $authedRepoUrl $projectPath } else { Write-Log "Actualizando '$($project.name)'..."; git -C $projectPath pull --quiet }
    } catch { Resolve-NewError -errorRecord $_ }
}

Write-Log "Paso 4/4: Sincronizando logs al repositorio remoto..."
$logsRepoDir = Join-Path $baseDir "logs_clone"
$authedLogsUrl = $config.repositories.logs.Replace("https://", "https://$($config.github_pat)@")
if (-not (Test-Path $logsRepoDir)) { git clone --quiet $authedLogsUrl $logsRepoDir }
cd $logsRepoDir; git config pull.rebase false; git pull --quiet
Copy-Item -Path $logFile -Destination $logsRepoDir -Force
git add .; $commitMessage = "Registro de sincronizacion: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"; git commit -m $commitMessage --quiet; git push --quiet

Write-Log "--- FIN DE SINCRONIZACION ---"
'@

# Escribir los archivos generados
$configJsonContent | Out-File -FilePath (Join-Path $syncRepoDir "config.json") -Encoding utf8
$syncPs1Content | Out-File -FilePath (Join-Path $syncRepoDir "sync.ps1") -Encoding utf8

# --- 4. REGISTRO DE LA TAREA PROGRAMADA PARA EL FUTURO ---
Write-Host "[PASO 4/5] Registrando el guardian 'sync.ps1' para ejecuciones automaticas futuras..."
$taskName = "User_LivingEnvironment_Guardian"
$scriptPath = Join-Path $syncRepoDir "sync.ps1"
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`"" -WorkingDirectory $syncRepoDir
$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Hours 1) -Once -At (Get-Date)
$principal = New-ScheduledTaskPrincipal -UserId (Get-CimInstance Win32_ComputerSystem).UserName -LogonType Interactive
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries)
Write-Host "[INFO] Tarea '$taskName' registrada. El entorno se mantendra sincronizado cada hora."

# --- 5. EJECUCION DE LA PRIMERA SINCRONIZACION INMEDIATA ---
Write-Host "[PASO 5/5] Lanzando la PRIMERA sincronizacion ahora. El software se instalara a continuacion..."
PowerShell.exe -ExecutionPolicy Bypass -File $scriptPath

Write-Host ""
Write-Host "========================================================================"
Write-Host "======                INSTALACION COMPLETADA                       ======"
Write-Host "========================================================================"
Write-Host "El Entorno Viviente esta listo y programado para futuras sincronizaciones."
Write-Host "Puedes cerrar esta ventana."```
