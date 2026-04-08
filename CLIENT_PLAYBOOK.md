# Fynos Tally Connect — Client Setup Playbook

This guide walks you through getting your **Tally ERP** data synced to **Fynos**. It covers three options, in order of preference. Start with **Option A** — if it works, you are done in ten minutes. Only move to Option B or C if the previous option does not work on your machine.

| Option | What it is | When to use it | Difficulty |
|---|---|---|---|
| **A** — Fynos Tally Connect App | A small desktop app that auto-syncs Tally to Fynos | Always try this first | Easy |
| **B** — Fallback script | A one-time PowerShell script that exports Tally data to XML files | Use if Option A will not connect to Tally | Easy |
| **C** — Manual export from Tally | Export the reports directly from Tally's menus | Use if Option B also fails, or if port 9000 is not open | Medium |

No matter which option you use, the end result is the same: your Tally data reaches the Fynos team, who load it into your account.

---

## Before You Start

You will need the following, on the **same Windows machine where Tally is running**:

1. **Tally is running** with your company loaded. The company name should be visible at the top of the Tally window.
2. **A working internet connection** (only needed for Option A).
3. **An invite code** from your Fynos account manager. It looks like `FTC-A7K9P`.
4. **Port 9000 enabled in Tally** for XML API requests. To check:
   - In **TallyPrime**: press `F1` → `Settings` → `Connectivity` → `Client/Server Configuration`. Set **TallyPrime is acting as** to `Both` (or at least `Server`), **Port** to `9000`, and save.
   - In **Tally.ERP 9**: press `F12` → `Advanced Configuration`. Set **Tally.ERP 9 is acting as** to `Server`, **Port** to `9000`.
5. **Quick sanity check** — open a web browser on the Tally machine and go to `http://127.0.0.1:9000`. You should see a page that says **"TallyPrime Server is Running"** or similar. If you see this, Tally is ready. If not, go back to step 4.

---

## Option A — Fynos Tally Connect App (Recommended)

### A.1 Download the installer

Open your browser and go to:

**https://github.com/fyn-os/fynos-tally-connect-releases/releases/latest**

Scroll down to the **Assets** section and click **one** of these files to download:

- `Fynos.Tally.Connect_x.y.z_x64-setup.exe` — for most Windows machines
- `Fynos.Tally.Connect_x.y.z_x64_en-US.msi` — alternative MSI installer, use if your IT team prefers MSI

Save the file to your Downloads folder.

### A.2 Install the app

1. Double-click the downloaded `.exe` or `.msi` file.
2. If Windows SmartScreen shows a warning, click **More info** → **Run anyway**. (This happens because we are a new publisher.)
3. Click through the installer — no settings to change.
4. Click **Finish**.

The app will launch automatically and place an icon in your Windows system tray (the area near the clock).

### A.3 Connect to Fynos (first run only)

When the app opens for the first time, you will see a short setup wizard with three steps.

**Step 1 — Welcome**
Click **Get Started**.

**Step 2 — Connect to Fynos Cloud**
Enter the invite code your Fynos account manager gave you (e.g. `FTC-A7K9P`) and click **Connect**. You should see a "Device linked!" message within a few seconds.

**Step 3 — Verify Tally**
The app tries to talk to Tally automatically. You should see a **green checkmark** next to "Tally ERP". Click **Launch Sync Agent**.

> **If Step 3 shows a red X** — first try changing **Host** from `localhost` to `127.0.0.1` and click **Retry**. If it is still red, close the app completely and jump to **Option B** below.

### A.4 Verify it is working

Once the main dashboard loads, look at the top-right corner. You should see two pills:

- **Tally** — green = the app can reach Tally
- **Cloud** — green = the app can reach Fynos

The middle bar should show your company name on both sides: `Tally: [your company] → Fynos: [your company]`.

Click **Sync Now** to trigger an immediate sync. You will see progress messages, and the status should say "All data synced" within a minute or two. That is it — you are done.

