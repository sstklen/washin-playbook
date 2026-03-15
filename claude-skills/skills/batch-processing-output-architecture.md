---
name: batch-processing-output-architecture
description: |
  批次處理系統的輸出檔案架構設計指南。三層策略：sidecar 檔案（個別 metadata）、
  master 資料庫（聚合數據）、operation ledger（稽核軌跡）。
  使用時機：
  1. 大量批次處理媒體檔案（影片標籤、圖片分析、文件處理）
  2. 需要同時查詢個別檔案結果和聚合分析報告
  3. 需要稽核合規（audit compliance）— 追蹤每筆操作紀錄
  4. 檔案在工作流中移動（input → processing → completed）
  5. 設計 Gemini/OpenAI Batch API 的輸出儲存架構
  觸發條件與症狀：
  - sidecar 檔案與主檔案分離（移動資料夾後 metadata 遺失）
  - 無法查詢「所有已處理的檔案」（缺少聚合層）
  - 重複處理同一檔案（缺少 deduplication 機制）
  - 操作紀錄遺失、無法追溯處理歷史
  工具：SQLite、JSON sidecar、CSV ledger、Python pathlib
author: Claude Code
version: 1.0.0
date: 2026-01-31
---

# Batch Processing Output Architecture

## Problem

Batch processing systems (video tagging, image analysis, document processing) need:
- Individual file metadata (for per-file queries)
- Aggregated analytics (for batch insights)
- Audit trails (for compliance/debugging)
- Files that move during workflow (input→processing→completed)

**Common failures:**
- Sidecar files get separated from main files
- Can't query "all processed files"
- No audit trail of operations
- Duplicate processing (no deduplication)

## Context / Trigger Conditions

Use this architecture when:
- Processing 100+ files in batches
- Files have rich metadata (10+ fields per file)
- Files move through workflow stages
- Need both individual lookups and batch analytics
- Require audit compliance (who processed what, when)
- Want to prevent duplicate processing

## Solution: Three-Tier Output Architecture

### Architecture Overview

```
File Processing System
├── Tier 1: Sidecar Files (individual metadata)
│   └── video.mp4 + video.gaia.json
├── Tier 2: Master Database (aggregated)
│   └── master_db.json (all files combined)
└── Tier 3: Operation Ledger (audit trail)
    └── operations.jsonl (append-only log)
```

### Tier 1: Sidecar Files

**Purpose:** Individual file metadata that stays with the file.

**Location:** Same folder as main file, same name + extension.

```
data/completed/
├── video1.mp4
├── video1.gaia.json    ← Sidecar (moves with video)
├── video2.mp4
└── video2.gaia.json    ← Sidecar (moves with video)
```

**Structure:**
```json
{
  "file_path": "video1.mp4",
  "sha256": "abc123...",
  "processed_at": "2026-01-31T10:30:00Z",
  "metadata": {
    "duration": 15.5,
    "resolution": "1920x1080",
    "tags": ["outdoor", "sunny"]
  }
}
```

**Benefits:**
- ✅ Self-contained (zip file with both)
- ✅ Easy individual lookup
- ✅ Survives folder moves

**Implementation:**
```python
def save_sidecar(file_path: Path, metadata: dict):
    """Save sidecar JSON next to main file"""
    sidecar_path = file_path.with_suffix('.gaia.json')
    with open(sidecar_path, 'w', encoding='utf-8') as f:
        json.dump(metadata, f, indent=2, ensure_ascii=False)

def move_with_sidecar(file_path: Path, dest_dir: Path):
    """Move file and its sidecar together"""
    dest = dest_dir / file_path.name

    # Move main file
    shutil.move(str(file_path), str(dest))

    # Move sidecar (if exists)
    sidecar = file_path.with_suffix('.gaia.json')
    if sidecar.exists():
        sidecar_dest = dest.with_suffix('.gaia.json')
        shutil.move(str(sidecar), str(sidecar_dest))
```

### Tier 2: Master Database

**Purpose:** Aggregated view of all processed files for analytics.

**Location:** Fixed location (`results/master_db.json`).

