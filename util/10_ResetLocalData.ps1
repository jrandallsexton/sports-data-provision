# 10_ResetLocalData.ps1
<#
.SYNOPSIS
    Fully reset local development data for SportDeets.

.DESCRIPTION
    Drops PostgreSQL tables, MongoDB collections, and optionally Hangfire schemas.
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [string]$Sport = ""
)

if (-not $env:SPORTDEETS_SECRETS_PATH) {
    throw "ERROR: SPORTDEETS_SECRETS_PATH environment variable is not set."
}

Write-Host "Starting local data reset..."

# Load secrets file (PowerShell .ps1 that defines $script:* variables)
$secretsPath = $env:SPORTDEETS_SECRETS_PATH
. "$secretsPath\_common-variables.ps1"

# PostgreSQL connection values
$pgHost = $script:pgHostLocal
$pgUser = $script:pgUserLocal
$pgPass = $script:pgPasswordLocal
$pgDatabases = $script:pgDatabasesLocal

# RabbitMQ connection values
$rabbitHost = "localhost"
$rabbitPort = "15672"
$rabbitUser = $script:rmqUsernameLocal
$rabbitPass = $script:rmqPasswordLocal
$rabbitVhost = "%2F" # URL-encoded "/"

# MongoDB fallback (hardcoded for now)
$mongoConn = "mongodb://localhost:27017"
$mongoDb = "Provider-Local"
$allMongoCollections = @("FootballNcaa", "FootballNfl")
$mongoCollections = if ($Sport) { $allMongoCollections | Where-Object { $_ -eq $Sport } } else { $allMongoCollections }

# Confirm prompt
if (-not $Force) {
    $confirm = Read-Host "This will delete all LOCAL data. Type YES to continue"
    if ($confirm -ne "YES") {
        Write-Host "Cancelled."
        exit
    }
}

# Write SQL to temp file
function Write-TempSqlFile($sql) {
    $tempPath = [System.IO.Path]::GetTempFileName()
    # Use a StreamWriter to explicitly disable BOM
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $writer = New-Object System.IO.StreamWriter($tempPath, $false, $utf8NoBom)
    $writer.Write($sql)
    $writer.Close()
    return $tempPath
}

# SQL statements
# SQL statements
$dropTablesSql = @'
DO $$
DECLARE
    stmt TEXT;
BEGIN
    FOR stmt IN
        SELECT 'DROP TABLE IF EXISTS "' || tablename || '" CASCADE;'
        FROM pg_tables
        WHERE schemaname = 'public'
    LOOP
        EXECUTE stmt;
    END LOOP;
END
$$;
'@

$dropHangfireSql = "DROP SCHEMA IF EXISTS hangfire CASCADE;"

function Reset-PgDb($label, $dbName) {
    Write-Host "Dropping $label ($dbName) PostgreSQL tables and Hangfire schema..."

    $dropFile = Write-TempSqlFile $dropTablesSql
    $hangfireFile = Write-TempSqlFile $dropHangfireSql

    # Sanity checks
    if (-not $pgHost) { throw "pgHost is null or empty." }
    if (-not $pgUser) { throw "pgUser is null or empty." }
    if (-not $pgPass) { throw "pgPass is null or empty." }
    if (-not $dbName) { throw "pgDb (actual: $label) is null or empty." }

    Write-Host "  Host: $pgHost"
    Write-Host "  User: $pgUser"
    Write-Host "  DB:   $dbName"

    $argsDrop = @("-h", $pgHost, "-U", $pgUser, "-d", $dbName, "-f", $dropFile)
    $argsHangfire = @("-h", $pgHost, "-U", $pgUser, "-d", $dbName, "-f", $hangfireFile)

    Write-Host "  Running psql drop: $($argsDrop -join ' ')"
    & psql @argsDrop
    if ($LASTEXITCODE -ne 0) {
        throw "psql drop failed with exit code $LASTEXITCODE"
    }

    Write-Host "  Running psql hangfire: $($argsHangfire -join ' ')"
    & psql @argsHangfire
    if ($LASTEXITCODE -ne 0) {
        throw "psql hangfire failed with exit code $LASTEXITCODE"
    }

    Remove-Item $dropFile, $hangfireFile
}

# Set PGPASSWORD for psql
$env:PGPASSWORD = $pgPass

# Filter PG databases by sport if specified
$targetDatabases = if ($Sport) {
    $pgDatabases | Where-Object { $_ -like "*$Sport*" }
} else {
    $pgDatabases
}

