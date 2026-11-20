<#
.SYNOPSIS
    Останавливает контейнеры Arij.

.DESCRIPTION
    Выполняет docker compose down (без -v). Контейнеры и сеть удаляются,
    volume arij_pgdata с данными PostgreSQL сохраняется.
    С ключом -Volumes удаляет и volume — все локальные данные БД будут потеряны.

.PARAMETER Volumes
    Удалить volume arij_pgdata вместе с данными PostgreSQL.

.EXAMPLE
    ./scripts/dev-down.ps1

.EXAMPLE
    ./scripts/dev-down.ps1 -Volumes
#>

[CmdletBinding()]
param(
    [switch]$Volumes
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$repoRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $repoRoot '.env'

Push-Location -LiteralPath $repoRoot
try {
    Assert-Docker
    Assert-EnvFile -Path $envFile

    if ($Volumes) {
        Write-Host 'ВНИМАНИЕ: volume arij_pgdata и все локальные данные PostgreSQL будут удалены.' -ForegroundColor Yellow
        Invoke-Compose @('down', '-v')
        Write-Host 'Контейнеры остановлены, volume arij_pgdata удалён.' -ForegroundColor Green
    }
    else {
        Invoke-Compose @('down')
        Write-Host 'Контейнеры остановлены. Данные PostgreSQL сохранены в volume arij_pgdata.' -ForegroundColor Green
    }
}
finally {
    Pop-Location
}
