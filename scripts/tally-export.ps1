<#
.SYNOPSIS
  Export all masters and month-by-month trial balances from a running Tally
  instance to local XML files.

.DESCRIPTION
  Standalone fallback script that mirrors what fynos-tally-connect does over
  the Tally XML API, but without any UI, scheduler, or backend upload. Writes
  plain XML files to a timestamped folder so they can be inspected locally or
  handed off to someone else.

  The script auto-discovers which Tally XML method works on the user's
  TallyPrime build, by trying multiple approaches in order:

    1. Trial Balance report with ALL F12 detail flags set together
       (ISDETAILED, EXPANDALLINDETAILEDFORMAT, SHOWOPENINGBALANCE, etc.)
    2. Trial Balance report with EXPLODEFLAG (single-level expansion)
    3. Trial Balance report with EXPLODENESTEDFLAG (recursive expansion)
    4. Built-in Ledger collection (no custom TDL)
    5. Custom TDL Collection (LAST resort — many builds block this)

  For each method, the script does a one-month preflight test, counts the
  number of ledger rows in the response, and picks the first method that
  returns more than the group-only threshold (>50 rows). The chosen method
  is then used for all 12 monthly exports.

  If NO method works, the script writes a clear DIAGNOSIS.txt file in the
  output folder explaining what was tried, what each method returned, and
  what to do next (typically: switch to manual Option C export from Tally).

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
  - Requires: Windows 10+ (built-in curl.exe), Tally running, company loaded.
  - Uses curl.exe directly to bypass PowerShell's curl -> Invoke-WebRequest
    alias which has incompatible flags.
  - All requests have a 5-minute (300s) timeout to handle large datasets.
  - Detailed responses on a real company are typically 50-500 KB per month.
  - If the chosen method returns < 5 KB it's almost certainly group-only.
#>

param(
  [string]$FromMonth = "2025-04",
  [string]$ToMonth   = "2026-03",
  [string]$TallyUrl  = "http://127.0.0.1:9000/"
)

$ErrorActionPreference = "Stop"

# ─── Setup ────────────────────────────────────────────────────────────
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir = Join-Path (Get-Location) "tally-export-$timestamp"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

# Threshold: if a response has fewer than this many <DSPDISPNAME> rows, it's
# almost certainly only showing group totals (real companies have 100s of
# ledgers). Tuned conservatively — even tiny companies have 30-50+ ledgers.
$LEDGER_ROW_THRESHOLD = 50

# ─── Core HTTP function ───────────────────────────────────────────────

