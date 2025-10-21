<#
.SYNOPSIS
    Bootstrapper de Entorno Viviente - Version 11 (Logica de Clonacion Corregida)
.DESCRIPTION
    Esta es la version definitiva. Corrige el error fundamental que impedia la instalacion
    de aplicaciones, asegurando que el script principal CLONE el repositorio en lugar
    de solo crear un archivo. Esto garantiza que la primera ejecucion de 'sync.ps1'
    sea exitosa. Ademas, establece el intervalo de la tarea programada a 10 segundos.
#>

$ErrorActionPreference = 'Stop'
Write-Host "Iniciando despliegue AUTONOMO del Entorno Viviente..."

# --- 1. VERIFICACION E INSTALACION DE GIT ---
Write-Host "[PASO 1/6] Verificando prerrequisito: Git..."
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[INFO] Git no se encuentra. Instalando via winget..."
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

# --- 2. DEFINICION Y CREACION DEL ENTORNO PERSISTENTE ---
$baseDir = Join-Path $env:USERPROFILE "Desktop\LivingEnvironment"
$syncRepoDir = Join-Path $baseDir "source"
Write-Host "[PASO 2/6] Definiendo directorio persistente en: '$baseDir'"

# --- 3. CLONACION INICIAL DEL REPOSITORIO FUENTE ---
$configForClone = ConvertFrom-Json -InputObject (
    # Se genera un config temporal solo para obtener la URL y el PAT para el clonado inicial
    @"
    {
      "github_pat": "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",
      "repositories": { "sync_source": "https://github.com/1willfreeman1/entorno-viviente.git" }
    }
"@
)
$authedSyncUrl = $configForClone.repositories.sync_source.Replace("https://", "https://$($configForClone.github_pat)@")

Write-Host "[PASO 3/6] Clonando el repositorio 'entorno-viviente' como base del sistema..."
if (Test-Path $syncRepoDir) {
    Write-Host "[INFO] Se encontro una instalacion anterior. Limpiando para asegurar un estado limpio..."
    Remove-Item -Path $syncRepoDir -Recurse -Force
}
git clone --quiet $authedSyncUrl $syncRepoDir

# --- 4. GENERACION Y ESCRITURA DEL CONFIG.JSON DEFINITIVO ---
Write-Host "[PASO 4/6] Generando y escribiendo el archivo 'config.json' definitivo..."
$configJsonContent = @'
{
  "github_username": "1willfreeman1",
  "github_pat": "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",
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
$configJsonContent | Out-File -FilePath (Join-Path $syncRepoDir "config.json") -Encoding utf8

# AHORA EL SCRIPT SYNC.PS1 YA EXISTE PORQUE FUE CLONADO. No necesitamos crearlo.

# --- 5. REGISTRO DE LA TAREA PROGRAMADA PARA EL FUTURO ---
Write-Host "[PASO 5/6] Registrando el guardian 'sync.ps1' para ejecucion cada 10 segundos..."
$taskName = "User_LivingEnvironment_Guardian"
$scriptPath = Join-Path $syncRepoDir "sync.ps1" # Este archivo ahora existe gracias al 'git clone'
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$scriptPath`"" -WorkingDirectory $syncRepoDir
$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Seconds 10) -Once -At (Get-Date)
$principal = New-ScheduledTaskPrincipal -UserId (Get-CimInstance Win32_ComputerSystem).UserName -LogonType Interactive
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5))
Write-Host "[INFO] Tarea '$taskName' registrada. El entorno se mantendra sincronizado."

# --- 6. EJECUCION DE LA PRIMERA SINCRONIZACION INMEDIATA ---
Write-Host "[PASO 6/6] Lanzando la PRIMERA sincronizacion ahora. El software se instalara a continuacion..."
PowerShell.exe -ExecutionPolicy Bypass -File $scriptPath

Write-Host ""
Write-Host "========================================================================"
Write-Host "======                INSTALACION COMPLETADA                       ======"
Write-Host "========================================================================"
Write-Host "El Entorno Viviente esta listo y programado para futuras sincronizaciones."
Write-Host "Puedes cerrar esta ventana."
