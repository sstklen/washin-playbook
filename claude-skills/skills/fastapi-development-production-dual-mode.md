---
name: fastapi-development-production-dual-mode
description: |
  FastAPI 開發/生產雙模式架構 + Agent 快取 + Next.js 整合檢查清單。
  使用時機：(1) 需要在真實數據就緒前測試 API，(2) 開發模式用靜態資料、生產模式用即時計算，
  (3) 需要快取 AI agents/models 避免重複載入，(4) 檢查 Next.js 前端整合（動態路由硬編碼、
  API Key 缺失、"403 Forbidden"、"429 Too Many Requests"、"params is a Promise"），
  (5) Python 3.9 type hints 錯誤、Pydantic Settings "Extra inputs not permitted"。
author: Claude Code
version: 2.0.0
date: 2026-02-10
---

# FastAPI Development/Production Dual-Mode Architecture

## Problem

When building data-intensive APIs (analytics, ML inference, real-time calculations), you often face a chicken-and-egg problem:

- **Need to test the API** before real data pipeline is ready
- **Frontend integration testing** requires working endpoints
- **Production mode** should compute from real data sources (GAIA tags, live metrics, etc.)
- **Development mode** should use static test data from database

Without dual-mode support, you're forced to either:
- Block frontend work until data pipeline is ready ❌
- Build temporary mock endpoints that diverge from production code ❌
- Manually comment/uncomment code when switching environments ❌

## Context / Trigger Conditions

Use this pattern when:
- ✅ Building analytics/dashboard APIs that aggregate from large datasets
- ✅ Frontend team needs working APIs before data pipeline is complete
- ✅ Want to run integration tests with predictable test data
- ✅ Production needs real-time calculation but development needs fast iteration

**Specific scenario**: Digital Twin API
- Production: Calculate completeness from 294 video tags (5+ seconds)
- Development: Load from pre-computed database row (<50ms)

## Solution

### Architecture Overview

```
┌─────────────────────────────────────────────────┐
│  FastAPI Endpoint                               │
│  └─> Service.calculate(pet_id)                  │
│       │                                          │
│       ├─> [DEV MODE] Load from database ✅       │
│       │   └─> Fast, predictable, repeatable     │
│       │                                          │
│       └─> [PROD MODE] Calculate from GAIA ✅    │
│           └─> Real-time, accurate               │
└─────────────────────────────────────────────────┘
```

### Step 1: Add Mode Configuration

**config.py** (Pydantic Settings):
```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    # ... existing fields ...

    # 🔄 Dual-mode configuration
    digital_twin_mode: str = "development"  # development | production

    class Config:
        env_file = ".env"
```

**.env**:
```bash
# Development mode: use database test data
DIGITAL_TWIN_MODE=development

# Production mode: calculate from real data
# DIGITAL_TWIN_MODE=production
```

### Step 2: Implement Service Layer with Mode Switching

**services/my_service.py**:
```python
from sqlalchemy.orm import Session
from typing import Dict, Any, Optional  # ⚠️ Use Optional, not | for Python 3.9
from loguru import logger
import os

class MyService:
    def __init__(self, db: Session):
        self.db = db
        self.mode = os.getenv("DIGITAL_TWIN_MODE", "development")

    def calculate(self, entity_id: str) -> Dict[str, Any]:
        """
        Calculate result with dual-mode support
        """
        try:
            # 🔄 Development mode: prioritize database
            if self.mode == "development":
                db_data = self._load_from_database(entity_id)
                if db_data:
                    logger.info(f"[DEV MODE] Loaded {entity_id} from database")
                    return db_data
                logger.info(f"[DEV MODE] No database data, falling back to calculation")

            # 🎯 Production mode: calculate from real data source
            result = self._calculate_from_source(entity_id)

            if not result:
                return {"error": "No data available"}

            return result

        except Exception as e:
            logger.error(f"Calculation failed: {e}")
            return {"error": str(e)}

    def _load_from_database(self, entity_id: str) -> Optional[Dict[str, Any]]:
        """
        Load pre-computed test data from database (development mode)

        ⚠️ Python 3.9: Use Optional[Dict[str, Any]], NOT Dict[str, Any] | None
        """
        try:
            record = self.db.query(MyModel).filter_by(id=entity_id).first()

            if not record:
                return None

            # Convert to API response format
            return {
                "id": record.id,
                "value": float(record.value),
                "metadata": {...}
            }

        except Exception as e:
            logger.error(f"Database load failed: {e}")
            return None

    def _calculate_from_source(self, entity_id: str) -> Dict[str, Any]:
        """
        Calculate from real data source (production mode)
        """
        # Your actual calculation logic
        ...
```

