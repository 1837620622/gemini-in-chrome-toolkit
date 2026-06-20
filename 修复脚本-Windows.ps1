# ============================================================
# Gemini in Chrome 完整修复脚本（Windows 通用）
# ------------------------------------------------------------
# 适用场景一：从未启用过 Gemini in Chrome，想要从零开始启用
# 适用场景二：之前能用 Gemini，被指纹浏览器或错误教程污染后失效
# ------------------------------------------------------------
# 适配：Windows 10 / Windows 11
# 兼容：PowerShell 5.1 及 PowerShell 7.x
# 兼容：中文系统（GBK / CP936）与英文系统（UTF-8）双编码环境
# ------------------------------------------------------------
# 作者：万能程序员
# 微信：1837620622（传康Kk）
# 邮箱：2040168455@qq.com
# ============================================================

# ============================================================
# 编码自适应：自动识别并强制切换为 UTF-8
# Windows 中文系统默认控制台编码是 GBK（CP936），脚本中的中文会乱码
# 切换到 UTF-8（CP65001）后，无论原系统是 GBK 还是 UTF-8 均能正确显示
# ============================================================
$script:OriginalConsoleEncoding = [Console]::OutputEncoding
$script:OriginalConsoleInputEncoding = [Console]::InputEncoding
$script:OriginalOutputEncoding = $OutputEncoding
$script:OriginalCodePage = $null

try {
    # ----- 记录原始代码页（脚本结束时恢复，避免影响后续命令）-----
    $cpOutput = & chcp.com 2>$null
    if ($cpOutput -match '\d+') {
        $script:OriginalCodePage = ($cpOutput -replace '[^\d]', '')
    }

    # ----- 强制切换到 UTF-8 -----
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding  = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    & chcp.com 65001 | Out-Null
}
catch {
    # 即使编码切换失败也不中断（某些受限环境会失败，但脚本主体功能依然可用）
}

