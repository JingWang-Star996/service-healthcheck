========================================================
  OpenClaw Healthcheck — 19 项全量自检脚本
========================================================

一个纯 Bash 脚本，用于 OpenClaw Gateway 和 Agent 运行
环境的 19 项全量自检。

零依赖。零 token 消耗。结构化 JSON 输出。趋势记录。

GitHub: https://github.com/JingWang-Star996/openclaw-healthcheck


--------------------------------------------------------
  为什么需要
--------------------------------------------------------

OpenClaw（及类似 AI Agent 框架）长时间运行时，常见问题：

  - 内存泄漏导致 OOM 崩溃
  - 子代理卡死 / 僵尸进程
  - 代码死循环疯狂写文件
  - WebSocket 连接泄漏
  - 崩溃日志堆积但无人发现

传统做法是每次用 AI agent 手动执行命令检查——浪费 token，
且无法积累趋势。

这个脚本用纯 Bash 解决：每小时自动跑，零 token，结构化输
出，异常时自动通知。


--------------------------------------------------------
  架构
--------------------------------------------------------

系统 crontab (每小时)        OpenClaw cron (错开几分钟)
      |                              |
      v                              v
healthcheck.sh --json          读取 status.json
      |                              |
      +-- 跑 19 项检查               +-- overall=ok → 静默
      +-- 写 status.json             +-- overall≠ok → 通知
      +-- 追加 trends.jsonl
      +-- 有异常 → 创建 anomaly 文件


--------------------------------------------------------
  自检项目（共 19 项）
--------------------------------------------------------

L0 — 基础存活层（6 项）

  [Q1] 进程存活
       Gateway 进程存在且非僵尸状态

  [Q2] 内存 RSS
       小于 2GB 正常，2 到 2.5GB 警告，大于 3GB 紧急

  [Q3] 磁盘根分区
       小于 80% 正常，大于 95% 紧急

  [Q4] OOM 检测
       最近 10 分钟无 OOM kill

  [Q5] 子代理状态
       活跃子代理数不超过 5 个

  [Q6] 死循环检测
       30 分钟内修改文件数少于 20 个


L1 — 运行时层（3 项）

  [L1-01] WebSocket 连接
          1 到 50 正常，0 或大于 50 异常

  [L1-02] 关键端口
          Gateway 端口监听中

  [L1-03] 崩溃日志
          最近 1 小时无 FATAL 或 SEGFAULT


L2 — 深度分析层（6 项）

  [L2-01] 内存趋势
          对比最近 5 次基线，增长超过 300MB 告警

  [L2-02] 僵尸进程
          无额外 node 进程

  [L2-03] 环境基线
          记录 Node 和 npm 版本

  [L2-04] 临时文件
          无超过 24 小时的残留文件

  [L2-05] 网络连通
          DNS 解析正常

  [L2-06] 磁盘工作区
          工作区目录磁盘使用率


L3 — 业务合规层（4 项）

  [L3-01] 项目活跃
          至少 1 个项目 7 天内有变更

  [L3-02] 每日摘要
          最近 2 天的摘要文件存在

  [L3-03] MEMORY.md
          最近 2 天内有更新

  [L3-04] 待办队列
          Pending 任务不超过 5 个


--------------------------------------------------------
  输出示例
--------------------------------------------------------

终端输出：

  $ bash scripts/healthcheck.sh
    全部通过 | 19/19 | 耗时 < 5s

加 --verbose 显示明细：

  $ bash scripts/healthcheck.sh --verbose
  L0-Q1  OK  PID=254413
  L0-Q2  OK  1286MB
  L0-Q3  OK  4%
  ...
  全部通过 | 19/19 | 耗时 < 5s

JSON 状态文件：

  {
    "ts": "2026-05-01T11:14:38+08:00",
    "overall": "ok",
    "total": 19, "ok": 19, "warn": 0, "critical": 0,
    "anomalies": [],
    "checks": [
      {"id": "L0-Q1", "status": "ok", "value": 1}
    ]
  }

趋势记录（JSONL 格式）：

  {"ts":"2026-05-01T11:14:38+08:00","check":"L0-Q2",
   "metric":"status","value":1286,"status":"ok"}


--------------------------------------------------------
  安装
--------------------------------------------------------

方式一：克隆到 OpenClaw workspace

  cd ~/.openclaw/workspace
  git clone https://github.com/JingWang-Star996/openclaw-healthcheck.git projects/openclaw-healthcheck

方式二：独立使用

  git clone https://github.com/JingWang-Star996/openclaw-healthcheck.git
  cd openclaw-healthcheck
  bash scripts/healthcheck.sh


--------------------------------------------------------
  配置
--------------------------------------------------------

1. 系统 crontab（零 token）

   每小时整点运行，输出静默：

   (crontab -l 2>/dev/null; echo "0 * * * * bash /path/to/scripts/healthcheck.sh --json >> /dev/null 2>&1") | crontab -

2. OpenClaw cron（异常通知）

   读取 status.json，overall=ok 则静默，否则提取异常项
   私聊通知用户。

3. Heartbeat 集成

   每次 Heartbeat 执行 healthcheck.sh，脚本输出中看
   🔴/🚨 标记，有异常则汇报。


--------------------------------------------------------
  退出码
--------------------------------------------------------

  0 — 全部通过
  1 — 有警告（warn）
  2 — 有异常（critical）


--------------------------------------------------------
  自定义
--------------------------------------------------------

调整阈值：编辑脚本中的判断逻辑，例如内存阈值：

  if (( RSS_MB < 2048 )); then ...

增减检查项：在对应层级段添加 record 调用：

  record "LX-XX" "ok|warn|critical" 数值 "描述"

自定义输出路径：修改脚本开头的路径变量：

  STATUS_FILE="/your/path/status.json"
  TRENDS_FILE="/your/path/trends.jsonl"
  ANOMALY_FILE="/tmp/your-anomaly"


--------------------------------------------------------
  技术约束
--------------------------------------------------------

  - 纯 Bash + 少量 Python3（仅 JSON 解析）
  - 只读操作，不修改任何系统状态
  - 单次运行不超过 5 秒
  - 不依赖外部 API
  - Linux/WSL2 环境

========================================================
