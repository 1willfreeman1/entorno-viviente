
=======================================================
? ERROR: La sesión falló. Iniciando protocolo de auto-reparación...
   -> Modo de ejecución: Desde Memoria (iex). La auto-reparación no es posible.
   -> ACCIÓN REQUERIDA: Usa el siguiente 'Lanzador Robusto' que habilita la auto-reparación:

Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force; $tempPath = Join-Path $env:TEMP "Maestro-Installer.ps1"; irm 'https://raw.githubusercontent.com/1willfreeman1/entorno-viviente/main/Install-Environment-PROD.ps1' | Set-Content -Path $tempPath; & $tempPath

Abortando. Por favor, usa el 'Lanzador Robusto' para re-ejecutar el script.
En línea: 118 Carácter: 9
+         throw "Abortando. Por favor, usa el 'Lanzador Robusto' para r ...
+         ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : OperationStopped: (Abortando. Por ...utar el script.:String) [], RuntimeException
    + FullyQualifiedErrorId : Abortando. Por favor, usa el 'Lanzador Robusto' para re-ejecutar el script.
