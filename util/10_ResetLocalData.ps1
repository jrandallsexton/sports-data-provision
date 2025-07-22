<#
.SYNOPSIS
    Fully reset local development data for SportDeets.

.DESCRIPTION
    Drops PostgreSQL tables, MongoDB collections, and optionally Hangfire schemas.
#>

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
$pgDatabases = $script:pgDatabases

# MongoDB fallback (hardcoded for now)
$mongoConn = "mongodb://localhost:27017"
$mongoDb = "Provider-Local"
$mongoCollection = "FootballNcaa"

# Confirm prompt
$confirm = Read-Host "This will delete all local dev data. Type YES to continue"
if ($confirm -ne "YES") {
    Write-Host "Cancelled."
    exit
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
    Write-Host "  Running psql hangfire: $($argsHangfire -join ' ')"
    & psql @argsHangfire

    Remove-Item $dropFile, $hangfireFile
}

# Set PGPASSWORD for psql
$env:PGPASSWORD = $pgPass

# Run PG drops for each defined database
foreach ($dbName in $pgDatabases) {
    Reset-PgDb -label $dbName -dbName $dbName
}

# Drop Mongo collection if mongo CLI is installed
$mongoDbName = "Provider-Local"
$mongoCollection = "FootballNcaa"

if (Get-Command "mongosh" -ErrorAction SilentlyContinue) {
    Write-Host "Deleting all documents from MongoDB collection '$mongoCollection' in database '$mongoDbName'..."
    try {
        mongosh --quiet --eval `
            "db.getSiblingDB('$mongoDbName').getCollection('$mongoCollection').deleteMany({})"
        Write-Host "All documents in '$mongoDbName.$mongoCollection' deleted successfully."
    }
    catch {
        Write-Warning "mongosh execution failed: $_"
    }
} else {
    Write-Warning "'mongosh' CLI not found. Skipping MongoDB document purge."
}

Write-Host "Local reset complete."