The app will now sync automatically on a schedule. You can close the window at any time; it keeps running in the system tray.

### A.5 If Option A does not work

Common reasons Option A can fail:

- Your IT firewall blocks the app from reaching Fynos Cloud.
- Antivirus software blocks the app's network access.
- Your Tally version does not accept the app's connection probe (we have seen this on some custom TDL installations).

In any of these cases, move on to **Option B**. You do not need to uninstall the app.

---

## Option B — Fallback Script (One-Time Export)

This is a small script that runs once, exports everything Fynos needs to local XML files, and then exits. No installation, no background services, no internet access needed during the export. You send the resulting files to Fynos, and they load the data on their side.

### B.1 Save the script

You need a file called **`tally-export.ps1`**. There are three ways to get it — use whichever is easiest:

1. **From your Fynos contact** — they will send it as an attachment along with this playbook.
2. **Direct download** — right-click this link and choose "Save link as", then save the file as `tally-export.ps1`:
   `https://raw.githubusercontent.com/fyn-os/fynos-tally-connect-releases/main/scripts/tally-export.ps1`
3. **Copy from this playbook** — if neither of the above works, copy the full script text from **Appendix A** at the bottom of this document into a new file named `tally-export.ps1`.

Save the file to your **Desktop** — this keeps the path simple.

### B.2 Open PowerShell

1. Click the Windows **Start** button.
2. Type `PowerShell`.
3. Right-click **Windows PowerShell** and choose **Run as Administrator**. (Administrator is not strictly required, but avoids permission issues on some machines.)

### B.3 Navigate to your Desktop

In the PowerShell window, type **one** of the following and press **Enter** (all three do the same thing — use whichever works on your machine):

```powershell
cd "$env:USERPROFILE\Desktop"
```

```powershell
cd ~\Desktop
```

```powershell
cd $HOME\Desktop
```

> **Note:** Do NOT right-click the `.ps1` file and choose "Run with PowerShell". That opens a window that closes immediately, and you won't be able to see the output or pass parameters. Always run the script from inside a PowerShell window you opened yourself.

### B.4 Allow the script to run (first time only)

By default, Windows blocks unsigned scripts. Run this once per PowerShell session:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Press **Y** and **Enter** if it asks for confirmation. This only affects this one PowerShell window and does not change any system settings.

### B.5 (Optional) Quick sanity check before the full run

Before running the full script, you can verify Tally is responding with a single command. This is optional but recommended, especially if Option A did not work:

```powershell
curl.exe -X POST -H "Content-Type: text/xml" --data-binary "<ENVELOPE><HEADER><TALLYREQUEST>Export Data</TALLYREQUEST></HEADER><BODY><EXPORTDATA><REQUESTDESC><REPORTNAME>Trial Balance</REPORTNAME><STATICVARIABLES><EXPLODEFLAG>Yes</EXPLODEFLAG><SVFROMDATE>20250401</SVFROMDATE><SVTODATE>20250430</SVTODATE><SVEXPORTFORMAT>$$SysName:XML</SVEXPORTFORMAT></STATICVARIABLES></REQUESTDESC></EXPORTDATA></BODY></ENVELOPE>" http://127.0.0.1:9000/ -o test-tb.xml
```

Then check what came back:

```powershell
(Get-Content test-tb.xml -TotalCount 30)
```

**Good result**: you see many lines with individual ledger names like `Aastha Enterprises`, `AMAZON SELLER SERVICES`, expense account names, etc. This means the fast method works.

**OK result**: you only see a handful of lines with group names like `Capital Account`, `Current Liabilities`, `Current Assets`. This means the fast method did not expand into ledger detail, but **that is fine** — the script automatically detects this and switches to an alternative method that works on all Tally versions. Just run the script as normal in the next step.

**Bad result**: you see `<LINEERROR>` — also fine, the script handles this too.

You can delete the test file afterwards: `Remove-Item test-tb.xml`

### B.6 Run the script

For the default period (Financial Year 2025-26, April 2025 to March 2026):

