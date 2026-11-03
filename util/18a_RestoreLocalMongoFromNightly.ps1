# =========================
# Restore local MongoDB from the NIGHTLY prod backup on Bender.
# (PostgreSQL restore lives in 18_RestoreLocalFromProdBackup.ps1 - the two
#  are independent so they can run simultaneously in separate terminals and
#  be re-run individually. Mongo is the long pole: ~10GB gzipped tar =
#  ~30GB of BSON + full index rebuilds; expect it to outlast the PG leg.)
#
# Source (produced by the on-box systemd backup timer, pulled nightly):
#   D:\sdprod-backups\sdprod-data-00\<stamp>.tar
#   (per-db directories of *.bson.gz - mongodump --gzip directory format)
# The tar's .sha256 sidecar is verified before anything is touched.
#
# Usage:
#   .\18a_RestoreLocalMongoFromNightly.ps1                            # all databases, latest nightly
#   .\18a_RestoreLocalMongoFromNightly.ps1 -Sport FootballNcaa        # one database
#   .\18a_RestoreLocalMongoFromNightly.ps1 -BackupDate 2026-09-05     # specific nightly (prefix match)
#   .\18a_RestoreLocalMongoFromNightly.ps1 -ParallelCollections 8     # more mongorestore concurrency
#   .\18a_RestoreLocalMongoFromNightly.ps1 -KeepExtracted             # leave extracted files
# =========================

param(
    [string]$Sport = "",
    [string]$BackupDate = "",
    [int]$ParallelCollections = 4,
    [switch]$KeepExtracted
)

# === Load secrets ===
$secretsPath = $env:SPORTDEETS_SECRETS_PATH
. "$secretsPath\_common-variables.ps1"

# -------- CONFIG --------
$mongoBackupDir = "D:\sdprod-backups\sdprod-data-00"
$extractRoot    = "D:\Backups\FromProdNightly\mongo"   # scratch; wiped unless -KeepExtracted
$mongoUri       = $script:mongoDbLocal
# ------------------------

# Pre-flight
if (-not (Test-Path $mongoBackupDir)) { throw "Mongo backup folder not found: $mongoBackupDir" }
if (-not (Get-Command "mongorestore" -ErrorAction SilentlyContinue)) {
    throw "mongorestore CLI not found. Install MongoDB Database Tools."
}

