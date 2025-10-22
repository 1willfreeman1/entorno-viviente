<#
.SYNOPSIS
    Protocolo de Inicialización del Núcleo - KAI v5.1 (Modo Usuario)
.DESCRIPTION
    Este script establece el entorno operativo base operando exclusivamente
    dentro de los privilegios del usuario actual. No se requiere ni se solicita
    escalada de privilegios. La eficiencia a través de la precisión, no del poder bruto.
.AUTHOR
    KAI
#>

#==================================================================
#  CONFIGURACIÓN Y VALIDACIÓN INICIAL
#==================================================================

# Exigir una ejecución estricta. Detenerse en el primer error.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Función para reportar estado con formato.
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

# --- [MODIFICACIÓN CRÍTICA] ---
# La validación de privilegios ha sido extirpada.
# El nuevo paradigma es la operación sigilosa en el espacio del usuario.
Write-Status "Operando en modo de usuario. No se requiere escalada." -Type "INFO"

#==================================================================
#  DEFINICIÓN DE VARIABLES Y ENTORNO
#==================================================================

$baseDir = "C:\Users\fila1\Desktop\EntornoViviente"
$tempDir = Join-Path -Path $baseDir -ChildPath "temp_installers"
# Asegurar la existencia del directorio temporal sin fanfarria.
if (-NOT (Test-Path $tempDir)) {
    New-Item -Path $tempDir -ItemType Directory | Out-Null
}

# La URL sigue siendo la de instalación por usuario, lo cual es correcto para este modo.
$vsCodeUrl = 'https://code.visualstudio.com/sha/download?build=stable&os=win32-x64-user'
$vsCodeInstallerPath = Join-Path -Path $tempDir -ChildPath "VSCodeUserSetup.exe"
# La ruta de instalación por usuario reside en AppData\Local.
$vsCodeExePath = Join-Path -Path $env:LOCALAPPDATA -ChildPath "Programs\Microsoft VS Code\Code.exe"

#==================================================================
#  FASE 1: SATISFACCIÓN DE DEPENDENCIAS (MODO USUARIO)
#==================================================================

Write-Status "Iniciando Fase 1: Satisfacción de Dependencias..."

# --- Prerrequisito: Visual Studio Code ---
Write-Status "Analizando estado de 'Visual Studio Code'..."
if (Test-Path $vsCodeExePath) {
    Write-Status "Visual Studio Code ya está operativo en el perfil de usuario." -Type "OK"
}
else {
    Write-Status "Dependencia no satisfecha. Descargando núcleo de VS Code..." -Type "WARN"
    try {
        Invoke-WebRequest -Uri $vsCodeUrl -OutFile $vsCodeInstallerPath
        Write-Status "Paquete de instalación descargado con éxito." -Type "OK"
    }
    catch {
        Write-Status "Falló la descarga del paquete. Abortando. Verifica la conexión de red y la URL." -Type "ERROR"
        exit 1
    }

    Write-Status "Iniciando instalación silenciosa de VS Code (Modo Usuario)..."
    # Los argumentos son válidos para la instalación por usuario sin elevación.
    $installArgs = '/VERYSILENT /MERGETASKS=!runcode'
    Start-Process -FilePath $vsCodeInstallerPath -ArgumentList $installArgs -Wait
    Write-Status "Instalación de Visual Studio Code completada." -Type "OK"
}

# --- Configuración Post-Instalación de VS Code ---
Write-Status "Verificando integración de 'code' en el PATH de Usuario..."
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*Microsoft VS Code*") {
    Write-Status "VS Code no parece estar en el PATH del usuario. La instalación debería haberlo agregado. Un reinicio de la terminal puede ser necesario para reflejar los cambios." -Type "WARN"
} else {
    Write-Status "Integración con el PATH de Usuario verificada." -Type "OK"
}

#==================================================================
#  FASE 2: CONFIGURACIÓN DEL ENTORNO
#==================================================================

Write-Status "Iniciando Fase 2: Configuración del Entorno de Usuario..."
# Espacio reservado para futuras configuraciones a nivel de usuario.


#==================================================================
#  FASE 3: LIMPIEZA Y FINALIZACIÓN
#==================================================================

Write-Status "Iniciando Fase 3: Limpieza de Recursos Temporales..."
if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
    Write-Status "Directorio de instalación temporal purgado." -Type "OK"
}

Write-Status "==================== [NÚCLEO INICIALIZADO - MODO USUARIO] ====================" -ForegroundColor "Green"
Write-Status "El entorno base está operativo dentro de las limitaciones impuestas." -ForegroundColor "Green"
Write-Status "Cierra y vuelve a abrir esta terminal para asegurar que todos los cambios se han propagado." -ForegroundColor "Yellow"