```powershell
.\tally-export.ps1
```

For a different period (example: FY 2024-25):

```powershell
.\tally-export.ps1 -FromMonth 2024-04 -ToMonth 2025-03
```

If your Tally is running on a different computer on the same network (example: IP `192.168.1.50`):

```powershell
.\tally-export.ps1 -TallyUrl http://192.168.1.50:9000/
```

### B.7 What you will see

The script exports masters and then 12 monthly trial balances. A normal run looks like:

```
Tally export
  URL:     http://127.0.0.1:9000/
  Period:  2025-04 through 2026-03
  Output:  C:\Users\You\Desktop\tally-export-20260406-143022

Masters:
  [ OK ] Ledgers + Groups (List of Accounts) (1843267 bytes)

Trial balances (ledger-level, month-end):
  [ OK ] Trial Balance 2025-04 (20250401 -> 20250430) (125430 bytes)
  [ OK ] Trial Balance 2025-05 (20250501 -> 20250531) (128004 bytes)
  ...
  [ OK ] Trial Balance 2026-03 (20260301 -> 20260331) (131102 bytes)

Done. Files in: C:\Users\You\Desktop\tally-export-20260406-143022
```

Each trial balance file contains every individual ledger (vendors, customers, expenses, bank accounts, etc.) with their opening and closing balances for that month. This gives Fynos month-by-month balance data at the individual account level.

**As long as `Ledgers + Groups` and the monthly `Trial Balance` rows are `[ OK ]`, you have everything Fynos needs.**

### B.8 Zip and send the output

1. Open **File Explorer** and navigate to your **Desktop**.
2. You will see a folder named something like `tally-export-20260406-143022`.
3. Right-click that folder → **Send to** → **Compressed (zipped) folder**.
4. Email the resulting `.zip` file to your Fynos contact, or upload it to the link they provide.

**That is it for Option B.**

### B.9 If the script is blocked: raw curl commands (last resort for Option B)

If your IT policy blocks `.ps1` scripts entirely and `Set-ExecutionPolicy` does not work, you can paste these commands **directly into PowerShell** one at a time. No script file needed — just copy-paste each block.

First, create an output folder:

```powershell
mkdir "$env:USERPROFILE\Desktop\Fynos-Tally-Export" -Force
```

**Export masters (ledgers + groups):**

```powershell
curl.exe -sS -X POST -H "Content-Type: text/xml" --data-binary "<ENVELOPE><HEADER><TALLYREQUEST>Export Data</TALLYREQUEST></HEADER><BODY><EXPORTDATA><REQUESTDESC><REPORTNAME>List of Accounts</REPORTNAME></REQUESTDESC></EXPORTDATA></BODY></ENVELOPE>" http://127.0.0.1:9000/ -o "$env:USERPROFILE\Desktop\Fynos-Tally-Export\masters-ledgers.xml"
```

**Export trial balances (one per month)** — copy-paste all 12 commands:

