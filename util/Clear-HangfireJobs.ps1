#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deletes ALL Hangfire jobs from Producer and/or Provider databases
.DESCRIPTION
    Truncates the Hangfire job tables to clear every job, in every state.

    This removes far more than the enqueued backlog. It also deletes Scheduled
    jobs (future delayed work, including competition streamers), Processing jobs,
    and all job history. Recurring job DEFINITIONS are preserved - they live in
    hangfire.set / hangfire.hash, which this script never touches - so the crons
    will re-materialise their jobs on the next run. Anything already scheduled
    before the next cron fire is gone and may need a manual scheduler trigger.

    Tables truncated:
      hangfire.jobqueue, hangfire.state, hangfire.jobparameter, hangfire.job
      hangfire.counter, hangfire.aggregatedcounter   (dashboard statistics)

    Tables deliberately NOT touched:
      hangfire.set, hangfire.hash    (recurring job definitions)
      hangfire.server                (re-registers on its own)

    TRUNCATE is used rather than DELETE: it is effectively instant, reclaims the
    space immediately, and leaves no dead tuples behind. The previous DELETE +
    VACUUM FULL approach took an ACCESS EXCLUSIVE lock for the duration of a full
    table rewrite and required roughly 2x the table size in free disk.
.PARAMETER Database
    Which database to clear: Producer, Provider, or Both (default).
    Against -Target Prod this must be specified explicitly.
.PARAMETER Sport
    Sport mode: FootballNcaa (default), FootballNfl, BaseballMlb, GolfPga
.PARAMETER Target
    Environment target: Local (default) or Prod
.PARAMETER WhatIf
    Show what would be deleted without actually deleting
.PARAMETER Force
    Skip the per-database "type YES to confirm" prompt. Useful when running
    repeatedly during local dev. Has no effect with -WhatIf (which never
    deletes anything).
.PARAMETER KeepStatistics
    Preserve hangfire.counter / hangfire.aggregatedcounter. By default these are
    cleared too, otherwise the dashboard keeps reporting totals for jobs that no
    longer exist.
.EXAMPLE
    .\Clear-HangfireJobs.ps1 -Database Provider -Target Local
    .\Clear-HangfireJobs.ps1 -Database Producer -Sport FootballNcaa -Target Prod -WhatIf
    .\Clear-HangfireJobs.ps1 -Database Both -Sport BaseballMlb -Target Local -Force
#>

param(
    [ValidateSet('Producer', 'Provider', 'Both')]
    [string]$Database = 'Both',

    [ValidateSet('FootballNcaa', 'FootballNfl', 'BaseballMlb', 'GolfPga')]
    [string]$Sport = 'FootballNcaa',

    [ValidateSet('Local', 'Prod')]
    [string]$Target = 'Local',

    [switch]$WhatIf,

    [switch]$Force,

    [switch]$KeepStatistics
)

$ErrorActionPreference = 'Stop'

# Against production, refuse to fall back to the 'Both' default. Clearing the
# wrong database here is unrecoverable, and the two have very different
# contents - Producer's backlog is often bookkeeping residue while Provider's
# is live sourcing work, or vice versa.
if ($Target -eq 'Prod' -and -not $PSBoundParameters.ContainsKey('Database')) {
    throw "ERROR: -Database must be specified explicitly when -Target is Prod (Producer, Provider, or Both)."
}

# Load secrets file
if (-not $env:SPORTDEETS_SECRETS_PATH) {
    throw "ERROR: SPORTDEETS_SECRETS_PATH environment variable is not set."
}

$secretsPath = $env:SPORTDEETS_SECRETS_PATH
. "$secretsPath\_common-variables.ps1"

# PostgreSQL connection details from secrets based on target
if ($Target -eq 'Local') {
    $pgHost = $script:pgHostLocal
    $pgPort = "5432"
    $pgUser = $script:pgUserLocal
    $pgPassword = $script:pgPasswordLocal
} else {
    $pgHost = $script:pgHostProd
    $pgPort = "5432"
    $pgUser = $script:pgUserProd
    $pgPassword = $script:pgPasswordProd
}

$producerDb = "sdProducer.$Sport.Hangfire"
$providerDb = "sdProvider.$Sport.Hangfire"

function Write-ColorLog {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
}

