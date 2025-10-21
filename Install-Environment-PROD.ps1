<#
.SYNOPSIS
    Bootstrapper de Entorno Viviente - PROD (Version Robusta)
.DESCRIPTION
    Este es el unico punto de entrada para desplegar el sistema. Es autonomo,
    robusto contra errores de codificacion y se instala en una carpeta unica
    en el Escritorio del usuario.
#>

$ErrorActionPreference = 'Stop'
Write-Host "Iniciando despliegue del Entorno Viviente..."

# --- 1. Definicion del Entorno de Despliegue en el Escritorio ---
$baseDir = Join-Path $env:USERPROFILE "Desktop\LivingEnvironment"
Write-Host "Directorio base del entorno: '$baseDir'"

if (-not (Test-Path $baseDir)) {
    Write-Host "Creando directorio base..."
    New-Item -Path $baseDir -ItemType Directory -Force | Out-Null
}

# --- 2. Contenido Embebido de los Archivos del Sistema (ASCII-Safe) ---

# Contenido para config.json
$configJsonContent = @"
{
  "github_username": "1willfreeman1",
  "github_pat": "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",
  "gemini_api_key": "AIzaSyCi3ssyNg5XQFC8KWpD3TwmXkSbqJEEhOc",
  "repositories": {
    "sync_source": "https://github.com/1willfreeman1/dev-environment-sync.git",
    "settings_backup": "https://github.com/1willfreeman1/vscode-settings-backup.git",
    "logs": "https://github.com/1willfreeman1/dev-environment-logs.git"
  },
  "apps_to_install": [
    { "name": "Visual Studio Code", "id": "Microsoft.VisualStudioCode" },
    { "name": "Git", "id": "Git.Git" },
    { "name": "Python 3", "id": "Python.Python.3" },
    { "name": "Google Chrome", "id": "Google.Chrome" }
  ],
  "projects_to_clone": [
    { "name": "dotfiles", "repo_url": "https://github.com/1willfreeman1/dotfiles.git" },
    { "name": "project-orion", "repo_url": "https://github.com/1willfreeman1/project-orion.git" }
  ]
}
"@