```powershell
curl.exe -sS -X POST -H "Content-Type: text/xml" --data-binary "<ENVELOPE><HEADER><VERSION>1</VERSION><TALLYREQUEST>Export</TALLYREQUEST><TYPE>Collection</TYPE><ID>TrialBalanceLedgers</ID></HEADER><BODY><DESC><STATICVARIABLES><SVFROMDATE>20250401</SVFROMDATE><SVTODATE>20250430</SVTODATE></STATICVARIABLES><TDL><TDLMESSAGE><COLLECTION NAME=""TrialBalanceLedgers"" ISMODIFY=""No""><TYPE>Ledger</TYPE><FETCH>Name,Parent,ClosingBalance,OpeningBalance</FETCH></COLLECTION></TDLMESSAGE></TDL></DESC></BODY></ENVELOPE>" http://127.0.0.1:9000/ -o "$env:USERPROFILE\Desktop\Fynos-Tally-Export\trial-balance-2025-04.xml"

curl.exe -sS -X POST -H "Content-Type: text/xml" --data-binary "<ENVELOPE><HEADER><VERSION>1</VERSION><TALLYREQUEST>Export</TALLYREQUEST><TYPE>Collection</TYPE><ID>TrialBalanceLedgers</ID></HEADER><BODY><DESC><STATICVARIABLES><SVFROMDATE>20250501</SVFROMDATE><SVTODATE>20250531</SVTODATE></STATICVARIABLES><TDL><TDLMESSAGE><COLLECTION NAME=""TrialBalanceLedgers"" ISMODIFY=""No""><TYPE>Ledger</TYPE><FETCH>Name,Parent,ClosingBalance,OpeningBalance</FETCH></COLLECTION></TDLMESSAGE></TDL></DESC></BODY></ENVELOPE>" http://127.0.0.1:9000/ -o "$env:USERPROFILE\Desktop\Fynos-Tally-Export\trial-balance-2025-05.xml"

curl.exe -sS -X POST -H "Content-Type: text/xml" --data-binary "<ENVELOPE><HEADER><VERSION>1</VERSION><TALLYREQUEST>Export</TALLYREQUEST><TYPE>Collection</TYPE><ID>TrialBalanceLedgers</ID></HEADER><BODY><DESC><STATICVARIABLES><SVFROMDATE>20250601</SVFROMDATE><SVTODATE>20250630</SVTODATE></STATICVARIABLES><TDL><TDLMESSAGE><COLLECTION NAME=""TrialBalanceLedgers"" ISMODIFY=""No""><TYPE>Ledger</TYPE><FETCH>Name,Parent,ClosingBalance,OpeningBalance</FETCH></COLLECTION></TDLMESSAGE></TDL></DESC></BODY></ENVELOPE>" http://127.0.0.1:9000/ -o "$env:USERPROFILE\Desktop\Fynos-Tally-Export\trial-balance-2025-06.xml"

curl.exe -sS -X POST -H "Content-Type: text/xml" --data-binary "<ENVELOPE><HEADER><VERSION>1</VERSION><TALLYREQUEST>Export</TALLYREQUEST><TYPE>Collection</TYPE><ID>TrialBalanceLedgers</ID></HEADER><BODY><DESC><STATICVARIABLES><SVFROMDATE>20250701</SVFROMDATE><SVTODATE>20250731</SVTODATE></STATICVARIABLES><TDL><TDLMESSAGE><COLLECTION NAME=""TrialBalanceLedgers"" ISMODIFY=""No""><TYPE>Ledger</TYPE><FETCH>Name,Parent,ClosingBalance,OpeningBalance</FETCH></COLLECTION></TDLMESSAGE></TDL></DESC></BODY></ENVELOPE>" http://127.0.0.1:9000/ -o "$env:USERPROFILE\Desktop\Fynos-Tally-Export\trial-balance-2025-07.xml"

curl.exe -sS -X POST -H "Content-Type: text/xml" --data-binary "<ENVELOPE><HEADER><VERSION>1</VERSION><TALLYREQUEST>Export</TALLYREQUEST><TYPE>Collection</TYPE><ID>TrialBalanceLedgers</ID></HEADER><BODY><DESC><STATICVARIABLES><SVFROMDATE>20250801</SVFROMDATE><SVTODATE>20250831</SVTODATE></STATICVARIABLES><TDL><TDLMESSAGE><COLLECTION NAME=""TrialBalanceLedgers"" ISMODIFY=""No""><TYPE>Ledger</TYPE><FETCH>Name,Parent,ClosingBalance,OpeningBalance</FETCH></COLLECTION></TDLMESSAGE></TDL></DESC></BODY></ENVELOPE>" http://127.0.0.1:9000/ -o "$env:USERPROFILE\Desktop\Fynos-Tally-Export\trial-balance-2025-08.xml"

curl.exe -sS -X POST -H "Content-Type: text/xml" --data-binary "<ENVELOPE><HEADER><VERSION>1</VERSION><TALLYREQUEST>Export</TALLYREQUEST><TYPE>Collection</TYPE><ID>TrialBalanceLedgers</ID></HEADER><BODY><DESC><STATICVARIABLES><SVFROMDATE>20250901</SVFROMDATE><SVTODATE>20250930</SVTODATE></STATICVARIABLES><TDL><TDLMESSAGE><COLLECTION NAME=""TrialBalanceLedgers"" ISMODIFY=""No""><TYPE>Ledger</TYPE><FETCH>Name,Parent,ClosingBalance,OpeningBalance</FETCH></COLLECTION></TDLMESSAGE></TDL></DESC></BODY></ENVELOPE>" http://127.0.0.1:9000/ -o "$env:USERPROFILE\Desktop\Fynos-Tally-Export\trial-balance-2025-09.xml"

curl.exe -sS -X POST -H "Content-Type: text/xml" --data-binary "<ENVELOPE><HEADER><VERSION>1</VERSION><TALLYREQUEST>Export</TALLYREQUEST><TYPE>Collection</TYPE><ID>TrialBalanceLedgers</ID></HEADER><BODY><DESC><STATICVARIABLES><SVFROMDATE>20251001</SVFROMDATE><SVTODATE>20251031</SVTODATE></STATICVARIABLES><TDL><TDLMESSAGE><COLLECTION NAME=""TrialBalanceLedgers"" ISMODIFY=""No""><TYPE>Ledger</TYPE><FETCH>Name,Parent,ClosingBalance,OpeningBalance</FETCH></COLLECTION></TDLMESSAGE></TDL></DESC></BODY></ENVELOPE>" http://127.0.0.1:9000/ -o "$env:USERPROFILE\Desktop\Fynos-Tally-Export\trial-balance-2025-10.xml"

curl.exe -sS -X POST -H "Content-Type: text/xml" --data-binary "<ENVELOPE><HEADER><VERSION>1</VERSION><TALLYREQUEST>Export</TALLYREQUEST><TYPE>Collection</TYPE><ID>TrialBalanceLedgers</ID></HEADER><BODY><DESC><STATICVARIABLES><SVFROMDATE>20251101</SVFROMDATE><SVTODATE>20251130</SVTODATE></STATICVARIABLES><TDL><TDLMESSAGE><COLLECTION NAME=""TrialBalanceLedgers"" ISMODIFY=""No""><TYPE>Ledger</TYPE><FETCH>Name,Parent,ClosingBalance,OpeningBalance</FETCH></COLLECTION></TDLMESSAGE></TDL></DESC></BODY></ENVELOPE>" http://127.0.0.1:9000/ -o "$env:USERPROFILE\Desktop\Fynos-Tally-Export\trial-balance-2025-11.xml"

curl.exe -sS -X POST -H "Content-Type: text/xml" --data-binary "<ENVELOPE><HEADER><VERSION>1</VERSION><TALLYREQUEST>Export</TALLYREQUEST><TYPE>Collection</TYPE><ID>TrialBalanceLedgers</ID></HEADER><BODY><DESC><STATICVARIABLES><SVFROMDATE>20251201</SVFROMDATE><SVTODATE>20251231</SVTODATE></STATICVARIABLES><TDL><TDLMESSAGE><COLLECTION NAME=""TrialBalanceLedgers"" ISMODIFY=""No""><TYPE>Ledger</TYPE><FETCH>Name,Parent,ClosingBalance,OpeningBalance</FETCH></COLLECTION></TDLMESSAGE></TDL></DESC></BODY></ENVELOPE>" http://127.0.0.1:9000/ -o "$env:USERPROFILE\Desktop\Fynos-Tally-Export\trial-balance-2025-12.xml"

curl.exe -sS -X POST -H "Content-Type: text/xml" --data-binary "<ENVELOPE><HEADER><VERSION>1</VERSION><TALLYREQUEST>Export</TALLYREQUEST><TYPE>Collection</TYPE><ID>TrialBalanceLedgers</ID></HEADER><BODY><DESC><STATICVARIABLES><SVFROMDATE>20260101</SVFROMDATE><SVTODATE>20260131</SVTODATE></STATICVARIABLES><TDL><TDLMESSAGE><COLLECTION NAME=""TrialBalanceLedgers"" ISMODIFY=""No""><TYPE>Ledger</TYPE><FETCH>Name,Parent,ClosingBalance,OpeningBalance</FETCH></COLLECTION></TDLMESSAGE></TDL></DESC></BODY></ENVELOPE>" http://127.0.0.1:9000/ -o "$env:USERPROFILE\Desktop\Fynos-Tally-Export\trial-balance-2026-01.xml"

curl.exe -sS -X POST -H "Content-Type: text/xml" --data-binary "<ENVELOPE><HEADER><VERSION>1</VERSION><TALLYREQUEST>Export</TALLYREQUEST><TYPE>Collection</TYPE><ID>TrialBalanceLedgers</ID></HEADER><BODY><DESC><STATICVARIABLES><SVFROMDATE>20260201</SVFROMDATE><SVTODATE>20260228</SVTODATE></STATICVARIABLES><TDL><TDLMESSAGE><COLLECTION NAME=""TrialBalanceLedgers"" ISMODIFY=""No""><TYPE>Ledger</TYPE><FETCH>Name,Parent,ClosingBalance,OpeningBalance</FETCH></COLLECTION></TDLMESSAGE></TDL></DESC></BODY></ENVELOPE>" http://127.0.0.1:9000/ -o "$env:USERPROFILE\Desktop\Fynos-Tally-Export\trial-balance-2026-02.xml"

curl.exe -sS -X POST -H "Content-Type: text/xml" --data-binary "<ENVELOPE><HEADER><VERSION>1</VERSION><TALLYREQUEST>Export</TALLYREQUEST><TYPE>Collection</TYPE><ID>TrialBalanceLedgers</ID></HEADER><BODY><DESC><STATICVARIABLES><SVFROMDATE>20260301</SVFROMDATE><SVTODATE>20260331</SVTODATE></STATICVARIABLES><TDL><TDLMESSAGE><COLLECTION NAME=""TrialBalanceLedgers"" ISMODIFY=""No""><TYPE>Ledger</TYPE><FETCH>Name,Parent,ClosingBalance,OpeningBalance</FETCH></COLLECTION></TDLMESSAGE></TDL></DESC></BODY></ENVELOPE>" http://127.0.0.1:9000/ -o "$env:USERPROFILE\Desktop\Fynos-Tally-Export\trial-balance-2026-03.xml"
```

