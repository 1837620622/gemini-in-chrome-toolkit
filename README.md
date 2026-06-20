# Gemini in Chrome 完整启用与修复工具

一个跨平台一键修复 Gemini in Chrome 不显示问题的开源工具。覆盖从零启用全流程，并彻底解决指纹浏览器（Roxy / AdsPower 等）污染、`--disable-actor-safety-checks` 命令行参数残留、Chrome Sync 云端污染等深层问题。

适配 **Windows 10/11、macOS、Linux**，全自动备份与一键回滚。

[English README](./README_EN.md) ｜ [完整启用教程](./启用教程-完整版.md)

## 适用场景

| 场景 | 描述 |
| :--- | :--- |
| 从未启用 | 浏览器右上角从未见过 Gemini 按钮，想要从零开始启用 |
| 突然失效 | 之前能用，最近右上角的 Gemini 按钮突然消失了 |
| 黄色警告 | 浏览器顶部出现「您使用的是不受支持的命令行标记 --disable-actor-safety-checks」 |
| 安装指纹浏览器后 | 用过 Roxy、AdsPower、MultiLogin、GoLogin 等指纹浏览器后 Gemini 失效 |
| 教程失败 | 按全网教程改 Local State / chrome://flags 后仍不显示 |
| 删数据才好 | 之前删除所有浏览器数据后能用，但不想再删（怕丢历史和密码） |

## 核心特性

| 特性 | 说明 |
| :--- | :--- |
| 三端通用 | 同一套修复逻辑覆盖 Windows、macOS、Linux |
| 数据零损 | 完整保留历史、书签、密码、Cookie、扩展，仅清缓存和异常配置 |
| 自动备份 | 所有修改前自动创建时间戳备份，支持秒级回滚 |
| 编码自适应 | Windows 中文系统的 GBK / CP936 自动切换 UTF-8，无乱码 |
| 指纹识别 | 自动扫描 10 种主流指纹浏览器残留并提示 |
| Sync 重置 | 清云端污染缓存，让 Chrome 重新做账号握手 |
| 核心启用 | 自动设置 `is_glic_eligible`、`variations_country`、`variations_permanent_consistency_country` 三个关键开关 |

## 工作原理简述

Gemini in Chrome 不显示，本质是 Chrome 的 **Glic 子系统**初始化失败。常见根因：

第一，`chrome://flags` 里残留了 `glic-disable-actor-safety-checks` 这条已废弃 flag。许多 Roxy 教程会教用户开启它，但新版 Chrome 检测到它会触发 actor 安全机制熔断，**直接隐藏 Gemini 按钮**。

第二，Chrome 把这个 flag 偏好状态**同步到了 Google 账号云端**。即使本地删了，下次启动 Chrome 会从云端再拉回来——这就是「为什么改了还是不行」的根源。

第三，指纹浏览器（Roxy、AdsPower 等）在用户数据目录里留下了 IndexedDB、content_settings、Sync 缓存等多层污染。

本工具的修复策略：**设置 Glic 功能开关 → 设置地区码为支持地区 → 清空本地 flag 偏好 → 清空 Sync 同步缓存 → 清理所有指纹污染**，让 Chrome 启动后做一次完整的「云端重新握手」，把云端污染状态也一起刷新掉。

## 系统要求

| 项 | 要求 |
| :--- | :--- |
| Chrome 版本 | 137 及以上（141+ 完整支持 Gemini） |
| Windows | Windows 10 / Windows 11，PowerShell 5.1 或更高 |
| macOS | macOS 11 (Big Sur) 及以上，自带 Python 3 |
| Linux | 任意发行版，需安装 python3 |
| 账号要求 | 个人 Google 账号，注册地需为支持地区 |

## Windows 部署步骤

```powershell
# 第一步：下载脚本
# 把 修复脚本-Windows.ps1 下载到桌面或任意目录

# 第二步：以管理员身份打开 PowerShell
# 在「开始」菜单搜索 PowerShell，右键「以管理员身份运行」

# 第三步：允许执行脚本（首次需要）
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force

# 第四步：切到脚本目录并运行
cd $env:USERPROFILE\Desktop
.\修复脚本-Windows.ps1
```

如果 PowerShell 提示无法运行脚本：
```powershell
# 临时绕过策略仅本次执行
powershell -ExecutionPolicy Bypass -File .\修复脚本-Windows.ps1
```

## macOS 部署步骤

```bash
# 第一步：下载脚本到任意目录（这里以下载目录为例）
cd ~/Downloads

# 第二步：赋予执行权限
chmod +x 修复脚本-macOS-Linux.sh

# 第三步：运行
bash 修复脚本-macOS-Linux.sh
```

如果系统提示 Python 未安装：
```bash
brew install python3
```

## Linux 部署步骤

```bash
# 第一步：确认依赖
sudo apt update && sudo apt install -y python3
# 或 CentOS / Fedora：
sudo yum install -y python3

# 第二步：下载脚本并运行
cd ~/Downloads
chmod +x 修复脚本-macOS-Linux.sh
bash 修复脚本-macOS-Linux.sh
```

