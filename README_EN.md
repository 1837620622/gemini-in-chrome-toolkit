# Gemini in Chrome — Full Enable & Repair Toolkit

A cross-platform one-click toolkit that fixes the "Gemini button missing in Chrome" problem. Covers everything from zero-config enablement to deep cleanup of fingerprint-browser pollution (Roxy, AdsPower, etc.), residual `--disable-actor-safety-checks` command-line switches, and Chrome Sync cloud-side contamination.

Supports **Windows 10/11, macOS, and Linux**. Auto-backup with one-command rollback.

[中文 README](./README.md)

## When You Need This Tool

| Scenario | Description |
| :--- | :--- |
| Never enabled | Gemini button has never appeared in your browser toolbar |
| Suddenly missing | Gemini worked before but the button disappeared recently |
| Yellow warning | A yellow banner shows "You are using an unsupported command-line flag: --disable-actor-safety-checks" |
| After fingerprint browser | Gemini stopped working after installing Roxy, AdsPower, MultiLogin, GoLogin, etc. |
| Tutorial failed | You followed online tutorials editing Local State / chrome://flags but still no Gemini |
| Only data-wipe works | Clearing all browser data fixes it, but you don't want to lose history & passwords |

## Core Features

| Feature | Description |
| :--- | :--- |
| Cross-platform | Same fix logic for Windows, macOS, Linux |
| Zero data loss | Preserves history, bookmarks, passwords, cookies, extensions |
| Auto backup | Timestamped backup before any modification, second-level rollback |
| Encoding-aware | Auto-detects GBK / CP936 on Chinese Windows and switches to UTF-8 |
| Fingerprint scan | Detects 10+ mainstream fingerprint browsers and warns user |
| Sync reset | Clears cloud contamination cache, forces fresh account handshake |

## How It Works

Gemini in Chrome failure usually stems from Chrome's **Glic subsystem** failing to initialize. The most common root causes are:

**One**, a deprecated `glic-disable-actor-safety-checks` flag enabled in `chrome://flags`. Many Roxy tutorials instruct users to enable this, but modern Chrome detects it and triggers the actor safety fail-safe, **silently hiding the Gemini button**.

**Two**, Chrome syncs your flag preference **to your Google account in the cloud**. Even after deleting it locally, the next Chrome launch pulls it back from the cloud — explaining why "I fixed it but it broke again".

**Three**, fingerprint browsers (Roxy, AdsPower, etc.) leave multi-layer pollution in your Chrome user data: IndexedDB, content_settings, Sync cache.

This toolkit's strategy: **simultaneously clear local flag preferences, wipe Sync cache, and remove all fingerprint pollution**, forcing Chrome to perform a fresh cloud handshake on next launch.

## System Requirements

| Item | Requirement |
| :--- | :--- |
| Chrome version | 137 or higher (141+ for full Gemini support) |
| Windows | Windows 10 / 11 with PowerShell 5.1 or higher |
| macOS | macOS 11 (Big Sur) or higher, Python 3 (built-in) |
| Linux | Any distribution with `python3` installed |
| Account | Personal Google account from a supported region |

## Windows Setup

```powershell
# Step 1: Download 修复脚本-Windows.ps1 to Desktop or any folder

# Step 2: Open PowerShell as Administrator
# Search "PowerShell" in Start menu, right-click "Run as administrator"

# Step 3: Allow script execution (first time only)
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force

# Step 4: Navigate to the script and run
cd $env:USERPROFILE\Desktop
.\修复脚本-Windows.ps1
```

If you encounter execution policy errors, bypass once:

```powershell
powershell -ExecutionPolicy Bypass -File .\修复脚本-Windows.ps1
```

## macOS Setup

```bash
# Step 1: Navigate to the script directory
cd ~/Downloads

# Step 2: Make it executable
chmod +x 修复脚本-macOS-Linux.sh

# Step 3: Run
bash 修复脚本-macOS-Linux.sh
```