After all commands complete, zip the `Fynos-Tally-Export` folder and send it to your Fynos contact (same as step B.8).

> **Tip:** If Tally is on a different port or IP, replace `http://127.0.0.1:9000/` in every command above with the correct address.

### B.10 If Option B also fails

If Tally is not accepting requests on port 9000 at all (for example, your IT team disabled the XML API feature, or you are on a very old Tally version), move to **Option C**.

---

## Option C — Manual Export from Tally (Last Resort)

This option uses only Tally itself — no scripts, no network, no HTTP. You export each report by hand using Tally's built-in export feature. It is slower than Options A and B, but it works on every Tally installation that has ever existed.

You will press **E** (for **Export**) from inside each report.

### C.1 Create an output folder

1. Open **File Explorer**.
2. Go to your **Desktop**.
3. Right-click empty space → **New** → **Folder**.
4. Name the folder `Fynos-Tally-Export` (exact name is not important, but use something you will remember).

### C.2 Open Tally and load your company

Make sure the company you want to export is the **currently loaded** company. You can see the company name in the top bar of Tally.

### C.3 Export the Ledger Master

This gives Fynos your full Chart of Accounts — every vendor, customer, bank, expense account, etc.

1. From the **Gateway of Tally**, navigate to:
   - **TallyPrime:** `Display More Reports` → `List of Accounts`
   - **Tally.ERP 9:** `Display` → `List of Accounts`