function Invoke-TallyRequest {
  param(
    [string]$Xml,
    [string]$OutFile,
    [string]$Label,
    [int]$TimeoutSec = 300
  )

  & curl.exe `
    --max-time $TimeoutSec `
    -sS `
    -X POST `
    -H "Content-Type: text/xml" `
    --data-binary $Xml `
    $TallyUrl `
    -o $OutFile

  if ($LASTEXITCODE -ne 0) {
    Write-Host ("    [FAIL] {0} - curl exit code {1}" -f $Label, $LASTEXITCODE) -ForegroundColor Red
    return @{ Success = $false; Size = 0; Rows = 0; Error = "curl exit $LASTEXITCODE" }
  }

  if (-not (Test-Path $OutFile)) {
    Write-Host ("    [FAIL] {0} - output file not created" -f $Label) -ForegroundColor Red
    return @{ Success = $false; Size = 0; Rows = 0; Error = "no output file" }
  }

  $size = (Get-Item $OutFile).Length
  $content = Get-Content $OutFile -Raw -ErrorAction SilentlyContinue

  # Detect the various error responses Tally can return
  if ($content -match "<LINEERROR>([^<]+)</LINEERROR>") {
    $err = $Matches[1]
    Write-Host ("    [FAIL] {0} ({1} bytes) - LINEERROR: {2}" -f $Label, $size, $err) -ForegroundColor Red
    return @{ Success = $false; Size = $size; Rows = 0; Error = "LINEERROR: $err" }
  }

  if ($content -match "<RESPONSE>Unknown Request[^<]*</RESPONSE>") {
    Write-Host ("    [FAIL] {0} ({1} bytes) - Unknown Request (TallyPrime blocked this method)" -f $Label, $size) -ForegroundColor Red
    return @{ Success = $false; Size = $size; Rows = 0; Error = "Unknown Request" }
  }

  if ($content -match "<RESPONSE>([^<]+)</RESPONSE>" -and $content -notmatch "<DSPDISPNAME>") {
    Write-Host ("    [FAIL] {0} ({1} bytes) - response was {2}" -f $Label, $size, $Matches[1]) -ForegroundColor Red
    return @{ Success = $false; Size = $size; Rows = 0; Error = $Matches[1] }
  }

  # Count <DSPDISPNAME> rows (Trial Balance row count) or <LEDGER NAME=> tags
  # (Collection format) — whichever is present
  $rows = ([regex]::Matches($content, '<DSPDISPNAME>')).Count
  if ($rows -eq 0) {
    $rows = ([regex]::Matches($content, '<LEDGER\s+NAME=')).Count
  }

  Write-Host ("    [ OK ] {0} ({1} bytes, {2} rows)" -f $Label, $size, $rows) -ForegroundColor Green
  return @{ Success = $true; Size = $size; Rows = $rows; Error = $null }
}

# ─── XML envelope builders ────────────────────────────────────────────

function Get-TBXmlMethod1-AllFlags {
  param([string]$From, [string]$To)
  # Method 1: Trial Balance report with EVERY F12 detail flag set together.
  # Maps directly to the F12 dialog: Format=Detailed, Expand all=Yes,
  # Show Opening Balance=Yes. This is the closest equivalent to what a
  # human would do via the Tally UI.
  return @"
<ENVELOPE><HEADER><TALLYREQUEST>Export Data</TALLYREQUEST></HEADER><BODY><EXPORTDATA><REQUESTDESC><REPORTNAME>Trial Balance</REPORTNAME><STATICVARIABLES><SVFROMDATE>$From</SVFROMDATE><SVTODATE>$To</SVTODATE><SVEXPORTFORMAT>`$`$SysName:XML</SVEXPORTFORMAT><ISDETAILED>Yes</ISDETAILED><EXPANDALLINDETAILEDFORMAT>Yes</EXPANDALLINDETAILEDFORMAT><EXPLODEFLAG>Yes</EXPLODEFLAG><EXPLODENESTEDFLAG>Yes</EXPLODENESTEDFLAG><EXPLODEALLLEVELSFLAG>Yes</EXPLODEALLLEVELSFLAG><SHOWOPENINGBALANCE>Yes</SHOWOPENINGBALANCE><ISITEMISE>Yes</ISITEMISE></STATICVARIABLES></REQUESTDESC></EXPORTDATA></BODY></ENVELOPE>
"@
}

function Get-TBXmlMethod2-ExplodeFlag {
  param([string]$From, [string]$To)
  # Method 2: Standard EXPLODEFLAG (one-level expansion). Original approach
  # we tried before. Returns groups + their direct children only.
  return @"
<ENVELOPE><HEADER><TALLYREQUEST>Export Data</TALLYREQUEST></HEADER><BODY><EXPORTDATA><REQUESTDESC><REPORTNAME>Trial Balance</REPORTNAME><STATICVARIABLES><EXPLODEFLAG>Yes</EXPLODEFLAG><SVFROMDATE>$From</SVFROMDATE><SVTODATE>$To</SVTODATE><SVEXPORTFORMAT>`$`$SysName:XML</SVEXPORTFORMAT></STATICVARIABLES></REQUESTDESC></EXPORTDATA></BODY></ENVELOPE>
"@
}

function Get-TBXmlMethod3-NestedExplode {
  param([string]$From, [string]$To)
  # Method 3: EXPLODENESTEDFLAG = recursive expansion. Tally TDL
  # documentation says this should walk the entire group hierarchy.
  return @"
<ENVELOPE><HEADER><TALLYREQUEST>Export Data</TALLYREQUEST></HEADER><BODY><EXPORTDATA><REQUESTDESC><REPORTNAME>Trial Balance</REPORTNAME><STATICVARIABLES><EXPLODENESTEDFLAG>Yes</EXPLODENESTEDFLAG><SVFROMDATE>$From</SVFROMDATE><SVTODATE>$To</SVTODATE><SVEXPORTFORMAT>`$`$SysName:XML</SVEXPORTFORMAT></STATICVARIABLES></REQUESTDESC></EXPORTDATA></BODY></ENVELOPE>
"@
}

function Get-TBXmlMethod4-LedgerCollection {
  param([string]$From, [string]$To)
  # Method 4: Built-in Ledger collection. No custom TDL — just asks Tally
  # for its built-in "Ledger" collection by ID. Should work even on builds
  # that block custom TDL (Method 5).
  return @"
<ENVELOPE><HEADER><VERSION>1</VERSION><TALLYREQUEST>Export</TALLYREQUEST><TYPE>Collection</TYPE><ID>Ledger</ID></HEADER><BODY><DESC><STATICVARIABLES><SVFROMDATE>$From</SVFROMDATE><SVTODATE>$To</SVTODATE><SVEXPORTFORMAT>`$`$SysName:XML</SVEXPORTFORMAT></STATICVARIABLES></DESC></BODY></ENVELOPE>
"@
}

function Get-TBXmlMethod5-CustomTDL {
  param([string]$From, [string]$To)
  # Method 5: Custom TDL Collection — LAST resort. Many corporate/restricted
  # TallyPrime builds block this entirely with "Unknown Request".
  return @"
<ENVELOPE><HEADER><VERSION>1</VERSION><TALLYREQUEST>Export</TALLYREQUEST><TYPE>Collection</TYPE><ID>TrialBalanceLedgers</ID></HEADER><BODY><DESC><STATICVARIABLES><SVFROMDATE>$From</SVFROMDATE><SVTODATE>$To</SVTODATE></STATICVARIABLES><TDL><TDLMESSAGE><COLLECTION NAME=`"TrialBalanceLedgers`" ISMODIFY=`"No`"><TYPE>Ledger</TYPE><FETCH>Name,Parent,ClosingBalance,OpeningBalance</FETCH></COLLECTION></TDLMESSAGE></TDL></DESC></BODY></ENVELOPE>
"@
}

