<#
  Compila la app web y la copia al ERP, que la sirve en /clientes/.

  Uso (desde la carpeta moblar_clientes):
    .\tool\publicar_web.ps1
    .\tool\publicar_web.ps1 -Erp C:\ruta\a\Osmon-moblar-CAML

  Despues, en el ERP: git add public/clientes, commit y push como siempre.
  La app web habla con el mismo dominio que la sirve (ver lib/config.dart):
  el preview de Vercel prueba contra su preview y master contra produccion.
#>
param(
  [string]$Erp = (Join-Path (Split-Path $PSScriptRoot -Parent) "..\Osmon-moblar-CAML")
)
$ErrorActionPreference = "Stop"

$raiz = Split-Path $PSScriptRoot -Parent
$Erp = [System.IO.Path]::GetFullPath($Erp)
if (-not (Test-Path (Join-Path $Erp "next.config.ts"))) {
  throw "No encuentro el ERP en '$Erp'. Pasa la ruta con -Erp."
}

Push-Location $raiz
try {
  flutter build web --release --base-href /clientes/
  if ($LASTEXITCODE -ne 0) { throw "flutter build web fallo." }
} finally {
  Pop-Location
}

$destino = Join-Path $Erp "public\clientes"
if (Test-Path $destino) { Remove-Item $destino -Recurse -Force }
New-Item -ItemType Directory -Force $destino | Out-Null
# Todo menos canvaskit/: el motor lo descarga del CDN de Google (gstatic) y
# la copia local (~37 MB) no se usa; no tiene caso cargarla al repo del ERP.
Get-ChildItem (Join-Path $raiz "build\web") |
  Where-Object { $_.Name -ne "canvaskit" } |
  Copy-Item -Destination $destino -Recurse

Write-Host ""
Write-Host "Listo: app web copiada a $destino" -ForegroundColor Green
Write-Host "Siguiente: en el ERP -> git add public/clientes; git commit; git push"