**Structure:**
```json
{
  "metadata": {
    "total_files": 1245,
    "last_updated": "2026-01-31T18:45:00Z",
    "version": "v4.2"
  },
  "assets": {
    "sha256_abc123": {
      "file_name": "video1.mp4",
      "processed_at": "2026-01-31T10:30:00Z",
      "tags": ["outdoor", "sunny"]
    },
    "sha256_def456": {
      "file_name": "video2.mp4",
      "processed_at": "2026-01-31T11:15:00Z",
      "tags": ["indoor", "evening"]
    }
  }
}
```

**Benefits:**
- ✅ Fast batch queries ("all outdoor videos")
- ✅ Deduplication (by SHA256 hash)
- ✅ Analytics dashboard data source

**Implementation:**
```python
def update_master_db(file_hash: str, metadata: dict):
    """Update master database with new file"""
    db_path = Path("results/master_db.json")

    # Load existing
    if db_path.exists():
        with open(db_path, 'r') as f:
            db = json.load(f)
    else:
        db = {"metadata": {}, "assets": {}}

    # Update
    db["assets"][file_hash] = metadata
    db["metadata"]["total_files"] = len(db["assets"])
    db["metadata"]["last_updated"] = datetime.now().isoformat()

    # Save
    with open(db_path, 'w', encoding='utf-8') as f:
        json.dump(db, f, indent=2, ensure_ascii=False)
```

### Tier 3: Operation Ledger

**Purpose:** Append-only audit trail of all operations.

**Location:** Fixed location (`results/operations.jsonl`).

**Format:** JSONL (one JSON object per line, append-only).

```jsonl
{"ts":"2026-01-31T10:30:00Z","op":"process","file":"video1.mp4","status":"success","cost":0.0042}
{"ts":"2026-01-31T10:31:15Z","op":"process","file":"video2.mp4","status":"success","cost":0.0042}
{"ts":"2026-01-31T10:32:00Z","op":"process","file":"broken.mp4","status":"error","error":"corrupt"}
```

**Benefits:**
- ✅ Complete audit trail
- ✅ Debugging failed operations
- ✅ Cost tracking
- ✅ Performance analytics

**Implementation:**
```python
def log_operation(operation: str, file_name: str, status: str, **extra):
    """Append operation to ledger"""
    ledger_path = Path("results/operations.jsonl")

    entry = {
        "ts": datetime.now().isoformat(),
        "op": operation,
        "file": file_name,
        "status": status,
        **extra
    }

    # Append (create if not exists)
    with open(ledger_path, 'a', encoding='utf-8') as f:
        f.write(json.dumps(entry, ensure_ascii=False) + '\n')
```

## Complete Workflow Example

```python
def process_file(file_path: Path):
    """Process file with three-tier output"""

    # 1. Calculate hash (for deduplication)
    file_hash = calculate_sha256(file_path)

    # 2. Check if already processed (master DB)
    if is_already_processed(file_hash):
        log_operation("skip", file_path.name, "duplicate", hash=file_hash)
        return

    # 3. Process file
    try:
        metadata = analyze_file(file_path)

        # 4. Save Tier 1: Sidecar
        save_sidecar(file_path, metadata)

        # 5. Update Tier 2: Master DB
        update_master_db(file_hash, metadata)

        # 6. Log Tier 3: Ledger
        log_operation("process", file_path.name, "success",
                     hash=file_hash, cost=0.0042)

        # 7. Move to completed (with sidecar)
        move_with_sidecar(file_path, Path("data/completed"))

    except Exception as e:
        log_operation("process", file_path.name, "error",
                     error=str(e))
        raise
```

## File Movement Pattern

**Problem:** Files move through workflow, sidecars must follow.

```
Workflow Stages:
00_input/          ← User drops files
   ↓
01_processing/     ← Being processed
   ↓
02_completed/      ← Success (file + sidecar moved together)
   ↓
03_failed/         ← Failed (file + sidecar moved together)
```

**Critical:** Always move sidecar with main file!

```python
def move_to_stage(file_path: Path, stage: str):
    """Move file through workflow stages"""
    stage_map = {
        "processing": Path("data/01_processing"),
        "completed": Path("data/02_completed"),
        "failed": Path("data/03_failed")
    }

    dest_dir = stage_map[stage]
    dest_dir.mkdir(parents=True, exist_ok=True)

    # Preserve folder structure
    rel_path = file_path.relative_to(Path("data/01_processing"))
    dest = dest_dir / rel_path
    dest.parent.mkdir(parents=True, exist_ok=True)

    # Move main file
    shutil.move(str(file_path), str(dest))

    # Move sidecar (if exists)
    for ext in ['.json', '.gaia.json', '.meta.json']:
        sidecar = file_path.with_suffix(ext)
        if sidecar.exists():
            sidecar_dest = dest.with_suffix(ext)
            shutil.move(str(sidecar), str(sidecar_dest))
```

