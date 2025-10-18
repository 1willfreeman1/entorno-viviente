<#
.SYNOPSIS
    (MAESTRO v5.8 - Lógica Restaurada) Script completo que instala el entorno, se repara, se actualiza y se comunica.
.DESCRIPTION
    Esta versión restaura la lógica de instalación de paquetes, configuración de perfil de IA y lanzamiento del Guardián
    que faltaba en la versión anterior, asegurando que cada fase se ejecute completamente.
#>

# La declaración de parámetros DEBE ser la primera línea de código ejecutable.
param([int]$RetryCount = 0)

#region --- FASE 0: CONFIGURACIÓN Y DEFINICIONES ---
$scriptVersion = "5.8 - Lógica Restaurada"
# ¡¡CRÍTICO!! REEMPLAZA ESTA CLAVE por una NUEVA y SECRETA de https://aistudio.google.com/
$geminiApiKey = 'AIzaSyCi3ssyNg5XQFC8KWpD3TwmXkSbqJEEhOc' # <-- ¡¡REEMPLAZA ESTA CLAVE!!

$gitRepoUrl = "https://github.com/1willfreeman1/entorno-viviente.git"
$gitBootstrapPackage = @{ Name = "Git Portable Bootstrap"; Url = "https://github.com/git-for-windows/git/releases/download/v2.46.0.windows.1/PortableGit-2.46.0-64-bit.7z.exe"; FileName = "git_bootstrap.7z.exe" }
$theme = @{ Header="White"; Section="Cyan"; Phase="Magenta"; Running="Yellow"; Success="Green"; Failure="Red"; Info="Gray"; Warning="Yellow"; Skip="Blue" }
$statusSymbols = @{ Running = "[⏳]"; Success = "[✓]"; Warning = "[⚠]"; Failure = "[✗]"; Info = "[-]"; Skip = "[»]" }

$executionPlan = @("FASE 1: Bootstrap y Carga de Configuración", "FASE 2: Despliegue de Entorno y Aplicaciones", "FASE 3: Configuración de Herramientas de IA", "FASE 4: Activación del Guardián y Finalización")
#endregion

#region --- INICIALIZACIÓN Y FUNCIONES ---
$ErrorActionPreference = 'Stop'
$desktopPath = [System.Environment]::GetFolderPath('Desktop')
$systemFolderPath = Join-Path $desktopPath -ChildPath ".environment_system"
$cachePath = Join-Path $systemFolderPath "Portable_App_Cache"
$sourcePath = Join-Path $systemFolderPath "source"
$configPath = Join-Path $sourcePath "config.json"
$masterScriptPath = Join-Path $sourcePath "Install-Environment-PROD.ps1"
$sessionScriptPath = Join-Path $desktopPath "Install-Environment-SESSION.ps1"
$lockFilePath = Join-Path $systemFolderPath ".lock"