If Python 3 is missing:

```bash
brew install python3
```

## Linux Setup

```bash
# Step 1: Install dependency
sudo apt update && sudo apt install -y python3
# or: sudo yum install -y python3

# Step 2: Run the script
cd ~/Downloads
chmod +x 修复脚本-macOS-Linux.sh
bash 修复脚本-macOS-Linux.sh
```

## What The Script Does

The script runs the following steps in order:

| Step | Action | Impact |
| :--- | :--- | :--- |
| 1 | Detect Chrome data directory | Read-only |
| 2 | Verify Python dependency | Read-only |
| 3 | Fully close Chrome processes | Closes browser |
| 4 | Create timestamped backup | Creates backup dir |
| 5 | Scan fingerprint browser residues | Read-only, prompts |
| 6 | Clean abnormal flags from Local State | Removes bad flags |
| 7 | Reorder profile language priority | Sets en-US first |
| 8 | Clear proxy site IndexedDB | Removes site DBs |
| 9 | Clear optimization hint cache | Clears cache |
| 10 | Clean content_settings pollution | Removes bad entries |
| 11 | Reset chrome://flags preferences | Resets all flags |
| 12 | Clear Sync cache | Forces fresh handshake |
| 13 | User data integrity check | Verifies key files |

## Manual Steps After Script Completion

After the script finishes, perform these manual actions:

**Step 1**: Launch Chrome from your Start menu / Applications folder. Do NOT use command-line flags.

**Step 2**: Check the top of the browser for a yellow warning banner. If present:
1. Enter `chrome://flags` in the address bar
2. Click the red **Reset all** button (top right)
3. Click the blue **Relaunch** button (bottom)

**Step 3**: Switch to the profile with your logged-in account. The Gemini icon (sparkle) should appear in the top-right toolbar. Click it and follow the opt-in flow.

## Full Enable Tutorial (For New Users)

If you've never seen the Gemini button, follow this end-to-end enablement guide.

### Step 1: Update Chrome to Latest

| Platform | How |
| :--- | :--- |
| Windows | Three-dot menu → Help → About Google Chrome → auto-updates |
| macOS | Menu bar Chrome → About Google Chrome → auto-updates |
| Linux | `sudo apt update && sudo apt upgrade google-chrome-stable` |

Gemini in Chrome requires version 141+ for full support.

### Step 2: Sign In With a Supported-Region Google Account

Currently supported regions include: US, Canada, UK, Japan, South Korea, India, Brazil, Mexico, Australia, New Zealand, and most EU countries. Mainland China accounts are **not supported**.

Check your account region:
1. Visit `https://myaccount.google.com/`
2. Look at "Personal info" → Country
3. If it shows China, the account cannot enable Gemini

### Step 3: Set Chrome Display Language to English (United States)

1. Address bar: `chrome://settings/languages`
2. Click **Add languages** and add English (United States)
3. Drag it to the top
4. Check "Display Google Chrome in this language"
5. Restart Chrome

### Step 4: Exit Incognito / Guest Mode

Gemini does not show in Incognito or Guest windows. Use a regular window.

### Step 5: Click the Gemini Icon

After update, look for the sparkle (✦) icon in Chrome's top-right toolbar. First click triggers an opt-in dialog — accept the terms to use Gemini.

If the icon doesn't appear after all the above, your environment has pollution. Run this toolkit's fix script.

## Troubleshooting

### Q1: Script says "python3 not found"

**Windows**: No Python needed. The Windows script uses native PowerShell JSON. Make sure you're running `.ps1` not `.sh`.