## 修复执行流程

脚本会按顺序自动完成以下步骤：

| 步骤 | 操作 | 影响 |
| :--- | :--- | :--- |
| 1 | 探测 Chrome 数据目录 | 仅读取 |
| 2 | 校验 Python 依赖 | 仅读取 |
| 3 | 完全关闭 Chrome 进程 | 关闭浏览器 |
| 4 | 创建完整备份 | 仅创建备份目录 |
| 5 | 扫描指纹浏览器残留 | 仅扫描提示 |
| 6 | 启用 Glic 并锁定地区码 | 设置 `is_glic_eligible=true`、`variations_country=us` |
| 7 | 清理 Local State 异常 flag | 移除问题 flag |
| 8 | 调整 profile 语言优先级 | 英语 US 设为首位 |
| 9 | 清除代理站点 IndexedDB | 清网站数据库 |
| 10 | 清除优化引擎 hint cache | 清缓存 |
| 11 | 清除 content_settings 污染 | 清污染条目 |
| 12 | 清空 chrome://flags 偏好 | 重置 flag 偏好 |
| 13 | 清理 Sync 同步缓存 | 让账号重新握手 |
| 14 | 用户数据完整性校验 | 验证关键文件未损 |

## 脚本完成后的手动操作

本工具完成自动修复后，需要你手动做最后三步：

第一步：从开始菜单或应用程序里启动 Chrome（不要带命令行参数）。

第二步：检查浏览器顶部是否还有黄色警告条。如果还有：
1. 地址栏输入 `chrome://flags`
2. 右上角点击红色 **Reset all** 按钮
3. 底部点击蓝色 **Relaunch** 按钮

第三步：切换到登录账号的 profile，浏览器右上区域应出现 Gemini 按钮（星星图标）。首次点击跟随 opt-in 引导完成即可。

## 完整启用教程（从未启用过 Gemini 的用户）

如果你的浏览器从未出现过 Gemini 按钮，本节是完整启用流程。

### 步骤一：更新 Chrome 到最新版

| 平台 | 操作 |
| :--- | :--- |
| Windows | 点击三个点菜单 → 帮助 → 关于 Google Chrome → 自动更新 |
| macOS | 菜单栏 Chrome → 关于 Google Chrome → 自动更新 |
| Linux | `sudo apt update && sudo apt upgrade google-chrome-stable` |

Gemini in Chrome 要求 Chrome 版本 141 或更高（早期版本只支持部分功能）。

### 步骤二：使用支持地区的 Google 账号登录

支持地区目前包括：美国、加拿大、英国、日本、韩国、印度、巴西、墨西哥、澳大利亚、新西兰，以及大部分欧盟国家。中国大陆账号目前不支持。

判断账号是否在支持地区：
1. 访问 `https://myaccount.google.com/`
2. 查看「个人信息」→ 国家或地区
3. 若显示中国大陆，则当前账号无法启用 Gemini

### 步骤三：设置 Chrome 主语言为 English (United States)

1. 地址栏输入 `chrome://settings/languages`
2. 点击 **Add languages** 添加 English (United States)
3. 把它拖到列表最顶部
4. 勾选「Display Google Chrome in this language」
5. 重启 Chrome

### 步骤四：退出隐身 / 访客模式

Gemini 在隐身模式与访客模式下都不显示。必须用普通窗口。

### 步骤五：在浏览器顶部点击 Gemini 图标

更新到 137 及以上后，Chrome 工具栏右侧会出现一个 ✦ 星星状的 Gemini 图标。第一次点击会弹出 opt-in 提示，同意服务条款后即可使用。

如果按完全部步骤后仍看不到图标，说明你的账号或环境有污染问题，运行本工具的修复脚本即可解决。

## 故障排除

### Q1: 脚本运行报错「未找到 python3」

**Windows**: 不需要 Python，本仓库的 `修复脚本-Windows.ps1` 使用 PowerShell 原生 JSON 处理。请确认你运行的是 `.ps1` 而不是 `.sh`。

