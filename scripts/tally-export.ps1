<#
.SYNOPSIS
  Export all masters and month-by-month trial balances from a running Tally
  instance to local XML files.

.DESCRIPTION
  Standalone fallback script that mirrors what fynos-tally-connect does over
  the Tally XML API, but without any UI, scheduler, or backend upload. Writes
  plain XML files to a timestamped folder so they can be inspected locally or
  handed off to someone else.

  Use this when the Tally Connect desktop app is misbehaving at a client site
  and you need to get data out of Tally right now.

.PARAMETER FromMonth
  First month to fetch (inclusive), in YYYY-MM format.
  Default: 2025-04 (start of FY 2025-26).

.PARAMETER ToMonth
  Last month to fetch (inclusive), in YYYY-MM format.
  Default: 2026-03 (end of FY 2025-26).

.PARAMETER TallyUrl
  Tally XML API endpoint.
  Default: http://127.0.0.1:9000/

.EXAMPLE
  .\tally-export.ps1
  # Exports masters + 12 monthly trial balances for FY 2025-26 from localhost.

.EXAMPLE
  .\tally-export.ps1 -FromMonth 2024-04 -ToMonth 2025-03
  # Exports FY 2024-25.

.EXAMPLE
  .\tally-export.ps1 -TallyUrl http://192.168.1.50:9000/
  # Exports from a Tally machine on the local network.

.NOTES
  - Requires: Windows 10+ (for built-in curl.exe), Tally running with a
    company loaded.
  - The script calls curl.exe directly to avoid PowerShell's alias quirks
    around Invoke-WebRequest headers.
  - If Tally returns a <LINEERROR> for a given report, the script marks it
    as FAIL but continues with the rest. Open the failed XML file to see
    what Tally said.
#>

param(
  [string]$FromMonth = "2025-04",
  [string]$ToMonth   = "2026-03",
  [string]$TallyUrl  = "http://127.0.0.1:9000/"
)

$ErrorActionPreference = "Stop"

# Output folder: ./tally-export-YYYYMMDD-HHMMSS/
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir = Join-Path (Get-Location) "tally-export-$timestamp"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