**macOS**: `brew install python3` (install Homebrew from [brew.sh](https://brew.sh) if needed).

**Linux**: `sudo apt install python3` (Debian/Ubuntu) or `sudo yum install python3` (CentOS/Fedora).

### Q2: PowerShell says "cannot be loaded because running scripts is disabled"

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
```

Or one-time bypass:

```powershell
powershell -ExecutionPolicy Bypass -File .\修复脚本-Windows.ps1
```

### Q3: Gemini still missing after running the script

Check in this order:
1. Yellow warning banner still present → go to `chrome://flags` → **Reset all** → **Relaunch**
2. Verify account region is not China (`myaccount.google.com` → Personal info)
3. Verify Chrome display language is English (United States)
4. Turn off VPN, use real network from supported region
5. Wait 1 to 72 hours for Google's server-side rollout

### Q4: Where are the backups?

Backups live at `.gemini_fix_backup_{timestamp}/` inside Chrome's data directory:
- macOS: `~/Library/Application Support/Google/Chrome/.gemini_fix_backup_*/`
- Windows: `%LOCALAPPDATA%\Google\Chrome\User Data\.gemini_fix_backup_*\`

### Q5: How to roll back?

**macOS / Linux**:
```bash
BAK=~/Library/Application\ Support/Google/Chrome/.gemini_fix_backup_*
cp "$BAK/Local State" ~/Library/Application\ Support/Google/Chrome/Local\ State
for p in Default "Profile 1" "Profile 2"; do
  [ -f "$BAK/$p/Preferences" ] && cp "$BAK/$p/Preferences" ~/Library/Application\ Support/Google/Chrome/"$p"/Preferences
done
```

**Windows**:
```powershell
$bak = (Get-ChildItem "$env:LOCALAPPDATA\Google\Chrome\User Data\.gemini_fix_backup_*")[0].FullName
Copy-Item "$bak\Local State" "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State" -Force
```

## Technical Details

### Chrome Configuration Three-Layer Architecture

| Layer | Location | Contents |
| :--- | :--- | :--- |
| Browser-level | Local State | Flag preferences, region code, profile index |
| User-level | Preferences | Language, extensions, content_settings |
| Server-level | Google account | Gemini eligibility, Sync content |

A complete fix must address all three.

### Glic Subsystem Fail-Safe

Chrome internally calls Gemini in Chrome "Glic" (Gemini Logic in Chrome). The actor engine within Glic lets Gemini operate the browser (open tabs, fill forms, click).

The flag `glic-disable-actor-safety-checks` was meant for developer debugging. Production Chrome detects it being enabled and triggers a fail-safe — **the Gemini button is silently hidden**. By design, not a bug.

### Encoding Adaption (Windows)

Chinese Windows uses GBK / CP936 by default. PowerShell will mangle Chinese characters. The Windows script auto-switches at startup:

```powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp.com 65001
```

It restores the original encoding on exit to avoid affecting other commands.

### PowerShell JSON: -Depth 64

Chrome's Local State and Preferences are deeply nested JSON. PowerShell's `ConvertTo-Json` defaults to depth 2 — beyond which values get truncated to strings. This script uses `-Depth 64` for complete serialization.

## Project Structure

```
├── README.md                    # Chinese readme
├── README_EN.md                 # English readme (this file)
├── 启用教程-完整版.md            # Full enable tutorial (Chinese)
├── 修复脚本-macOS-Linux.sh      # macOS / Linux script
├── 修复脚本-Windows.ps1         # Windows script
├── LICENSE                     # MIT License
└── .gitignore                  # git ignore
```

## Disclaimer

This tool modifies local Chrome configuration files only. No data is uploaded. All operations are automatically backed up. Please read the full README and understand the risks before use.

This tool does not guarantee Gemini in Chrome will be enabled. Final eligibility depends on:
1. Whether your Google account is included in Google's Gemini rollout
2. Whether your network can reach Google's services normally
3. Whether your account registration region is supported

## License

This project is licensed under the [MIT License](./LICENSE).

## Author

| Item | Info |
| :--- | :--- |
| Nickname | 万能程序员 (Universal Programmer) |
| WeChat | 1837620622 (传康Kk) |
| Email | 2040168455@qq.com |
