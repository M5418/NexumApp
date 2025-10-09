# Single-click Flutter Web deploy to S3 + CloudFront (Nexum)
# - Builds Flutter web (auto-detects --web-renderer support)
# - Syncs hashed assets with long cache
# - Uploads app shell with no-cache
# - Invalidates CloudFront for EP13A2DVW6MQR
# Optional: Purge Cloudflare if CF env vars are set

param(
  [string]$DistId = "EP13A2DVW6MQR",
  [ValidateSet("html","canvaskit")]
  [string]$Renderer = "html",
  [switch]$SkipBuild = $false,
  [string]$AwsProfile = $env:AWS_PROFILE  # optional
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Test-Cmd {
  param([Parameter(Mandatory=$true)][string]$Name)
  try { Get-Command $Name -ErrorAction Stop | Out-Null }
  catch { throw "Command not found: $Name. Add it to PATH." }
}

function Write-Section {
  param([Parameter(Mandatory=$true)][string]$Message)
  Write-Host ""
  Write-Host "=== $Message ===" -ForegroundColor Cyan
}

# Find repo root (directory containing pubspec.yaml), walking up from this script
function Find-RepoRoot {
  param([Parameter(Mandatory=$true)][string]$Start)
  $dir = Resolve-Path $Start
  for ($i=0; $i -lt 6; $i++) {
    if (Test-Path (Join-Path $dir "pubspec.yaml")) { return $dir }
    $parent = Split-Path $dir -Parent
    if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $dir) { break }
    $dir = $parent
  }
  throw "Could not find Flutter project root (pubspec.yaml) starting from '$Start'."
}

$repoRoot = Find-RepoRoot -Start $PSScriptRoot

# 0) Requirements
Test-Cmd -Name "aws"
Test-Cmd -Name "flutter"

# 1) Build Flutter web
if (-not $SkipBuild) {
  Write-Section -Message "Building Flutter web (auto-detecting --web-renderer support)"
  Push-Location $repoRoot

  flutter clean
  flutter pub get

  # Detect whether this Flutter supports the --web-renderer flag
  $help = flutter build web -h 2>&1 | Out-String
  if ($help -match "--web-renderer") {
    Write-Host "Using renderer: $Renderer"
    flutter build web --release --web-renderer $Renderer
  } else {
    Write-Warning "This Flutter version does not support --web-renderer. Using default renderer."
    flutter build web --release
  }

  Pop-Location
} else {
  Write-Section -Message "Skipping build (using existing build/web)"
}

# Use build output from repo root
$webDir = Join-Path $repoRoot "build\web"
if (-not (Test-Path $webDir)) {
  throw "Not found: $webDir. Build step failed? Check Flutter logs above. You can run: flutter build web --release"
}

# 2) Discover bucket from distribution
Write-Section -Message "Resolving CloudFront distribution $DistId"
$dist = aws cloudfront get-distribution --id $DistId | ConvertFrom-Json
$originDomain = $dist.Distribution.DistributionConfig.Origins.Items[0].DomainName
if ([string]::IsNullOrWhiteSpace($originDomain)) {
  throw "Could not read origin domain from distribution"
}
$Bucket = $originDomain.Split('.')[0]

Write-Host "Origin domain: $originDomain"
Write-Host "Bucket name  : $Bucket"

Write-Section -Message "Finding S3 bucket region"
$loc = aws s3api get-bucket-location --bucket $Bucket | ConvertFrom-Json
$Region = $loc.LocationConstraint
if (-not $Region) { $Region = "us-east-1" } # null means us-east-1
Write-Host "Region       : $Region"

# Helper for aws args
$profileArgs = @()
if ($AwsProfile) { $profileArgs += @("--profile", $AwsProfile) }

# 3) Sync hashed/static assets (long cache)
# IMPORTANT: exclude files that are NOT content-hashed and must be no-cache
Write-Section -Message "Syncing hashed assets (immutable cache)"
$syncArgs = @(
  "s3", "sync", $webDir, "s3://$Bucket",
  "--region", $Region,
  "--delete",
  "--exclude", "index.html",
  "--exclude", "flutter_service_worker.js",
  "--exclude", "version.json",
  "--exclude", "assets/AssetManifest.json",
  "--exclude", "assets/FontManifest.json",
  "--exclude", "main.dart.js",
  "--exclude", "flutter_bootstrap.js",
  "--exclude", "flutter.js",
  "--cache-control", "public, max-age=31536000, immutable"
) + $profileArgs
aws @syncArgs