2. Once the list is on screen, press **`Alt + E`** (or click **`E: Export`** in the top button bar on TallyPrime).
3. An Export dialog opens. Set:
   - **Format**: `XML (data interchange)`
   - **Output File Name**: `ledger-master.xml`
   - **Folder Path**: browse to your `Fynos-Tally-Export` folder on the Desktop
   - **Server Applicable**: `No`
   - Leave everything else as default.
4. Press **`Ctrl + A`** (or click **Export**) to save.

You should see the file appear in your output folder.

### C.4 Export the Trial Balance, month by month

This is the most important part. Fynos needs the trial balance at the end of **each month** for the financial year.

Repeat the steps below **twelve times** — once per month of the year you are exporting.

#### C.4.1 Open the Trial Balance

From the **Gateway of Tally**, navigate to:

- **TallyPrime:** `Display More Reports` → `Trial Balance`
- **Tally.ERP 9:** `Display` → `Trial Balance`

#### C.4.2 Set the period for the month

Press **`F2`** (Period). In the period box, enter:

- **From date**: first day of the month (e.g. `1-4-2025` for April 2025)
- **To date**: last day of the month (e.g. `30-4-2025`)

Press **Enter**. The Trial Balance updates to show balances for that month.

#### C.4.3 Export

Press **`Alt + E`** (or click **`E: Export`**). In the Export dialog:

