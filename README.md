# OpenClaw Healthcheck

<p align="center">
  <strong>🇨🇳 中文</strong> · <strong>🇬🇧 English</strong> · <strong>🇯🇵 日本語</strong>
</p>

> 一个纯 Bash 脚本，用于 OpenClaw Gateway 和 Agent 运行环境的 **19 项全量自检**。
> 零依赖、零 token 消耗、输出结构化 JSON，支持趋势记录。

> A pure Bash script for **19-item comprehensive self-check** of OpenClaw Gateway and Agent runtime environment.
> Zero dependencies, zero token cost, structured JSON output, trend tracking.

> OpenClaw Gateway と Agent 実行環境の **19 項目包括的セルフチェック** を行う纯 Bash スクリプト。
> ゼロ依存、ゼロトークン消費、構造化 JSON 出力、トレンド追跡対応。

---

## 语言导航 / Language Navigation

| 语言 | 直达链接 |
|------|----------|
| 🇨🇳 中文 | [为什么需要](#-为什么需要) · [架构](#-架构) · [自检项目](#-自检项目19-项) · [输出](#-输出) · [安装](#-安装) · [配置](#-配置) |
| 🇬🇧 English | [Why](#-why) · [Architecture](#-architecture) · [Checks](#-checks-19-items) · [Output](#-output) · [Install](#-installation) · [Config](#-configuration) |
| 🇯🇵 日本語 | [なぜ必要](#-なぜ必要か) · [アーキテクチャ](#-アーキテクチャ) · [チェック項目](#-チェック項目19-項目) · [出力](#-出力) · [インストール](#-インストール) · [設定](#-設定) |

---

## 🇨🇳 中文

### 为什么需要

OpenClaw（及类似 AI Agent 框架）长时间运行时，常见问题包括：
- 内存泄漏导致 OOM 崩溃
- 子代理卡死/僵尸进程
- 代码死循环疯狂写文件
- WebSocket 连接泄漏
- 崩溃日志堆积但无人发现

传统做法是每次用 AI agent 手动执行命令检查——**浪费 token，且无法积累趋势**。

这个脚本用纯 Bash 解决：**每小时自动跑，零 token，结构化输出，异常时自动通知**。

### 架构

```
系统 crontab (每小时)     OpenClaw cron (错开几分钟)
      ↓                        ↓
healthcheck.sh --json    读取 status.json
      ↓                        ↓
  ├─ 跑 19 项检查          ├─ overall=ok → NO_REPLY（静默）
  ├─ 写 status.json        └─ overall≠ok → 私聊通知
  ├─ 追加 trends.jsonl
  └─ 有异常 → 创建 anomaly 文件
```

### 自检项目（19 项）

#### L0 — 基础存活层（6 项）
| # | 检查项 | 判定标准 |
|---|--------|----------|
| Q1 | 进程存活 | Gateway 进程存在且非僵尸 |
| Q2 | 内存 RSS | <2GB OK / 2-2.5GB 警告 / >3GB 紧急 |
| Q3 | 磁盘根分区 | <80% OK / >95% 紧急 |
| Q4 | OOM 检测 | 最近 10 分钟无 OOM kill |
| Q5 | 子代理状态 | 活跃子代理数 ≤5 |
| Q6 | 死循环检测 | 30min 内修改文件 <20 个 |

#### L1 — 运行时层（3 项）
| # | 检查项 | 判定标准 |
|---|--------|----------|
| L1-01 | WebSocket 连接 | 1-50 正常 / 0 或 >50 异常 |
| L1-02 | 关键端口 | Gateway 端口监听中 |
| L1-03 | 崩溃日志 | 最近 1 小时无 FATAL/SEGFAULT |

#### L2 — 深度分析层（6 项）
| # | 检查项 | 判定标准 |
|---|--------|----------|
| L2-01 | 内存趋势 | 对比最近 5 次基线，>300MB 告警 |
| L2-02 | 僵尸进程 | 无额外 node 进程 |
| L2-03 | 环境基线 | Node/npm 版本记录 |
| L2-04 | 临时文件 | 无 >24h 残留文件 |
| L2-05 | 网络连通 | DNS 解析正常 |
| L2-06 | 磁盘工作区 | 工作区目录磁盘使用率 |

#### L3 — 业务合规层（4 项）
| # | 检查项 | 判定标准 |
|---|--------|----------|
| L3-01 | 项目活跃 | 至少 1 个项目 7 天内有变更 |
| L3-02 | 每日摘要 | 最近 2 天摘要文件存在 |
| L3-03 | MEMORY.md | 最近 2 天内有更新 |
| L3-04 | 待办队列 | Pending 任务 ≤5 |

### 输出

**终端输出：**
```bash
$ bash scripts/healthcheck.sh
  ✅ 全部通过 | 19/19 | 耗时 < 5s
```

**加 `--verbose` 显示明细：**
```bash
$ bash scripts/healthcheck.sh --verbose
┌─ L0: 基础存活层 ────────────────────────┐
│ L0-Q1  ✅ PID=254413
│ L0-Q2  ✅ 1286MB
...
└────────────────────────────────────────────┘
```

**JSON 状态文件：**
```json
{
  "ts": "2026-05-01T11:14:38+08:00",
  "overall": "ok",
  "total": 19, "ok": 19, "warn": 0, "critical": 0,
  "anomalies": [],
  "checks": [
    {"id": "L0-Q1", "status": "ok", "value": 1, "detail": "PID=254413"},
    {"id": "L0-Q2", "status": "ok", "value": 1286, "detail": "1286MB"}
  ]
}
```

**趋势记录（JSONL）：**
```jsonl
{"ts":"2026-05-01T11:14:38+08:00","check":"L0-Q2","metric":"status","value":1286,"status":"ok"}
```

### 安装

```bash
# 方式一：克隆到 OpenClaw workspace
cd ~/.openclaw/workspace
git clone https://github.com/JingWang-Star996/openclaw-healthcheck.git projects/openclaw-healthcheck

# 方式二：独立使用
git clone https://github.com/JingWang-Star996/openclaw-healthcheck.git
cd openclaw-healthcheck
bash scripts/healthcheck.sh
```

### 配置

**系统 crontab（零 token）：**
```bash
(crontab -l 2>/dev/null; echo "0 * * * * bash /path/to/scripts/healthcheck.sh --json >> /dev/null 2>&1") | crontab -
```

**OpenClaw cron（异常通知）：**
```json
{
  "name": "自检结果检查",
  "schedule": { "kind": "every", "everyMs": 3600000 },
  "payload": {
    "kind": "agentTurn",
    "message": "读取 status.json，overall=ok → NO_REPLY，否则提取 anomalies 私聊通知。"
  },
  "sessionTarget": "isolated"
}
```

### 退出码

| 退出码 | 含义 |
|--------|------|
| 0 | 全部通过 |
| 1 | 有警告（warn） |
| 2 | 有异常（critical） |

---

## 🇬🇧 English

### Why

When OpenClaw (and similar AI Agent frameworks) run for extended periods, common issues include:
- Memory leaks leading to OOM crashes
- Sub-agent hangs / zombie processes
- Dead loops writing files continuously
- WebSocket connection leaks
- Crash logs accumulating unnoticed

The traditional approach is to manually execute commands via AI agent each time — **wasting tokens and unable to build trends**.

This script solves it in pure Bash: **runs automatically every hour, zero tokens, structured output, auto-notifies on anomalies**.

### Architecture

```
System crontab (hourly)    OpenClaw cron (offset)
      ↓                        ↓
healthcheck.sh --json    Read status.json
      ↓                        ↓
  ├─ Run 19 checks         ├─ overall=ok → NO_REPLY (silent)
  ├─ Write status.json     └─ overall≠ok → Notify user
  ├─ Append trends.jsonl
  └─ On anomaly → create anomaly file
```

### Checks (19 items)

#### L0 — Survival Layer (6 items)
| # | Check | Criteria |
|---|-------|----------|
| Q1 | Process alive | Gateway process exists, not zombie |
| Q2 | Memory RSS | <2GB OK / 2-2.5GB warn / >3GB critical |
| Q3 | Root disk | <80% OK / >95% critical |
| Q4 | OOM detection | No OOM kill in last 10 min |
| Q5 | Sub-agent state | Active sub-agents ≤5 |
| Q6 | Dead-loop detection | <20 files modified in 30 min |

#### L1 — Runtime Layer (3 items)
| # | Check | Criteria |
|---|-------|----------|
| L1-01 | WebSocket connections | 1-50 normal / 0 or >50 abnormal |
| L1-02 | Key port | Gateway port listening |
| L1-03 | Crash logs | No FATAL/SEGFAULT in last 1 hour |

#### L2 — Deep Analysis Layer (6 items)
| # | Check | Criteria |
|---|-------|----------|
| L2-01 | Memory trend | vs last 5-run baseline, >300MB alert |
| L2-02 | Zombie processes | No extra node processes |
| L2-03 | Environment baseline | Node/npm version record |
| L2-04 | Temp files | No files >24h old |
| L2-05 | Network connectivity | DNS resolution works |
| L2-06 | Workspace disk | Workspace directory disk usage |

#### L3 — Business Compliance Layer (4 items)
| # | Check | Criteria |
|---|-------|----------|
| L3-01 | Project activity | At least 1 project changed in 7 days |
| L3-02 | Daily summary | Recent 2 daily summary files exist |
| L3-03 | MEMORY.md | Updated within 2 days |
| L3-04 | Pending tasks | Pending tasks ≤5 |

### Output

**Terminal output:**
```bash
$ bash scripts/healthcheck.sh
  ✅ All passed | 19/19 | < 5s
```

**JSON status file:**
```json
{
  "ts": "2026-05-01T11:14:38+08:00",
  "overall": "ok",
  "total": 19, "ok": 19, "warn": 0, "critical": 0,
  "anomalies": [],
  "checks": [
    {"id": "L0-Q1", "status": "ok", "value": 1, "detail": "PID=254413"}
  ]
}
```

### Installation

```bash
# Clone to OpenClaw workspace
cd ~/.openclaw/workspace
git clone https://github.com/JingWang-Star996/openclaw-healthcheck.git projects/openclaw-healthcheck

# Or standalone
git clone https://github.com/JingWang-Star996/openclaw-healthcheck.git
cd openclaw-healthcheck
bash scripts/healthcheck.sh
```

### Configuration

**System crontab (zero tokens):**
```bash
(crontab -l 2>/dev/null; echo "0 * * * * bash /path/to/scripts/healthcheck.sh --json >> /dev/null 2>&1") | crontab -
```

**OpenClaw cron (anomaly notification):**
```json
{
  "name": "Health Check Result",
  "schedule": { "kind": "every", "everyMs": 3600000 },
  "payload": {
    "kind": "agentTurn",
    "message": "Read status.json, overall=ok → NO_REPLY, else extract anomalies and notify user."
  },
  "sessionTarget": "isolated"
}
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All passed |
| 1 | Warnings present |
| 2 | Critical anomalies |

---

## 🇯🇵 日本語

### なぜ必要か

OpenClaw（および類似の AI Agent フレームワーク）が長時間実行される場合、一般的な問題点：
- メモリリークによる OOM クラッシュ
- サブエージェントのハング / ゾンビプロセス
- デッドループによるファイルの連続書き込み
- WebSocket 接続のリーク
- クラッシュログの蓄積（誰も気づかない）

従来の方法は、毎回 AI agent でコマンドを手動実行すること——**トークンの無駄、かつトレンドの蓄積が不可能**。

このスクリプトは纯 Bash で解決：**毎時間自動実行、ゼロトークン、構造化出力、異常時に自動通知**。

### アーキテクチャ

```
システム crontab（毎時）    OpenClaw cron（ずらす）
      ↓                        ↓
healthcheck.sh --json    status.json を読み取り
      ↓                        ↓
  ├─ 19 項目チェック        ├─ overall=ok → NO_REPLY（沈黙）
  ├─ status.json を書き込む  └─ overall≠ok → ユーザーに通知
  ├─ trends.jsonl に追記
  └─ 異常時 → anomaly ファイルを作成
```

### チェック項目（19 項目）

#### L0 — 生存レイヤー（6 項目）
| # | チェック | 判定基準 |
|---|----------|----------|
| Q1 | プロセス存活 | Gateway プロセス存在、ゾンビでない |
| Q2 | メモリ RSS | <2GB OK / 2-2.5GB 警告 / >3GB 緊急 |
| Q3 | ルートディスク | <80% OK / >95% 緊急 |
| Q4 | OOM 検出 | 直近 10 分以内に OOM kill なし |
| Q5 | サブエージェント状態 | 稼働中 ≤5 |
| Q6 | デッドループ検出 | 30 分以内のファイル変更 <20 個 |

#### L1 — ランタイムレイヤー（3 項目）
| # | チェック | 判定基準 |
|---|----------|----------|
| L1-01 | WebSocket 接続数 | 1-50 正常 / 0 or >50 異常 |
| L1-02 | 重要ポート | Gateway ポートがリスニング中 |
| L1-03 | クラッシュログ | 直近 1 時間以内に FATAL/SEGFAULT なし |

#### L2 — 深度分析レイヤー（6 項目）
| # | チェック | 判定基準 |
|---|----------|----------|
| L2-01 | メモリトレンド | 直近 5 回ベースライン比較、>300MB で警告 |
| L2-02 | ゾンビプロセス | 余分な node プロセスなし |
| L2-03 | 環境ベースライン | Node/npm バージョン記録 |
| L2-04 | 一時ファイル | 24 時間以上の残存ファイルなし |
| L2-05 | ネットワーク接続 | DNS 解決が正常 |
| L2-06 | ワークスペースディスク | ワークスペースディレクトリのディスク使用率 |

#### L3 — ビジネスコンプライアンスレイヤー（4 項目）
| # | チェック | 判定基準 |
|---|----------|----------|
| L3-01 | プロジェクト活動 | 少なくとも 1 プロジェクトが 7 日以内に変更 |
| L3-02 | 日次サマリー | 直近 2 日のサマリーファイルが存在 |
| L3-03 | MEMORY.md | 2 日以内に更新 |
| L3-04 | 保留タスク | 保留タスク ≤5 |

### 出力

**ターミナル出力：**
```bash
$ bash scripts/healthcheck.sh
  ✅ 全て通過 | 19/19 | < 5秒
```

**JSON 状態ファイル：**
```json
{
  "ts": "2026-05-01T11:14:38+08:00",
  "overall": "ok",
  "total": 19, "ok": 19, "warn": 0, "critical": 0,
  "anomalies": []
}
```

### インストール

```bash
# OpenClaw workspace にクローン
cd ~/.openclaw/workspace
git clone https://github.com/JingWang-Star996/openclaw-healthcheck.git projects/openclaw-healthcheck

# またはスタンドアロン
git clone https://github.com/JingWang-Star996/openclaw-healthcheck.git
cd openclaw-healthcheck
bash scripts/healthcheck.sh
```

### 設定

**システム crontab（ゼロトークン）：**
```bash
(crontab -l 2>/dev/null; echo "0 * * * * bash /path/to/scripts/healthcheck.sh --json >> /dev/null 2>&1") | crontab -
```

**OpenClaw cron（異常通知）：**
```json
{
  "name": "ヘルスチェック結果",
  "schedule": { "kind": "every", "everyMs": 3600000 },
  "payload": {
    "kind": "agentTurn",
    "message": "status.json を読み取り、overall=ok → NO_REPLY、そうでなければ anomalies を抽出してユーザーに通知。"
  },
  "sessionTarget": "isolated"
}
```

### 終了コード

| コード | 意味 |
|--------|------|
| 0 | 全て通過 |
| 1 | 警告あり |
| 2 | 重大な異常あり |

---

## 技术约束 / Technical Constraints / 技術制約

| | 🇨🇳 | 🇬🇧 | 🇯🇵 |
|---|---|---|---|
| 语言 | 纯 Bash + 少量 Python3 | Pure Bash + minimal Python3 | 纯 Bash + 最小限の Python3 |
| 操作 | 只读操作 | Read-only | 読み取り専用 |
| 耗时 | 单次 < 5 秒 | < 5s per run | 1 回 < 5 秒 |
| API | 不依赖外部 API | No external API | 外部 API 不要 |
| 环境 | Linux/WSL2 | Linux/WSL2 | Linux/WSL2 |

## License

MIT