# ============================================================
# 终端颜色辅助（不影响功能，仅美化输出）
# ============================================================
function Write-Info    { param([string]$msg) Write-Host "[信息] " -ForegroundColor Cyan   -NoNewline; Write-Host $msg }
function Write-Ok      { param([string]$msg) Write-Host "[成功] " -ForegroundColor Green  -NoNewline; Write-Host $msg }
function Write-Warn    { param([string]$msg) Write-Host "[警告] " -ForegroundColor Yellow -NoNewline; Write-Host $msg }
function Write-Err     { param([string]$msg) Write-Host "[错误] " -ForegroundColor Red    -NoNewline; Write-Host $msg }
function Write-Step    { param([string]$msg) Write-Host ""; Write-Host "━━━ $msg ━━━" -ForegroundColor Blue }
function Write-Header  {
    param([string]$msg)
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $msg" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

# ============================================================
# Chrome 数据目录探测
# Windows 标准路径：%LOCALAPPDATA%\Google\Chrome\User Data
# 兼容：Chrome 主版本、Beta、Canary 与 Chromium
# ============================================================
function Get-ChromeDataDir {
    $candidates = @(
        "$env:LOCALAPPDATA\Google\Chrome\User Data",
        "$env:LOCALAPPDATA\Google\Chrome Beta\User Data",
        "$env:LOCALAPPDATA\Google\Chrome SxS\User Data",
        "$env:LOCALAPPDATA\Chromium\User Data"
    )
    foreach ($p in $candidates) {
        if (Test-Path -LiteralPath $p) {
            return $p
        }
    }
    return $null
}

# ============================================================
# 依赖校验：PowerShell 版本
# PowerShell 5.1 是 Windows 10/11 自带版本，本脚本完全兼容
# ============================================================
function Test-Dependencies {
    $ver = $PSVersionTable.PSVersion
    Write-Info "PowerShell 版本：$ver"
    if ($ver.Major -lt 5) {
        Write-Err "PowerShell 版本过低，需要 5.1 或更高版本"
        Write-Info "Windows 10/11 自带 PowerShell 5.1，可在「开始」搜索 PowerShell 启动"
        exit 1
    }
}

# ============================================================
# 关闭 Chrome
# 必须完全关闭，否则 Local State 修改会被 Chrome 退出时覆盖
# ============================================================
function Stop-ChromeProcesses {
    Write-Step "关闭 Chrome 浏览器"
    $names = @("chrome", "chromium")
    $procs = Get-Process -Name $names -ErrorAction SilentlyContinue
    if ($procs) {
        Write-Info "正在优雅关闭 Chrome..."
        foreach ($p in $procs) {
            try {
                $p.CloseMainWindow() | Out-Null
            } catch {}
        }
        Start-Sleep -Seconds 3
        $procs = Get-Process -Name $names -ErrorAction SilentlyContinue
        if ($procs) {
            Write-Warn "Chrome 未优雅退出，强制结束"
            Stop-Process -Name $names -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
    }
    $remaining = Get-Process -Name $names -ErrorAction SilentlyContinue
    if (-not $remaining) {
        Write-Ok "Chrome 已完全关闭"
    } else {
        Write-Err "无法关闭 Chrome（残留 $($remaining.Count) 个进程），请手动关闭后重试"
        exit 1
    }
}

# ============================================================
# 创建完整备份
# 时间戳化目录，所有修改均可秒级回滚
# ============================================================
$script:BackupTs = [int][double]::Parse((Get-Date -UFormat %s))
$script:BackupBase = $null

function New-FullBackup {
    param([string]$ChromeDir)
    Write-Step "创建完整备份（时间戳：$script:BackupTs）"

    $script:BackupBase = Join-Path $ChromeDir ".gemini_fix_backup_$script:BackupTs"
    New-Item -ItemType Directory -Path $script:BackupBase -Force | Out-Null

    $lsPath = Join-Path $ChromeDir "Local State"
    if (Test-Path -LiteralPath $lsPath) {
        Copy-Item -LiteralPath $lsPath -Destination (Join-Path $script:BackupBase "Local State") -Force
        Write-Ok "已备份 Local State"
    }

    foreach ($prof in (Get-ChildItem -LiteralPath $ChromeDir -Directory | Where-Object {
        $_.Name -eq "Default" -or $_.Name -match "^Profile \d+$"
    })) {
        $prefSrc = Join-Path $prof.FullName "Preferences"
        if (Test-Path -LiteralPath $prefSrc) {
            $profBak = Join-Path $script:BackupBase $prof.Name
            New-Item -ItemType Directory -Path $profBak -Force | Out-Null
            Copy-Item -LiteralPath $prefSrc -Destination (Join-Path $profBak "Preferences") -Force
            Write-Ok "已备份 $($prof.Name)/Preferences"
        }
    }
    Write-Info "备份目录：$script:BackupBase"
}

# ============================================================
# 扫描指纹浏览器残留
# ============================================================
function Find-FingerprintBrowsers {
    Write-Step "扫描指纹浏览器残留"
    $found = @()
    $paths = @(
        "$env:LOCALAPPDATA\RoxyBrowser",
        "$env:APPDATA\RoxyBrowser",
        "$env:LOCALAPPDATA\AdsPower",
        "$env:APPDATA\AdsPower_Global",
        "$env:LOCALAPPDATA\MultiLogin",
        "$env:LOCALAPPDATA\GoLogin",
        "$env:APPDATA\GoLogin",
        "$env:LOCALAPPDATA\Incogniton",
        "$env:LOCALAPPDATA\Dolphin{anty}",
        "${env:ProgramFiles}\RoxyBrowser",
        "${env:ProgramFiles}\AdsPower",
        "${env:ProgramFiles(x86)}\RoxyBrowser",
        "${env:ProgramFiles(x86)}\AdsPower"
    )
    foreach ($p in $paths) {
        if ($p -and (Test-Path -LiteralPath $p)) {
            $found += $p
        }
    }
    if ($found.Count -gt 0) {
        Write-Warn "检测到 $($found.Count) 项指纹浏览器残留："
        foreach ($f in $found) {
            Write-Host "    · $f"
        }
        Write-Warn "建议先卸载这些工具再继续（否则修复后会被再次污染）"
    } else {
        Write-Ok "未检测到指纹浏览器残留"
    }
}

# ============================================================
# JSON 读取 / 写入辅助
# Chrome 的 Local State 与 Preferences 都是 UTF-8 编码 JSON（不带 BOM）
# PowerShell 5.x 的 ConvertFrom-Json 默认只解析 2 层，必须用 -AsHashtable + -Depth
# 但 PowerShell 5.1 不支持 -AsHashtable，所以用 PSCustomObject + 递归处理
# ============================================================
function Read-JsonFile {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $text  = [System.Text.Encoding]::UTF8.GetString($bytes)
    # 处理可能的 BOM
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) {
        $text = $text.Substring(1)
    }
    return $text | ConvertFrom-Json
}

function Write-JsonFile {
    param(
        [string]$Path,
        $Data
    )
    # 紧凑格式（与 Chrome 原生写出一致），UTF-8 无 BOM
    $json = $Data | ConvertTo-Json -Depth 64 -Compress
    $tmp = "$Path.tmp_write"
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($tmp, $json, $utf8NoBom)
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}

# ============================================================
# 核心修复一：清理 Local State 异常 flag
# 重点：移除 glic-disable-actor-safety-checks 等会触发 Glic 熔断的污染 flag
# ============================================================
function Repair-LocalState {
    param([string]$ChromeDir)
    Write-Step "核心修复一：清理 Local State 异常 flag"
    $lsPath = Join-Path $ChromeDir "Local State"
    if (-not (Test-Path -LiteralPath $lsPath)) {
        Write-Warn "Local State 不存在，跳过"
        return
    }

    $data = Read-JsonFile -Path $lsPath
    if (-not $data.browser) {
        $data | Add-Member -NotePropertyName browser -NotePropertyValue (New-Object PSObject)
    }
    if (-not $data.browser.enabled_labs_experiments) {
        $data.browser | Add-Member -NotePropertyName enabled_labs_experiments -NotePropertyValue @()
    }

    $flagsBefore = @($data.browser.enabled_labs_experiments)
    Write-Host "  修复前 flag 总数：$($flagsBefore.Count)"

    # ----- 黑名单：必删的污染 flag（无论是否带 @N 后缀均删除）-----
    $blacklist = @(
        "glic-disable-actor-safety-checks",
        "disable-actor-safety-checks",
        "optimization-guide-debug-logs",
        "optimization-guide-enable-dogfood-logging"
    )

    # ----- 双重过滤：①不在黑名单 ②必须有 @N 后缀（格式正确）-----
    $flagsAfter = @()
    $removed = @()
    foreach ($f in $flagsBefore) {
        $isBlack = $false
        foreach ($p in $blacklist) {
            if ($f -eq $p -or $f.StartsWith("$p@")) {
                $isBlack = $true; break
            }
        }
        $hasFormat = $f -match "@"
        if ($isBlack -or -not $hasFormat) {
            $removed += $f
        } else {
            $flagsAfter += $f
        }
    }

    $data.browser.enabled_labs_experiments = $flagsAfter
    Write-Host "  修复后 flag 总数：$($flagsAfter.Count)"
    Write-Host "  移除异常 flag：$($removed.Count) 条"
    foreach ($r in $removed) {
        Write-Host "    剪除：$r"
    }

    # ----- 递归搜索并启用所有 is_glic_eligible（Chrome 可能在嵌套层也有此字段）-----
    $nGlic = 0
    function Set-GlicRecursive {
        param($obj)
        $count = 0
        if ($obj -is [PSObject]) {
            $propsToCheck = @($obj.PSObject.Properties)
            foreach ($prop in $propsToCheck) {
                if ($prop.Name -eq "is_glic_eligible" -and $prop.Value -ne $true) {
                    $obj.$($prop.Name) = $true
                    $count++
                } else {
                    $count += Set-GlicRecursive -obj $prop.Value
                }
            }
        } elseif ($obj -is [System.Collections.IList]) {
            foreach ($item in $obj) {
                $count += Set-GlicRecursive -obj $item
            }
        }
        return $count
    }
    $nGlic = Set-GlicRecursive -obj $data
    Write-Host "  递归启用 is_glic_eligible：$nGlic 处"

    # ----- 添加 Glic 实验 flag（帮助 Chrome 注册 Glic 子系统）-----
    $glicFlags = @("glic@2", "glic-side-panel@1", "glic-actor@1", "glic-pre-warming@1")
    if (-not $data.browser) {
        $data | Add-Member -NotePropertyName browser -NotePropertyValue (New-Object PSObject)
    }
    if (-not $data.browser.enabled_labs_experiments) {
        $data.browser | Add-Member -NotePropertyName enabled_labs_experiments -NotePropertyValue @()
    }
    $existingFlags = @($data.browser.enabled_labs_experiments)
    $addedFlags = @()
    foreach ($f in $glicFlags) {
        $found = $false
        foreach ($e in $existingFlags) {
            if ($e -eq $f) { $found = $true; break }
        }
        if (-not $found) {
            $addedFlags += $f
        }
    }
    if ($addedFlags.Count -gt 0) {
        $data.browser.enabled_labs_experiments = $existingFlags + $addedFlags
        Write-Host "  添加 Glic 实验 flag：$($addedFlags -join ', ')"
    }

    # ----- 设置地区码为支持地区（关键：不设置则 Gemini 不显示）-----
    $country = ""
    if ($data.PSObject.Properties["variations_country"]) {
        $country = $data.variations_country
    }
    if ([string]::IsNullOrEmpty($country) -or $country -eq "cn" -or $country -eq "CN") {
        $data.variations_country = "us"
        Write-Host "  已设置 variations_country='us'（原值：'$country'）"
    }

    # ----- 设置永久一致性地区码（保留 Chrome 版本号，仅改国家为 us）-----
    $permProp = $data.PSObject.Properties["variations_permanent_consistency_country"]
    $needsPermFix = $true
    if ($permProp -and $data.variations_permanent_consistency_country) {
        $pv = $data.variations_permanent_consistency_country
        if ($pv -is [array] -and $pv.Count -ge 2) {
            $needsPermFix = $pv[-1] -ne "us"
        } elseif ($pv -is [string] -and $pv.ToLower() -eq "us") {
            $needsPermFix = $false
        }
    }
    if ($needsPermFix) {
        $oldPermStr = if ($permProp) { "$($data.variations_permanent_consistency_country)" } else { "None" }
        if (-not $permProp) {
            $data | Add-Member -NotePropertyName "variations_permanent_consistency_country" -NotePropertyValue @(" ", "us")
        } elseif ($pv -is [array]) {
            $data.variations_permanent_consistency_country[-1] = "us"
        } else {
            $data.variations_permanent_consistency_country = @(" ", "us")
        }
        Write-Host "  已修正 variations_permanent_consistency_country（原值：'$oldPermStr'）"
    }

    Write-JsonFile -Path $lsPath -Data $data
    Write-Ok "Local State 修复完成"
}

# ============================================================
# 核心修复二：所有 profile 的语言设置改为 English (United States) 首位
# ============================================================
function Repair-ProfileLanguages {
    param([string]$ChromeDir)
    Write-Step "核心修复二：调整所有 profile 的语言优先级"

    $fixed = 0
    foreach ($prof in (Get-ChildItem -LiteralPath $ChromeDir -Directory | Where-Object {
        $_.Name -eq "Default" -or $_.Name -match "^Profile \d+$"
    })) {
        $prefPath = Join-Path $prof.FullName "Preferences"
        if (-not (Test-Path -LiteralPath $prefPath)) { continue }

        try {
            $data = Read-JsonFile -Path $prefPath
        } catch {
            Write-Host "  跳过 $($prof.Name)：$_"
            continue
        }

        if (-not $data.intl) {
            $data | Add-Member -NotePropertyName intl -NotePropertyValue (New-Object PSObject) -Force
        }

        $changed = $false
        foreach ($key in @("accept_languages", "selected_languages")) {
            $old = ""
            if ($data.intl.PSObject.Properties[$key]) {
                $old = $data.intl.$key
            }
            $items = @()
            if (-not [string]::IsNullOrEmpty($old)) {
                $items = @($old -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -and ($_ -notmatch "^(en-US|en)$") })
            }
            $new = (@("en-US") + $items) -join ","
            if ($items.Count -eq 0 -and [string]::IsNullOrEmpty($old)) {
                $new = "en-US,zh-CN,zh"
            }
            if ($new -ne $old) {
                if ($data.intl.PSObject.Properties[$key]) {
                    $data.intl.$key = $new
                } else {
                    $data.intl | Add-Member -NotePropertyName $key -NotePropertyValue $new
                }
                $changed = $true
            }
        }

        if ($changed) {
            Write-JsonFile -Path $prefPath -Data $data
            $fixed++
            Write-Host "  ✓ $($prof.Name)"
        }
    }
    Write-Host "  共修复 $fixed 个 profile"
    Write-Ok "语言修复完成"
}