# ─── Banner ───────────────────────────────────────────────────────────

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════"
Write-Host "  Fynos Tally Export"
Write-Host "═══════════════════════════════════════════════════════════════"
Write-Host "  URL:     $TallyUrl"
Write-Host "  Period:  $FromMonth through $ToMonth"
Write-Host "  Output:  $outDir"
Write-Host ""

# ─── Phase 1: Masters export ──────────────────────────────────────────

Write-Host "── Phase 1: Masters (Chart of Accounts) ──" -ForegroundColor Cyan

$mastersResult = Invoke-TallyRequest `
  -Xml '<ENVELOPE><HEADER><TALLYREQUEST>Export Data</TALLYREQUEST></HEADER><BODY><EXPORTDATA><REQUESTDESC><REPORTNAME>List of Accounts</REPORTNAME></REQUESTDESC></EXPORTDATA></BODY></ENVELOPE>' `
  -OutFile (Join-Path $outDir "masters-ledgers.xml") `
  -Label "Ledgers + Groups (List of Accounts)"

if (-not $mastersResult.Success) {
  Write-Host ""
  Write-Host "[ABORT] Masters export failed. Cannot continue." -ForegroundColor Red
  Write-Host "        Check that Tally is running and a company is loaded." -ForegroundColor Red
  exit 1
}

Write-Host ""

# ─── Phase 2: Method discovery (preflight) ────────────────────────────

Write-Host "── Phase 2: Discovering best trial balance method ──" -ForegroundColor Cyan
Write-Host "  Testing each method against $FromMonth to find one that returns ledger-level detail..."
Write-Host "  (Threshold: more than $LEDGER_ROW_THRESHOLD rows = ledger-level)"
Write-Host ""

$testFrom = $FromMonth.Split('-')
$testY = [int]$testFrom[0]
$testM = [int]$testFrom[1]
$testLastDay = [DateTime]::DaysInMonth($testY, $testM)
$testSvfrom = "{0:D4}{1:D2}01" -f $testY, $testM
$testSvto   = "{0:D4}{1:D2}{2:D2}" -f $testY, $testM, $testLastDay

$methods = @(
  @{
    Name = "Method 1: Trial Balance + ALL detail flags (ISDETAILED, EXPANDALL, EXPLODE*, etc.)"
    ShortName = "all-flags"
    XmlFn = ${function:Get-TBXmlMethod1-AllFlags}
  },
  @{
    Name = "Method 2: Trial Balance + EXPLODEFLAG only (single-level expansion)"
    ShortName = "explodeflag"
    XmlFn = ${function:Get-TBXmlMethod2-ExplodeFlag}
  },
  @{
    Name = "Method 3: Trial Balance + EXPLODENESTEDFLAG (recursive expansion)"
    ShortName = "nested-explode"
    XmlFn = ${function:Get-TBXmlMethod3-NestedExplode}
  },
  @{
    Name = "Method 4: Built-in Ledger collection (no custom TDL)"
    ShortName = "ledger-collection"
    XmlFn = ${function:Get-TBXmlMethod4-LedgerCollection}
  },
  @{
    Name = "Method 5: Custom TDL TrialBalanceLedgers collection (last resort)"
    ShortName = "custom-tdl"
    XmlFn = ${function:Get-TBXmlMethod5-CustomTDL}
  }
)

$chosenMethod = $null
$diagnostics = @()

foreach ($method in $methods) {
  Write-Host "  Trying $($method.Name)" -ForegroundColor Yellow
  $testFile = Join-Path $outDir ("_preflight_{0}.xml" -f $method.ShortName)
  $xml = & $method.XmlFn -From $testSvfrom -To $testSvto

  $result = Invoke-TallyRequest `
    -Xml $xml `
    -OutFile $testFile `
    -Label "Preflight: $($method.ShortName)"

  $diagnostics += [PSCustomObject]@{
    Method  = $method.ShortName
    Success = $result.Success
    Size    = $result.Size
    Rows    = $result.Rows
    Error   = $result.Error
  }

  if ($result.Success -and $result.Rows -gt $LEDGER_ROW_THRESHOLD) {
    Write-Host ("    >>> WINNER: $($result.Rows) rows >= threshold $LEDGER_ROW_THRESHOLD") -ForegroundColor Green
    $chosenMethod = $method
    break
  } elseif ($result.Success -and $result.Rows -le $LEDGER_ROW_THRESHOLD) {
    Write-Host ("    [SKIP] Only $($result.Rows) rows — likely group-level only, trying next") -ForegroundColor Yellow
  }
  Write-Host ""
}

