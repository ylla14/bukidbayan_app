param(
  [int]$WebPort = 7357,
  [string]$EmulatorHost = '127.0.0.1'
)

$ErrorActionPreference = 'Stop'

function Test-CommandExists {
  param([string]$Name)

  return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Wait-ForTcpPort {
  param(
    [string]$Host,
    [int]$Port,
    [int]$TimeoutSeconds = 60
  )

  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
      $async = $client.BeginConnect($Host, $Port, $null, $null)
      if ($async.AsyncWaitHandle.WaitOne(500) -and $client.Connected) {
        $client.EndConnect($async)
        return $true
      }
    } catch {
      # Keep polling until timeout.
    } finally {
      $client.Dispose()
    }

    Start-Sleep -Milliseconds 500
  }

  return $false
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$functionsDir = Join-Path $repoRoot 'functions'
$envFile = Join-Path $functionsDir '.env'
$nodeModulesDir = Join-Path $functionsDir 'node_modules'

if (-not (Test-CommandExists 'flutter')) {
  throw 'Flutter is not installed or not available on PATH.'
}

if (-not (Test-CommandExists 'firebase')) {
  throw 'Firebase CLI is not installed or not available on PATH.'
}

if (-not (Test-Path $envFile)) {
  throw 'functions/.env was not found. Copy functions/.env.example to functions/.env first.'
}

if (-not (Test-Path $nodeModulesDir)) {
  throw 'functions/node_modules was not found. Run "cd functions" then "npm install" first.'
}

$emulatorCommand = "Set-Location '$repoRoot'; firebase emulators:start --only firestore,functions"
$flutterCommand = "Set-Location '$repoRoot'; flutter run -d chrome --web-port $WebPort --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=$EmulatorHost"

Write-Host 'Opening Firebase emulators in a new PowerShell window...'
Start-Process powershell.exe -ArgumentList @(
  '-NoExit',
  '-Command',
  $emulatorCommand
)

Write-Host 'Waiting for Firestore emulator on port 8080...'
if (-not (Wait-ForTcpPort -Host $EmulatorHost -Port 8080 -TimeoutSeconds 90)) {
  throw 'Timed out waiting for Firestore emulator on port 8080.'
}

Write-Host 'Waiting for Functions emulator on port 5001...'
if (-not (Wait-ForTcpPort -Host $EmulatorHost -Port 5001 -TimeoutSeconds 90)) {
  throw 'Timed out waiting for Functions emulator on port 5001.'
}

Write-Host 'Seeding local crowdfunding campaigns into the Firestore emulator...'
Push-Location $functionsDir
try {
  $env:FIRESTORE_EMULATOR_HOST = "${EmulatorHost}:8080"
  $env:GCLOUD_PROJECT = 'bukidbayan-capstoners'
  node .\scripts\seed_local_crowdfunding_campaigns.js
} finally {
  Pop-Location
}

Write-Host 'Opening Flutter web in a new PowerShell window...'
Start-Process powershell.exe -ArgumentList @(
  '-NoExit',
  '-Command',
  $flutterCommand
)

Write-Host ''
Write-Host 'Teammate test environment started.'
Write-Host "Flutter web will open on http://127.0.0.1:$WebPort"
Write-Host 'Use a real Firebase Auth test account to sign in.'
Write-Host 'Payment confirmation still needs a public PayMongo webhook endpoint to finalize as paid.'