# ============================================================
# 核心修复三：清空 chrome://flags 用户偏好
# ============================================================
function Reset-FlagsPreference {
    param([string]$ChromeDir)
    Write-Step "核心修复三：清空 chrome://flags 偏好（让 Chrome 重新评估）"
    $lsPath = Join-Path $ChromeDir "Local State"
    if (-not (Test-Path -LiteralPath $lsPath)) {
        Write-Warn "Local State 不存在，跳过"
        return
    }
    $data = Read-JsonFile -Path $lsPath
    if (-not $data.browser) {
        $data | Add-Member -NotePropertyName browser -NotePropertyValue (New-Object PSObject)
    }
    if (-not $data.browser.enabled_labs_experiments) {
        $data.browser | Add-Member -NotePropertyName enabled_labs_experiments -NotePropertyValue @()
    }

    $count = @($data.browser.enabled_labs_experiments).Count
    Write-Host "  清空前 flag 数：$count"
    $data.browser.enabled_labs_experiments = @()
    Write-JsonFile -Path $lsPath -Data $data
    Write-Host "  清空完成（Chrome 重启后 chrome://flags 全部回到 Default 状态）"
    Write-Ok "chrome://flags 偏好已重置"
}

# ============================================================
# 核心修复四：清理 Sync 同步缓存
# 让 Chrome 重新做账号握手，避免云端旧污染状态再次拉回
# ============================================================
function Clear-SyncCache {
    param([string]$ChromeDir)
    Write-Step "核心修复四：清理 Sync 同步缓存"

    $syncDirs = @("Sync Data", "Sync Extension Settings", "Sync App Settings", "GCM Store", "Sessions")
    $cleared = 0
    foreach ($prof in (Get-ChildItem -LiteralPath $ChromeDir -Directory | Where-Object {
        $_.Name -eq "Default" -or $_.Name -match "^Profile \d+$"
    })) {
        foreach ($d in $syncDirs) {
            $target = Join-Path $prof.FullName $d
            if (Test-Path -LiteralPath $target) {
                Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue
                $cleared++
                Write-Ok "已清除 $($prof.Name)/$d"
            }
        }
    }
    Write-Info "共清除 $cleared 个同步缓存目录"
    Write-Info "重启 Chrome 后会自动从云端重建（密码、书签、扩展等不会丢失）"
}