<#
    Runs psql and FAILS LOUDLY. The previous version piped stderr to $null and
    ignored the exit code, so a bad password, a missing database or a permission
    error produced a silent no-op that still reported success.
    $ErrorActionPreference = 'Stop' does not trap native executable failures,
    hence the explicit $LASTEXITCODE check.
#>
function Invoke-Psql {
    param(
        [string]$DatabaseName,
        [string]$Query,
        [switch]$Scalar
    )

    $env:PGPASSWORD = $pgPassword
    try {
        $psqlArgs = @(
            '-h', $pgHost,
            '-p', $pgPort,
            '-U', $pgUser,
            '-d', $DatabaseName,
            '-v', 'ON_ERROR_STOP=1',
            '--no-psqlrc'
        )
        if ($Scalar) { $psqlArgs += @('-t', '-A') }
        $psqlArgs += @('-c', $Query)

        $output = & psql @psqlArgs
        if ($LASTEXITCODE -ne 0) {
            throw "psql exited with code $LASTEXITCODE against '$DatabaseName'. Query: $Query"
        }
        return $output
    }
    finally {
        Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
    }
}

<#
    Returns the full picture rather than just the enqueued count, because the
    truncate removes every state. Reporting only 'Enqueued' understated the
    blast radius of what was about to be destroyed.
#>
function Get-JobBreakdown {
    param([string]$DatabaseName)

    $query = @"
SELECT COALESCE(statename, '(no state)') AS state, COUNT(*)::bigint AS cnt
FROM hangfire.job
GROUP BY 1
UNION ALL
SELECT '~ jobqueue rows (actual queue depth)', COUNT(*)::bigint FROM hangfire.jobqueue
ORDER BY 1;
"@

    $rows = Invoke-Psql -DatabaseName $DatabaseName -Query $query -Scalar

    $breakdown = [ordered]@{}
    foreach ($row in $rows) {
        if ([string]::IsNullOrWhiteSpace($row)) { continue }
        $parts = $row.Split('|')
        if ($parts.Count -ge 2) {
            $breakdown[$parts[0].Trim()] = [int64]$parts[1].Trim()
        }
    }
    return $breakdown
}