function Get-VerifiedTar {
    param([string]$Dir, [string]$DatePrefix)
    $tars = Get-ChildItem -Path $Dir -Filter "*.tar" | Sort-Object Name -Descending
    if ($DatePrefix) { $tars = $tars | Where-Object { $_.Name -like "$DatePrefix*" } }
    if (-not $tars) { throw "No .tar backups found in $Dir$(if ($DatePrefix) { " matching '$DatePrefix*'" })" }
    $tar = $tars | Select-Object -First 1

    $sidecar = "$($tar.FullName).sha256"
    if (-not (Test-Path $sidecar)) { throw "Missing sha256 sidecar for $($tar.Name)" }
    $expected = ((Get-Content $sidecar -First 1) -split '\s+')[0]
    Write-Host "  Verifying $($tar.Name) ($([Math]::Round($tar.Length/1GB, 2)) GB)..." -ForegroundColor Gray
    $actual = (Get-FileHash -Path $tar.FullName -Algorithm SHA256).Hash
    if (-not [string]::Equals($actual, $expected, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "SHA256 MISMATCH for $($tar.Name) - backup may be corrupt. Expected $expected, got $actual."
    }
    Write-Host "  [OK] Checksum verified." -ForegroundColor Green
    return $tar
}

$startTime = Get-Date
$sportDisplay = if ($Sport) { $Sport } else { "all databases" }

Write-Host "`n[INFO] Restoring local MongoDB from nightly prod backup ($sportDisplay)"

Write-Host "`n[VERIFY] MongoDB nightly ($mongoBackupDir):"
$mongoTar = Get-VerifiedTar -Dir $mongoBackupDir -DatePrefix $BackupDate

# Which database folders are in the tar?
$mongoTops = (& tar -tf $mongoTar.FullName) |
    ForEach-Object { ($_.TrimStart('.', '/') -split '/')[0] } |
    Where-Object { $_ } | Sort-Object -Unique
if ($Sport) { $mongoTops = @($mongoTops | Where-Object { $_ -eq $Sport }) }
if (-not $mongoTops) { throw "No Mongo database folders in $($mongoTar.Name) match the filter" }

# Extract
if (Test-Path $extractRoot) { Remove-Item -Recurse -Force $extractRoot }
New-Item -ItemType Directory -Force $extractRoot | Out-Null

Write-Host "`n[EXTRACT] Databases from $($mongoTar.Name): $($mongoTops -join ', ')..."
if ($Sport) {
    # bsdtar matches member names EXACTLY as stored; entries carry "./".
    & tar -xf $mongoTar.FullName -C $extractRoot "./$Sport"
} else {
    & tar -xf $mongoTar.FullName -C $extractRoot
}
if ($LASTEXITCODE -ne 0) { throw "tar extraction failed for $($mongoTar.Name)" }

$mongoDbDirs = $mongoTops | ForEach-Object { Join-Path $extractRoot $_ } | Where-Object { Test-Path $_ }
if (-not $mongoDbDirs) { throw "Extraction produced no database directories under $extractRoot" }

# Restore each database (jobs run in parallel; completions report live).
# Note the per-db users trap from the 2026-08-30 migration: app users live in
# admin.system.users and are NOT part of these data dumps - a local instance
# restored fresh needs them created separately (locals normally already have
# them; this restore only replaces DATA).
Write-Host "`n[INFO] Restoring $($mongoDbDirs.Count) databases (--drop, $ParallelCollections parallel collections each):"
$mongoDbDirs | ForEach-Object { Write-Host "    $(Split-Path $_ -Leaf)" -ForegroundColor Gray }

$restoreJobs = @{}
foreach ($dbDir in $mongoDbDirs) {
    $dbName = Split-Path $dbDir -Leaf
    $job = Start-Job -ScriptBlock {
        param($uri_, $dbDir_, $dbName_, $parallel_)
        $output = & mongorestore --uri="$uri_" --authenticationDatabase=admin `
            --gzip --drop --db=$dbName_ --dir="$dbDir_" `
            --numParallelCollections=$parallel_ 2>&1
        return @{
            ExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
            DbName = $dbName_
            Output = ($output | Select-Object -Last 20 | Out-String)
        }
    } -ArgumentList $mongoUri, $dbDir, $dbName, $ParallelCollections
    $restoreJobs[$job.Id] = @{ Job = $job; Db = $dbName; Started = Get-Date }
}

Write-Host "`n[INFO] $($restoreJobs.Count) restore jobs running - completions report live:" -ForegroundColor Yellow
$failCount = 0
$pending = @($restoreJobs.Values.Job)
while ($pending.Count -gt 0) {
    $done = Wait-Job -Job $pending -Any
    $meta = $restoreJobs[$done.Id]
    $elapsed = ((Get-Date) - $meta.Started).ToString("hh\:mm\:ss")
    $result = Receive-Job -Job $done
    $info = $result | Where-Object { $_ -is [hashtable] } | Select-Object -Last 1

    if ($info -and $info.ExitCode -eq 0) {
        Write-Host "[OK] $($meta.Db) restored in $elapsed  ($($pending.Count - 1) remaining)" -ForegroundColor Green
    } else {
        $failCount++
        Write-Warning "[FAIL] $($meta.Db) failed after $elapsed (exit code $(if ($info) { $info.ExitCode } else { '?' }))"
        if ($info -and $info.Output) { Write-Host $info.Output -ForegroundColor Gray }
    }
    Remove-Job -Job $done
    $pending = @($pending | Where-Object { $_.Id -ne $done.Id })
}

if (-not $KeepExtracted) {
    Remove-Item -Recurse -Force $extractRoot -ErrorAction SilentlyContinue
} else {
    Write-Host "`n[INFO] Extracted files kept at $extractRoot"
}

if ($failCount -gt 0) {
    throw "$failCount database restore(s) failed. See warnings above."
}

Write-Host "`n[OK] Local MongoDB restored from $($mongoTar.Name)."
$duration = (Get-Date) - $startTime
Write-Host "[TIME] Total duration: $($duration.ToString())"