## Query Patterns

### Query Individual File

```python
# Option 1: Read sidecar directly
def get_file_metadata(file_path: Path) -> dict:
    sidecar = file_path.with_suffix('.gaia.json')
    with open(sidecar, 'r') as f:
        return json.load(f)

# Use when: Viewing single file details
```

### Query All Files

```python
# Option 2: Read master database
def get_all_metadata() -> dict:
    with open("results/master_db.json", 'r') as f:
        return json.load(f)

# Use when: Analytics dashboard, batch queries
```

### Query Operation History

```python
# Option 3: Read ledger (JSONL)
def get_operation_log(file_name: str = None) -> list:
    logs = []
    with open("results/operations.jsonl", 'r') as f:
        for line in f:
            entry = json.loads(line)
            if file_name is None or entry['file'] == file_name:
                logs.append(entry)
    return logs

# Use when: Debugging, audit, cost tracking
```

## Deduplication Strategy

**Use SHA256 hash of file content (not filename).**

```python
import hashlib

def calculate_sha256(file_path: Path) -> str:
    """Calculate file hash for deduplication"""
    sha256 = hashlib.sha256()
    with open(file_path, 'rb') as f:
        for chunk in iter(lambda: f.read(8192), b''):
            sha256.update(chunk)
    return sha256.hexdigest()

def is_already_processed(file_hash: str) -> bool:
    """Check if file already in master DB"""
    db_path = Path("results/master_db.json")
    if not db_path.exists():
        return False

    with open(db_path, 'r') as f:
        db = json.load(f)

    return file_hash in db.get("assets", {})
```

## Verification Checklist

- [ ] Sidecar files move with main files (test file movement)
- [ ] Master DB updates after each process
- [ ] Ledger appends (never overwrites)
- [ ] Deduplication works (hash-based)
- [ ] Can query individual file (sidecar)
- [ ] Can query all files (master DB)
- [ ] Can audit operations (ledger)
- [ ] Failed files still have sidecars

## Real-World Example: GAIA System

**Use case:** 24/7 video processing system (1000+ videos/day).

**Output structure:**
```
data/
├── 02_completed/
│   ├── jelly_01.mp4
│   ├── jelly_01.gaia.json       ← Tier 1: Sidecar
│   ├── gold_02.mp4
│   └── gold_02.gaia.json
├── results/
│   ├── gaia_db_v4_2.json        ← Tier 2: Master DB
│   └── gaia_ledger_v4_2.jsonl   ← Tier 3: Ledger
```

**Query examples:**

```python
# Individual: What tags does jelly_01.mp4 have?
metadata = json.load(open("data/02_completed/jelly_01.gaia.json"))
print(metadata["tags"])

# Batch: How many videos processed today?
db = json.load(open("results/gaia_db_v4_2.json"))
today_count = sum(1 for asset in db["assets"].values()
                  if asset["processed_at"].startswith("2026-01-31"))

# Audit: How much did we spend this month?
total_cost = 0
with open("results/gaia_ledger_v4_2.jsonl") as f:
    for line in f:
        entry = json.loads(line)
        if entry["ts"].startswith("2026-01") and "cost" in entry:
            total_cost += entry["cost"]
```

## Notes

- Sidecar extension should be distinctive (`.meta.json`, `.gaia.json`)
- Master DB should be compact (don't duplicate all sidecar data)
- Ledger is append-only (never delete, can rotate by date)
- Use UTF-8 encoding for all JSON files
- Consider `.gitignore` for master DB and ledger (too large)
- Backup strategy: Sidecars follow files, DB/ledger backed up separately

## References

- [JSONL format specification](http://jsonlines.org/)
- [Python shutil for file operations](https://docs.python.org/3/library/shutil.html)
- [SHA256 for file hashing](https://docs.python.org/3/library/hashlib.html)

---

*Created from real architecture: GAIA 24-hour video processing system (2026-01-31)*
