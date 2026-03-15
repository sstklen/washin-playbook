---
name: llm-model-version-migration-2026
description: |
  LLM API 常見錯誤修復：模型版本遷移與結構化輸出問題。
  使用時機：
  1. 遇到 "model: claude-3-5-sonnet-20241022" 404 錯誤（not_found_error）
  2. 從 Claude 3.x 遷移到 Claude 4.x 模型
  3. LLM 輸出正確結構但時間戳值錯誤（如 2024-01-01 而非當前日期）
  4. Schema 標註 "ISO 8601 format" 但 LLM 填入範例值而非實際時間
  5. Gemini/GPT/Claude 在 timestamp 欄位填入 placeholder 數據
  涵蓋 2026 年模型命名慣例、可用模型列表、遷移策略、結構化輸出指令模式。
author: Claude Code
version: 1.1.0
date: 2026-02-02
---

# Anthropic Claude Model Version Migration (2026)

## Problem

Anthropic Claude API returns 404 "model not found" errors when using model names from 2024-2025 that have been deprecated or retired.

## Context / Trigger Conditions

**Error Messages:**
```json
{
  "type": "error",
  "error": {
    "type": "not_found_error",
    "message": "model: claude-3-5-sonnet-20241022"
  }
}
```

**When This Occurs:**
- Using Anthropic Python SDK (`anthropic.Anthropic()`)
- Model parameter contains old version strings (e.g., `claude-3-5-sonnet-20241022`)
- Code written before 2025 using Claude 3.x models
- Environment variables or config files with hardcoded old model names

**Common Outdated Models (Retired):**
- `claude-3-5-sonnet-20241022` ❌ (deprecated)
- `claude-3-5-haiku-20241022` ❌ (deprecated)
- `claude-3-5-sonnet-20240620` ❌ (deprecated)
- `claude-3-opus-20240229` ❌ (retired June 30, 2025)
- `claude-3-sonnet-20240229` ❌ (retired July 21, 2025)

## Root Cause

Anthropic regularly updates and retires model versions:
- **Claude 3 Opus**: Deprecated June 30, 2025, retired January 5, 2026
- **Claude 3 Sonnet**: Fully retired July 21, 2025
- **Claude 3.5 series**: Superseded by Claude 4.x in late 2025

The model naming convention changed from date-based (`20241022`) to semantic versioning in Claude 4.x.

## Solution

### Step 1: Identify Current Models (2026)

**Claude 4.5 Series (Latest, Recommended):**

| Model | API ID (Exact) | Alias | Use Case | Pricing (per 1M tokens) |
|-------|----------------|-------|----------|------------------------|
| **Sonnet 4.5** | `claude-sonnet-4-5-20250929` | `claude-sonnet-4-5` | Balanced performance, coding, agents | $3 in / $15 out |
| **Haiku 4.5** | `claude-haiku-4-5-20251001` | `claude-haiku-4-5` | Fastest, cost-effective | $1 in / $5 out |
| **Opus 4.5** | `claude-opus-4-5-20251101` | `claude-opus-4-5` | Highest capability, complex reasoning | $5 in / $25 out |

**Important Notes:**
- ⚠️ **Haiku naming is different**: Uses `claude-haiku-4-5-YYYYMMDD` (not `claude-haiku-4-YYYYMMDD`)
- Aliases auto-update to latest snapshots (use specific versions in production)
- Snapshot dates ensure consistency across platforms

### Step 2: Update Model Configuration

**Option A: Update Code Directly**

```python
# ❌ Old (404 error)
client = anthropic.Anthropic(api_key=api_key)
response = client.messages.create(
    model="claude-3-5-sonnet-20241022",  # Deprecated!
    max_tokens=1024,
    messages=[{"role": "user", "content": "Hello"}]
)

# ✅ New (2026)
client = anthropic.Anthropic(api_key=api_key)
response = client.messages.create(
    model="claude-sonnet-4-5-20250929",  # Latest Sonnet
    max_tokens=1024,
    messages=[{"role": "user", "content": "Hello"}]
)
```

**Haiku-Specific Update:**

```javascript
// ❌ Old (404 error)
const CONFIG = {
  MODEL_FAST: 'claude-3-5-haiku-20241022',  // Deprecated!
};

// ✅ New (2026)
const CONFIG = {
  MODEL_FAST: 'claude-haiku-4-5-20251001',  // Latest Haiku
};
```

**Option B: Update Environment Variables**

```bash
# .env file
# ❌ Old
CLAUDE_MODEL=claude-3-5-sonnet-20241022
CLAUDE_MODEL_FAST=claude-3-5-haiku-20241022

# ✅ New
CLAUDE_MODEL=claude-sonnet-4-5-20250929
CLAUDE_MODEL_FAST=claude-haiku-4-5-20251001
```

**Option C: Update Config Files**

```python
# config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # ❌ Old
    # claude_model: str = "claude-3-5-sonnet-20241022"
    # claude_model_fast: str = "claude-3-5-haiku-20241022"

    # ✅ New
    claude_model: str = "claude-sonnet-4-5-20250929"
    claude_model_fast: str = "claude-haiku-4-5-20251001"
```

### Step 3: Test Model Availability

```python
import anthropic
import os

client = anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))

# Test multiple models to find available ones
models_to_try = [
    "claude-sonnet-4-5-20250929",  # Sonnet 4.5
    "claude-haiku-4-5-20251001",   # Haiku 4.5
    "claude-opus-4-5-20251101",    # Opus 4.5
]

for model in models_to_try:
    try:
        response = client.messages.create(
            model=model,
            max_tokens=10,
            messages=[{"role": "user", "content": "Hi"}]
        )
        print(f"✅ {model}: Available")
        print(f"   Response: {response.content[0].text}")
        break
    except Exception as e:
        if "not_found_error" in str(e):
            print(f"❌ {model}: Not found")
        else:
            print(f"❌ {model}: {e}")
```