# ============================================================
# 辅助修复一：清除代理站点 IndexedDB
# ============================================================
function Clear-ProxyIndexedDB {
    param([string]$ChromeDir)
    Write-Step "辅助修复一：清除代理站点 IndexedDB"

    $patterns = @("*roxy*", "*1024proxy*", "*lokiproxy*", "*antidetect*", "*multilogin*", "*adspower*", "*gologin*", "*incogniton*")
    $total = 0
    foreach ($prof in (Get-ChildItem -LiteralPath $ChromeDir -Directory | Where-Object {
        $_.Name -eq "Default" -or $_.Name -match "^Profile \d+$"
    })) {
        $idb = Join-Path $prof.FullName "IndexedDB"
        if (-not (Test-Path -LiteralPath $idb)) { continue }
        foreach ($pat in $patterns) {
            $items = Get-ChildItem -LiteralPath $idb -Filter $pat -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "  ✂ $($prof.Name)/IndexedDB/$($item.Name)"
                $total++
            }
        }
    }
    Write-Host "  共清除 $total 个污染数据库"
    Write-Ok "代理站点 IndexedDB 清理完成"
}

# ============================================================
# 辅助修复二：清除优化引擎 hint cache
# ============================================================
function Clear-OptimizationHints {
    param([string]$ChromeDir)
    Write-Step "辅助修复二：清除优化引擎 hint cache"

    $cleared = 0
    foreach ($prof in (Get-ChildItem -LiteralPath $ChromeDir -Directory | Where-Object {
        $_.Name -eq "Default" -or $_.Name -match "^Profile \d+$"
    })) {
        $cache = Join-Path $prof.FullName "optimization_guide_hint_cache_store"
        if (Test-Path -LiteralPath $cache) {
            Remove-Item -LiteralPath $cache -Recurse -Force -ErrorAction SilentlyContinue
            Write-Ok "已清除 $($prof.Name) 的 hint cache"
            $cleared++
        }
    }
    Write-Info "共清除 $cleared 个 hint cache 目录"
}

