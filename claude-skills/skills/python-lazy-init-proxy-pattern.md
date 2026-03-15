---
name: python-lazy-init-proxy-pattern
description: |
  Python 開發模式集合：懶初始化 Proxy、部署打包、Pydantic Settings 列表解析。
  使用時機：
  1. `from module import var` 綁定到 None — AttributeError: 'NoneType' object has no attribute 'xxx'
  2. 部署打包 — 建立包含大型模型檔案的可攜式部署包（sidecar files、Unicode 檔名、缺失模型）
  3. Pydantic Settings 列表解析 — "SettingsError: error parsing value for field"、"JSONDecodeError: Expecting value"
  4. CORS 400 "Disallowed CORS origin" — 環境變數需用 JSON 格式 + 跨版本 field_validator
  適用於 FastAPI/Telegram Bot、AI/ML 系統部署、環境變數配置。
author: Washin Village + Claude Code
version: 2.0.0
date: 2026-02-10
---

# Python 懶初始化 Proxy 模式

## Problem

Python 的 `from module import var` 語法會在 import 時建立一個**名字綁定的副本**。
如果 `var` 在 import 時是 `None`，後來在其他地方被重新賦值，handler 裡拿到的仍然是 `None`。

這是 Python 初學者到中級開發者最常踩的坑之一，特別在 FastAPI / Telegram Bot / 任何
需要「啟動後才初始化服務」的框架中。

## Context / Trigger Conditions

**錯誤訊息：**
```
AttributeError: 'NoneType' object has no attribute 'send_text'
AttributeError: 'NoneType' object has no attribute 'list_tickets'
```

**出現場景：**
- FastAPI app 在 `lifespan` 中初始化服務（如 DB client、Bot instance）
- Handler 用 `from services.xxx import xxx_service` 引用
- import 發生在模組載入時（`None`），init 發生在 runtime（新物件）
- Handler 的本地綁定永遠指向 `None`

**典型錯誤代碼：**
```python
# services/telegram_service.py
telegram_service: Optional[TelegramService] = None  # import 時 = None

def init_telegram_service(bot):
    global telegram_service
    telegram_service = TelegramService(bot)  # runtime 時改了全域變數
    return telegram_service

# handlers/command_handler.py
from services.telegram_service import telegram_service  # ← 綁定到 None！

async def handle_start(update, context):
    await telegram_service.send_text(...)  # ← AttributeError: NoneType!
```

**為什麼 `global` 也沒用？**
```python
# handler 檔案中的 telegram_service 是 import 時複製的名字綁定
# 即使 services 模組中的 telegram_service 已經被 global 改了
# handler 檔案的綁定仍然指向最初的 None
```

## Solution

### Proxy 模式（推薦）

用一個永遠不變的 proxy 物件取代原始全域變數。
所有消費者 import 的都是 proxy，proxy 內部委派到真實實例。

```python
# services/telegram_service.py
from typing import Optional


class TelegramService:
    """實際的服務類別"""
    def __init__(self, bot):
        self._bot = bot

    async def send_text(self, chat_id, text):
        await self._bot.send_message(chat_id=chat_id, text=text)


class _TelegramServiceProxy:
    """代理模式：讓 import 綁定穩定，init 後自動委派"""

    def __init__(self):
        self._instance: Optional[TelegramService] = None

    def __getattr__(self, name):
        if self._instance is None:
            raise RuntimeError(
                "TelegramService 尚未初始化，請先呼叫 init_telegram_service()"
            )
        return getattr(self._instance, name)


# 全域 proxy — 這個物件的身份永遠不變
telegram_service = _TelegramServiceProxy()


def init_telegram_service(bot) -> TelegramService:
    """初始化全域服務（在 app lifespan 中呼叫）"""
    real = TelegramService(bot=bot)
    telegram_service._instance = real  # 改 proxy 內部，不改 proxy 身份
    return real
```

### 為什麼這招有效？

```python
# handlers/command_handler.py
from services.telegram_service import telegram_service
# ↑ import 綁定到 _TelegramServiceProxy 物件（永遠不變）

# 當 init_telegram_service() 被呼叫後：
# telegram_service._instance = 真實的 TelegramService

# 當 handler 呼叫 telegram_service.send_text() 時：
# 1. Python 找 _TelegramServiceProxy 有沒有 send_text → 沒有
# 2. 觸發 __getattr__("send_text")
# 3. __getattr__ 從 _instance 取得真實的 send_text
# 4. 成功！
```