function Invoke-TallyRequest {
  param(
    [string]$Xml,
    [string]$OutFile,
    [string]$Label
  )

  # Use curl.exe directly — Windows 10+ ships with it, and it bypasses the
  # PowerShell `curl -> Invoke-WebRequest` alias that has incompatible flags.
  & curl.exe -sS `
    -X POST `
    -H "Content-Type: text/xml" `
    --data-binary $Xml `
    $TallyUrl `
    -o $OutFile

  if ($LASTEXITCODE -ne 0) {
    Write-Host "  [FAIL] $Label - curl exit code $LASTEXITCODE" -ForegroundColor Red
    return
  }

  $size = (Get-Item $OutFile).Length
  $content = Get-Content $OutFile -Raw -ErrorAction SilentlyContinue

  if ($content -match "<LINEERROR>([^<]+)</LINEERROR>") {
    $err = $Matches[1]
    Write-Host ("  [FAIL] {0} ({1} bytes) - Tally said: {2}" -f $Label, $size, $err) -ForegroundColor Red
    return $false
  }

  Write-Host ("  [ OK ] {0} ({1} bytes)" -f $Label, $size) -ForegroundColor Green
  return $true
}

Write-Host ""
Write-Host "Tally export"
Write-Host "  URL:     $TallyUrl"
Write-Host "  Period:  $FromMonth through $ToMonth"
Write-Host "  Output:  $outDir"
Write-Host ""

# ─── Masters ──────────────────────────────────────────────────────────
# "List of Accounts" is the one report name that works reliably across
# TallyPrime and Tally.ERP 9. It exports groups AND ledgers in one shot,
# so separate "List of Groups" / "All Masters" calls are unnecessary.
Write-Host "Masters:"

Invoke-TallyRequest `
  -Xml '<ENVELOPE><HEADER><TALLYREQUEST>Export Data</TALLYREQUEST></HEADER><BODY><EXPORTDATA><REQUESTDESC><REPORTNAME>List of Accounts</REPORTNAME></REQUESTDESC></EXPORTDATA></BODY></ENVELOPE>' `
  -OutFile (Join-Path $outDir "masters-ledgers.xml") `
  -Label "Ledgers + Groups (List of Accounts)"

Write-Host ""

# ─── Pre-flight: pick the right trial balance method ──────────────────
# Some TallyPrime builds ignore EXPLODEFLAG and return group-level totals.
# We test with one month first. If the result is too small (< 5KB = likely
# only ~9 group rows), we fall back to a TDL Collection request which
# bypasses the report layer entirely and asks Tally's object model directly
# for ledger-level closing balances.

Write-Host "Pre-flight: testing trial balance method..."

$testFrom = $FromMonth.Split('-')
$testLastDay = [DateTime]::DaysInMonth([int]$testFrom[0], [int]$testFrom[1])
$testSvfrom = "{0}{1}01" -f $testFrom[0], $testFrom[1]
$testSvto   = "{0}{1}{2:D2}" -f $testFrom[0], $testFrom[1], $testLastDay
$testFile   = Join-Path $outDir "_preflight-test.xml"

$testXml = "<ENVELOPE><HEADER><TALLYREQUEST>Export Data</TALLYREQUEST></HEADER><BODY><EXPORTDATA><REQUESTDESC><REPORTNAME>Trial Balance</REPORTNAME><STATICVARIABLES><EXPLODEFLAG>Yes</EXPLODEFLAG><SVFROMDATE>$testSvfrom</SVFROMDATE><SVTODATE>$testSvto</SVTODATE><SVEXPORTFORMAT>`$`$SysName:XML</SVEXPORTFORMAT></STATICVARIABLES></REQUESTDESC></EXPORTDATA></BODY></ENVELOPE>"

$testResult = Invoke-TallyRequest `
  -Xml $testXml `
  -OutFile $testFile `
  -Label "Pre-flight test ($testSvfrom)"

$useTDL = $false
if ($testResult) {
  $testSize = (Get-Item $testFile).Length
  if ($testSize -lt 5120) {
    Write-Host "  [WARN] Response too small ($testSize bytes) - likely group-level only." -ForegroundColor Yellow
    Write-Host "         Switching to TDL Collection method for ledger-level detail." -ForegroundColor Yellow
    $useTDL = $true
  } else {
    Write-Host "  [GOOD] EXPLODEFLAG works - got ledger-level detail ($testSize bytes)." -ForegroundColor Green
  }
} else {
  Write-Host "  [WARN] EXPLODEFLAG trial balance failed. Switching to TDL Collection method." -ForegroundColor Yellow
  $useTDL = $true
}

Remove-Item $testFile -ErrorAction SilentlyContinue
Write-Host ""

# ─── Month-by-month Trial Balance (ledger-level) ─────────────────────
if ($useTDL) {
  Write-Host "Trial balances (TDL Collection method, ledger-level):"
} else {
  Write-Host "Trial balances (EXPLODEFLAG method, ledger-level):"
}

$fromParts = $FromMonth.Split('-')
$toParts   = $ToMonth.Split('-')
$y         = [int]$fromParts[0]
$m         = [int]$fromParts[1]
$toYear    = [int]$toParts[0]
$toMon     = [int]$toParts[1]

while (($y -lt $toYear) -or ($y -eq $toYear -and $m -le $toMon)) {
  $lastDay = [DateTime]::DaysInMonth($y, $m)
  $tag     = "{0:D4}-{1:D2}" -f $y, $m
  $svfrom  = "{0:D4}{1:D2}01" -f $y, $m
  $svto    = "{0:D4}{1:D2}{2:D2}" -f $y, $m, $lastDay

  if ($useTDL) {
    # TDL Collection: bypasses the report layer and queries Tally's object
    # model directly. Asks for every Ledger's Name, Parent group, and
    # ClosingBalance within the given date range. Works on all TallyPrime
    # and Tally.ERP 9 builds.
    $xml = "<ENVELOPE><HEADER><VERSION>1</VERSION><TALLYREQUEST>Export</TALLYREQUEST><TYPE>Collection</TYPE><ID>TrialBalanceLedgers</ID></HEADER><BODY><DESC><STATICVARIABLES><SVFROMDATE>$svfrom</SVFROMDATE><SVTODATE>$svto</SVTODATE></STATICVARIABLES><TDL><TDLMESSAGE><COLLECTION NAME=`"TrialBalanceLedgers`" ISMODIFY=`"No`"><TYPE>Ledger</TYPE><FETCH>Name,Parent,ClosingBalance,OpeningBalance</FETCH></COLLECTION></TDLMESSAGE></TDL></DESC></BODY></ENVELOPE>"
  } else {
    $xml = "<ENVELOPE><HEADER><TALLYREQUEST>Export Data</TALLYREQUEST></HEADER><BODY><EXPORTDATA><REQUESTDESC><REPORTNAME>Trial Balance</REPORTNAME><STATICVARIABLES><EXPLODEFLAG>Yes</EXPLODEFLAG><SVFROMDATE>$svfrom</SVFROMDATE><SVTODATE>$svto</SVTODATE><SVEXPORTFORMAT>`$`$SysName:XML</SVEXPORTFORMAT></STATICVARIABLES></REQUESTDESC></EXPORTDATA></BODY></ENVELOPE>"
  }

  Invoke-TallyRequest `
    -Xml $xml `
    -OutFile (Join-Path $outDir "trial-balance-$tag.xml") `
    -Label ("Trial Balance {0} ({1} -> {2})" -f $tag, $svfrom, $svto) | Out-Null

  $m++
  if ($m -gt 12) { $m = 1; $y++ }
}

Write-Host ""
Write-Host "Done. Files in: $outDir" -ForegroundColor Cyan
Get-ChildItem $outDir | Format-Table Name, @{Name="Size(KB)";Expression={[math]::Round($_.Length/1KB,1)}} -AutoSize