# ============================================================
# 辅助修复三：清除 Preferences 内 content_settings 的代理站点污染
# ============================================================
function Clean-ContentSettings {
    param([string]$ChromeDir)
    Write-Step "辅助修复三：清除 content_settings 污染"

    $dirtyRegex = '(?i)(roxybrowser|1024proxy|lokiproxy|antidetect)'

    function Remove-DirtyKeys {
        param($obj)
        $count = 0
        if ($obj -is [PSObject]) {
            $keysToRemove = @()
            foreach ($prop in $obj.PSObject.Properties) {
                if ($prop.Name -match $dirtyRegex) {
                    $keysToRemove += $prop.Name
                } else {
                    $count += Remove-DirtyKeys -obj $prop.Value
                }
            }
            foreach ($k in $keysToRemove) {
                $obj.PSObject.Properties.Remove($k)
                $count++
            }
        } elseif ($obj -is [System.Collections.IList]) {
            foreach ($item in $obj) {
                $count += Remove-DirtyKeys -obj $item
            }
        }
        return $count
    }

    $total = 0
    foreach ($prof in (Get-ChildItem -LiteralPath $ChromeDir -Directory | Where-Object {
        $_.Name -eq "Default" -or $_.Name -match "^Profile \d+$"
    })) {
        $prefPath = Join-Path $prof.FullName "Preferences"
        if (-not (Test-Path -LiteralPath $prefPath)) { continue }
        try {
            $data = Read-JsonFile -Path $prefPath
        } catch {
            continue
        }
        $n = Remove-DirtyKeys -obj $data
        if ($n -gt 0) {
            Write-JsonFile -Path $prefPath -Data $data
            $total += $n
            Write-Host "  ✓ $($prof.Name) 清除 $n 条"
        }
    }
    Write-Host "  共清除 $total 条污染"
    Write-Ok "content_settings 清理完成"
}