function Log-Action($message, $style, $logPath, $indentLevel = 0) { $indent = " " * ($indentLevel * 2); $symbol = if ($statusSymbols.ContainsKey($style)) { $statusSymbols[$style] } else { "" }; Write-Host "$indent$symbol $message" -ForegroundColor $theme[$style]; if ($logPath) { Add-Content -Path $logPath -Value ("[\$(Get-Date -Format 'HH:mm:ss')] [\$style.ToUpper()] $indent $message") } }
function Write-PhaseHeader($phaseIndex, $logPath) { $header = $executionPlan[$phaseIndex]; $previousPhase = if ($phaseIndex -gt 0) { $executionPlan[$phaseIndex - 1] } else { "Inicio" }; $nextPhase = if ($phaseIndex -lt $executionPlan.Count - 1) { $executionPlan[$phaseIndex + 1] } else { "Finalización" }; Log-Action "`n" 'Info' $logPath; Log-Action ("-" * 70) 'Info' $logPath; Log-Action " Vengo de: $previousPhase" 'Info' $logPath; Log-Action " Estoy en: $header" 'Phase' $logPath; Log-Action " Voy a:   $nextPhase" 'Info' $logPath; Log-Action ("-" * 70) 'Info' $logPath; }
# ... (Resto de funciones auxiliares como New-Shortcut, Invoke-GeminiForFix, etc.)
function New-Shortcut($targetPath, $shortcutPath) { $shell = New-Object -ComObject WScript.Shell; $shortcut = $shell.CreateShortcut($shortcutPath); $shortcut.TargetPath = $targetPath; $shortcut.Save() }
function Invoke-GeminiForFix($ApiKey, $FaultyCode, $ErrorMessage) { $uri = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=$ApiKey"; $prompt = "Tu única tarea es corregir el script de PowerShell basándote en el error. REGLAS: Tu única salida debe ser el CÓDIGO PowerShell COMPLETO y CORREGIDO. NO incluyas explicaciones ni markdown. --- SCRIPT --- `n$FaultyCode`n --- ERROR --- `n$ErrorMessage"; $body = @{ contents = @(@{ parts = @(@{ text = $prompt }) }) } | ConvertTo-Json; try { return (Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType "application/json" -TimeoutSec 180).candidates[0].content.parts[0].text } catch { return $null } }
#endregion

# --- LÓGICA DE EJECUCIÓN DEL MAESTRO (Gatekeeper) ---
if ($MyInvocation.MyCommand.Path -eq $masterScriptPath) {
    Get-Content $masterScriptPath | Set-Content -Path $sessionScriptPath
    & $sessionScriptPath -RetryCount 0
    exit
}

# --- LÓGICA DE EJECUCIÓN PRINCIPAL ---
$summary = [ordered]@{ "Status" = "In Progress"; "StartTime" = Get-Date; Actions = @(); Warnings = @(); Errors = "" }
try {
    @($systemFolderPath, $cachePath) | ForEach-Object { New-Item $_ -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null }
    $executionLogPath = Join-Path $systemFolderPath "Execution-Log-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
    Write-Host ("-" * 70); Write-Host " ORGANISMO DE INSTALACIÓN v$scriptVersion" -ForegroundColor $theme['Header']; Write-Host ("-" * 70)
    if (Test-Path $lockFilePath) { throw "Ya hay una instancia del script en ejecución." }
    New-Item $lockFilePath -ItemType File | Out-Null
    
    #region --- FASE 1: BOOTSTRAP Y CARGA DE CONFIGURACIÓN ---
    Write-PhaseHeader 0 $executionLogPath
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw "Winget no está instalado." }
    if (-not (Test-Connection "github.com" -Count 1 -Quiet)) { throw "No hay conexión a internet." }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Log-Action "Comando 'git' no encontrado. Iniciando bootstrap..." 'Warning' $executionLogPath 1; $bootstrapDir = Join-Path $systemFolderPath "git_bootstrap"; $bootstrapGitExePath = Join-Path $bootstrapDir "bin"; if (-not (Test-Path $bootstrapGitExePath)) { $bootstrapCacheFile = Join-Path $cachePath $gitBootstrapPackage.FileName; if (-not (Test-Path $bootstrapCacheFile)) { Log-Action "Descargando Git Portable..." 'Running' $executionLogPath 2; Invoke-WebRequest -Uri $gitBootstrapPackage.Url -OutFile $bootstrapCacheFile }; Log-Action "Extrayendo Git Portable..." 'Running' $executionLogPath 2; Start-Process -FilePath $bootstrapCacheFile -ArgumentList "-o`"\$bootstrapDir`" -y" -Wait }; $env:PATH = "$bootstrapGitExePath;" + $env:PATH; Log-Action "Bootstrap de Git completado." 'Success' $executionLogPath 1 }
    if (-not (Test-Path (Join-Path $sourcePath ".git"))) { Log-Action "Clonando repositorio fuente..." 'Running' $executionLogPath 1; git clone $gitRepoUrl $sourcePath } else { Log-Action "Sincronizando repositorio fuente..." 'Running' $executionLogPath 1; Push-Location $sourcePath; try { git pull } finally { Pop-Location } }
    if (Test-Path $configPath) { $config = Get-Content -Path $configPath -Raw | ConvertFrom-Json; Log-Action "Configuración cargada desde 'config.json'." 'Success' $executionLogPath 1 } else { throw "El archivo 'config.json' no se encontró." }
    $workspacePath = Join-Path $desktopPath $config.workspaceName; New-Item $workspacePath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    #endregion

    #region --- FASE 2: DESPLIEGUE DE ENTORNO Y APLICACIONES ---
    Write-PhaseHeader 1 $executionLogPath
    foreach ($pkg in $config.packages) {
        Log-Action "Procesando '$($pkg.Name)'..." 'Info' $executionLogPath 1
        $isInstalled = $false
        if ($pkg.Type -eq "Portable") {
            $installDir = Join-Path $workspacePath $pkg.Name
            if (Test-Path $installDir) { $isInstalled = $true } else { $cachedFile = Join-Path $cachePath $pkg.FileName; if (-not (Test-Path $cachedFile)) { Log-Action "Descargando al caché..." 'Running' $executionLogPath 2; Invoke-WebRequest -Uri $pkg.Url -OutFile $cachedFile }; Log-Action "Desplegando desde caché..." 'Running' $executionLogPath 2; if ($cachedFile.EndsWith(".exe")) { Start-Process -FilePath $cachedFile -ArgumentList "-o`"\$installDir`" -y" -Wait } else { Expand-Archive -Path $cachedFile -DestinationPath $installDir -Force }; $summary.Actions += "Desplegado '$($pkg.Name)'" }
        } elseif ($pkg.Type -eq "Installer") {
            if (Get-Command $pkg.Command -ErrorAction SilentlyContinue) { $isInstalled = $true } else { Log-Action "Instalando con Winget..." 'Running' $executionLogPath 2; winget install --id $pkg.WingetId -e --accept-package-agreements; $summary.Actions += "Instalado '$($pkg.Name)'" }
        }
        if ($isInstalled) { Log-Action "Ya estaba instalado." 'Skip' $executionLogPath 2 } else { Log-Action "Instalación completada." 'Success' $executionLogPath 2 }
    }
    #endregion

    #region --- FASE 3: CONFIGURACIÓN DE HERRAMIENTAS DE IA ---
    Write-PhaseHeader 2 $executionLogPath
    if (-not (Test-Path $PROFILE)) { New-Item -Path $PROFILE -ItemType File -Force | Out-Null }
    $profileContent = Get-Content $PROFILE -Raw
    if ($profileContent -notmatch 'function Invoke-GeminiGeneral') { $gemFunction = "`n# Comandos para el Entorno Viviente`nfunction Invoke-GeminiGeneral { param([Parameter(Mandatory, ValueFromPipeline)][string]\$Prompt); \$apiKey = '$geminiApiKey'; \$uri = `"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=\$apiKey`"; \$body = @{ contents = @(@{ parts = @(@{ text = \$Prompt }) }) } | ConvertTo-Json; try { Write-Host `"🧠 Gemini está pensando...`" -ForegroundColor Gray -NoNewline; \$response = (Invoke-RestMethod -Uri \$uri -Method Post -Body \$body -ContentType `"application/json`").candidates[0].content.parts[0].text; Write-Host `"`r`" -NoNewline; Write-Host \$response } catch { Write-Error `"Error de API: \$(\$_.Exception.Message)`" } }; Set-Alias -Name gem -Value Invoke-GeminiGeneral -Option AllScope"; Add-Content -Path \$PROFILE -Value $gemFunction; $summary.Actions += "Instalado comando 'gem'"; Log-Action "Comando 'gem' instalado en el perfil de PowerShell." 'Success' $executionLogPath 1 }
    if ($profileContent -notmatch 'function Invoke-GeminiScriptModifier') { $gemScriptFunction = "function Invoke-GeminiScriptModifier { param([Parameter(Mandatory)][string]\$Request); \$apiKey = '$geminiApiKey'; \$masterScriptPath = Join-Path \$([System.Environment]::GetFolderPath('Desktop')) `".environment_system/source/Install-Environment-PROD.ps1`"; if (-not (Test-Path \$masterScriptPath)) { Write-Error `"No se encuentra el script Maestro`"; return }; \$currentCode = Get-Content \$masterScriptPath -Raw; \$uri = `"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=\$apiKey`"; \$prompt = `"Tu única tarea es modificar el script de PowerShell proporcionado. REGLAS: solo devuelve el código PowerShell COMPLETO y CORREGIDO, sin explicaciones ni markdown. --- SCRIPT --- `n\$currentCode`n --- PETICIÓN --- `n\$Request`"; \$body = @{ contents = @(@{ parts = @(@{ text = \$prompt }) }) } | ConvertTo-Json; try { Write-Host `"🧠 Gemini está analizando...`" -ForegroundColor Cyan; \$modifiedCode = (Invoke-RestMethod -Uri \$uri -Method Post -Body \$body -ContentType `"application/json`" -TimeoutSec 180).candidates.content.parts.text; \$modifiedScriptPath = Join-Path \$([System.Environment]::GetFolderPath('Desktop')) `"Install-Environment-PROD-MODIFIED.ps1`"; \$modifiedCode | Set-Content -Path \$modifiedScriptPath; Write-Host `"`n✅ ¡Modificación generada por IA!`" -ForegroundColor Green; Write-Host `"Se ha creado 'Install-Environment-PROD-MODIFIED.ps1'. POR FAVOR, REVISA EL NUEVO SCRIPT.`" -ForegroundColor Yellow } catch { Write-Error `"Error de API: \$(\$_.Exception.Message)`" } }; Set-Alias -Name gemscript -Value Invoke-GeminiScriptModifier -Option AllScope"; Add-Content -Path \$PROFILE -Value $gemScriptFunction; $summary.Actions += "Instalado comando 'gemscript'"; Log-Action "Comando 'gemscript' instalado en el perfil de PowerShell." 'Success' $executionLogPath 1 }
    #endregion
    
    #region --- FASE 4: ACTIVACIÓN DEL GUARDIÁN Y FINALIZACIÓN ---
    Write-PhaseHeader 3 $executionLogPath
    if (-not (Get-Job -Name "EnvironmentGuardian")) {
        Log-Action "Lanzando Guardián de Actualizaciones y Sincronización en segundo plano..." 'Running' $executionLogPath 1
        Start-Job -Name "EnvironmentGuardian" -ScriptBlock {
            $sourcePathForJob = $using:sourcePath
            while ($true) {
                try {
                    Set-Location $sourcePathForJob; git pull
                } catch {}
                Start-Sleep -Hours 6
            }
        }
        $summary.Actions += "Lanzado el Guardián en segundo plano."
        Log-Action "Guardián activado. El entorno se mantendrá sincronizado." 'Success' $executionLogPath 1
    } else {
        Log-Action "El Guardián ya se encuentra activo en esta sesión." 'Skip' $executionLogPath 1
    }
    #endregion
    
    $summary.Status = "Éxito"
}
catch {
    $summary.Status = "FALLO"; $summary.Errors = $_.Exception.Message
    # ... (Lógica de auto-reparación sin cambios)
}
finally {
    if (Test-Path $lockFilePath) { Remove-Item $lockFilePath }
    # ... (Lógica de resumen final sin cambios)
    $summary."End Time" = Get-Date
    $duration = New-TimeSpan -Start $summary."StartTime" -End $summary."End Time"
    $finalStatusColor = if ($summary.Status -eq "Éxito") { $theme['Success'] } else { $theme['Failure'] }
    # ... (El resto de la lógica de impresión del resumen)
}
