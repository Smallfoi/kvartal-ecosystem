# STAW — поднять ВСЁ dev-окружение одной командой (после перезагрузки ПК).
#
# Зачем: бэкенд (Docker) + мост телефона + 3 статических сервера (витрина-сайт 5500,
# превью сайта 5577, превью web-сборки приложения 5578). Без 5577/5578 «Конструктор»
# в админке (/admin/merch/) показывает пустые iframe.
#
# Запуск:  правый клик по файлу → «Выполнить с помощью PowerShell»
#     или:  powershell -ExecutionPolicy Bypass -File D:\MyProjectsCLAUDE\scripts\start-dev.ps1

$ErrorActionPreference = "Continue"
$root  = "D:\MyProjectsCLAUDE"
$site  = "$root\САЙТ STAW"
$web   = "$root\mata_store\build\web"
$serve = "$root\scripts\serve_static.py"
$adb   = "C:\Android\platform-tools\adb.exe"

Write-Host "[1/5] Docker Desktop..." -ForegroundColor Cyan
$dd = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
if (-not (Get-Process "Docker Desktop" -ErrorAction SilentlyContinue)) {
    if (Test-Path $dd) { Start-Process $dd }
}
for ($i = 0; $i -lt 48; $i++) {
    docker info 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { break }
    Start-Sleep -Seconds 5
}

Write-Host "[2/5] Бэкенд (docker compose up + migrate)..." -ForegroundColor Cyan
Push-Location "$root\backend"
docker compose up -d
docker compose exec -T web python manage.py migrate
Pop-Location

Write-Host "[3/5] Мост телефона (adb reverse)..." -ForegroundColor Cyan
if (Test-Path $adb) { & $adb reverse tcp:8000 tcp:8000 2>$null }

Write-Host "[4/5] Статические серверы (сайт 5500, превью 5577/5578)..." -ForegroundColor Cyan
Start-Process python -ArgumentList "`"$serve`"", "5500", "`"$site`"" -WindowStyle Hidden
Start-Process python -ArgumentList "`"$serve`"", "5577", "`"$site`"" -WindowStyle Hidden
if (Test-Path "$web\index.html") {
    Start-Process python -ArgumentList "`"$serve`"", "5578", "`"$web`"" -WindowStyle Hidden
} else {
    Write-Host "  ! web-сборки нет ($web). Превью приложения (5578) пропущено." -ForegroundColor Yellow
    Write-Host "    Собрать: cd mata_store; flutter build web --pwa-strategy=none --dart-define=PREVIEW=1" -ForegroundColor Yellow
}

Write-Host "[5/5] Проверка + открываю админку и сайт..." -ForegroundColor Cyan
Start-Sleep -Seconds 3
foreach ($u in @("http://127.0.0.1:8000/v1/health","http://127.0.0.1:5500/index.html","http://127.0.0.1:5577/","http://127.0.0.1:5578/")) {
    try { $c = (Invoke-WebRequest $u -UseBasicParsing -TimeoutSec 5).StatusCode } catch { $c = "нет" }
    Write-Host ("  {0,-45} {1}" -f $u, $c)
}
Start-Process "http://127.0.0.1:8000/admin/"
Start-Process "http://127.0.0.1:5500/"
Write-Host "Готово. Конструктор витрины: http://127.0.0.1:8000/admin/merch/" -ForegroundColor Green