# Run PG drops for each targeted database in parallel
$resetJobs = @()
foreach ($dbName in $targetDatabases) {
    Write-Host "  Starting parallel reset for $dbName..." -ForegroundColor Gray
    $job = Start-Job -ScriptBlock {
        param($host_, $user_, $pass_, $dbName_)

        $env:PGPASSWORD = $pass_

        # Write SQL to temp files (no BOM)
        function Write-TempSqlFile($sql) {
            $tempPath = [System.IO.Path]::GetTempFileName()
            $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
            $writer = New-Object System.IO.StreamWriter($tempPath, $false, $utf8NoBom)
            $writer.Write($sql)
            $writer.Close()
            return $tempPath
        }

        $dropTablesSql = @'
DO $$
DECLARE
    stmt TEXT;
BEGIN
    FOR stmt IN
        SELECT 'DROP TABLE IF EXISTS "' || tablename || '" CASCADE;'
        FROM pg_tables
        WHERE schemaname = 'public'
    LOOP
        EXECUTE stmt;
    END LOOP;
END
$$;
'@
        $dropHangfireSql = "DROP SCHEMA IF EXISTS hangfire CASCADE;"

        $dropFile = Write-TempSqlFile $dropTablesSql
        $hangfireFile = Write-TempSqlFile $dropHangfireSql

        $output = @()
        $output += "Resetting $dbName_..."

        & psql -h $host_ -U $user_ -d $dbName_ -f $dropFile 2>&1 | ForEach-Object { $output += "  $_" }
        $dropExit = $LASTEXITCODE

        & psql -h $host_ -U $user_ -d $dbName_ -f $hangfireFile 2>&1 | ForEach-Object { $output += "  $_" }
        $hangfireExit = $LASTEXITCODE

        Remove-Item $dropFile, $hangfireFile -ErrorAction SilentlyContinue

        return @{
            DbName = $dbName_
            DropExit = $dropExit
            HangfireExit = $hangfireExit
            Output = $output
        }
    } -ArgumentList $pgHost, $pgUser, $pgPass, $dbName

    $resetJobs += $job
}

Write-Host "  Waiting for $($resetJobs.Count) parallel PG reset jobs..." -ForegroundColor Gray
$resetJobs | Wait-Job | Out-Null

foreach ($job in $resetJobs) {
    $result = Receive-Job -Job $job
    $info = $result | Where-Object { $_ -is [hashtable] } | Select-Object -Last 1
    if ($info) {
        $info.Output | ForEach-Object { Write-Host $_ }
        if ($info.DropExit -ne 0) {
            Write-Warning "psql drop failed for $($info.DbName) with exit code $($info.DropExit)"
        }
        if ($info.HangfireExit -ne 0) {
            Write-Warning "psql hangfire drop failed for $($info.DbName) with exit code $($info.HangfireExit)"
        }
        if ($info.DropExit -eq 0 -and $info.HangfireExit -eq 0) {
            Write-Host "  $($info.DbName) reset complete" -ForegroundColor Green
        }
    }
    Remove-Job -Job $job
}

# Drop Mongo collections if mongo CLI is installed
$mongoDbName = "Provider-Local"

if (Get-Command "mongosh" -ErrorAction SilentlyContinue) {
    foreach ($mongoCollection in $mongoCollections) {
        Write-Host "Deleting all documents from MongoDB collection '$mongoCollection' in database '$mongoDbName'..."
        try {
            mongosh --quiet --eval `
                "db.getSiblingDB('$mongoDbName').getCollection('$mongoCollection').deleteMany({})"
            Write-Host "All documents in '$mongoDbName.$mongoCollection' deleted successfully."
        }
        catch {
            Write-Warning "mongosh execution failed for '$mongoCollection': $_"
        }
    }
} else {
    Write-Warning "'mongosh' CLI not found. Skipping MongoDB document purge."
}

Write-Host "Cleaning RabbitMQ queues..." -ForegroundColor Cyan

# Get all queues using RabbitMQ Management HTTP API
try {
    $rabbitApiUrl = "http://${rabbitHost}:${rabbitPort}/api/queues/${rabbitVhost}"
    $cred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${rabbitUser}:${rabbitPass}"))
    $headers = @{ Authorization = "Basic $cred" }
    
    $queues = Invoke-RestMethod -Uri $rabbitApiUrl -Headers $headers -Method Get
    
    if ($queues.Count -gt 0) {
        Write-Host "  Found $($queues.Count) queue(s) to purge"
        foreach ($queue in $queues) {
            $queueName = $queue.name
            Write-Host "  Purging queue: $queueName"
            
            # Purge (delete all messages) from the queue
            $purgeUrl = "http://${rabbitHost}:${rabbitPort}/api/queues/${rabbitVhost}/${queueName}/contents"
            try {
                Invoke-RestMethod -Uri $purgeUrl -Headers $headers -Method Delete | Out-Null
                Write-Host "    ✓ Purged successfully" -ForegroundColor Green
            }
            catch {
                Write-Warning "    Failed to purge queue '$queueName': $_"
            }
        }
    } else {
        Write-Host "  No queues found."
    }
    
    Write-Host "RabbitMQ cleanup complete." -ForegroundColor Green
}
catch {
    Write-Warning "Failed to connect to RabbitMQ Management API: $_"
    Write-Warning "Make sure RabbitMQ is running (.\24_StartRabbitMQ.ps1)"
}


Write-Host "Local reset complete." -ForegroundColor Green
exit 0