## Verification

After updating:

```python
from anthropic import Anthropic

client = Anthropic(api_key="your-api-key")

response = client.messages.create(
    model="claude-sonnet-4-5-20250929",
    max_tokens=100,
    messages=[{"role": "user", "content": "Test message"}]
)

print(f"✅ Model: {response.model}")
print(f"✅ Response: {response.content[0].text}")
# Output should show successful response without 404 error
```

## Example: Complete Migration

**Before (Broken):**

```python
# api.py
from anthropic import Anthropic

client = Anthropic(api_key="sk-ant-...")

def chat(message: str):
    response = client.messages.create(
        model="claude-3-5-sonnet-20241022",  # ❌ 404 error
        max_tokens=2048,
        messages=[{"role": "user", "content": message}]
    )
    return response.content[0].text

# Error: model: claude-3-5-sonnet-20241022 not found
```

**After (Fixed):**

```python
# config.py
from pydantic_settings import BaseSettings
from pathlib import Path

class Settings(BaseSettings):
    anthropic_api_key: str
    claude_model: str = "claude-sonnet-4-5-20250929"  # ✅ Updated
    claude_model_fast: str = "claude-haiku-4-5-20251001"  # ✅ Fast model

    class Config:
        env_file = ".env"

settings = Settings()

# api.py
from anthropic import Anthropic
from config import settings

client = Anthropic(api_key=settings.anthropic_api_key)

def chat(message: str):
    response = client.messages.create(
        model=settings.claude_model,  # ✅ Uses config
        max_tokens=2048,
        messages=[{"role": "user", "content": message}]
    )
    return response.content[0].text

# .env
ANTHROPIC_API_KEY=sk-ant-...
CLAUDE_MODEL=claude-sonnet-4-5-20250929  # ✅ Centralized config
CLAUDE_MODEL_FAST=claude-haiku-4-5-20251001
```

## Notes

### ⚠️ Haiku Model Naming Convention

**Important:** Haiku 4.5 uses a **different naming pattern** than Sonnet/Opus:

```
Sonnet: claude-sonnet-4-5-YYYYMMDD   ✅
Opus:   claude-opus-4-5-YYYYMMDD     ✅
Haiku:  claude-haiku-4-5-YYYYMMDD    ✅ (NOT claude-haiku-4-YYYYMMDD)
```

**Common Mistake:**
```javascript
// ❌ Wrong (will cause 404)
MODEL_FAST: 'claude-haiku-4-20251001'

// ✅ Correct
MODEL_FAST: 'claude-haiku-4-5-20251001'
```

This inconsistency caught many developers during the Claude 4.5 migration. Always include the `-5` suffix for all Claude 4.5 models.

### Model Selection Guide (2026)

Choose based on your needs:

| Need | Recommended Model | Reason |
|------|------------------|--------|
| General API usage | `claude-sonnet-4-5-20250929` | Best balance of cost/performance |
| Coding, AI agents | `claude-sonnet-4-5-20250929` | Optimized for coding tasks |
| Complex reasoning | `claude-opus-4-5-20251101` | Highest capability |
| High volume, simple tasks | `claude-haiku-4-5-20251001` | Fastest & cheapest |

### Context Windows

- **Claude 4.5 Sonnet/Opus**: 1 million tokens (preview)
- **Claude 4.5 Haiku**: Standard context window

### Availability Platforms

Claude 4.x models are available via:
- Anthropic API (direct)
- AWS Bedrock
- Google Vertex AI

### Migration Checklist

- [ ] Update model name in code
- [ ] Update `.env` or environment variables
- [ ] Update config files (`config.py`, `settings.py`)
- [ ] Update hardcoded strings in multiple files
- [ ] Test API calls with new model
- [ ] Update documentation
- [ ] Restart services that cache config

### Common Mistakes

1. **Forgetting `.env` files**: Code updated but `.env` still has old model
2. **Multiple config locations**: Update one place, miss others
3. **Cached configs**: Service needs restart after config change
4. **Hardcoded strings**: Grep for old model names across codebase

```bash
# Find all occurrences of old model names
rg -i "claude-3-5-sonnet-20241022|claude-3-5-haiku-20241022|claude-3-opus" .

# Check .env files specifically
rg "CLAUDE_MODEL|claude.*model" .env*

# Find Haiku-specific issues (missing -5 suffix)
rg "claude-haiku-4-[0-9]" .  # Should be claude-haiku-4-5-YYYYMMDD
```

## References

- [Anthropic Models Overview](https://platform.claude.com/docs/en/about-claude/models/overview)
- [Claude API Reference - List Models](https://platform.claude.com/docs/en/api/models/list)
- [All Claude AI Models 2025](https://www.datastudios.org/post/all-claude-ai-models-available-in-2025-full-list-for-web-app-api-and-cloud-platforms)
- [Claude Opus 4.5 Announcement](https://www.anthropic.com/news/claude-opus-4-5)

## See Also

- `python-lazy-init-proxy-pattern` - Environment variable configuration patterns
- `fastapi-development-production-dual-mode` - FastAPI AI agent caching (uses Claude API)

## Merged Skills (archived)

The following skills have been merged into this guide:
- **llm-schema-timestamp-instruction** — LLM 生成 timestamp 使用範例值而非當前時間的修復方法
