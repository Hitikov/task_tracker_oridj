# Общие функции для скриптов Arij.
# Файл не запускается напрямую: скрипты подключают его через
#   . (Join-Path $PSScriptRoot 'common.ps1')

# В PowerShell 7.3+ неуспешная native-команда не должна превращаться в
# исключение раньше, чем мы проверим $LASTEXITCODE.
$PSNativeCommandUseErrorActionPreference = $false

function Assert-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'Docker CLI не найден. Установите Docker Desktop (Windows/macOS) или Docker Engine (Linux) и перезапустите терминал.'
    }

    & docker info --format '{{.ServerVersion}}' *> $null
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker не запущен. Запустите Docker Desktop/Docker Engine и повторите попытку.'
    }

    & docker compose version *> $null
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker Compose v2 не найден. Обновите Docker Desktop или установите плагин docker compose.'
    }
}

function Get-DotEnvValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Key,
        [string]$Default = ''
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $Default
    }

    $line = Get-Content -LiteralPath $Path -Encoding UTF8 |
        Where-Object { $_ -match "^\s*$([regex]::Escape($Key))\s*=" } |
        Select-Object -Last 1

    if (-not $line) {
        return $Default
    }

    $value = ($line -split '=', 2)[1].Trim().Trim('"').Trim("'")
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $Default
    }
    return $value
}

function Assert-EnvFile {
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Не найден .env. Скопируйте .env.example в .env (Copy-Item .env.example .env) и выполните ./scripts/dev-up.ps1."
    }
}

function Invoke-Compose {
    param(
        [Parameter(Mandatory)][string[]]$Arguments
    )

    & docker compose @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose $($Arguments -join ' ') завершился с кодом $LASTEXITCODE."
    }
}
