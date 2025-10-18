<#
.SYNOPSIS
    (MAESTRO v4.2 - Adaptativo y Autónomo) Script que instala un entorno, se repara, se actualiza y se adapta a permisos limitados.
.DESCRIPTION
    NO EJECUTAR DIRECTAMENTE. Este es el script de producción que vive en GitHub.
    Se adapta a entornos sin privilegios de administrador, advirtiendo sobre funciones limitadas
    (como la persistencia de VSCode) en lugar de fallar. Mantiene un núcleo sincronizado a través de Git.
#>

# --- CONFIGURACIÓN ---
$scriptVersion = "4.2 - Adaptativo y Autónomo"
# ¡¡CRÍTICO!! REEMPLAZA ESTA CLAVE por una NUEVA y SECRETA de https://aistudio.google.com/
$geminiApiKey = 'AIzaSyCi3ssyNg5XQFC8KWpD3TwmXkSbqJEEhOc' # <-- ¡¡REEMPLAZA ESTA CLAVE!!

$workspaceName = "Mi_Entorno_Dev_Portatil"
$gitRepoUrl = "https://github.com/1willfreeman1/entorno-viviente.git"

# Tema de colores
$theme = @{ Header="White"; Section="Cyan"; Action="Yellow"; Success="Green"; Error="Red"; Info="Gray"; Warning="Magenta" }