# ============================================================
# 用户数据完整性校验
# ============================================================
function Test-UserDataIntegrity {
    param([string]$ChromeDir)
    Write-Step "用户数据完整性校验"

    $critical = @("History", "Bookmarks", "Login Data", "Cookies", "Web Data", "Top Sites", "Favicons")
    foreach ($prof in (Get-ChildItem -LiteralPath $ChromeDir -Directory | Where-Object {
        $_.Name -eq "Default" -or $_.Name -match "^Profile \d+$"
    })) {
        Write-Host "  ── $($prof.Name) ──" -ForegroundColor Cyan
        foreach ($f in $critical) {
            $p = Join-Path $prof.FullName $f
            if (Test-Path -LiteralPath $p) {
                $sz = (Get-Item -LiteralPath $p).Length
                Write-Host "    ✓ $f ($sz bytes)"
            }
        }
    }
}

# ============================================================
# 修复完成总结 + 后续手动操作指引
# ============================================================
function Show-Summary {
    param([string]$ChromeDir)
    Write-Header "修复完成 — 重要后续操作"

    Write-Host "所有自动修复步骤已完成。请按以下顺序进行手动操作：" -ForegroundColor Green
    Write-Host ""
    Write-Host "步骤一：启动 Chrome" -ForegroundColor White
    Write-Host "  从开始菜单或桌面直接打开，不要使用任何命令行参数"
    Write-Host ""
    Write-Host "步骤二：检查浏览器顶部黄色警告条" -ForegroundColor White
    Write-Host "  如果出现「您使用的是不受支持的命令行标记 --disable-actor-safety-checks」"
    Write-Host "  说明 chrome://flags 偏好还有残留，操作如下："
    Write-Host "    1. 地址栏输入：chrome://flags"
    Write-Host "    2. 右上角点击红色 Reset all 按钮"
    Write-Host "    3. 底部点击蓝色 Relaunch 按钮"
    Write-Host ""
    Write-Host "步骤三：确认账号资格" -ForegroundColor White
    Write-Host "  · 必须是个人 Google 账号（非企业 / 学校 / 未成年账号）"
    Write-Host "  · 账号注册地需为支持地区（美国、日本、加拿大、英国等）"
    Write-Host "  · QQ 邮箱注册的 Google 账号会被视为中国账号，无法启用"
    Write-Host ""
    Write-Host "步骤四：寻找 Gemini 按钮" -ForegroundColor White
    Write-Host "  浏览器右上区域应出现 Gemini 图标（星星状）"
    Write-Host "  首次点击时跟着 opt-in 引导完成即可使用"
    Write-Host ""
    Write-Host "步骤五：等待服务端灰度（如果按钮仍未出现）" -ForegroundColor White
    Write-Host "  Gemini in Chrome 是逐步放量功能"
    Write-Host "  账号资格通过后可能需要 1 至 72 小时才能激活"
    Write-Host ""
    Write-Host "备份位置：" -NoNewline -ForegroundColor Yellow
    Write-Host "$script:BackupBase"
    Write-Host ""
    Write-Host "作者：万能程序员" -ForegroundColor White
    Write-Host "  微信：1837620622（传康Kk）"
    Write-Host "  邮箱：2040168455@qq.com"
    Write-Host ""
}