### Step 3: Database Setup (Development Mode)

**Insert test data** for development:
```sql
-- Insert predictable test data
INSERT INTO my_model (id, value, created_at)
VALUES ('test-entity', 73.5, NOW());
```

### Step 4: Verify Mode Switching

```bash
# Test development mode
DIGITAL_TWIN_MODE=development uvicorn api:app --reload

# Test production mode
DIGITAL_TWIN_MODE=production uvicorn api:app --reload
```

## Common Pitfalls & Solutions

### Pitfall 1: Python 3.9 Type Hint Syntax Error

**Error**:
```
TypeError: unsupported operand type(s) for |: '_GenericAlias' and 'NoneType'
```

**Cause**: Python 3.9 doesn't support `Type | None` syntax (added in 3.10)

**Solution**:
```python
# ❌ Python 3.9 FAILS
def method(self) -> Dict[str, Any] | None:
    ...

# ✅ Python 3.9 WORKS
from typing import Optional

def method(self) -> Optional[Dict[str, Any]]:
    ...
```

### Pitfall 2: Pydantic Settings "Extra inputs not permitted"

**Error**:
```
pydantic_core._pydantic_core.ValidationError: 1 validation error for Settings
my_new_field
  Extra inputs are not permitted [type=extra_forbidden, input_value='...', input_type=str]
```

**Cause**: Adding new field to `.env` but not declaring it in `Settings` class

**Solution**:
```python
# Step 1: Declare in Settings class FIRST
class Settings(BaseSettings):
    my_new_field: str = "default_value"  # ✅ Declare first

    class Config:
        env_file = ".env"

# Step 2: Then add to .env
# MY_NEW_FIELD=actual_value
```

**Alternative** (if you want flexible fields):
```python
class Settings(BaseSettings):
    class Config:
        env_file = ".env"
        extra = "allow"  # Allow extra fields (not recommended for production)
```

### Pitfall 3: Wrong Database Connection

**Symptom**: Database query returns None even though data exists

**Cause**: `DATABASE_URL` points to wrong database

**Solution**:
```python
# Check current DATABASE_URL
import os
print(os.getenv("DATABASE_URL"))

# Fix in database.py (default value)
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://user@localhost/correct_db"  # ✅ Correct database
)
```

## Verification

### Test Development Mode
```bash
# 1. Set mode
export DIGITAL_TWIN_MODE=development

# 2. Start server
uvicorn api:app --reload

# 3. Test endpoint (should be fast, < 100ms)
curl http://localhost:8000/api/v1/my-endpoint/test-entity

# 4. Check logs for "[DEV MODE]" message
tail -f app.log | grep "DEV MODE"
```

### Test Production Mode
```bash
# 1. Set mode
export DIGITAL_TWIN_MODE=production

# 2. Start server
uvicorn api:app --reload

# 3. Test endpoint (may be slower, actual calculation)
curl http://localhost:8000/api/v1/my-endpoint/test-entity

# 4. Verify no "[DEV MODE]" in logs
```

## Example: Complete Implementation

**Directory structure**:
```
my_agent_sdk/
├── .env                          # DIGITAL_TWIN_MODE=development
├── config.py                     # Settings with dual_mode field
├── database.py                   # SQLAlchemy setup
├── models/
│   └── my_model.py              # Database model
├── services/
│   └── my_service.py            # Service with dual-mode logic
└── routes/
    └── my_routes.py             # FastAPI endpoints
```

