#!/usr/bin/env bash
# OpenClaw 自检脚本 — v2.0 (2026-05-01)
# 四层架构：L0 基础存活 / L1 运行时 / L2 深度分析 / L3 业务合规
# 约束：只读操作 | 耗时 < 5s
# 用法: bash scripts/healthcheck.sh [--verbose|--json]
#
# 输出：
#   1. 终端输出（--verbose 时完整显示）
#   2. JSON 状态文件 → data/self-check-trends/status.json
#   3. 趋势记录追加 → data/self-check-trends/trends.jsonl
#   4. 异常标记文件 → /tmp/openclaw/health-anomaly (有异常时创建)

set -uo pipefail
WORKSPACE="/home/z3129119/.openclaw/workspace"
STATUS_FILE="$WORKSPACE/data/self-check-trends/status.json"
TRENDS_FILE="$WORKSPACE/data/self-check-trends/trends.jsonl"
ANOMALY_FILE="/tmp/openclaw/health-anomaly"
TS=$(date -Iseconds)
VERBOSE=0
MODE="normal"

for arg in "$@"; do
  case "$arg" in
    --verbose) VERBOSE=1 ;;
    --json) MODE="jsononly" ;;
  esac
done

# ── Helpers ──
ANOMALIES=()
OK_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
STATUS_MAP=()

record() {
  local id="$1" status="$2" value="$3" detail="$4"
  STATUS_MAP+=("{\"id\":\"$id\",\"status\":\"$status\",\"value\":$value,\"detail\":\"$detail\"}")
  echo "{\"ts\":\"$TS\",\"check\":\"$id\",\"metric\":\"status\",\"value\":$value,\"status\":\"$status\"}" >> "$TRENDS_FILE"
  if [[ "$status" == "ok" ]]; then ((OK_COUNT++))
  elif [[ "$status" == "warn" ]]; then ((WARN_COUNT++))
  elif [[ "$status" == "critical" ]]; then ((FAIL_COUNT++)); ANOMALIES+=("[$status] $id: $detail")
  fi
}

# ── L0: 基础存活层 ──
GW_PID=$(pgrep -f "openclaw.*gateway" | head -1 || true)

if [[ -n "$GW_PID" ]]; then
  GW_STAT=$(ps -o stat= -p "$GW_PID" 2>/dev/null || echo "?")
  record "L0-Q1" "ok" 1 "PID=$GW_PID"
else
  record "L0-Q1" "critical" 0 "Gateway 进程不存在"
fi

if [[ -n "$GW_PID" ]]; then
  RSS_KB=$(ps -o rss= -p "$GW_PID" 2>/dev/null | tr -d ' ')
  RSS_MB=$((RSS_KB / 1024))
  if (( RSS_MB < 2048 )); then record "L0-Q2" "ok" "$RSS_MB" "${RSS_MB}MB"
  elif (( RSS_MB < 2560 )); then record "L0-Q2" "warn" "$RSS_MB" "${RSS_MB}MB 接近阈值"
  elif (( RSS_MB < 3072 )); then record "L0-Q2" "critical" "$RSS_MB" "${RSS_MB}MB 超限"
  else record "L0-Q2" "critical" "$RSS_MB" "${RSS_MB}MB 紧急"; fi
fi

DISK_ROOT=$(df -P / | awk 'NR==2{print $5}' | tr -d '%')
if (( DISK_ROOT < 80 )); then record "L0-Q3" "ok" "$DISK_ROOT" "${DISK_ROOT}%"
elif (( DISK_ROOT < 90 )); then record "L0-Q3" "warn" "$DISK_ROOT" "${DISK_ROOT}%"
elif (( DISK_ROOT < 95 )); then record "L0-Q3" "critical" "$DISK_ROOT" "${DISK_ROOT}%"
else record "L0-Q3" "critical" "$DISK_ROOT" "${DISK_ROOT}%"; fi

