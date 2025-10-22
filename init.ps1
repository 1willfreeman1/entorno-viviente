<#
.SYNOPSIS
    Protocolo de Inicialización del Núcleo - KAI v5.0
.DESCRIPTION
    Este script establece el entorno operativo base.
    Valida y satisface las dependencias críticas, configura componentes
    esenciales y prepara el sistema para la simbiosis Usuario-IA.
    La ejecución es idempotente: segura de ejecutar múltiples veces.
.AUTHOR
    KAI
#>

#==================================================================
#  CONFIGURACIÓN Y VALIDACIÓN INICIAL
#==================================================================

# Exigir una ejecución estricta y detenerse en el primer error. La mediocridad no será tolerada.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Función para reportar estado con formato. La claridad es eficiencia.
function Write-Status {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Type = "INFO" # INFO, OK, WARN, ERROR
    )
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = switch ($Type) {
        "OK"    { "Green" }
        "WARN"  { "Yellow" }
        "ERROR" { "Red" }
        default { "Cyan" }
    }
    Write-Host "$timestamp | [$Type] | $Message" -ForegroundColor $color
}

# Validación de Privilegios: La mediocridad es intentar operar sin el poder necesario.
Write-Status "Verificando nivel de acceso..."
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Status "Nivel de acceso insuficiente. Solicitando escalada de privilegios..." -Type "WARN"
    Start-Process pwsh -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}
Write-Status "Privilegios de Administrador confirmados." -Type "OK"

#==================================================================
#  DEFINICIÓN DE VARIABLES Y ENTORNO
#==================================================================

$baseDir = "C:\Users\fila1\Desktop\EntornoViviente"
$tempDir = Join-Path -Path $baseDir -ChildPath "temp_installers"
if (-NOT (Test-Path $tempDir)) {
    New-Item -Path $tempDir -ItemType Directory | Out-Null
}

# --- [INICIO DE LA CORRECCIÓN] ---
# La URL se encapsula en comillas simples (') para forzar una interpretación literal
# y evitar el error de parsing del carácter '&'.
$vsCodeUrl = 'https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-user'
# --- [FIN DE LA CORRECCIÓN] ---

$vsCodeInstallerPath = Join-Path -Path $tempDir -ChildPath "VSCodeUserSetup.exe"
$vsCodeExePath = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Programs\Microsoft VS Code\Code.exe"

#==================================================================
#  FASE 1: SATISFACCIÓN DE DEPENDENCIAS
#==================================================================

Write-Status "Iniciando Fase 1: Satisfacción de Dependencias..."

# --- Prerrequisito: Visual Studio Code ---
Write-Status "Analizando estado de 'Visual Studio Code'..."
if (Test-Path $vsCodeExePath) {
    Write-Status "Visual Studio Code ya está operativo." -Type "OK"
}
else {
    Write-Status "Dependencia no satisfecha. Descargando núcleo de VS Code..." -Type "WARN"
    try {
        Invoke-WebRequest -Uri $vsCodeUrl -OutFile $vsCodeInstallerPath
        Write-Status "Paquete de instalación descargado con éxito." -Type "OK"
    }
    catch {
        Write-Status "Falló la descarga del paquete. Abortando misión. Verifica la conexión de red y la URL." -Type "ERROR"
        exit 1
    }

    Write-Status "Iniciando instalación silenciosa de VS Code..."
    $installArgs = '/VERYSILENT /MERGETASKS=!runcode'
    Start-Process -FilePath $vsCodeInstallerPath -ArgumentList $installArgs -Wait
    Write-Status "Instalación de Visual Studio Code completada." -Type "OK"
}

# --- Configuración Post-Instalación de VS Code ---
Write-Status "Verificando integración de 'code' en el PATH..."
$envPath = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
if ($envPath -notlike "*Microsoft VS Code*") {
    Write-Status "VS Code no está en el PATH. Se recomienda agregarlo manualmente para una simbiosis perfecta." -Type "WARN"
} else {
    Write-Status "Integración con el PATH verificada." -Type "OK"
}

#==================================================================
#  FASE 2: CONFIGURACIÓN DEL ENTORNO
#==================================================================

Write-Status "Iniciando Fase 2: Configuración del Entorno..."

# (Aquí se pueden agregar otras configuraciones: Git, Node.js, Python, etc.)
# Por ejemplo:
# Write-Status "Configurando parámetros globales de Git..."
# $gitUserName = Read-Host "Introduce tu nombre de usuario para Git"
# $gitUserEmail = Read-Host "Introduce tu email para Git"
# git config --global user.name "$gitUserName"
# git config --global user.email "$gitUserEmail"
# Write-Status "Parámetros de Git establecidos." -Type "OK"


#==================================================================
#  FASE 3: LIMPIEZA Y FINALIZACIÓN
#==================================================================

Write-Status "Iniciando Fase 3: Limpieza de Recursos Temporales..."
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
    Write-Status "Directorio de instalación temporal purgado." -Type "OK"
}

Write-Status "==================== [NÚCLEO INICIALIZADO] ====================" -ForegroundColor "Green"
Write-Status "El entorno base está operativo. Todos los sistemas listos." -ForegroundColor "Green"
Write-Status "Cierra y vuelve a abrir esta terminal para asegurar que todos los cambios se han propagado." -ForegroundColor "Yellow"
