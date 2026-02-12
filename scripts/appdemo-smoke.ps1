Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$port = 3210
$serverProcess = $null
$oldPort = $env:PORT

try {
  $portInUse = netstat -ano | Select-String ":$port\s+.*LISTENING"
  if ($null -ne $portInUse) {
    throw "Port $port is already in use. Stop existing process before running smoke test."
  }

  $serverEntry = Join-Path $repoRoot "dist\\src\\server.js"
  if (-not (Test-Path $serverEntry)) {
    Write-Host "[appdemo-smoke] dist missing, building..."
    npm run build
  }

  Write-Host "[appdemo-smoke] starting server on port $port"
  $env:PORT = "$port"
  $serverProcess = Start-Process -FilePath "node" `
    -ArgumentList "dist/src/server.js" `
    -WorkingDirectory $repoRoot `
    -PassThru

  $health = $null
  for ($i = 0; $i -lt 10; $i += 1) {
    Start-Sleep -Milliseconds 500
    try {
      $health = Invoke-RestMethod -Uri "http://localhost:$port/health" -Method Get
      break
    } catch {
      continue
    }
  }
  if ($null -eq $health) {
    throw "Health check failed: server did not become ready"
  }

  if ($health.status -ne "ok") {
    throw "Health check failed: unexpected status"
  }

  $created = Invoke-RestMethod -Uri "http://localhost:$port/api/tasks" -Method Post -Body '{"title":"smoke"}' -ContentType "application/json"
  if (-not $created.id) {
    throw "Create task failed: missing id"
  }

  $list = Invoke-RestMethod -Uri "http://localhost:$port/api/tasks" -Method Get
  if ($list.count -lt 1) {
    throw "List tasks failed: expected at least one task"
  }

  Write-Host "[appdemo-smoke] passed"
  Write-Host ("[appdemo-smoke] health={0} count={1}" -f $health.status, $list.count)
} finally {
  $env:PORT = $oldPort
  if ($null -ne $serverProcess -and -not $serverProcess.HasExited) {
    Stop-Process -Id $serverProcess.Id -Force
  }
}
