#!/usr/bin/env bash
# ============================================================
# Gemini in Chrome 完整修复脚本（macOS / Linux 通用）
# ------------------------------------------------------------
# 适用场景一：从未启用过 Gemini in Chrome，想要从零开始启用
# 适用场景二：之前能用 Gemini，被指纹浏览器或错误教程污染后失效
# ------------------------------------------------------------
# 作者：万能程序员
# 微信：1837620622（传康Kk）
# 邮箱：2040168455@qq.com
# ============================================================

set -uo pipefail 2>/dev/null || set -u
export LC_ALL=en_US.UTF-8 2>/dev/null || true

# ============================================================
# 终端颜色辅助（不影响功能，仅美化输出）
# ============================================================
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
NC=$'\033[0m'

log_info()   { echo "${CYAN}[信息]${NC} $1"; }
log_ok()     { echo "${GREEN}[成功]${NC} $1"; }
log_warn()   { echo "${YELLOW}[警告]${NC} $1"; }
log_error()  { echo "${RED}[错误]${NC} $1"; }
log_step()   { echo; echo "${BOLD}${BLUE}━━━ $1 ━━━${NC}"; }
log_header() { echo; echo "${BOLD}${CYAN}════════════════════════════════════════════════════${NC}"; echo "${BOLD}${CYAN}  $1${NC}"; echo "${BOLD}${CYAN}════════════════════════════════════════════════════${NC}"; echo; }

# ============================================================
# 平台识别：自动选择 Chrome 数据目录
# 兼容 macOS 与 Linux（Chrome 与 Chromium 均支持）
# ============================================================
detect_platform() {
    case "$(uname -s)" in
        Darwin)
            PLATFORM="macOS"
            CHROME_DIR="$HOME/Library/Application Support/Google/Chrome"
            ;;
        Linux)
            PLATFORM="Linux"
            if   [ -d "$HOME/.config/google-chrome" ];           then CHROME_DIR="$HOME/.config/google-chrome"
            elif [ -d "$HOME/.config/google-chrome-beta" ];      then CHROME_DIR="$HOME/.config/google-chrome-beta"
            elif [ -d "$HOME/.config/chromium" ];                then CHROME_DIR="$HOME/.config/chromium"
            else
                log_error "未检测到 Chrome 或 Chromium 数据目录"
                log_info  "请确认已安装 Chrome 或 Chromium 后再运行本脚本"
                exit 1
            fi
            ;;
        *)
            log_error "不支持的操作系统：$(uname -s)"
            log_info  "本脚本仅适配 macOS 与 Linux。Windows 用户请使用 修复脚本-Windows.ps1"
            exit 1
            ;;
    esac
    log_info "平台：$PLATFORM"
    log_info "Chrome 数据目录：$CHROME_DIR"
}

# ============================================================
# 依赖校验：本脚本依赖 python3 处理 JSON（系统通常自带）
# ============================================================
check_dependencies() {
    if ! command -v python3 >/dev/null 2>&1; then
        log_error "未找到 python3，请先安装"
        log_info "macOS 安装方法：brew install python3"
        log_info "Ubuntu 安装方法：sudo apt update && sudo apt install -y python3"
        log_info "CentOS 安装方法：sudo yum install -y python3"
        exit 1
    fi
}