# Clean up preflight test files
Get-ChildItem $outDir -Filter "_preflight_*.xml" | Remove-Item -ErrorAction SilentlyContinue

# ─── Phase 3: Final decision ──────────────────────────────────────────

Write-Host ""
Write-Host "── Phase 3: Method discovery results ──" -ForegroundColor Cyan
$diagnostics | Format-Table Method, Success, Size, Rows, Error -AutoSize

if ($null -eq $chosenMethod) {
  # No method returned ledger-level detail. Write a diagnosis file and exit.
  Write-Host ""
  Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Red
  Write-Host "  NO METHOD WORKED FOR LEDGER-LEVEL TRIAL BALANCE" -ForegroundColor Red
  Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Red

  $diagFile = Join-Path $outDir "DIAGNOSIS.txt"
  $diagText = @"
Fynos Tally Export — Diagnosis
================================
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Tally URL: $TallyUrl
Test month: $testSvfrom to $testSvto

The script tried 5 different XML API methods to fetch ledger-level trial
balance data. NONE of them returned more than $LEDGER_ROW_THRESHOLD rows.

This means your TallyPrime build does not allow detailed XML export through
any of the standard XML API approaches we know about.

Method-by-method results:
-------------------------
$($diagnostics | ForEach-Object { "  $($_.Method.PadRight(20)) Success=$($_.Success) Size=$($_.Size) Rows=$($_.Rows) Error=$($_.Error)" } | Out-String)

What this means:
----------------
Your TallyPrime build is locked down. It only allows the XML API to return
group-level (Condensed) totals, not individual ledgers.

What to do next: MANUAL EXPORT FROM TALLY (Option C)
-----------------------------------------------------
This always works, regardless of XML API restrictions.

  1. Open TallyPrime, load the company you want to export.
  2. Go to: Display More Reports -> Trial Balance.
  3. Press F12 (Configure) — the configuration panel opens.
  4. Change these settings:
       Format of Report                       : Detailed
       Expand all levels in Detailed format   : Yes
       Show Opening Balance                   : Yes
  5. Press Ctrl + A to accept the configuration.
  6. The Trial Balance now shows individual ledgers (vendors, customers,
     expenses, etc.) — confirm you can see them on screen.
  7. Press F2 to set the period:
       From date: 1-4-2025      To date: 30-4-2025  (April 2025)
  8. Press Alt + E -> Export -> Format: XML (data interchange).
     Save as: trial-balance-2025-04.xml
     Save in: $outDir
  9. Repeat steps 7 and 8 for each month, changing the dates and filename:
       trial-balance-2025-04.xml  (1-4-2025  to 30-4-2025)
       trial-balance-2025-05.xml  (1-5-2025  to 31-5-2025)
       trial-balance-2025-06.xml  (1-6-2025  to 30-6-2025)
       trial-balance-2025-07.xml  (1-7-2025  to 31-7-2025)
       trial-balance-2025-08.xml  (1-8-2025  to 31-8-2025)
       trial-balance-2025-09.xml  (1-9-2025  to 30-9-2025)
       trial-balance-2025-10.xml  (1-10-2025 to 31-10-2025)
       trial-balance-2025-11.xml  (1-11-2025 to 30-11-2025)
       trial-balance-2025-12.xml  (1-12-2025 to 31-12-2025)
       trial-balance-2026-01.xml  (1-1-2026  to 31-1-2026)
       trial-balance-2026-02.xml  (1-2-2026  to 28-2-2026)
       trial-balance-2026-03.xml  (1-3-2026  to 31-3-2026)
 10. Zip the entire output folder and send it to your Fynos contact.

The masters-ledgers.xml file has already been exported successfully.
You only need to do the manual trial balance exports for the 12 months.

If you only need final balances (not month-by-month), you can do step 7
ONCE with period 1-4-2025 to 31-3-2026, and that gives you a single file
with the closing balance of every ledger as of 31-Mar-2026.
"@

  Set-Content -Path $diagFile -Value $diagText
  Write-Host ""
  Write-Host "  Diagnosis written to: $diagFile" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "  Next step: open the diagnosis file for instructions on the"
  Write-Host "  manual export workaround. The masters file IS already exported"
  Write-Host "  successfully — you only need the manual trial balance step."
  Write-Host ""
  Write-Host "  Output folder: $outDir" -ForegroundColor Cyan
  exit 2
}

Write-Host ""
Write-Host "  WINNING METHOD: $($chosenMethod.Name)" -ForegroundColor Green
Write-Host ""

# ─── Phase 4: Run the chosen method for all 12 months ─────────────────

Write-Host "── Phase 4: Exporting all months using winning method ──" -ForegroundColor Cyan

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

  $xml = & $chosenMethod.XmlFn -From $svfrom -To $svto

  Invoke-TallyRequest `
    -Xml $xml `
    -OutFile (Join-Path $outDir "trial-balance-$tag.xml") `
    -Label ("Trial Balance {0} ({1} to {2})" -f $tag, $svfrom, $svto) | Out-Null

  $m++
  if ($m -gt 12) { $m = 1; $y++ }
}

# ─── Done ─────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════"
Write-Host "  Done. Files in: $outDir" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════"
Get-ChildItem $outDir | Sort-Object Name | Format-Table Name, @{Name="Size(KB)";Expression={[math]::Round($_.Length/1KB,1)}} -AutoSize

Write-Host ""
Write-Host "  Used method: $($chosenMethod.Name)"
Write-Host ""
Write-Host "  Next: zip the folder and send it to your Fynos contact."
Write-Host ""