- **Format**: `XML (data interchange)`
- **Output File Name**: `trial-balance-2025-04.xml` (use the year-month for that period)
- **Folder Path**: your `Fynos-Tally-Export` folder
- **Server Applicable**: `No`

Press **`Ctrl + A`** or **Export**.

#### C.4.4 Repeat

Change the period with `F2` again and export the next month, changing the filename to match:

| Month | Filename |
|---|---|
| April 2025 | `trial-balance-2025-04.xml` |
| May 2025 | `trial-balance-2025-05.xml` |
| June 2025 | `trial-balance-2025-06.xml` |
| July 2025 | `trial-balance-2025-07.xml` |
| August 2025 | `trial-balance-2025-08.xml` |
| September 2025 | `trial-balance-2025-09.xml` |
| October 2025 | `trial-balance-2025-10.xml` |
| November 2025 | `trial-balance-2025-11.xml` |
| December 2025 | `trial-balance-2025-12.xml` |
| January 2026 | `trial-balance-2026-01.xml` |
| February 2026 | `trial-balance-2026-02.xml` |
| March 2026 | `trial-balance-2026-03.xml` |

### C.5 (Optional) Export the Day Book

If Fynos also asked you for transaction-level data, export the Day Book for the full period.

1. From the **Gateway of Tally**, navigate to:
   - **TallyPrime:** `Display More Reports` → `Day Book`
   - **Tally.ERP 9:** `Display` → `Day Book`
2. Press **`F2`** and set the period to the full financial year (e.g. `1-4-2025` to `31-3-2026`).
3. Press **`Alt + E`** and export as `day-book.xml` in the same folder. Format: `XML (data interchange)`.

### C.6 Zip and send

Same as Option B:

1. Right-click the `Fynos-Tally-Export` folder → **Send to** → **Compressed (zipped) folder**.
2. Email the resulting `.zip` to your Fynos contact.

---

## Quick Troubleshooting

| Problem | Likely cause | Fix |
|---|---|---|
| `http://127.0.0.1:9000` does not open in browser | Tally XML API is disabled | Re-check **Before You Start**, step 4 |
| App's Tally pill is red even though Tally is running | Hostname resolution issue | In app **Settings**, change Tally Host from `localhost` to `127.0.0.1` |
| App says "Cloud" is red | Firewall or no internet | Check internet on the Tally machine; ask your IT team to whitelist `*.fynos.com` |
| Script says `curl.exe` not found | Very old Windows version | Use Option C instead, or update to Windows 10 or later |
| Script runs but all rows are [FAIL] | No company loaded in Tally, or port 9000 is blocked | Open a company in Tally and rerun; confirm the browser check from **Before You Start** |
| `Set-ExecutionPolicy` gives an error | Group policy lockdown | Use Option C instead — no PowerShell needed |
| Trial balance files are very small (< 5 KB) | Tally returned group-level totals instead of individual ledger balances | Contact your Fynos account manager — they can provide an updated script |
| Some Trial Balance files are much smaller than others | Tally returned an error for those months | Open the file in Notepad. If you see `<LINEERROR>`, the period had no company loaded — reopen the company and rerun for that month |
| Manual export (Option C) produces empty XML | Wrong report selected, or period outside company's financial year | Confirm the company's financial year in Tally matches the period you are exporting |