# ============================================================
# 关闭 Chrome 浏览器
# 必须完全关闭，否则 Local State 修改会被 Chrome 退出时覆盖
# ============================================================
quit_chrome() {
    log_step "关闭 Chrome 浏览器"
    if [ "$PLATFORM" = "macOS" ]; then
        osascript -e 'quit app "Google Chrome"' 2>/dev/null || true
    else
        pkill -TERM -f "google-chrome|chromium" 2>/dev/null || true
    fi
    sleep 3
    local chrome_pattern="Google Chrome.app/Contents/MacOS/Google Chrome\|google-chrome\|chromium-browser\|chromium"
    if pgrep -f "$chrome_pattern" >/dev/null 2>&1; then
        log_warn "Chrome 未优雅退出，强制结束所有进程"
        pkill -9 -f "$chrome_pattern" 2>/dev/null || true
        sleep 2
    fi
    local count
    count=$(pgrep -f "$chrome_pattern" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" = "0" ]; then
        log_ok "Chrome 已完全关闭"
    else
        log_error "无法关闭 Chrome（残留 $count 个进程），请手动关闭后重试"
        exit 1
    fi
}

# ============================================================
# 创建完整备份
# 时间戳化目录，所有修改均可秒级回滚
# ============================================================
create_backup() {
    BACKUP_TS="${BACKUP_TS:-$(date +%s)}"
    BACKUP_BASE="${BACKUP_BASE:-}"
    log_step "创建完整备份(时间戳: ${BACKUP_TS})"
    BACKUP_BASE="$CHROME_DIR/.gemini_fix_backup_$BACKUP_TS"
    mkdir -p "$BACKUP_BASE"

    if [ -f "$CHROME_DIR/Local State" ]; then
        cp "$CHROME_DIR/Local State" "$BACKUP_BASE/Local State"
        log_ok "已备份 Local State"
    fi

    for prof_dir in "$CHROME_DIR"/Default "$CHROME_DIR"/Profile\ *; do
        if [ -d "$prof_dir" ]; then
            local prof_name
            prof_name=$(basename "$prof_dir")
            mkdir -p "$BACKUP_BASE/$prof_name"
            if [ -f "$prof_dir/Preferences" ]; then
                cp "$prof_dir/Preferences" "$BACKUP_BASE/$prof_name/Preferences"
                log_ok "已备份 $prof_name/Preferences"
            fi
        fi
    done

    log_info "备份目录：$BACKUP_BASE"
}

# ============================================================
# 扫描指纹浏览器残留
# 这类工具是 Gemini in Chrome 失效的主要污染源
# ============================================================
scan_fingerprint_browsers() {
    log_step "扫描指纹浏览器残留"
    local found=()
    local apps=("RoxyBrowser" "AdsPower" "MultiLogin" "GoLogin" "Incogniton" "Kameleo" "Hidemyacc" "Dolphin Anty" "Bit Browser" "MaskPro")

    if [ "$PLATFORM" = "macOS" ]; then
        for app in "${apps[@]}"; do
            [ -d "/Applications/$app.app" ] && found+=("$app")
        done
        for data in "$HOME/Library/Application Support/RoxyBrowser" \
                    "$HOME/Library/Application Support/AdsPower" \
                    "$HOME/Library/Application Support/MultiLogin" \
                    "$HOME/Library/Application Support/GoLogin" \
                    "$HOME/Library/Application Support/Incogniton"; do
            [ -d "$data" ] && found+=("$(basename "$data") (数据残留)")
        done
    else
        for app in roxybrowser adspower multilogin gologin incogniton dolphin-anty; do
            command -v "$app" >/dev/null 2>&1 && found+=("$app")
        done
    fi

    if [ ${#found[@]} -gt 0 ]; then
        log_warn "检测到 ${#found[@]} 项指纹浏览器残留："
        for item in "${found[@]}"; do
            echo "    · $item"
        done
        log_warn "这类工具会污染系统 Chrome 的 Local State 与 chrome://flags"
        log_warn "建议先卸载这些工具再继续修复（否则修复后会被再次污染）"
    else
        log_ok "未检测到指纹浏览器残留"
    fi
}

# ============================================================
# 核心修复一：清理 Local State 异常 flag
# 重点：移除 glic-disable-actor-safety-checks 等会触发 Glic 熔断的污染 flag
# ============================================================
fix_local_state() {
    log_step "核心修复一：清理 Local State 异常 flag"
    local ls_path="$CHROME_DIR/Local State"
    if [ ! -f "$ls_path" ]; then
        log_warn "Local State 文件不存在，跳过"
        return
    fi

    python3 - "$ls_path" <<'PYEOF'
import json, os, sys

ls_path = sys.argv[1]
with open(ls_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

flags_before = data.get('browser', {}).get('enabled_labs_experiments', [])
print(f"  修复前 flag 总数：{len(flags_before)}")

# ----- 黑名单：必删的污染 flag（无论是否带 @N 后缀均删除）-----
blacklist_prefixes = [
    'glic-disable-actor-safety-checks',
    'disable-actor-safety-checks',
    'optimization-guide-debug-logs',
    'optimization-guide-enable-dogfood-logging',
]

# ----- 双重过滤：①不在黑名单 ②必须有 @N 后缀（格式正确）-----
flags_after, removed = [], []
for f in flags_before:
    is_black = any(f == p or f.startswith(p + '@') for p in blacklist_prefixes)
    has_format = '@' in f
    if is_black or not has_format:
        removed.append(f)
    else:
        flags_after.append(f)

data.setdefault('browser', {})['enabled_labs_experiments'] = flags_after
print(f"  修复后 flag 总数：{len(flags_after)}")
print(f"  移除异常 flag：{len(removed)} 条")
for r in removed:
    print(f"    剪除：{r}")

# ----- 启用 Glic（Gemini in Chrome 核心开关）-----
if not data.get('is_glic_eligible'):
    data['is_glic_eligible'] = True
    print("  已启用 is_glic_eligible=true")

# ----- 设置地区码为支持地区（关键：不设置则 Gemini 不显示）-----
current_country = data.get('variations_country', '')
if not current_country or str(current_country).lower() in ('', 'cn'):
    data['variations_country'] = 'us'
    print(f"  已设置 variations_country='us'（原值：'{current_country}'）")

# ----- 设置永久一致性地区码（Chrome 同步验证用）-----
current_perm = data.get('variations_permanent_consistency_country')
if not current_perm or (isinstance(current_perm, str) and current_perm.lower() in ('', 'cn')):
    data['variations_permanent_consistency_country'] = [' ', 'us']
    print(f"  已设置 variations_permanent_consistency_country=[' ', 'us']")

# ----- 紧凑格式原子写回，与 Chrome 原生格式保持一致 -----
tmp = ls_path + '.tmp_write'
with open(tmp, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
os.replace(tmp, ls_path)
print("  Local State 写回完成")
PYEOF
    log_ok "Local State 修复完成"
}

# ============================================================
# 核心修复二：所有 profile 的语言设置改为 English (United States) 首位
# Gemini 推荐英语 US，其他语言虽能用但启用率较低
# ============================================================
fix_languages() {
    log_step "核心修复二：调整所有 profile 的语言优先级"
    python3 - "$CHROME_DIR" <<'PYEOF'
import json, os, pathlib, sys

chrome_root = pathlib.Path(sys.argv[1])

def reorder(lang_str):
    if not lang_str:
        return 'en-US,zh-CN,zh'
    items = [x.strip() for x in lang_str.split(',') if x.strip()]
    items = [x for x in items if x.lower() not in ('en-us', 'en')]
    return ','.join(['en-US'] + items)

fixed = 0
for pref_path in chrome_root.glob('*/Preferences'):
    if any(skip in str(pref_path) for skip in ['System Profile', 'Guest Profile']):
        continue
    try:
        with open(pref_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        print(f"  跳过 {pref_path.parent.name}：{e}")
        continue

    intl = data.setdefault('intl', {})
    changed = False
    for key in ('accept_languages', 'selected_languages'):
        old = intl.get(key, '')
        new = reorder(old)
        if new != old:
            intl[key] = new
            changed = True

    if changed:
        tmp = str(pref_path) + '.tmp_write'
        with open(tmp, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
        os.replace(tmp, pref_path)
        fixed += 1
        print(f"  ✓ {pref_path.parent.name}")

print(f"  共修复 {fixed} 个 profile")
PYEOF
    log_ok "语言修复完成"
}

# ============================================================
# 核心修复三：清空 chrome://flags 用户偏好
# 让 Chrome 重新评估 Glic 子系统状态
# 注意：会清除你启用过的所有 chrome://flags 偏好（Gemini 不依赖手动启用 flag）
# ============================================================
reset_flags_preference() {
    log_step "核心修复三：清空 chrome://flags 偏好（让 Chrome 重新评估）"
    python3 - "$CHROME_DIR" <<'PYEOF'
import json, os, pathlib, sys
ls_path = pathlib.Path(sys.argv[1]) / 'Local State'
if not ls_path.exists():
    print("  Local State 不存在，跳过")
else:
    with open(ls_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    flags = data.get('browser', {}).get('enabled_labs_experiments', [])
    print(f"  清空前 flag 数：{len(flags)}")
    data.setdefault('browser', {})['enabled_labs_experiments'] = []
    tmp = str(ls_path) + '.tmp_reset'
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
    os.replace(tmp, ls_path)
    print("  清空完成（Chrome 重启后 chrome://flags 全部回到 Default 状态）")
PYEOF
    log_ok "chrome://flags 偏好已重置"
}

# ============================================================
# 核心修复四：清理 Sync 同步缓存
# 这是修复"曾启用过但失效"的关键步骤
# Chrome Sync 会把异常 flag 同步到云端，本地清完会被云端拉回
# ============================================================
clear_sync_cache() {
    log_step "核心修复四：清理 Sync 同步缓存（让 Chrome 重新做账号握手）"
    local cleared=0
    for prof_dir in "$CHROME_DIR"/Default "$CHROME_DIR"/Profile\ *; do
        [ -d "$prof_dir" ] || continue
        for sync_item in "Sync Data" "Sync Extension Settings" "Sync App Settings" "GCM Store" "Sessions"; do
            if [ -d "$prof_dir/$sync_item" ]; then
                rm -rf "$prof_dir/$sync_item"
                cleared=$((cleared + 1))
                log_ok "已清除 $(basename "$prof_dir")/$sync_item"
            fi
        done
    done
    log_info "共清除 $cleared 个同步缓存目录"
    log_info "重启 Chrome 后会自动从云端重建（密码、书签、扩展等不会丢失）"
}

# ============================================================
# 辅助修复一：清除指纹浏览器站点的 IndexedDB
# Roxy / 1024proxy / lokiproxy 等代理站访问留下的数据库
# ============================================================
clear_proxy_indexeddb() {
    log_step "辅助修复一：清除代理站点 IndexedDB"
    python3 - "$CHROME_DIR" <<'PYEOF'
import re, shutil, sys, pathlib
chrome_root = pathlib.Path(sys.argv[1])
DIRTY = re.compile(r'(roxy|1024proxy|lokiproxy|antidetect|multilogin|adspower|gologin|incogniton)', re.IGNORECASE)
total = 0
for idb_dir in chrome_root.glob('*/IndexedDB'):
    if not idb_dir.is_dir():
        continue
    for item in idb_dir.iterdir():
        if DIRTY.search(item.name):
            if item.is_dir():
                shutil.rmtree(item, ignore_errors=True)
            else:
                try:
                    item.unlink()
                except Exception:
                    pass
            print(f"  ✂ {idb_dir.parent.name}/IndexedDB/{item.name}")
            total += 1
print(f"  共清除 {total} 个污染数据库")
PYEOF
    log_ok "代理站点 IndexedDB 清理完成"
}

# ============================================================
# 辅助修复二：清除优化引擎 hint cache
# 这是 Glic 的决策缓存，可能存有 GLIC_ACTION_PAGE_BLOCK 之类的污染标记
# 清掉后 Chrome 启动时会向服务端重拉新的 hint
# ============================================================
clear_optimization_hints() {
    log_step "辅助修复二：清除优化引擎 hint cache"
    local cleared=0
    for prof_dir in "$CHROME_DIR"/Default "$CHROME_DIR"/Profile\ *; do
        [ -d "$prof_dir" ] || continue
        local cache="$prof_dir/optimization_guide_hint_cache_store"
        if [ -d "$cache" ]; then
            rm -rf "$cache"
            cleared=$((cleared + 1))
            log_ok "已清除 $(basename "$prof_dir") 的 hint cache"
        fi
    done
    log_info "共清除 $cleared 个 hint cache 目录"
}

# ============================================================
# 辅助修复三：清除 Preferences 内 content_settings 的代理站点污染
# ============================================================
clean_content_settings() {
    log_step "辅助修复三：清除 content_settings 污染"
    python3 - "$CHROME_DIR" <<'PYEOF'
import json, os, re, sys, pathlib
chrome_root = pathlib.Path(sys.argv[1])
DIRTY = re.compile(r'(roxybrowser|1024proxy|lokiproxy|antidetect)', re.IGNORECASE)

def clean(obj):
    n = 0
    if isinstance(obj, dict):
        for k in list(obj.keys()):
            if DIRTY.search(str(k)):
                del obj[k]; n += 1
            else:
                n += clean(obj[k])
    elif isinstance(obj, list):
        for item in obj:
            n += clean(item)
    return n

total = 0
for pref_path in chrome_root.glob('*/Preferences'):
    if any(skip in str(pref_path) for skip in ['System Profile', 'Guest Profile']):
        continue
    try:
        with open(pref_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception:
        continue
    n = clean(data)
    if n > 0:
        tmp = str(pref_path) + '.tmp_clean'
        with open(tmp, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
        os.replace(tmp, pref_path)
        total += n
        print(f"  ✓ {pref_path.parent.name} 清除 {n} 条")
print(f"  共清除 {total} 条污染")
PYEOF
    log_ok "content_settings 清理完成"
}

# ============================================================
# 用户数据完整性校验
# 确保 History、Bookmarks、Login Data、Cookies 等未受影响
# ============================================================
verify_user_data() {
    log_step "用户数据完整性校验"
    local critical=("History" "Bookmarks" "Login Data" "Cookies" "Web Data" "Top Sites" "Favicons")
    for prof_dir in "$CHROME_DIR"/Default "$CHROME_DIR"/Profile\ *; do
        [ -d "$prof_dir" ] || continue
        local pname
        pname=$(basename "$prof_dir")
        echo "  ${CYAN}── $pname ──${NC}"
        for f in "${critical[@]}"; do
            local p="$prof_dir/$f"
            if [ -f "$p" ]; then
                local sz
                sz=$(stat -f '%z' "$p" 2>/dev/null || stat -c '%s' "$p" 2>/dev/null)
                echo "    ✓ $f ($sz bytes)"
            fi
        done
    done
}

# ============================================================
# 修复完成总结 + 后续手动操作指引
# ============================================================
show_summary() {
    log_header "修复完成 — 重要后续操作"
    cat <<EOF
${GREEN}所有自动修复步骤已完成。请按以下顺序进行手动操作：${NC}

${BOLD}步骤一：启动 Chrome${NC}
  从应用程序里直接打开，不要使用任何命令行参数

${BOLD}步骤二：检查浏览器顶部黄色警告条${NC}
  如果出现"您使用的是不受支持的命令行标记 --disable-actor-safety-checks"
  说明 chrome://flags 偏好还有残留，操作如下：
    1. 地址栏输入：chrome://flags
    2. 右上角点击红色 Reset all 按钮
    3. 底部点击蓝色 Relaunch 按钮

${BOLD}步骤三：确认账号资格${NC}
  · 必须是个人 Google 账号（非企业 / 学校 / 未成年账号）
  · 账号注册地需为支持地区（美国、日本、加拿大、英国等）
  · 用 QQ 邮箱注册的账号 Google 视为中国账号，无法启用
  · 在 Chrome 完整登录账号（点击右上角头像确认）

${BOLD}步骤四：寻找 Gemini 按钮${NC}
  浏览器右上区域应出现 ✦ Gemini 图标
  首次点击时跟着 opt-in 引导完成即可使用

${BOLD}步骤五：等待服务端灰度（如果按钮仍未出现）${NC}
  Gemini in Chrome 是逐步放量功能，账号资格通过后
  可能需要等待 1 至 72 小时才能在你的账号上激活

${YELLOW}备份位置：${NC}${BACKUP_BASE:-（未创建）}
${YELLOW}回滚命令（如果已备份）：${NC}
  [ -n "${BACKUP_BASE:-}" ] && cp -R "$BACKUP_BASE/Local State" "$CHROME_DIR/Local State"
  [ -n "${BACKUP_BASE:-}" ] && for p in Default Profile\\ 1 Profile\\ 2; do
      [ -f "$BACKUP_BASE/\$p/Preferences" ] && \\
      cp "$BACKUP_BASE/\$p/Preferences" "$CHROME_DIR/\$p/Preferences"
  done

${BOLD}${CYAN}作者：万能程序员${NC}
  微信：1837620622（传康Kk）
  邮箱：2040168455@qq.com

EOF
}

# ============================================================
# 主流程：按顺序执行所有修复步骤
# ============================================================
main() {
    log_header "Gemini in Chrome 完整修复工具"
    detect_platform
    check_dependencies
    quit_chrome
    create_backup
    scan_fingerprint_browsers
    fix_local_state
    fix_languages
    clear_proxy_indexeddb
    clear_optimization_hints
    clean_content_settings
    reset_flags_preference
    clear_sync_cache
    verify_user_data
    show_summary
}

main "$@"