# ============================================================
# 编码恢复（脚本结束时调用，避免影响后续命令）
# ============================================================
function Restore-Encoding {
    try {
        if ($script:OriginalCodePage) {
            & chcp.com $script:OriginalCodePage | Out-Null
        }
        if ($script:OriginalConsoleEncoding) {
            [Console]::OutputEncoding = $script:OriginalConsoleEncoding
        }
        if ($script:OriginalConsoleInputEncoding) {
            [Console]::InputEncoding = $script:OriginalConsoleInputEncoding
        }
        if ($script:OriginalOutputEncoding) {
            $script:OriginalOutputEncoding | Out-Null
        }
    } catch {}
}

# ============================================================
# 主流程
# ============================================================
function Invoke-Main {
    Write-Header "Gemini in Chrome 完整修复工具（Windows 版）"

    $chromeDir = Get-ChromeDataDir
    if (-not $chromeDir) {
        Write-Err "未检测到 Chrome 数据目录"
        Write-Info "请确认已安装 Chrome（默认路径 C:\Users\<你的用户名>\AppData\Local\Google\Chrome\User Data）"
        exit 1
    }
    Write-Info "Chrome 数据目录：$chromeDir"

    Test-Dependencies
    Stop-ChromeProcesses
    New-FullBackup        -ChromeDir $chromeDir
    Find-FingerprintBrowsers
    Repair-LocalState     -ChromeDir $chromeDir
    Repair-ProfileLanguages -ChromeDir $chromeDir
    Clear-ProxyIndexedDB  -ChromeDir $chromeDir
    Clear-OptimizationHints -ChromeDir $chromeDir
    Clean-ContentSettings -ChromeDir $chromeDir
    Reset-FlagsPreference -ChromeDir $chromeDir
    Clear-SyncCache       -ChromeDir $chromeDir
    Test-UserDataIntegrity -ChromeDir $chromeDir
    Show-Summary          -ChromeDir $chromeDir
}

try {
    Invoke-Main
}
finally {
    Restore-Encoding
}
