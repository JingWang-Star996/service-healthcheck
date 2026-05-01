# OpenClaw Healthcheck — 19-Item Self-Check Script

<p align="center">
  <strong>🇨🇳 中文</strong> · <strong>🇬🇧 English</strong> · <strong>🇯🇵 日本語</strong> · <strong>🇰🇷 한국어</strong> · <strong>🇪🇸 Español</strong> · <strong>🇫🇷 Français</strong> · <strong>🇩🇪 Deutsch</strong> · <strong>🇷🇺 Русский</strong>
</p>

> A pure Bash script for comprehensive self-check of AI Agent runtime environments.
> Zero dependencies, zero token cost, structured JSON output, trend tracking.

> 一个纯 Bash 脚本，用于 AI Agent 运行环境的 19 项全量自检。零依赖、零 token、结构化 JSON 输出。

> AI Agent 実行環境の包括的セルフチェックを行う纯 Bash スクリプト。ゼロ依存、ゼロトークン。

> AI Agent 실행 환경의 포괄적 셀프 체크를 위한 순수 Bash 스크립트. 제로 의존성, 제로 토큰.

> Un script Bash puro para verificación integral de entornos de ejecución de IA. Cero dependencias, cero tokens.

> Un script Bash pur pour la vérification des environnements d'exécution IA. Zéro dépendance, zéro token.

> Ein reines Bash-Skript für umfassende Selbstprüfung von KI-Agent-Laufzeitumgebungen. Null Abhängigkeiten, null Token.

> Чистый Bash-скрипт для комплексной самодиагностики сред исполнения AI-агентов. Нулевые зависимости, нулевые токены.

---

## Language Navigation / 语言导航 / 言語ナビ / 언어 네비게이션 / Navegación / Navigation / Navigation / Навигация