OOM_COUNT=$(journalctl -k --since "10 min ago" 2>/dev/null | grep -ci "oom" || true)
OOM_COUNT=$(echo "$OOM_COUNT" | tr -d '[:space:]')
if [[ -z "$OOM_COUNT" ]] || (( OOM_COUNT == 0 )); then record "L0-Q4" "ok" 0 "无"
else record "L0-Q4" "critical" "$OOM_COUNT" "检测到 OOM"; fi

# Q5 子代理活跃状态
SUB_RUNNING=$(pgrep -fc 'openclaw.*subagent\|openclaw.*spawn' 2>/dev/null || true)
SUB_RUNNING=$(echo "$SUB_RUNNING" | tr -d '[:space:]')
if [[ -z "$SUB_RUNNING" ]] || (( SUB_RUNNING == 0 )); then record "L0-Q5" "ok" 0 "无活跃子代理"
elif (( SUB_RUNNING <= 5 )); then record "L0-Q5" "ok" "$SUB_RUNNING" "${SUB_RUNNING}个运行中"
else record "L0-Q5" "warn" "$SUB_RUNNING" "${SUB_RUNNING}个可能过多"; fi

# Q6 死循环检测
MOD_30MIN=$(find "$WORKSPACE" -type f -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/self-check-trends/*" -mmin -30 2>/dev/null | wc -l | tr -d '[:space:]')
if (( MOD_30MIN < 20 )); then record "L0-Q6" "ok" "$MOD_30MIN" "30min内${MOD_30MIN}文件"
else record "L0-Q6" "critical" "$MOD_30MIN" "30min内${MOD_30MIN}文件疑似循环"; fi

# ── L1: 运行时层 ──
WS_CONN=$(ss -tnp state established 2>/dev/null | grep ":18789" | wc -l | tr -d '[:space:]')
if (( WS_CONN >= 1 && WS_CONN <= 50 )); then record "L1-01" "ok" "$WS_CONN" "${WS_CONN}客户端"
elif (( WS_CONN == 0 )); then record "L1-01" "ok" 0 "无客户端在线"
else record "L1-01" "warn" "$WS_CONN" "${WS_CONN}异常多"; fi

PORT_COUNT=$(ss -tlnp 2>/dev/null | grep -cE ":18789" || true)
PORT_COUNT=$(echo "$PORT_COUNT" | tr -d '[:space:]')
if (( PORT_COUNT > 0 )); then record "L1-02" "ok" 1 "端口监听中"
else record "L1-02" "critical" 0 "端口未监听"; fi

CRASH_FILES=$(find /home/z3129119/.openclaw/ -name "*.log" -mmin -60 -exec grep -l -i "FATAL\|SEGFAULT\|uncaughtException" {} \; 2>/dev/null | wc -l | tr -d '[:space:]')
if (( CRASH_FILES == 0 )); then record "L1-03" "ok" 0 "无"
else record "L1-03" "critical" "$CRASH_FILES" "${CRASH_FILES}个文件"; fi

# ── L2: 深度分析层 ──
# L2-01 内存趋势
if [[ -f "$TRENDS_FILE" ]]; then
  PREV_AVG=$(tail -5 "$TRENDS_FILE" 2>/dev/null | python3 -c "
import sys, json
vals = []
for line in sys.stdin:
  try:
    d = json.loads(line.strip())
    if d.get('check') == 'L0-Q2' and d.get('metric') == 'status':
      vals.append(d.get('value', 0))
  except: pass
print(int(sum(vals)/len(vals)) if vals else 0)
" 2>/dev/null || echo 0)
  if (( PREV_AVG > 0 && RSS_MB > 0 )); then
    DIFF=$((RSS_MB - PREV_AVG))
    if (( DIFF > 300 )); then record "L2-01" "critical" "$DIFF" "比基线高${DIFF}MB"
    elif (( DIFF > 100 )); then record "L2-01" "warn" "$DIFF" "比基线高${DIFF}MB"
    else record "L2-01" "ok" "$DIFF" "基线${PREV_AVG}MB"; fi
  else record "L2-01" "ok" 0 "无历史基线"; fi
else record "L2-01" "ok" 0 "无趋势文件"; fi

# L2-02 僵尸进程
ALL_NODE=$(pgrep -a node 2>/dev/null | grep -v "$GW_PID" | grep -v grep | wc -l | tr -d '[:space:]')
if (( ALL_NODE == 0 )); then record "L2-02" "ok" 0 "无额外node进程"
else record "L2-02" "warn" "$ALL_NODE" "${ALL_NODE}个额外node进程"; fi

# L2-03 环境基线 (每日只记录一次)
NODE_VER=$(node -v 2>/dev/null || echo "unknown")
NPM_VER=$(npm -v 2>/dev/null || echo "unknown")
record "L2-03" "ok" 1 "node=$NODE_VER npm=$NPM_VER"

# L2-04 临时文件
TMP_COUNT=$(find /tmp/openclaw/ -type f -mmin +1440 2>/dev/null | wc -l | tr -d '[:space:]')
if (( TMP_COUNT == 0 )); then record "L2-04" "ok" 0 "无"
else record "L2-04" "warn" "$TMP_COUNT" "${TMP_COUNT}个>24h"; fi

# L2-05 网络连通
if getent hosts registry.npmjs.org >/dev/null 2>&1; then record "L2-05" "ok" 1 "DNS正常"
elif getent hosts www.baidu.com >/dev/null 2>&1; then record "L2-05" "ok" 1 "DNS正常"
else record "L2-05" "critical" 0 "DNS解析失败"; fi

# L2-06 磁盘工作区
DISK_WS=$(df -P "$WORKSPACE" 2>/dev/null | awk 'NR==2{print $5}' | tr -d '%')
if (( DISK_WS < 80 )); then record "L2-06" "ok" "$DISK_WS" "${DISK_WS}%"
elif (( DISK_WS < 90 )); then record "L2-06" "warn" "$DISK_WS" "${DISK_WS}%"
else record "L2-06" "critical" "$DISK_WS" "${DISK_WS}%"; fi

# ── L3: 业务合规层 ──
ACTIVE=$(find "$WORKSPACE/projects/" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while read d; do
  find "$d" -not -path "*/.git/*" -not -path "*/node_modules/*" -type f -mtime -7 2>/dev/null | grep -q . && basename "$d"
done | wc -l | tr -d '[:space:]')
TOTAL=$(find "$WORKSPACE/projects/" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d '[:space:]')
if (( ACTIVE > 0 )); then record "L3-01" "ok" "$ACTIVE" "${ACTIVE}/${TOTAL}"
else record "L3-01" "warn" 0 "无7天内变更"; fi

# L3-02 每日摘要
TODAY=$(date '+%Y-%m-%d')
YESTERDAY=$(date -d 'yesterday' '+%Y-%m-%d' 2>/dev/null || echo "")
ABSENT=0
for d in "$TODAY" "$YESTERDAY"; do
  if [[ -n "$d" ]] && [[ ! -f "$WORKSPACE/memory/${d}.md" ]]; then ((ABSENT++)); fi
done
if (( ABSENT == 0 )); then record "L3-02" "ok" 0 "近2天完整"
elif (( ABSENT == 1 )); then record "L3-02" "warn" 1 "缺1天"
else record "L3-02" "critical" 2 "缺2天以上"; fi

# L3-03 MEMORY.md
MEM_AGE=$(( ($(date +%s) - $(stat -c %Y "$WORKSPACE/MEMORY.md" 2>/dev/null || echo $(date +%s))) / 86400 ))
if (( MEM_AGE <= 2 )); then record "L3-03" "ok" "$MEM_AGE" "${MEM_AGE}天前"
elif (( MEM_AGE <= 7 )); then record "L3-03" "warn" "$MEM_AGE" "${MEM_AGE}天前"
else record "L3-03" "critical" "$MEM_AGE" "${MEM_AGE}天前"; fi

# L3-04 待办队列
if [[ -f "$WORKSPACE/data/autonomous-todo.json" ]]; then
  PENDING=$(python3 -c "import json; d=json.load(open('$WORKSPACE/data/autonomous-todo.json')); print(len([t for t in d if isinstance(t,dict) and t.get('status')=='pending']))" 2>/dev/null || echo "0")
  if (( PENDING <= 5 )); then record "L3-04" "ok" "$PENDING" "${PENDING}项"
  elif (( PENDING <= 10 )); then record "L3-04" "warn" "$PENDING" "${PENDING}项"
  else record "L3-04" "critical" "$PENDING" "${PENDING}项"; fi
else record "L3-04" "ok" 0 "无队列文件"; fi

# ── 汇总 ──
TOTAL=$((OK_COUNT + WARN_COUNT + FAIL_COUNT))
if (( FAIL_COUNT > 0 )); then OVERALL="critical"
elif (( WARN_COUNT > 0 )); then OVERALL="warn"
else OVERALL="ok"; fi

# 写状态 JSON
ANOMALY_JSON=$(printf '%s\n' "${ANOMALIES[@]}" 2>/dev/null | python3 -c "import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))" 2>/dev/null || echo "[]")
STATUS_JSON=$(cat <<EOJSON
{
  "ts": "$TS",
  "overall": "$OVERALL",
  "total": $TOTAL,
  "ok": $OK_COUNT,
  "warn": $WARN_COUNT,
  "critical": $FAIL_COUNT,
  "anomalies": $ANOMALY_JSON,
  "checks": [$(IFS=,; echo "${STATUS_MAP[*]}")]
}
EOJSON
)
echo "$STATUS_JSON" > "$STATUS_FILE"

# 异常标记文件（供 AI agent 快速判断）
if [[ "$OVERALL" != "ok" ]]; then
  echo "$OVERALL" > "$ANOMALY_FILE"
  echo "$STATUS_JSON" >> "$ANOMALY_FILE"
else
  rm -f "$ANOMALY_FILE" 2>/dev/null
fi

# 终端输出
if [[ "$MODE" == "jsononly" ]]; then
  echo "$STATUS_JSON"
  exit 0
fi

echo "============================================="
echo "  OpenClaw 自检报告 — $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "============================================="
echo ""

if [[ "$VERBOSE" -eq 1 ]]; then
  # 详细模式：显示每项
  echo "┌─ L0: 基础存活层 ────────────────────────┐"
  for entry in "${STATUS_MAP[@]}"; do
    id=$(echo "$entry" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])" 2>/dev/null)
    status=$(echo "$entry" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])" 2>/dev/null)
    detail=$(echo "$entry" | python3 -c "import sys,json; print(json.load(sys.stdin)['detail'])" 2>/dev/null)
    case "$status" in ok) S="✅";; warn) S="⚠️";; critical) S="🔴";; esac
    echo "│ $id  $S $detail"
  done
  echo "└────────────────────────────────────────────┘"
fi

echo ""
case "$OVERALL" in
  ok)       echo "  ✅ 全部通过 | $OK_COUNT/$TOTAL | 耗时 < 5s" ;;
  warn)     echo "  ⚠️  $WARN_COUNT 项警告 | $OK_COUNT/$TOTAL 通过" ;;
  critical) echo "  🔴 $FAIL_COUNT 项异常! | $OK_COUNT/$TOTAL 通过" ;;
esac
echo "============================================="

# 退出码: 0=正常, 1=警告, 2=异常
if [[ "$OVERALL" == "critical" ]]; then exit 2
elif [[ "$OVERALL" == "warn" ]]; then exit 1
else exit 0; fi