function Clear-HangfireDatabase {
    param(
        [string]$DatabaseName,
        [string]$Label
    )

    Write-ColorLog "`n=========================================" -Color Cyan
    Write-ColorLog "Processing: $Label ($DatabaseName)" -Color Cyan
    Write-ColorLog "=========================================" -Color Cyan

    try {
        $breakdown = Get-JobBreakdown -DatabaseName $DatabaseName
    }
    catch {
        Write-ColorLog "ERROR querying $DatabaseName : $_" -Color Red
        Write-ColorLog "Skipping this database. Nothing was deleted." -Color Red
        return
    }

    $totalJobs = 0
    foreach ($key in $breakdown.Keys) {
        if ($key -notlike '~*') { $totalJobs += $breakdown[$key] }
    }

    if ($totalJobs -eq 0) {
        Write-ColorLog "No jobs to clear." -Color Green
        return
    }

    Write-ColorLog "`nCurrent contents of hangfire.job, by state:" -Color Yellow
    foreach ($key in $breakdown.Keys) {
        $color = if ($key -like '~*') { 'Gray' } elseif ($key -eq 'Scheduled') { 'Red' } else { 'White' }
        Write-ColorLog ("    {0,-38} {1,12}" -f $key, $breakdown[$key].ToString('N0')) -Color $color
    }
    Write-ColorLog ("    {0,-38} {1,12}" -f 'TOTAL JOBS TO BE DELETED', $totalJobs.ToString('N0')) -Color Yellow

    # Scheduled jobs are future work - delayed jobs that have not fired yet,
    # which for Producer includes competition streamers for upcoming games.
    # Recurring definitions survive, but anything already materialised does not.
    $scheduled = if ($breakdown.Contains('Scheduled')) { $breakdown['Scheduled'] } else { 0 }
    if ($scheduled -gt 0) {
        Write-ColorLog "`n  !! $($scheduled.ToString('N0')) SCHEDULED job(s) will be destroyed." -Color Red
        Write-ColorLog "     These are future delayed jobs (e.g. competition streamers for" -Color Red
        Write-ColorLog "     upcoming games). Recurring DEFINITIONS survive and will re-create" -Color Red
        Write-ColorLog "     jobs on their next cron fire, but anything due before that fire" -Color Red
        Write-ColorLog "     is lost. Re-trigger the relevant scheduler after clearing." -Color Red
    }

    if ($WhatIf) {
        Write-ColorLog "`n[WHATIF] Would TRUNCATE: hangfire.jobqueue, hangfire.state, hangfire.jobparameter, hangfire.job" -Color Magenta
        if (-not $KeepStatistics) {
            Write-ColorLog "[WHATIF] Would TRUNCATE: hangfire.counter, hangfire.aggregatedcounter (dashboard stats)" -Color Magenta
        }
        Write-ColorLog "[WHATIF] Would PRESERVE: hangfire.set, hangfire.hash (recurring job definitions)" -Color Magenta
        return
    }

    # Confirm deletion (skipped when -Force was passed)
    Write-ColorLog "`nWARNING: About to delete $($totalJobs.ToString('N0')) jobs from $DatabaseName on $pgHost" -Color Red
    if ($Force) {
        Write-ColorLog "  (-Force specified, skipping confirmation)" -Color Yellow
    }
    else {
        $confirm = Read-Host "Type 'YES' to confirm deletion"

        if ($confirm -ne 'YES') {
            Write-ColorLog "Deletion cancelled." -Color Yellow
            return
        }
    }

    Write-ColorLog "`nTruncating..." -Color Yellow

    try {
        # Single statement so the mutual foreign keys are satisfied without
        # needing a delete order. TRUNCATE reclaims space immediately, so no
        # VACUUM FULL (and no long ACCESS EXCLUSIVE rewrite) is required.
        $tables = 'hangfire.jobqueue, hangfire.state, hangfire.jobparameter, hangfire.job'
        if (-not $KeepStatistics) {
            $tables += ', hangfire.counter, hangfire.aggregatedcounter'
        }

        $truncate = "TRUNCATE $tables;"
        Write-ColorLog "  Executing: $truncate" -Color Gray
        Invoke-Psql -DatabaseName $DatabaseName -Query $truncate | Out-Null

        # Verify
        $after = Get-JobBreakdown -DatabaseName $DatabaseName
        $afterTotal = 0
        foreach ($key in $after.Keys) {
            if ($key -notlike '~*') { $afterTotal += $after[$key] }
        }

        Write-ColorLog "`n[OK] Deletion complete." -Color Green
        Write-ColorLog "  Jobs before: $($totalJobs.ToString('N0'))" -Color Gray
        Write-ColorLog "  Jobs after:  $($afterTotal.ToString('N0'))" -Color Gray
        Write-ColorLog "  Deleted:     $(($totalJobs - $afterTotal).ToString('N0'))" -Color Green

        if ($afterTotal -ne 0) {
            Write-ColorLog "  NOTE: $($afterTotal.ToString('N0')) job(s) present after truncate - servers are enqueueing again." -Color Yellow
        }
        if ($scheduled -gt 0) {
            Write-ColorLog "`n  REMINDER: $($scheduled.ToString('N0')) scheduled job(s) were destroyed. Re-trigger the scheduler." -Color Yellow
        }
    }
    catch {
        Write-ColorLog "ERROR during deletion: $_" -Color Red
        throw
    }
}

# Main execution
Write-ColorLog "`n+========================================+" -Color Cyan
Write-ColorLog "|   Hangfire Job Deletion Utility        |" -Color Cyan
Write-ColorLog "+========================================+" -Color Cyan
Write-ColorLog "Target Environment: $Target" -Color White
Write-ColorLog "PostgreSQL Host: $pgHost" -Color White
Write-ColorLog "Sport: $Sport" -Color White
Write-ColorLog "Database(s): $Database" -Color White
Write-ColorLog "Statistics: $(if ($KeepStatistics) { 'preserved' } else { 'cleared' })" -Color White

if ($WhatIf) {
    Write-ColorLog "Mode: WHATIF (no changes will be made)" -Color Magenta
}

# Process databases
if ($Database -eq 'Producer' -or $Database -eq 'Both') {
    Clear-HangfireDatabase -DatabaseName $producerDb -Label "Producer"
}

if ($Database -eq 'Provider' -or $Database -eq 'Both') {
    Clear-HangfireDatabase -DatabaseName $providerDb -Label "Provider"
}

Write-ColorLog "`n=========================================" -Color Cyan
Write-ColorLog "Operation Complete" -Color Cyan
Write-ColorLog "=========================================" -Color Cyan
