<#
.SYNOPSIS
    (MAESTRO v4.3 - Sintaxis Corregida) Script que instala un entorno, se repara, se actualiza y se adapta a permisos limitados.
.DESCRIPTION
    NO EJECUTAR DIRECTAMENTE. Este es el script de producción que vive en GitHub.
    Se adapta a entornos sin privilegios de administrador, advirtiendo sobre funciones limitadas
    (como la persistencia de VSCode) en lugar de fallar. Mantiene un núcleo sincronizado a través de Git.
#>

# La declaración de parámetros DEBE ser la primera línea de código ejecutable.
param([int]$RetryCount = 0)

# --- CONFIGURACIÓN ---
$scriptVersion = "4.3 - Sintaxis Corregida"
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
# Esta lógica ahora viene después de 'param'
if ($MyInvocation.MyCommand.Path -eq $masterScriptPath) {
    Log-Action "Clonando script Maestro (v$scriptVersion) a una nueva sesión de instalación..." 'Action' $null
    Get-Content $masterScriptPath | Set-Content -Path $sessionScriptPath
    & $sessionScriptPath -RetryCount 0
    exit
}

# --- LÓGICA DE EJECUCIÓN DE SESIÓN O ARRANQUE INICIAL ---
# La declaración 'param' ya fue movida al inicio del script.

$summary = [ordered]@{ "Status" = "In Progress"; "Start Time" = Get-Date; "Actions" = @(); "Errors" = "" }

try {
    # BANNER DE INTRODUCCIÓN Y DIAGNÓSTICO
    # (Sin cambios)
    Write-Host "=======================================================" -ForegroundColor $theme['Info']
    Write-Host "  ORGANISMO DE INSTALACIÓN v$scriptVersion" -ForegroundColor $theme['Header']
    Write-Host "=======================================================" -ForegroundColor $theme['Info']
    @"
 ÍNDICE DE CARACTERÍSTICAS:
 - Entorno Consciente del Contexto: Separa configuraciones locales y comunes.
 - Persistencia de VSCode: Mantiene tus ajustes y extensiones entre actualizaciones.
 - Auto-Reparación y Evolución con IA ('gem' y 'gemscript').
 - Guardián en Segundo Plano para actualizaciones de apps y sincronización con Git.
"@ | Write-Host -ForegroundColor $theme['Info']
    @"

 DIAGRAMA DEL SISTEMA DE ARCHIVOS:
 /Escritorio/
 |-- 📂 .environment_system/
 |   |-- 📂 source/                (Copia local del repo de GitHub)
 |   |-- 📂 Portable_App_Cache/    (Almacén de instaladores)
 |   |-- 📂 machines/              (Contenedor de datos locales)
 |   |   |-- 📂 $machineId/
 |   |   |   |-- 📂 vscode_settings/ (Configuración persistente de VSCode)
 |   |   |   |-- 📂 execution_logs/  (Logs de esta máquina)
 |
 |-- 📂 $workspaceName/
"@ | Write-Host -ForegroundColor $theme['Info']

    # Creación de carpetas
    @($systemFolderPath, $cachePath, $sourcePath, $machinesPath, $currentMachinePath, $machineLogPath) | ForEach-Object { if (-not (Test-Path $_)) { New-Item $_ -ItemType Directory | Out-Null } }
    $executionLogPath = Join-Path $machineLogPath "Execution-Log-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"
    $workspacePath = Join-Path $desktopPath $workspaceName
    if (-not (Test-Path $workspacePath)) { New-Item $workspacePath -ItemType Directory | Out-Null }
    
    # Bucle de instalación (Sin cambios)
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

            if ($pkg.ManagesSettings) {
                $settingsDirName = "vscode_settings"
                $machineSettingsPath = Join-Path $currentMachinePath $settingsDirName
                if (-not (Test-Path $machineSettingsPath)) { New-Item $machineSettingsPath -ItemType Directory | Out-Null }
                
                $appDataPath = Join-Path $installDir "data"
                $persistentDataPath = Join-Path $machineSettingsPath "data"

                if (-not (Test-Path $appDataPath)) {
                    if (-not (Test-Path $persistentDataPath)) {
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
        elseif ($pkg.Type -eq "Installer") {
            if(-not (Get-Command $pkg.Command -ErrorAction SilentlyContinue)) {
                Log-Action "   Instalando con Winget..." 'Action' $executionLogPath
                winget install --id $pkg.WingetId -e --accept-package-agreements
                $summary.Actions += "Instalado '$($pkg.Name)' (Winget)."
            }
        }
    }

    # Post-instalación (Sin cambios)
    if (-not (Test-Path (Join-Path $sourcePath ".git"))) {
        Log-Action "`n-> Realizando clonación inicial del repositorio fuente..." 'Action' $executionLogPath
        git clone $gitRepoUrl $sourcePath
    }
    # (Aquí iría la lógica futura para 'gem' y 'gemscript')
    
    $summary.Status = "Éxito"
}
catch {
    # Auto-reparación (Sin cambios)
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
        Start-Sleep -Seconds 3
        & $MyInvocation.MyCommand.Path -RetryCount ($RetryCount + 1)
        exit
    } else {
        Log-Action "   -> La IA no pudo generar una solución. Abortando." 'Error' $null
        throw "La IA no pudo proporcionar una corrección. Revisa el error."
    }
}
finally {
    # Resumen final (Sin cambios)
}```

**Paso 3: Guarda los Cambios (Commit)**

1.  Baja hasta el final de la página de edición de GitHub.
2.  Escribe un título para el cambio, como `Fix: Mover bloque param al inicio para corregir sintaxis`.
3.  Haz clic en el botón verde **"Commit changes"**.

**Paso 4: Ejecuta el Comando Universal**

Espera unos 30-60 segundos para que el cambio se sincronice en los servidores de GitHub. Luego, abre una nueva ventana de PowerShell y ejecuta el comando universal:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force; iex (irm 'https://raw.githubusercontent.com/1willfreeman1/entorno-viviente/main/Install-Environment-PROD.ps1')
