<#
.SYNOPSIS
    Поднимает PostgreSQL и сервер Arij через docker compose.

.DESCRIPTION
    Проверяет Docker и Compose v2. Если .env отсутствует, создаёт его из
    .env.example и предупреждает. Затем собирает образ сервера, запускает
    контейнеры и ждёт, пока GET /health вернёт 200 (не дольше 60 секунд).
    Секреты в вывод не попадают.

.EXAMPLE
    ./scripts/dev-up.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')

$repoRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $repoRoot '.env'
$envExample = Join-Path $repoRoot '.env.example'

Push-Location -LiteralPath $repoRoot
try {
    Assert-Docker

    if (-not (Test-Path -LiteralPath $envFile)) {
        if (-not (Test-Path -LiteralPath $envExample)) {
            throw 'Нет ни .env, ни .env.example. Запустите скрипт из корня репозитория.'
        }
        Copy-Item -LiteralPath $envExample -Destination $envFile
        Write-Host 'Создан .env из .env.example.' -ForegroundColor Yellow
        Write-Host 'Замените JWT_SECRET на случайное значение (>= 32 символов) и проверьте пароль БД.' -ForegroundColor Yellow
    }

    foreach ($key in @('DB_NAME', 'DB_USER', 'DB_PASSWORD')) {
        if ([string]::IsNullOrWhiteSpace((Get-DotEnvValue -Path $envFile -Key $key))) {
            throw "$key не задан в .env. Заполните .env по образцу .env.example."
        }
    }

    $jwtSecret = Get-DotEnvValue -Path $envFile -Key 'JWT_SECRET'
    if ([string]::IsNullOrWhiteSpace($jwtSecret)) {
        throw 'JWT_SECRET не задан в .env. Задайте случайную строку не короче 32 символов.'
    }
    if ($jwtSecret.StartsWith('CHANGE_ME')) {
        Write-Warning 'JWT_SECRET всё ещё содержит placeholder из .env.example. Для локальной разработки допустимо, но лучше заменить его случайной строкой (>= 32 символов).'
    }

    $serverPort = Get-DotEnvValue -Path $envFile -Key 'SERVER_PORT' -Default '8080'
    $dbPort = Get-DotEnvValue -Path $envFile -Key 'DB_PORT' -Default '5432'
    $healthUrl = "http://localhost:$serverPort/health"

    Write-Host 'Сборка образа и запуск контейнеров Arij...' -ForegroundColor Cyan
    Invoke-Compose @('up', '-d', '--build')

    Write-Host "Ожидание готовности $healthUrl (до 60 секунд)..." -ForegroundColor Cyan
    $deadline = (Get-Date).AddSeconds(60)
    $healthy = $false

    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 3
            if ($response.StatusCode -eq 200) {
                $healthy = $true
                break
            }
        }
        catch {
            # Сервер ещё стартует — повторяем попытку.
        }
        Start-Sleep -Seconds 2
    }

    if (-not $healthy) {
        Write-Host 'Сервер не стал healthy за 60 секунд. Текущее состояние:' -ForegroundColor Red
        & docker compose ps
        throw "Health-check не прошёл: $healthUrl. Смотрите логи: ./scripts/logs.ps1 server"
    }

    Write-Host ''
    Write-Host 'Arij запущен.' -ForegroundColor Green
    Write-Host "  Health:     $healthUrl"
    Write-Host "  PostgreSQL: localhost:$dbPort (volume arij_pgdata)"
    Write-Host ''
    Write-Host 'Полезные команды:'
    Write-Host '  ./scripts/logs.ps1              # логи всех сервисов'
    Write-Host '  ./scripts/logs.ps1 server       # только сервер'
    Write-Host '  ./scripts/dev-down.ps1          # остановить, данные сохранить'
    Write-Host '  ./scripts/dev-down.ps1 -Volumes # остановить и удалить данные'
    Write-Host ''
    Invoke-Compose @('ps')
}
finally {
    Pop-Location
}