**核心原理：**
- `from module import var` 綁定到**物件本身**，不是變數名
- 只要物件身份不變（不做 `var = new_object`），綁定就不會斷
- Proxy 的身份永遠不變，只有 `._instance` 內部狀態改變

### 通用 Proxy 模板

如果你有多個服務需要同樣模式，可以抽象成通用模板：

```python
from typing import TypeVar, Generic, Optional

T = TypeVar("T")

class LazyProxy(Generic[T]):
    """通用懶初始化 Proxy"""

    def __init__(self, service_name: str = "Service"):
        self._instance: Optional[T] = None
        self._service_name = service_name

    def __getattr__(self, name: str):
        if self._instance is None:
            raise RuntimeError(
                f"{self._service_name} 尚未初始化"
            )
        return getattr(self._instance, name)

    def _set_instance(self, instance: T) -> None:
        self._instance = instance


# 使用範例
telegram_service: LazyProxy[TelegramService] = LazyProxy("TelegramService")
api_client: LazyProxy[CoreAPIClient] = LazyProxy("CoreAPIClient")

def init_telegram_service(bot):
    real = TelegramService(bot=bot)
    telegram_service._set_instance(real)
    return real
```

## Verification

```python
# 測試 1：init 前存取 → 拋 RuntimeError
try:
    telegram_service.send_text(123, "test")
except RuntimeError as e:
    assert "尚未初始化" in str(e)
    print("✅ init 前正確拋異常")

# 測試 2：init 後存取 → 正常工作
init_telegram_service(mock_bot)
result = await telegram_service.send_text(123, "Hello")
print("✅ init 後正常委派")

# 測試 3：在不同模組 import 後仍然有效
# handlers/command_handler.py
from services.telegram_service import telegram_service
# → 這裡的 telegram_service 是同一個 proxy 物件
# → init 後自動取得真實實例
```

## Example: ExampleApp OP Bot

在 OP Telegram Bot 中，兩個服務都用了這個模式：

```python
# services/api_client.py
api_client = _APIClientProxy()

# services/telegram_service.py
telegram_service = _TelegramServiceProxy()

# main.py — lifespan
async def lifespan(app):
    init_api_client(base_url=settings.CORE_API_URL, api_key=settings.CORE_API_KEY)
    init_telegram_service(bot=application.bot)
    yield
    await api_client.close()

# handlers/command_handler.py — 安全使用
from services.api_client import api_client
from services.telegram_service import telegram_service

async def handle_tickets(update, context):
    result = await api_client.list_tickets()    # ← 自動委派到真實 client
    text = format_ticket_list(result)
    await telegram_service.send_text(chat_id, text)  # ← 自動委派到真實 service
```

## Notes

### 其他替代方案（不推薦）

| 方法 | 缺點 |
|------|------|
| `import module; module.var` | 每次存取都要寫完整路徑，不 Pythonic |
| 全域 dict/container | 需要改所有消費者代碼 |
| FastAPI Depends | 只適用於 route handler，不適用於 callback/message handler |
| `global` 關鍵字 | 解決不了 `from x import y` 的綁定問題 |

### 何時用 Proxy vs 何時不需要

| 場景 | 是否需要 Proxy |
|------|---------------|
| 服務在 startup 初始化 + 多模組 import | ✅ 需要 |
| 服務在模組頂層直接建構 | ❌ 不需要 |
| 只有一個檔案使用 | ❌ 不需要，直接用 `import module` |
| FastAPI route 用 Depends 注入 | ❌ 不需要 |

### 注意事項

- `__getattr__` 只在「屬性不存在」時觸發，不影響 proxy 自身的屬性（如 `_instance`）
- 如果需要 `isinstance` 檢查，Proxy 不會通過（它不是真實類別的實例）
- 如果需要 `await proxy_method()`，確保真實方法是 async 的，proxy 自動傳遞
- Type hint 會顯示 proxy 類型而非真實類型，IDE 自動補全可能不完整

## See Also

- `railway-fastapi-deployment` — 這個 bug 常在部署到 Railway 後才發現
- `service-channel-replication-pattern` — 新增管道時需要多個全域服務
- `fastapi-development-production-dual-mode` — FastAPI 中的狀態管理模式

---

## Merged Skills (archived)

The following skills have been merged into this guide:
- **python-deployment-package-creation** — 建立包含大型模型檔案的可攜式 Python 部署包（處理 sidecar files、Unicode 檔名、模型檔案路徑）
- **pydantic-settings-env-list-parsing** — 修復 Pydantic Settings 的 JSON 解析錯誤、CORS 400 錯誤（環境變數需用 JSON 格式 + field_validator）