| # | Language | Quick Link |
|---|----------|-----------|
| 1 | 🇨🇳 中文 | [为什么需要](#zh-cn-中文) |
| 2 | 🇬🇧 English | [Why](#en-english) |
| 3 | 🇯🇵 日本語 | [なぜ必要](#ja-日本語) |
| 4 | 🇰🇷 한국어 | [왜 필요한가](#ko-한국어) |
| 5 | 🇪🇸 Español | [Por qué](#es-español) |
| 6 | 🇫🇷 Français | [Pourquoi](#fr-français) |
| 7 | 🇩🇪 Deutsch | [Warum](#de-deutsch) |
| 8 | 🇷🇺 Русский | [Зачем](#ru-русский) |

---

## Common — 公共信息 / 共通情報 / 공통 정보 / Información común / Info commune / Gemeinsame Infos / Общая информация

### Check Items (19) — 自检项目 / チェック項目 / 체크 항목 / Ítems / Éléments / Prüfpunkte / Элементы

| Layer | Items | Focus |
|-------|-------|-------|
| L0 — Survival | 6 | Process, Memory, Disk, OOM, Sub-agent, Dead-loop |
| L1 — Runtime | 3 | WebSocket, Port, Crash logs |
| L2 — Deep | 6 | Memory trend, Zombie, Env, Temp files, DNS, Workspace |
| L3 — Business | 4 | Projects, Daily summary, Memory freshness, Pending tasks |

### Output — 输出 / 出力 / 출력 / Salida / Sortie / Ausgabe / Вывод

```bash
$ bash scripts/healthcheck.sh
  ✅ All passed | 19/19 | < 5s
```

```json
{
  "ts": "2026-05-01T11:14:38+08:00",
  "overall": "ok",
  "total": 19, "ok": 19, "warn": 0, "critical": 0,
  "checks": [{"id": "L0-Q1", "status": "ok", "value": 1}]
}
```

### Exit Codes — 退出码 / 終了コード / 종료 코드 / Códigos / Codes / Exit-Codes / Коды

| Code | Meaning |
|------|---------|
| 0 | All passed |
| 1 | Warnings |
| 2 | Critical |

### Quick Install — 快速安装 / クイックインストール / 빠른 설치 / Instalación / Installation / Schnelle Installation / Быстрая установка

```bash
git clone https://github.com/JingWang-Star996/openclaw-healthcheck.git
cd openclaw-healthcheck
bash scripts/healthcheck.sh
```

### Crontab — 定时任务 / 定时タスク /定时 작업 / Cron / Cron / Cron / Крон

```bash
# Hourly, zero tokens
(crontab -l 2>/dev/null; echo "0 * * * * bash /path/to/scripts/healthcheck.sh --json >> /dev/null 2>&1") | crontab -
```

---

## 🇨🇳 中文

### 为什么需要

OpenClaw（及类似 AI Agent 框架）长时间运行时，常见问题包括：内存泄漏导致 OOM 崩溃、子代理卡死/僵尸进程、代码死循环疯狂写文件、WebSocket 连接泄漏、崩溃日志堆积但无人发现。传统做法是用 AI agent 手动检查——**浪费 token，无法积累趋势**。

### 架构

```
系统 crontab (每小时)        OpenClaw cron (错开几分钟)
      ↓                            ↓
healthcheck.sh --json        读取 status.json
      ↓                            ↓
  ├─ 跑 19 项检查              ├─ overall=ok → NO_REPLY（静默）
  ├─ 写 status.json            └─ overall≠ok → 私聊通知
  ├─ 追加 trends.jsonl
  └─ 有异常 → 创建 anomaly 文件
```

### 自检项目

| 层 | 项目 | 说明 |
|----|------|------|
| L0 | 进程/内存/磁盘/OOM/子代理/死循环 | 6 项基础存活检查 |
| L1 | WebSocket/端口/崩溃日志 | 3 项运行时检查 |
| L2 | 内存趋势/僵尸进程/环境/临时文件/网络/磁盘 | 6 项深度分析 |
| L3 | 项目活跃/每日摘要/MEMORY.md/待办队列 | 4 项业务合规 |

### 配置

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

### 技术约束
- ✅ 纯 Bash + 少量 Python3（仅 JSON 解析）
- ✅ 只读操作，不修改任何系统状态
- ✅ 单次运行 < 5 秒
- ✅ 不依赖外部 API
- ✅ Linux/WSL2 环境

---

## 🇬🇧 English

### Why

When AI Agent frameworks run for extended periods, common issues include: memory leaks causing OOM crashes, sub-agent hangs/zombie processes, dead loops writing files, WebSocket connection leaks, crash logs accumulating unnoticed. The traditional approach uses AI agent to manually check — **wasting tokens, unable to build trends**.

### Architecture

```
System crontab (hourly)        OpenClaw cron (offset)
      ↓                            ↓
healthcheck.sh --json        Read status.json
      ↓                            ↓
  ├─ Run 19 checks             ├─ overall=ok → NO_REPLY (silent)
  ├─ Write status.json         └─ overall≠ok → Notify user
  ├─ Append trends.jsonl
  └─ On anomaly → create anomaly file
```

### Checks

| Layer | Items | Description |
|-------|-------|-------------|
| L0 | Process/Memory/Disk/OOM/Sub-agent/Dead-loop | 6 survival checks |
| L1 | WebSocket/Port/Crash logs | 3 runtime checks |
| L2 | Memory trend/Zombie/Env/Temp files/DNS/Disk | 6 deep analysis |
| L3 | Projects/Daily summary/MEMORY.md/Pending tasks | 4 business compliance |

### Configuration

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

### Technical Constraints
- ✅ Pure Bash + minimal Python3 (JSON parsing only)
- ✅ Read-only, no system modifications
- ✅ < 5 seconds per run
- ✅ No external API dependencies
- ✅ Linux/WSL2 environment

---

## 🇯🇵 日本語

### なぜ必要か

AI Agent フレームワークが長時間実行される場合、メモリリークによる OOM クラッシュ、サブエージェントのハング/ゾンビプロセス、デッドループによる連続書き込み、WebSocket 接続リーク、クラッシュログの蓄積（誰も気づかない）などの問題が発生します。従来の AI agent による手動チェックは——**トークンの無駄、トレンド蓄積不可能**。

### アーキテクチャ

```
システム crontab（毎時）        OpenClaw cron（ずらす）
      ↓                            ↓
healthcheck.sh --json        status.json を読み取り
      ↓                            ↓
  ├─ 19 項目チェック             ├─ overall=ok → NO_REPLY（沈黙）
  ├─ status.json を書き込む      └─ overall≠ok → ユーザー通知
  ├─ trends.jsonl に追記
  └─ 異常時 → anomaly ファイル作成
```

### チェック項目

| レイヤー | 項目 | 説明 |
|----------|------|------|
| L0 | プロセス/メモリ/ディスク/OOM/サブエージェント/デッドループ | 6 項目生存チェック |
| L1 | WebSocket/ポート/クラッシュログ | 3 項目ランタイムチェック |
| L2 | メモリトレンド/ゾンビ/環境/一時ファイル/DNS/ディスク | 6 項目深度分析 |
| L3 | プロジェクト/日次サマリー/MEMORY.md/保留タスク | 4 項目ビジネスコンプライアンス |

### 設定

**OpenClaw cron（異常通知）：**
```json
{
  "name": "ヘルスチェック結果",
  "schedule": { "kind": "every", "everyMs": 3600000 },
  "payload": {
    "kind": "agentTurn",
    "message": "status.json を読み取り、overall=ok → NO_REPLY、異常なら anomalies を通知。"
  },
  "sessionTarget": "isolated"
}
```

### 技術制約
- ✅ 纯 Bash + 最小限の Python3（JSON パースのみ）
- ✅ 読み取り専用
- ✅ 1 回 < 5 秒
- ✅ 外部 API 不要
- ✅ Linux/WSL2 環境

---

## 🇰🇷 한국어

### 왜 필요한가

AI Agent 프레임워크가 장시간 실행될 때 발생하는 일반적인 문제: 메모리 누수로 인한 OOM 크래시, 서브 에이전트 멈춤/좀비 프로세스, 데드루프로 인한 파일 연속 쓰기, WebSocket 연결 누수, 크래시 로그 축적(아무도 모름). 기존 AI agent 수동 체크 방식은——**토큰 낭비, 트렌드 축적 불가**.

### 아키텍처

```
시스템 crontab (매시간)        OpenClaw cron (시간차)
      ↓                            ↓
healthcheck.sh --json        status.json 읽기
      ↓                            ↓
  ├─ 19개 체크 실행              ├─ overall=ok → NO_REPLY (조용)
  ├─ status.json 쓰기            └─ overall≠ok → 사용자 알림
  ├─ trends.jsonl 추가
  └─异常시 → anomaly 파일 생성
```

### 체크 항목

| 레이어 | 항목 | 설명 |
|--------|------|------|
| L0 | 프로세스/메모리/디스크/OOM/서브에이전트/데드루프 | 6개 생존 체크 |
| L1 | WebSocket/포트/크래시 로그 | 3개 런타임 체크 |
| L2 | 메모리 트렌드/좀비/환경/임시파일/DNS/디스크 | 6개 심층 분석 |
| L3 | 프로젝트/일일 요약/MEMORY.md/대기 작업 | 4개 비즈니스 컴플라이언스 |

### 설정

**OpenClaw cron (异常 알림):**
```json
{
  "name": "헬스체크 결과",
  "schedule": { "kind": "every", "everyMs": 3600000 },
  "payload": {
    "kind": "agentTurn",
    "message": "status.json 읽기, overall=ok → NO_REPLY, 아니면 anomalies 추출하여 사용자 알림."
  },
  "sessionTarget": "isolated"
}
```

### 기술 제약
- ✅ 순수 Bash + 최소 Python3 (JSON 파싱만)
- ✅ 읽기 전용
- ✅ 1회 < 5초
- ✅ 외부 API 불필요
- ✅ Linux/WSL2 환경

---

## 🇪🇸 Español

### Por qué

Cuando frameworks de IA se ejecutan por largos períodos, problemas comunes incluyen: fugas de memoria causando crashes OOM, procesos zombie, bucles infinitos escribiendo archivos, fugas de conexiones WebSocket, logs de crash acumulándose sin ser detectados. El enfoque tradicional con IA manual——**desperdicia tokens, imposible acumular tendencias**.

### Arquitectura

```
Crontab del sistema (cada hora)    Cron de OpenClaw (desfasado)
      ↓                                    ↓
healthcheck.sh --json                Leer status.json
      ↓                                    ↓
  ├─ Ejecutar 19 checks                ├─ overall=ok → NO_REPLY (silencio)
  ├─ Escribir status.json              └─ overall≠ok → Notificar usuario
  ├─ Agregar a trends.jsonl
  └─ En anomalía → crear archivo anomaly
```

### Ítems de verificación

| Capa | Ítems | Descripción |
|------|-------|-------------|
| L0 | Proceso/Memoria/Disco/OOM/Sub-agente/Bucle | 6 checks de supervivencia |
| L1 | WebSocket/Puerto/Logs de crash | 3 checks de runtime |
| L2 | Tendencia memoria/Zombie/Entorno/Temp/DNS/Disco | 6 análisis profundo |
| L3 | Proyectos/Resumen diario/MEMORY.md/Tareas pendientes | 4 cumplimiento negocio |

### Configuración

**OpenClaw cron (notificación de anomalías):**
```json
{
  "name": "Resultado de verificación",
  "schedule": { "kind": "every", "everyMs": 3600000 },
  "payload": {
    "kind": "agentTurn",
    "message": "Leer status.json, overall=ok → NO_REPLY, sino extraer anomalies y notificar."
  },
  "sessionTarget": "isolated"
}
```

### Restricciones técnicas
- ✅ Bash puro + Python3 mínimo (solo parsing JSON)
- ✅ Solo lectura
- ✅ < 5 segundos por ejecución
- ✅ Sin dependencias de API externa
- ✅ Entorno Linux/WSL2

---

## 🇫🇷 Français

### Pourquoi

Lorsque des frameworks IA tournent longtemps, problèmes courants : fuites mémoire causant des crashes OOM, processus zombies, boucles infinies écrivant des fichiers, fuites de connexions WebSocket, logs de crash s'accumulant sans être détectés. L'approche traditionnelle avec IA manuelle——**gâche des tokens, impossible d'accumuler des tendances**.

### Architecture

```
Crontab système (chaque heure)    Cron OpenClaw (décalé)
      ↓                                ↓
healthcheck.sh --json            Lire status.json
      ↓                                ↓
  ├─ Exécuter 19 vérifications      ├─ overall=ok → NO_REPLY (silence)
  ├─ Écrire status.json             └─ overall≠ok → Notifier l'utilisateur
  ├─ Ajouter à trends.jsonl
  └─ En anomalie → créer fichier anomaly
```

### Éléments de vérification

| Couche | Éléments | Description |
|--------|----------|-------------|
| L0 | Processus/Mémoire/Disque/OOM/Sous-agent/Boucle | 6 vérifications survie |
| L1 | WebSocket/Port/Logs de crash | 3 vérifications runtime |
| L2 | Tendance mémoire/Zombie/Env/Fichiers temp/DNS/Disque | 6 analyses profondes |
| L3 | Projets/Résumé quotidien/MEMORY.md/Tâches en attente | 4 conformité métier |

### Configuration

**OpenClaw cron (notification d'anomalies) :**
```json
{
  "name": "Résultat de vérification",
  "schedule": { "kind": "every", "everyMs": 3600000 },
  "payload": {
    "kind": "agentTurn",
    "message": "Lire status.json, overall=ok → NO_REPLY, sinon extraire anomalies et notifier."
  },
  "sessionTarget": "isolated"
}
```

### Contraintes techniques
- ✅ Bash pur + Python3 minimal (parsing JSON uniquement)
- ✅ Lecture seule
- ✅ < 5 secondes par exécution
- ✅ Pas de dépendances API externe
- ✅ Environnement Linux/WSL2

---

## 🇩🇪 Deutsch

### Warum

Wenn KI-Frameworks lange laufen, häufige Probleme: Speicherlecks导致 OOM-Crashes, Zombie-Prozesse, Endlosschleifen die Dateien schreiben, WebSocket-Verbindungslecks, Crash-Logs die unbemerkt anwachsen. Der traditionelle Ansatz mit manueller KI-Prüfung——**verschwendet Tokens, unmöglich Trends aufzubauen**.

### Architektur

```
System-Crontab (stündlich)        OpenClaw-Cron (versetzt)
      ↓                                ↓
healthcheck.sh --json            status.json lesen
      ↓                                ↓
  ├─ 19 Prüfungen ausführen         ├─ overall=ok → NO_REPLY (still)
  ├─ status.json schreiben          └─ overall≠ok → Benutzer benachrichtigen
  ├─ Zu trends.jsonl hinzufügen
  └─ Bei Anomalie → anomaly-Datei erstellen
```

### Prüfpunkte

| Ebene | Punkte | Beschreibung |
|-------|--------|--------------|
| L0 | Prozess/Speicher/Platte/OOM/Sub-Agent/Schleife | 6 Überlebensprüfungen |
| L1 | WebSocket/Port/Crash-Logs | 3 Runtime-Prüfungen |
| L2 | Speichertrend/Zombie/Env/Temp-Dateien/DNS/Platte | 6 Tiefenanalyse |
| L3 | Projekte/Tägliche Zusammenfassung/MEMORY.md/Offene Aufgaben | 4 Geschäfts-Compliance |

### Konfiguration

**OpenClaw cron (Anomalie-Benachrichtigung):**
```json
{
  "name": "Prüfergebnis",
  "schedule": { "kind": "every", "everyMs": 3600000 },
  "payload": {
    "kind": "agentTurn",
    "message": "status.json lesen, overall=ok → NO_REPLY, sonst anomalies extrahieren und benachrichtigen."
  },
  "sessionTarget": "isolated"
}
```

### Technische Einschränkungen
- ✅ Reines Bash + minimales Python3 (nur JSON-Parsing)
- ✅ Nur-Lesen
- ✅ < 5 Sekunden pro Lauf
- ✅ Keine externen API-Abhängigkeiten
- ✅ Linux/WSL2-Umgebung

---

## 🇷🇺 Русский

### Зачем

Когда AI-фреймворки работают длительное время, типичные проблемы: утечки памяти вызывающие OOM-краши, зомби-процессы, бесконечные циклы записи файлов, утечки WebSocket-соединений, логи крашей накапливаются незамеченными. Традиционный подход с ручной проверкой через AI——**тратит токены, невозможно накапливать тренды**.

### Архитектура

```
Системный crontab (каждый час)    OpenClaw cron (со сдвигом)
      ↓                                ↓
healthcheck.sh --json            Чтение status.json
      ↓                                ↓
  ├─ Запуск 19 проверок             ├─ overall=ok → NO_REPLY (тихо)
  ├─ Запись status.json             └─ overall≠ok → Уведомить пользователя
  ├─ Добавление в trends.jsonl
  └─ При аномалии → создать anomaly-файл
```

### Элементы проверки

| Уровень | Элементы | Описание |
|---------|----------|----------|
| L0 | Процесс/Память/Диск/OOM/Суб-агент/Цикл | 6 проверок выживания |
| L1 | WebSocket/Порт/Логи крашей | 3 проверки runtime |
| L2 | Тренд памяти/Зомби/Окружение/Врем.файлы/DNS/Диск | 6 глубокий анализ |
| L3 | Проекты/Ежедневный обзор/MEMORY.md/Ожидающие задачи | 4 бизнес-соответствие |

### Конфигурация

**OpenClaw cron (уведомление об аномалиях):**
```json
{
  "name": "Результат проверки",
  "schedule": { "kind": "every", "everyMs": 3600000 },
  "payload": {
    "kind": "agentTurn",
    "message": "Прочитать status.json, overall=ok → NO_REPLY, иначе извлечь anomalies и уведомить."
  },
  "sessionTarget": "isolated"
}
```

### Технические ограничения
- ✅ Чистый Bash + минимум Python3 (только парсинг JSON)
- ✅ Только чтение
- ✅ < 5 секунд за запуск
- ✅ Без внешних API-зависимостей
- ✅ Окружение Linux/WSL2

---

## License

MIT