# 4) Upload no-cache app shell files
Write-Section -Message "Uploading app shell (no-cache)"

function Copy-NoCache {
  param(
    [Parameter(Mandatory=$true)][string]$Local,
    [Parameter(Mandatory=$true)][string]$Remote,
    [string]$ContentType
  )
  $cpArgs = @(
    "s3", "cp", $Local, $Remote,
    "--region", $Region
  ) + $profileArgs
  if ($ContentType) { $cpArgs += @("--content-type", $ContentType) }
  $cpArgs += @("--cache-control", "no-cache, no-store, must-revalidate")
  aws @cpArgs
}

# Required files
Copy-NoCache -Local (Join-Path $webDir "index.html") -Remote "s3://$Bucket/index.html" -ContentType "text/html"

# Core JS (no-cache)
if (Test-Path (Join-Path $webDir "main.dart.js")) {
  Copy-NoCache -Local (Join-Path $webDir "main.dart.js") -Remote "s3://$Bucket/main.dart.js" -ContentType "application/javascript"
}
if (Test-Path (Join-Path $webDir "flutter_bootstrap.js")) {
  Copy-NoCache -Local (Join-Path $webDir "flutter_bootstrap.js") -Remote "s3://$Bucket/flutter_bootstrap.js" -ContentType "application/javascript"
}
if (Test-Path (Join-Path $webDir "flutter.js")) {
  Copy-NoCache -Local (Join-Path $webDir "flutter.js") -Remote "s3://$Bucket/flutter.js" -ContentType "application/javascript"
}

# Service worker: plain no-cache
$sw = Join-Path $webDir "flutter_service_worker.js"
aws s3 cp $sw "s3://$Bucket/flutter_service_worker.js" --region $Region --cache-control "no-cache" @profileArgs

# Manifests (no-cache)
$assetManifest = Join-Path (Join-Path $webDir "assets") "AssetManifest.json"
$fontManifest  = Join-Path (Join-Path $webDir "assets") "FontManifest.json"

aws s3 cp $assetManifest "s3://$Bucket/assets/AssetManifest.json" --region $Region --cache-control "no-cache" --content-type "application/json" @profileArgs
aws s3 cp $fontManifest  "s3://$Bucket/assets/FontManifest.json"  --region $Region --cache-control "no-cache" --content-type "application/json" @profileArgs

# version.json (if present)
$versionJson = Join-Path $webDir "version.json"
if (Test-Path $versionJson) {
  aws s3 cp $versionJson "s3://$Bucket/version.json" --region $Region --cache-control "no-cache" --content-type "application/json" @profileArgs
}

# 5) Invalidate CloudFront
Write-Section -Message "Creating CloudFront invalidation"
$paths = @("/index.html", "/flutter_service_worker.js", "/assets/AssetManifest.json", "/assets/FontManifest.json", "/version.json")

# Add core JS that must be refreshed
if (Test-Path (Join-Path $webDir "main.dart.js"))          { $paths += "/main.dart.js" }
if (Test-Path (Join-Path $webDir "flutter_bootstrap.js"))  { $paths += "/flutter_bootstrap.js" }
if (Test-Path (Join-Path $webDir "flutter.js"))            { $paths += "/flutter.js" }

$paths = $paths | Where-Object { $_ -ne "/version.json" -or (Test-Path $versionJson) }

$invArgs = @(
  "cloudfront", "create-invalidation",
  "--distribution-id", $DistId,
  "--paths"
) + $paths + $profileArgs
aws @invArgs | Out-Null
Write-Host "Invalidation submitted for: $($paths -join ', ')"

# 6) Optional Cloudflare purge
if ($env:CF_API_TOKEN -and $env:CF_ZONE_ID) {
  Write-Section -Message "Purging Cloudflare (paths)"
  $cfFiles = $paths | ForEach-Object { "https://nexum-connects.com$_" }
  $cfBody  = @{ files = $cfFiles } | ConvertTo-Json
  $headers = @{ Authorization = "Bearer $($env:CF_API_TOKEN)" }
  Invoke-RestMethod -Method Post -Uri "https://api.cloudflare.com/client/v4/zones/$($env:CF_ZONE_ID)/purge_cache" -Headers $headers -ContentType "application/json" -Body $cfBody | Out-Null
  Write-Host "Cloudflare purge requested."
} else {
  Write-Host "(Cloudflare purge skipped; set CF_API_TOKEN and CF_ZONE_ID to enable.)"
}

Write-Section -Message "Done"
Write-Host "Deployed to s3://$Bucket (region $Region) and invalidated $DistId."