<#
.SYNOPSIS
    Runs a comparative PostgreSQL load test on a remote NUC using pgbench.
    
.DESCRIPTION
    This script performs the following steps:
    1. Connects to the remote Postgres host (sdprod-data-0) via SSH.
    2. Runs a baseline pgbench load test against the current configuration.
    3. Applies a new configuration (postgresql.conf) provided by the user.
    4. Restarts the PostgreSQL service.
    5. Runs the same pgbench load test against the new configuration.
    6. Outputs a side-by-side comparison of the results.

.PARAMETER RemoteHost
    The IP address or hostname of the remote Postgres server. Default: 192.168.0.250
.PARAMETER RemoteUser
    The SSH username for the remote server. Default: jrandallsexton
.PARAMETER PgUser
    The PostgreSQL username. Default: postgres
.PARAMETER PgDb
    The PostgreSQL database to test against. Default: postgres
.PARAMETER ConfigFile
    Path to the local postgresql.conf file to apply. If omitted, only the baseline test is run.
.PARAMETER Duration
    Duration of the load test in seconds. Default: 60
.PARAMETER Clients
    Number of concurrent clients for pgbench. Default: 50
.PARAMETER Jobs
    Number of threads for pgbench. Default: 2

.EXAMPLE
    .\Compare-PgConfig.ps1 -ConfigFile ".\tuned-postgresql.conf"
#>

param(
    [string]$RemoteHost = "192.168.0.250",
    [string]$RemoteUser = "sportdeets",
    [string]$PgUser = "postgres",
    [string]$PgDb = "pgbench_test_db",
    [string]$ConfigFile,
    [int]$Duration = 60,
    [int]$Clients = 50,
    [int]$Jobs = 2,
    [int]$ScaleFactor = 100
)

$ErrorActionPreference = "Stop"

# Safety Check: Prevent running against critical databases
if ($PgDb -match "^sd") {
    Write-Error "SAFETY ERROR: You are attempting to run a load test against a production-like database name ('$PgDb')."
    Write-Error "This script drops tables! Please use a dedicated test database (e.g., 'pgbench_test_db')."
    exit 1
}

# Prompt for sudo password securely (required for switching to postgres user)
$SudoPass = Read-Host -Prompt "Enter sudo password for $RemoteUser (required for switching to postgres user)" -AsSecureString
$SudoPassPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SudoPass))

# --- Helper Functions ---

function Invoke-SshCommand {
    param($Command)
    Write-Host "[SSH] $Command" -ForegroundColor Gray
    # Quote the command to ensure it's passed as a single argument to SSH
    ssh -o StrictHostKeyChecking=no "$RemoteUser@$RemoteHost" "$Command"
}

function Run-PgBench {
    param($Label)
    
    Write-Host "`n--- Starting $Label Load Test ---" -ForegroundColor Cyan
    
    # Initialize pgbench (drop/create tables)
    Write-Host "Initializing pgbench data (Scale Factor $ScaleFactor)..."
    # Use sudo -S to accept password from stdin
    $initCmd = "echo '$SudoPassPlain' | sudo -S -u postgres pgbench -i -s $ScaleFactor $PgDb"
    Invoke-SshCommand $initCmd | Out-Null

    # Run the test
    # -c: clients, -j: threads, -T: time, -P: progress every 1 sec
    $benchCmd = "echo '$SudoPassPlain' | sudo -S -u postgres pgbench -c $Clients -j $Jobs -T $Duration -P 5 $PgDb"
    Write-Host "Running: pgbench -c $Clients -j $Jobs -T $Duration -P 5 $PgDb"
    
    $output = Invoke-SshCommand $benchCmd
    $output | Write-Host

    # Parse results
    $tps = ($output | Select-String "tps = " | Select-Object -First 1).ToString() -replace ".*tps = ([\d\.]+).*", '$1'
    $latency = ($output | Select-String "latency average = " | Select-Object -First 1).ToString() -replace ".*latency average = ([\d\.]+).*", '$1'
    
    return [PSCustomObject]@{
        Label = $Label
        TPS = [double]$tps
        LatencyMs = [double]$latency
    }
}

