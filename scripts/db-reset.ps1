<#
.SYNOPSIS
    Пересоздаёт локальную базу PostgreSQL с нуля.

.DESCRIPTION
    После подтверждения удаляет контейнеры и volume arij_pgdata (все локальные
    данные БД), затем заново запускает PostgreSQL и ждёт статус healthy.
    Сервер не запускается — используйте ./scripts/dev-up.ps1.
    Миграций на этапе 0 ещё нет: после сброса БД остаётся пустой.

.EXAMPLE
    ./scripts/db-reset.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$repoRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $repoRoot '.env'
$postgresContainer = 'arij-postgres'

Push-Location -LiteralPath $repoRoot
try {
    Assert-Docker
    Assert-EnvFile -Path $envFile

    Write-Host 'ВНИМАНИЕ: будут удалены контейнеры и volume arij_pgdata со всеми локальными данными PostgreSQL.' -ForegroundColor Yellow
    $answer = Read-Host 'Продолжить? [y/N]'
    if ($answer.Trim() -notmatch '^(y|yes|д|да)$') {
        Write-Host 'Отменено. Ничего не изменено.' -ForegroundColor Yellow
        return
    }

    Write-Host 'Удаление контейнеров и volume arij_pgdata...' -ForegroundColor Cyan
    Invoke-Compose @('down', '-v')

    Write-Host 'Запуск PostgreSQL с пустым volume...' -ForegroundColor Cyan
    Invoke-Compose @('up', '-d', 'postgres')

    Write-Host 'Ожидание готовности PostgreSQL (до 60 секунд)...' -ForegroundColor Cyan
    $deadline = (Get-Date).AddSeconds(60)
    $healthy = $false

    while ((Get-Date) -lt $deadline) {
        $status = & docker inspect --format '{{.State.Health.Status}}' $postgresContainer 2>$null
        if ($LASTEXITCODE -eq 0 -and ($status | Select-Object -First 1) -eq 'healthy') {
            $healthy = $true
            break
        }
        Start-Sleep -Seconds 2
    }

    if (-not $healthy) {
        & docker compose ps
        throw 'PostgreSQL не стал healthy за 60 секунд. Смотрите логи: ./scripts/logs.ps1 postgres'
    }

    Write-Host 'PostgreSQL пересоздан, база пустая.' -ForegroundColor Green
    Write-Host 'Миграций и схемы пока нет — они появятся на этапе 1 (docs/ROADMAP.md).'
    Write-Host 'Запуск сервера: ./scripts/dev-up.ps1'
}
finally {
    Pop-Location
}