---

## What Fynos Does With the Data

Regardless of which option you used, the Fynos team will:

1. Load your chart of accounts (ledgers + groups) into your Fynos workspace.
2. Import the monthly trial balances to populate your opening and closing balances.
3. (If you sent the Day Book) import transactions into the accounts payable and general ledger modules.
4. Reach out to you within one business day to confirm the import and walk through the result.

If anything looks wrong after import, tell your Fynos contact immediately — it is easier to fix the day of import than a week later.

---

## Appendix A — Full PowerShell Script (for Option B)

If you did not receive `tally-export.ps1` along with this playbook, or you want to verify the script contents yourself, here is the complete script. Copy everything between the lines below into a new file named `tally-export.ps1` on your Desktop.

---

```powershell
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

.EXAMPLE
  .\tally-export.ps1 -FromMonth 2024-04 -ToMonth 2025-03

.EXAMPLE
  .\tally-export.ps1 -TallyUrl http://192.168.1.50:9000/
#>

param(
  [string]$FromMonth = "2025-04",
  [string]$ToMonth   = "2026-03",
  [string]$TallyUrl  = "http://127.0.0.1:9000/"
)

$ErrorActionPreference = "Stop"

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir = Join-Path (Get-Location) "tally-export-$timestamp"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

function Invoke-TallyRequest {
  param(
    [string]$Xml,
    [string]$OutFile,
    [string]$Label
  )

  & curl.exe -sS `
    -X POST `
    -H "Content-Type: text/xml" `
    --data-binary $Xml `
    $TallyUrl `
    -o $OutFile

  if ($LASTEXITCODE -ne 0) {
    Write-Host "  [FAIL] $Label - curl exit code $LASTEXITCODE" -ForegroundColor Red
    return $false
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

Write-Host "Masters:"

Invoke-TallyRequest `
  -Xml '<ENVELOPE><HEADER><TALLYREQUEST>Export Data</TALLYREQUEST></HEADER><BODY><EXPORTDATA><REQUESTDESC><REPORTNAME>List of Accounts</REPORTNAME></REQUESTDESC></EXPORTDATA></BODY></ENVELOPE>' `
  -OutFile (Join-Path $outDir "masters-ledgers.xml") `
  -Label "Ledgers + Groups (List of Accounts)"

Write-Host ""

Write-Host "Trial balances (ledger-level, month-end):"

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

  $xml = "<ENVELOPE><HEADER><VERSION>1</VERSION><TALLYREQUEST>Export</TALLYREQUEST><TYPE>Collection</TYPE><ID>TrialBalanceLedgers</ID></HEADER><BODY><DESC><STATICVARIABLES><SVFROMDATE>$svfrom</SVFROMDATE><SVTODATE>$svto</SVTODATE></STATICVARIABLES><TDL><TDLMESSAGE><COLLECTION NAME=`"TrialBalanceLedgers`" ISMODIFY=`"No`"><TYPE>Ledger</TYPE><FETCH>Name,Parent,ClosingBalance,OpeningBalance</FETCH></COLLECTION></TDLMESSAGE></TDL></DESC></BODY></ENVELOPE>"

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
```

---

*Last updated: 2026-04-08. Questions or problems? Contact your Fynos account manager and include the zipped output folder plus the PowerShell output if you ran Option B.*