**Full service example** (services/digital_twin_completeness.py):
```python
from sqlalchemy.orm import Session
from typing import Dict, Any, Optional
from loguru import logger
import os

from models.digital_twin import DigitalTwinStatus

class DigitalTwinCompleteness:
    WEIGHTS = {
        "basic_behaviors": 0.20,
        "emotions": 0.25,
        "interactions": 0.20,
        "special_behaviors": 0.20,
        "environmental": 0.15
    }

    def __init__(self, db: Session):
        self.db = db
        self.mode = os.getenv("DIGITAL_TWIN_MODE", "development")

    def calculate(self, pet_id: str) -> Dict[str, Any]:
        try:
            # 🔄 Development mode: database first
            if self.mode == "development":
                db_data = self._load_from_database(pet_id)
                if db_data:
                    logger.info(f"[DEV MODE] Loaded {pet_id} from database")
                    return db_data
                logger.info(f"[DEV MODE] No data, switching to GAIA calculation")

            # 🎯 Production mode: calculate from GAIA tags
            distribution = self.statistics.get_tag_distribution(pet_id)

            if distribution.get("total_videos", 0) == 0:
                return {
                    "pet_id": pet_id,
                    "overall": 0.0,
                    "error": "No video data available"
                }

            # Actual calculation logic...
            overall = self._calculate_overall_score(distribution)

            return {
                "pet_id": pet_id,
                "overall": round(overall, 2),
                "categories": {...}
            }

        except Exception as e:
            logger.error(f"Calculation failed: {e}")
            return {"pet_id": pet_id, "overall": 0.0, "error": str(e)}

    def _load_from_database(self, pet_id: str) -> Optional[Dict[str, Any]]:
        """Load test data from database (dev mode)"""
        try:
            status = self.db.query(DigitalTwinStatus).filter_by(pet_id=pet_id).first()

            if not status:
                return None

            return {
                "pet_id": status.pet_id,
                "overall": float(status.overall_completeness),
                "total_videos": 294,  # Mock value
                "categories": {
                    "basic_behaviors": {
                        "score": float(status.basic_behaviors_score or 0),
                        "weight": self.WEIGHTS["basic_behaviors"],
                        "details": {}
                    },
                    # ... other categories
                }
            }

        except Exception as e:
            logger.error(f"Database load failed: {e}")
            return None
```

## Notes

### When to Use This Pattern

**✅ Good use cases**:
- Analytics/dashboard APIs with complex calculations
- ML inference endpoints (dev: cached results, prod: live inference)
- Real-time aggregation APIs (dev: sample data, prod: full scan)
- Report generation (dev: static PDFs, prod: dynamic generation)

**❌ Not recommended for**:
- Simple CRUD APIs (just use database directly)
- APIs where dev/prod logic differs significantly (consider separate endpoints)
- Stateless APIs without heavy computation

### Performance Considerations

| Mode | Speed | Data | Use Case |
|------|-------|------|----------|
| Development | <50ms | Static, predictable | Frontend integration testing |
| Production | Variable | Real-time, accurate | Actual user requests |

### Testing Strategy

```python
# Unit test: Mock mode switching
def test_development_mode(db_session):
    os.environ["DIGITAL_TWIN_MODE"] = "development"
    service = MyService(db_session)
    result = service.calculate("test-entity")
    assert result["from_database"] == True

def test_production_mode(db_session):
    os.environ["DIGITAL_TWIN_MODE"] = "production"
    service = MyService(db_session)
    result = service.calculate("test-entity")
    assert result["calculated"] == True
```

### Migration Path

**Phase 1**: Development only
```python
# Always load from database
return self._load_from_database(entity_id)
```

**Phase 2**: Add production mode (this pattern)
```python
# Conditional logic based on mode
if self.mode == "development":
    return self._load_from_database(entity_id)
return self._calculate_from_source(entity_id)
```

**Phase 3**: Production-only (data pipeline ready)
```python
# Remove development mode, always calculate
return self._calculate_from_source(entity_id)
```

## References

- [Pydantic Settings Documentation](https://docs.pydantic.dev/latest/concepts/pydantic_settings/)
- [FastAPI Configuration](https://fastapi.tiangolo.com/advanced/settings/)
- [Python 3.10 Type Union Operator](https://docs.python.org/3/library/stdtypes.html#types-union)
- [SQLAlchemy Session Management](https://docs.sqlalchemy.org/en/20/orm/session_basics.html)

## Merged Skills (archived)

The following skills have been merged into this guide:
- **fastapi-agent-caching-pattern** — In-memory caching for AI agents/models to avoid repeated loading
- **fastapi-nextjs-agent-integration-checklist** — 前後端整合檢查清單（動態路由硬編碼、API Key、Rate Limiting、XSS）
