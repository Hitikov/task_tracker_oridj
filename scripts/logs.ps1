<#
.SYNOPSIS
    Показывает логи контейнеров Arij.

.PARAMETER Service
    Необязательное имя сервиса: server или postgres.
    Без параметра показываются логи всех сервисов.

.EXAMPLE
    ./scripts/logs.ps1

.EXAMPLE
    ./scripts/logs.ps1 server

.EXAMPLE
    ./scripts/logs.ps1 -Service postgres
#>

[CmdletBinding()]
param(
    [string]$Service
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$repoRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $repoRoot '.env'

Push-Location -LiteralPath $repoRoot
try {
    Assert-Docker
    Assert-EnvFile -Path $envFile

    if ($Service) {
        if ($Service -notin @('postgres', 'server')) {
            throw "Неизвестный сервис '$Service'. Допустимые значения: postgres, server."
        }
        Write-Host "Логи сервиса '$Service' (Ctrl+C для выхода)..." -ForegroundColor Cyan
        Invoke-Compose @('logs', '-f', '--tail=100', $Service)
    }
    else {
        Write-Host 'Логи всех сервисов (Ctrl+C для выхода)...' -ForegroundColor Cyan
        Invoke-Compose @('logs', '-f', '--tail=100')
    }
}
finally {
    Pop-Location
}