# Contenido para install.ps1
$installPs1Content = @"
# install.ps1: Script de arranque desatendido.
\$ErrorActionPreference = 'Stop'
\$baseDir = Join-Path \$env:USERPROFILE "Desktop\LivingEnvironment"
\$syncRepoDir = Join-Path \$baseDir "source"
\$projectsDir = Join-Path \$baseDir "Projects"
\$configFile = Join-Path \$PSScriptRoot "config.json"
Write-Host "[INFO] Iniciando configuracion del entorno autonomo en '\$baseDir'..."
if (-not (Test-Path \$projectsDir)) { New-Item -Path \$projectsDir -ItemType Directory -Force | Out-Null }
\$config = Get-Content -Path \$configFile -Raw | ConvertFrom-Json
\$authedSyncUrl = \$config.repositories.sync_source.Replace("https://", "https://\$(\$config.github_pat)@")
Write-Host "[INFO] Clonando el repositorio fuente..."
if (Test-Path \$syncRepoDir) { Remove-Item -Path \$syncRepoDir -Recurse -Force }
git clone --quiet \$authedSyncUrl \$syncRepoDir
Copy-Item -Path \$configFile -Destination (Join-Path \$syncRepoDir "config.json") -Force
\$devModeKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
\$isDevModeEnabled = (Get-ItemProperty -Path \$devModeKey -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue).AllowDevelopmentWithoutDevLicense -eq 1
if (\$isDevModeEnabled) { Write-Host "[INFO] Modo Programador esta activo." } else { Write-Host "[WARNING] Modo Programador no esta activo. Se operara sin enlaces simbolicos." }
\$taskName = "User_DevEnvSync_Guardian"
\$scriptPath = Join-Path \$syncRepoDir "sync.ps1"
\$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File \`"\$scriptPath\`""
\$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Hours 1) -Once -At (Get-Date)
\$principal = New-ScheduledTaskPrincipal -UserId (Get-CimInstance Win32_ComputerSystem).UserName -LogonType Interactive
Unregister-ScheduledTask -TaskName \$taskName -Confirm:\$false -ErrorAction SilentlyContinue
Write-Host "[INFO] Registrando tarea programada '\$taskName' para ejecucion por hora."
Register-ScheduledTask -TaskName \$taskName -Action \$action -Trigger \$trigger -Principal \$principal -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries)
Write-Host "[SUCCESS] Instalacion completada! El sistema autonomo esta activo."
"@

# Contenido para sync.ps1
$syncPs1Content = @"
# sync.ps1: Proceso Guardian de Sincronizacion Continua.
\$ErrorActionPreference = 'SilentlyContinue'; \$ProgressPreference = 'SilentlyContinue'
\$baseDir = Join-Path \$env:USERPROFILE "Desktop\LivingEnvironment"
\$syncRepoDir = \$PSScriptRoot
\$configFile = Join-Path \$syncRepoDir "config.json"
\$config = Get-Content -Path \$configFile -Raw | ConvertFrom-Json
\$projectsBaseDir = Join-Path \$baseDir "Projects"
\$logsRepoDir = Join-Path \$baseDir "logs_clone"
\$logFile = Join-Path \$logsRepoDir "\$(Get-Date -Format 'yyyy-MM-dd').log"
\$authedLogsUrl = \$config.repositories.logs.Replace("https://", "https://\$(\$config.github_pat)@")
function Write-Log { param ([\$string]\$Message); \$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; \$logEntry = "[\$timestamp] \$Message"; Add-Content -Path \$logFile -Value \$logEntry }
if (-not (Test-Path \$logsRepoDir)) { git clone --quiet \$authedLogsUrl \$logsRepoDir }; cd \$logsRepoDir; git config pull.rebase false; git pull --quiet; cd \$syncRepoDir
Write-Log "--- INICIO DE SINCRONIZACION ---"
function Resolve-NewError {
    param (\$errorRecord)
    \$errorMessage = \$errorRecord.Exception.Message; Write-Log "ERROR NO CATALOGADO: \$errorMessage"
    \$prompt = "Task: Eres una IA de resolucion de problemas para un script de PowerShell. Context: Un script de automatizacion de entorno de desarrollo fallo. Instruction: Provee UN UNICO comando de PowerShell ejecutable para arreglar el problema. No des explicaciones, comentarios o formato. Solo el comando. Error: '\$errorMessage'"
    \$apiKey = \$config.gemini_api_key; \$apiUrl = "https://generativelenanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=\$apiKey"
    \$body = @{ contents = @( @{ parts = @( @{ text = \$prompt } ) } ) } | ConvertTo-Json
    try {
        \$response = Invoke-RestMethod -Uri \$apiUrl -Method Post -Body \$body -ContentType 'application/json'
        \$suggestedCommand = \$response.candidates.content.parts.text | Select-Object -First 1
        if (\$null -ne \$suggestedCommand) { Write-Log "Solucion IA recibida: '\$suggestedCommand'"; Write-Log "Ejecutando solucion..."; Invoke-Expression -Command \$suggestedCommand } else { Write-Log "La IA no pudo proveer una solucion." }
    } catch { Write-Log "Fallo al contactar API de IA: \$(\$_.Exception.Message)" }
}
Write-Log "Actualizando repositorio fuente (dev-environment-sync)..."; cd \$syncRepoDir; git config pull.rebase false; git pull --quiet
Write-Log "Verificando aplicaciones..."
foreach (\$app in \$config.apps_to_install) {
    try { if (-not (winget list --id \$app.id -e)) { Write-Log "Instalando \$(\$app.name)..."; winget install --id \$app.id -e --accept-source-agreements --accept-package-agreements --silent; if (\$?) { Write-Log "\$(\$app.name) instalado." } else { throw "Fallo la instalacion de \$(\$app.name)." } } } catch { Resolve-NewError -errorRecord \$_ }
}
Write-Log "Sincronizando proyectos de codigo..."
foreach (\$project in \$config.projects_to_clone) {
    \$projectPath = Join-Path \$projectsBaseDir \$project.name; \$authedRepoUrl = \$project.repo_url.Replace("https://", "https://\$(\$config.github_pat)@")
    try {
        if (-not (Test-Path \$projectPath)) { Write-Log "Clonando proyecto '\$(\$project.name)'..."; git clone --quiet \$authedRepoUrl \$projectPath } else { Write-Log "Actualizando proyecto '\$(\$project.name)'..."; cd \$projectPath; git config pull.rebase false; git pull --quiet; cd \$syncRepoDir }
    } catch { Resolve-NewError -errorRecord \$_ }
}
Write-Log "--- FIN DE SINCRONIZACION ---"
cd \$logsRepoDir; git add .; \$commitMessage = "Registro de sincronizacion automatica - \$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"; git commit -m \$commitMessage --quiet; git push --quiet --force-with-lease; cd \$PSScriptRoot
"@

# --- 3. Escritura de los archivos en el disco ---
Write-Host "Escribiendo archivos del sistema en '$baseDir'..."
$configJsonContent | Out-File -FilePath (Join-Path $baseDir "config.json") -Encoding utf8
$installPs1Content | Out-File -FilePath (Join-Path $baseDir "install.ps1") -Encoding utf8

# Placeholder para el script de sync
$syncPlaceholderDir = Join-Path $baseDir "source"
if (-not (Test-Path $syncPlaceholderDir)) {
    New-Item -Path $syncPlaceholderDir -ItemType Directory -Force | Out-Null
}
$syncPs1Content | Out-File -FilePath (Join-Path $syncPlaceholderDir "sync.ps1") -Encoding utf8

# --- 4. Lanzamiento del Proceso de Instalacion Principal ---
Write-Host "Lanzando script de instalacion 'install.ps1'..."
$installScriptPath = Join-Path $baseDir "install.ps1"
PowerShell.exe -ExecutionPolicy Bypass -File $installScriptPath

Write-Host "El bootstrapper ha finalizado. El sistema ahora operara de forma autonoma."