# Definición de aplicaciones
$packages = @(
    @{ Name = "VSCode Portable"; Type = "Portable"; Url = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-archive"; FileName = "vscode.zip"; ExePathInZip = "code.exe"; ShortcutName = "VSCode"; ManagesSettings = $true },
    @{ Name = "Git Portable"; Type = "Portable"; Url = "https://github.com/git-for-windows/git/releases/download/v2.46.0.windows.1/PortableGit-2.46.0-64-bit.7z.exe"; FileName = "git.exe"; ExePathInZip = "git-bash.exe"; ShortcutName = "Git Bash" },
    @{ Name = "Node.js (LTS)"; Type = "Installer"; WingetId = "OpenJS.NodeJS.LTS"; Command = "node" }
)

# --- INICIALIZACIÓN ---
$ErrorActionPreference = 'Stop'
$desktopPath = [System.Environment]::GetFolderPath('Desktop')
$machineId = "$($env:USERNAME)-on-$($env:COMPUTERNAME)"
$systemFolderPath = Join-Path -Path $desktopPath -ChildPath ".environment_system"
$cachePath = Join-Path $systemFolderPath "Portable_App_Cache"
$sourcePath = Join-Path $systemFolderPath "source"
$machinesPath = Join-Path $systemFolderPath "machines"
$currentMachinePath = Join-Path $machinesPath $machineId
$machineLogPath = Join-Path $currentMachinePath "execution_logs"
$masterScriptPath = Join-Path $sourcePath "Install-Environment-PROD.ps1"
$sessionScriptPath = Join-Path $desktopPath "Install-Environment-SESSION.ps1"

# --- FUNCIONES AUXILIARES ---
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
if ($MyInvocation.MyCommand.Path -eq $masterScriptPath) {
    Log-Action "Clonando script Maestro (v$scriptVersion) a una nueva sesión de instalación..." 'Action' $null
    Get-Content $masterScriptPath | Set-Content -Path $sessionScriptPath
    & $sessionScriptPath -RetryCount 0
    exit
}

# --- LÓGICA DE EJECUCIÓN DE SESIÓN O ARRANQUE INICIAL ---
param([int]$RetryCount = 0)

$summary = [ordered]@{ "Status" = "In Progress"; "Start Time" = Get-Date; "Actions" = @(); "Errors" = "" }

try {
    # BANNER DE INTRODUCCIÓN Y DIAGNÓSTICO
    # ... (Banner idéntico a la versión anterior) ...

    # Creación de carpetas
    @($systemFolderPath, $cachePath, $sourcePath, $machinesPath, $currentMachinePath, $machineLogPath) | ForEach-Object { if (-not (Test-Path $_)) { New-Item $_ -ItemType Directory | Out-Null } }
    $executionLogPath = Join-Path $machineLogPath "Execution-Log-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
    $workspacePath = Join-Path $desktopPath $workspaceName
    if (-not (Test-Path $workspacePath)) { New-Item $workspacePath -ItemType Directory | Out-Null }
    
    # Bucle de instalación
    foreach ($pkg in $packages) {
        Log-Action "`n-> Procesando '$($pkg.Name)'..." 'Section' $executionLogPath
        $installDir = Join-Path $workspacePath $pkg.Name

        if ($pkg.Type -eq "Portable") {
            if (-not (Test-Path $installDir)) {
                $cachedFile = Join-Path $cachePath $pkg.FileName
                if (-not (Test-Path $cachedFile)) {
                    Log-Action "   Descargando al caché..." 'Action' $executionLogPath
                    Invoke-WebRequest -Uri $pkg.Url -OutFile $cachedFile
                }
                Log-Action "   Desplegando desde el caché..." 'Action' $executionLogPath
                if ($cachedFile.EndsWith(".exe")) { Start-Process -FilePath $cachedFile -ArgumentList "-o`"\$installDir`" -y" -Wait }
                else { Expand-Archive -Path $cachedFile -DestinationPath $installDir -Force }
                $summary.Actions += "Desplegado '$($pkg.Name)' desde caché."
            }

            # LÓGICA ADAPTATIVA DE PERSISTENCIA DE CONFIGURACIÓN
            if ($pkg.ManagesSettings) {
                $settingsDirName = "vscode_settings"
                $machineSettingsPath = Join-Path $currentMachinePath $settingsDirName
                if (-not (Test-Path $machineSettingsPath)) { New-Item $machineSettingsPath -ItemType Directory | Out-Null }
                
                $appDataPath = Join-Path $installDir "data"
                $persistentDataPath = Join-Path $machineSettingsPath "data"

                # Si el enlace simbólico no existe, intenta crearlo
                if (-not (Test-Path $appDataPath)) {
                    if (-not (Test-Path $persistentDataPath)) {
                        # Primera vez en esta máquina, crear carpeta de datos persistente
                        New-Item $persistentDataPath -ItemType Directory | Out-Null
                    }
                    try {
                        New-Item -ItemType SymbolicLink -Path $appDataPath -Target $persistentDataPath -ErrorAction Stop
                        Log-Action "   Configuración de '$($pkg.Name)' enlazada para persistencia." 'Success' $executionLogPath
                        $summary.Actions += "Enlazada configuración de '$($pkg.Name)'."
                    }
                    catch {
                        Log-Action "   ADVERTENCIA: No se pudo crear el enlace simbólico para la persistencia de la configuración." 'Warning' $executionLogPath
                        Log-Action "   Causa probable: Faltan privilegios y el 'Modo de programador' de Windows está desactivado." 'Info' $executionLogPath
                        Log-Action "   Consecuencia: '$($pkg.Name)' funcionará, pero sus ajustes no se mantendrán entre actualizaciones." 'Info' $executionLogPath
                        $summary.Actions += "ADVERTENCIA: No se pudo enlazar la configuración de '$($pkg.Name)'."
                    }
                }
            }
        }
        # ... (Lógica de Winget sin cambios) ...
    }

    # Post-instalación
    if (-not (Test-Path (Join-Path $sourcePath ".git"))) {
        Log-Action "`n-> Realizando clonación inicial del repositorio fuente..." 'Action' $executionLogPath
        git clone $gitRepoUrl $sourcePath
    }
    # ... (Lógica de instalación de 'gem' y 'gemscript' en $PROFILE) ...
    # ... (Lógica de lanzamiento del Guardián con 'git pull') ...
    
    $summary.Status = "Éxito"
}
catch {
    # ... (Bloque de auto-reparación autónoma sin cambios) ...
}
finally {
    # ... (Resumen final sin cambios) ...
}