**macOS**: 终端执行 `brew install python3`，没有 Homebrew 先装 [https://brew.sh](https://brew.sh)。

**Linux**: 执行 `sudo apt install python3` (Debian/Ubuntu) 或 `sudo yum install python3` (CentOS/Fedora)。

### Q2: Windows PowerShell 提示「无法加载文件，因为在此系统上禁止运行脚本」

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
```

或一次性绕过：

```powershell
powershell -ExecutionPolicy Bypass -File .\修复脚本-Windows.ps1
```

### Q3: 脚本运行完后 Chrome 还是没出现 Gemini 按钮

按顺序排查：
1. 检查浏览器顶部是否仍有黄色警告条 → 去 `chrome://flags` 点 **Reset all** → **Relaunch**
2. 确认账号注册地不是中国大陆（`myaccount.google.com` 看个人信息）
3. 确认 Chrome 主语言是 English (United States)
4. 退出 VPN，使用支持地区的真实网络环境
5. 等待 1 至 72 小时让 Google 服务端灰度推送

### Q4: 卸载 Roxy 等指纹浏览器后还是被污染

指纹浏览器卸载常常残留：
- `~/Library/Application Support/RoxyBrowser/`（macOS）
- `%LOCALAPPDATA%\RoxyBrowser\`（Windows）
- pkg 安装收据（macOS）
- 注册表项（Windows）

本工具的 Roxy 残留扫描会主动提示，跟随提示手动清理这些目录。

### Q5: 备份在哪里？怎么回滚？

备份目录在 Chrome 数据目录下的 `.gemini_fix_backup_{时间戳}/`：
- macOS: `~/Library/Application Support/Google/Chrome/.gemini_fix_backup_*/`
- Windows: `%LOCALAPPDATA%\Google\Chrome\User Data\.gemini_fix_backup_*\`

**macOS / Linux 回滚**:
```bash
BAK=~/Library/Application\ Support/Google/Chrome/.gemini_fix_backup_*
cp "$BAK/Local State" ~/Library/Application\ Support/Google/Chrome/Local\ State
for p in Default "Profile 1" "Profile 2"; do
  [ -f "$BAK/$p/Preferences" ] && cp "$BAK/$p/Preferences" ~/Library/Application\ Support/Google/Chrome/"$p"/Preferences
done
```

**Windows 回滚**:
```powershell
$bak = (Get-ChildItem "$env:LOCALAPPDATA\Google\Chrome\User Data\.gemini_fix_backup_*")[0].FullName
Copy-Item "$bak\Local State" "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State" -Force
foreach ($p in @("Default","Profile 1","Profile 2")) {
    $src = "$bak\$p\Preferences"
    if (Test-Path $src) {
        Copy-Item $src "$env:LOCALAPPDATA\Google\Chrome\User Data\$p\Preferences" -Force
    }
}
```

### Q6: 删除备份目录的命令

确认 Chrome 工作正常 2 至 3 天后可清理备份：

**macOS / Linux**:
```bash
rm -rf ~/Library/Application\ Support/Google/Chrome/.gemini_fix_backup_*
```

**Windows**:
```powershell
Remove-Item "$env:LOCALAPPDATA\Google\Chrome\User Data\.gemini_fix_backup_*" -Recurse -Force
```

## 技术细节

### Chrome 配置三层架构

| 层 | 位置 | 内容 |
| :--- | :--- | :--- |
| 浏览器级 | Local State | flag 偏好、地区码、profile 索引 |
| 用户级 | Preferences | 语言设置、扩展配置、content_settings |
| 服务端 | Google 账号 | Gemini 资格、Sync 同步内容 |

修复必须三层同时清理。

### Glic 子系统熔断机制

Chrome 内部把 Gemini in Chrome 叫做「Glic」（Gemini Logic in Chrome）。Glic 的 actor 引擎负责让 Gemini 操作浏览器（开标签、填表、点击）。

`glic-disable-actor-safety-checks` 这条 flag 的本意是禁用 actor 安全检查（给开发者调试用），但生产环境检测到它被启用时，Glic 会触发 fail-safe 熔断，**直接不创建 Gemini 按钮**。这是设计上的安全机制，不是 bug。

### 编码自适应（Windows 专用）

Windows 中文系统的控制台默认是 GBK / CP936 编码，PowerShell 输出中文会乱码。`修复脚本-Windows.ps1` 启动时自动执行：

```powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp.com 65001
```

切换到 UTF-8（CP65001），脚本退出时自动恢复原始编码，**不影响后续命令**。

### JSON 处理：PowerShell 的 -Depth 64

Chrome 的 Local State 与 Preferences 是深度嵌套 JSON。PowerShell 的 `ConvertTo-Json` 默认只序列化 2 层深度，超出会被截断成字符串。本脚本统一使用 `-Depth 64` 确保完整序列化。

## 项目结构

```
├── README.md                    # 中文说明（本文件）
├── README_EN.md                 # 英文说明
├── 启用教程-完整版.md            # 从零启用的完整流程
├── 修复脚本-macOS-Linux.sh      # macOS / Linux 修复脚本
├── 修复脚本-Windows.ps1         # Windows 修复脚本
├── LICENSE                     # MIT 许可证
└── .gitignore                  # git 忽略文件
```

## 贡献与反馈

发现 bug 或有改进建议，请在 GitHub Issue 区反馈。

## 免责声明

本工具仅修改本地 Chrome 配置文件，不上传任何数据。所有操作均有自动备份。在使用前请阅读完整 README 并理解风险。

本工具不保证一定能启用 Gemini in Chrome，最终是否可用取决于：
1. 你的 Google 账号是否被 Google 服务端列入 Gemini 灰度名单
2. 你的网络环境是否能正常访问 Google 服务
3. 你的账号注册地是否为支持地区

## 许可证

本项目采用 [MIT License](./LICENSE)。

## 作者

| 项 | 信息 |
| :--- | :--- |
| 昵称 | 万能程序员 |
| 微信 | 1837620622（传康Kk） |
| 邮箱 | 2040168455@qq.com |
| 平台 | 咸鱼、Bilibili 同名 |