function Ensure-Test-Db {
    Write-Host "Checking for test database '$PgDb'..."
    $checkCmd = "echo '$SudoPassPlain' | sudo -S -u postgres psql -tc `"SELECT 1 FROM pg_database WHERE datname = '$PgDb'`" | grep -q 1 || echo '$SudoPassPlain' | sudo -S -u postgres createdb $PgDb"
    Invoke-SshCommand $checkCmd
}

# --- Main Execution ---

Write-Host "Target: $RemoteHost" -ForegroundColor Green
Write-Host "Test Params: ${Duration}s, $Clients clients, $Jobs threads, Scale Factor $ScaleFactor" -ForegroundColor Green

# 0. Ensure DB exists
Ensure-Test-Db

# 1. Baseline Test
$baseline = Run-PgBench -Label "BASELINE"

# 2. Apply Config (if provided)
if ($ConfigFile) {
    if (-not (Test-Path $ConfigFile)) {
        throw "Config file not found: $ConfigFile"
    }

    Write-Host "`n--- Applying New Configuration ---" -ForegroundColor Yellow
    
    # Copy config to remote temp
    Write-Host "Uploading $ConfigFile to remote..."
    scp "$ConfigFile" "$RemoteUser@${RemoteHost}:/tmp/postgresql.conf.new"

    # Backup existing config, move new one, fix permissions, restart
    # Assuming standard Ubuntu/Debian path. Adjust if different.
    $pgConfigPath = "/etc/postgresql/16/main/postgresql.conf" # Verify version!
    
    # Detect PG version path dynamically
    $detectPathCmd = "ls /etc/postgresql/*/main/postgresql.conf | head -n 1"
    $rawPath = Invoke-SshCommand $detectPathCmd
    
    # Handle potential array output or extra whitespace
    if ($rawPath -is [array]) {
        $remoteConfigPath = $rawPath | Select-Object -Last 1
    } else {
        $remoteConfigPath = $rawPath
    }
    
    # Aggressively sanitize: keep only safe chars
    $remoteConfigPath = $remoteConfigPath -replace "[^a-zA-Z0-9/._-]", ""
    
    if (-not $remoteConfigPath) {
        throw "Could not locate postgresql.conf on remote server."
    }
    Write-Host "Remote config path: $remoteConfigPath"

    # Create a remote script to avoid quoting/line-length issues over SSH
    $scriptContent = @"
#!/bin/bash
set -e
echo "Backing up config..."
cp "$remoteConfigPath" "${remoteConfigPath}.bak"
echo "Appending new config..."
# Append the new config to the existing one (Postgres uses last value)
cat /tmp/postgresql.conf.new >> "$remoteConfigPath"
echo "Setting permissions..."
chown postgres:postgres "$remoteConfigPath"
chmod 644 "$remoteConfigPath"
echo "Restarting PostgreSQL..."
service postgresql restart
sleep 5
service postgresql status
"@
    
    $localScriptPath = "$env:TEMP\apply_pg_config.sh"
    # Ensure Unix line endings
    [IO.File]::WriteAllText($localScriptPath, $scriptContent.Replace("`r`n", "`n"))
    
    Write-Host "Uploading apply script..."
    scp "$localScriptPath" "$RemoteUser@${RemoteHost}:/tmp/apply_pg_config.sh"
    
    # Execute the script
    $applyCmd = "echo '$SudoPassPlain' | sudo -S bash /tmp/apply_pg_config.sh"
    Invoke-SshCommand $applyCmd

    # 3. Tuned Test
    $tuned = Run-PgBench -Label "TUNED"

    # 4. Comparison Output
    Write-Host "`n--- Performance Comparison ---" -ForegroundColor Magenta
    
    $tpsDiff = $tuned.TPS - $baseline.TPS
    $tpsPct = ($tpsDiff / $baseline.TPS) * 100
    
    $latDiff = $tuned.LatencyMs - $baseline.LatencyMs
    $latPct = ($latDiff / $baseline.LatencyMs) * 100

    $baseline | Format-List
    $tuned | Format-List
    
    $tpsColor = if ($tpsDiff -ge 0) { "Green" } else { "Red" }
    Write-Host "TPS Change:     $($tpsDiff.ToString("F2")) ($($tpsPct.ToString("F2"))%)" -ForegroundColor $tpsColor
    
    $latColor = if ($latDiff -le 0) { "Green" } else { "Red" }
    Write-Host "Latency Change: $($latDiff.ToString("F2")) ms ($($latPct.ToString("F2"))%)" -ForegroundColor $latColor

} else {
    Write-Host "`nNo config file provided. Skipping comparison test." -ForegroundColor Yellow
    $baseline | Format-List
}
