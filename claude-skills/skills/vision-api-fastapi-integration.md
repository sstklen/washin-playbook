---
name: vision-api-fastapi-integration
description: |
  將 Claude Vision API 整合到 FastAPI 應用程式，實現多模態分析（文字+圖片）。
  採用模組化 engine pattern，搭配 feature flags 控制功能開關。
  使用時機：
  1. 需要在現有 FastAPI AI agent / chatbot 加入圖片理解功能
  2. 需要多模態能力（同時處理文字和圖片輸入）
  3. 想維持一致的模組化架構（feature flags、caching）
  4. 需要控制成本（Vision $0.0087/req vs 純文字 $0.0039/req）
  5. 需要處理用戶上傳圖片（multipart/form-data）
  觸發信號：用戶要求「看圖片」「分析截圖」「圖片辨識」、
  FastAPI 專案需要加入 image endpoint。
  技術涵蓋：Claude Vision API、FastAPI file upload、
  base64 image encoding、modular engine pattern、
  feature flags、cost analysis、retry 錯誤處理。
author: Claude Code
version: 1.0.0
date: 2026-02-01
---

# Claude Vision API Integration for FastAPI

## Problem

Adding vision capabilities to existing FastAPI AI agents requires:
1. Proper file upload handling (multipart/form-data)
2. Image encoding (base64) for Claude API
3. Maintaining modular architecture (feature flags, caching)
4. Cost-aware implementation (Vision is 2.2x more expensive than text)

## Context / Trigger Conditions

**Use this pattern when:**
- Existing FastAPI app with AI agents (using in-memory caching)
- Want to add "image understanding" without breaking existing features
- Need to control costs (Vision API charges per image token)
- Following modular engine pattern with feature flags

**Symptoms you need this:**
- User asks: "Can the AI see images?"
- Want to add photo upload to chatbot
- Need multimodal capabilities (text + image)

## Solution

### Step 1: Create Vision Engine Module

```python
# vision_engine.py
import base64
from pathlib import Path
from typing import Dict, Any, Optional
from datetime import datetime
import anthropic
from config import settings


class VisionEngine:
    """Vision understanding engine - based on Claude 3.5 Sonnet Vision"""

    def __init__(self, pet_id: str, persona: Dict[str, Any]):
        self.pet_id = pet_id
        self.persona = persona
        self.client = anthropic.Anthropic(api_key=settings.anthropic_api_key)

    def analyze_image(
        self,
        image_path: str,
        user_question: Optional[str] = None,
        user_id: str = "anonymous"
    ) -> Dict[str, Any]:
        """Analyze image and generate personalized response"""

        # 1. Encode image to base64
        image_data = self._encode_image(image_path)

        # 2. Build prompts (combine with persona)
        system_prompt = self._build_system_prompt()
        user_prompt = self._build_user_prompt(user_question)

        # 3. Call Claude Vision API with retry logic
        max_retries = 3
        for attempt in range(max_retries):
            try:
                response = self.client.messages.create(
                    model=settings.claude_model,
                    max_tokens=settings.max_tokens,
                    temperature=settings.temperature,
                    system=system_prompt,
                    messages=[
                        {
                            "role": "user",
                            "content": [
                                {
                                    "type": "image",
                                    "source": {
                                        "type": "base64",
                                        "media_type": self._get_media_type(image_path),
                                        "data": image_data,
                                    },
                                },
                                {
                                    "type": "text",
                                    "text": user_prompt
                                }
                            ]
                        }
                    ]
                )

                reply = response.content[0].text

                return {
                    "pet_id": self.pet_id,
                    "user_id": user_id,
                    "analysis": reply,
                    "reply": reply,
                    "confidence": self._estimate_confidence(reply),
                    "timestamp": datetime.now().isoformat(),
                    "model": settings.claude_model,
                }

            except Exception as e:
                if attempt < max_retries - 1:
                    import time
                    wait_time = 2 ** attempt  # Exponential backoff
                    print(f"⚠️ Vision API error (attempt {attempt + 1}/{max_retries}): {e}")
                    time.sleep(wait_time)
                else:
                    return {
                        "pet_id": self.pet_id,
                        "user_id": user_id,
                        "analysis": None,
                        "reply": f"Sorry, I can't see this image clearly 😿",
                        "confidence": 0.0,
                        "timestamp": datetime.now().isoformat(),
                        "error": str(e)
                    }

    def _encode_image(self, image_path: str) -> str:
        """Encode image to base64"""
        with open(image_path, "rb") as image_file:
            return base64.standard_b64encode(image_file.read()).decode("utf-8")

    def _get_media_type(self, image_path: str) -> str:
        """Get media type from file extension"""
        suffix = Path(image_path).suffix.lower()
        media_types = {
            ".jpg": "image/jpeg",
            ".jpeg": "image/jpeg",
            ".png": "image/png",
            ".gif": "image/gif",
            ".webp": "image/webp"
        }
        return media_types.get(suffix, "image/jpeg")

    def _build_system_prompt(self) -> str:
        """Build system prompt with persona"""
        personality_traits = self.persona.get("personality_traits", [])
        return f"""You are an AI with these personality traits: {', '.join(personality_traits)}.

Task: Analyze the image and respond in first person, maintaining your personality."""

    def _build_user_prompt(self, user_question: Optional[str] = None) -> str:
        """Build user prompt"""
        if user_question:
            return f"User asks: {user_question}\\n\\nPlease answer based on the image."
        else:
            return "Please look at this image and tell me your thoughts."

    def _estimate_confidence(self, reply: str) -> float:
        """Estimate confidence based on reply content"""
        reply_lower = reply.lower()
        if any(word in reply_lower for word in ["uncertain", "not sure", "can't see", "don't know"]):
            return 0.6
        if any(word in reply_lower for word in ["definitely", "clearly", "recognize", "this is"]):
            return 0.9
        return 0.75


def create_vision_engine(pet_id: str, persona: Dict[str, Any]) -> VisionEngine:
    """Factory function for vision engine"""
    return VisionEngine(pet_id, persona)
```

### Step 2: Add Feature Flag to Config

```python
# config.py
class Settings(BaseSettings):
    # ... existing settings ...

    # === Multimodal Features ===
    vision_enabled: bool = True  # Uses existing ANTHROPIC_API_KEY
```

### Step 3: Integrate into FastAPI App

```python
# api.py
from fastapi import FastAPI, UploadFile, File
from vision_engine import create_vision_engine

# In get_agent() function:
def get_agent(pet_id: str) -> Dict:
    if pet_id not in agent_cache:
        base_agent = create_agent(pet_id)

        # ... existing engines ...

        # Add vision engine
        if settings.vision_enabled:
            base_agent["vision_engine"] = create_vision_engine(
                pet_id,
                base_agent["persona"]
            )

        agent_cache[pet_id] = base_agent
    return agent_cache[pet_id]


@app.post("/api/v1/agents/{pet_id}/analyze-image")
async def analyze_image(
    pet_id: str,
    file: UploadFile = File(...),
    user_question: Optional[str] = None,
    user_id: str = "anonymous"
):
    """Vision API endpoint - analyze uploaded image"""

    # Check feature enabled
    if not settings.vision_enabled:
        raise HTTPException(503, "Vision feature not enabled")

    # Get agent
    agent = get_agent(pet_id)
    vision_engine = agent.get("vision_engine")

    if not vision_engine:
        raise HTTPException(503, "Vision engine not initialized")

    # Validate file type
    allowed_types = ["image/jpeg", "image/png", "image/gif", "image/webp"]
    if file.content_type not in allowed_types:
        raise HTTPException(400, f"Unsupported file type: {file.content_type}")

    # Save to temporary file
    import tempfile
    import os

    file_ext = Path(file.filename).suffix if file.filename else ".jpg"
    with tempfile.NamedTemporaryFile(delete=False, suffix=file_ext) as temp_file:
        content = await file.read()
        temp_file.write(content)
        temp_file_path = temp_file.name

    try:
        # Analyze image
        result = vision_engine.analyze_image(
            image_path=temp_file_path,
            user_question=user_question,
            user_id=user_id
        )
        return result
    finally:
        # Clean up temp file
        try:
            os.unlink(temp_file_path)
        except:
            pass
```

### Step 4: Update .env.example

```bash
# === Multimodal Features ===
# Vision understanding (AI can "see" user-uploaded images)
# Uses existing ANTHROPIC_API_KEY, no extra config needed
# Cost: ~$0.0087/request (2.2x text-only)
VISION_ENABLED=true
```

## Cost Analysis

### Token Calculation

**Text-only chat:**
```
Input:  System prompt (~500) + User message (~50) = 550 tokens
Output: AI reply (~150 tokens)
Cost:   (550 × $3/1M) + (150 × $15/1M) = $0.0039/request
```

**Vision chat (with image):**
```
Input:  System (~500) + User (~50) + Image (~1,600) = 2,150 tokens
Output: AI reply (~150 tokens)
Cost:   (2,150 × $3/1M) + (150 × $15/1M) = $0.0087/request
```

**Difference:**
- Vision is **2.2x more expensive** than text-only
- Cost increase: **+$0.0048** per request
- Still cheap: 100 requests = **$0.87** (vs $0.39 text-only)

### Monthly Cost Estimate (100 requests/month)

| Agents | Text-only | Vision | Difference |
|--------|-----------|--------|------------|
| 1 agent | $0.39 | $0.87 | **+$0.48** |
| 28 agents | $10.92 | $24.36 | **+$13.44** |

**Conclusion:** Vision adds ~$0.48/month per agent (acceptable!)

## Verification

### Test 1: API Startup

```bash
cd your-fastapi-app
python api.py

# Expected output:
# ✅ 配置驗證通過
# 🔄 首次載入 {agent_id} Agent...
# (Vision engine should load automatically if vision_enabled=true)
```

### Test 2: Upload Image

```bash
# Extract test frame from video
ffmpeg -i video.mp4 -ss 00:00:02 -frames:v 1 test.jpg -y

# Test Vision API
curl -X POST http://localhost:8000/api/v1/agents/jelly/analyze-image \
  -F "file=@test.jpg" \
  -F "user_question=What do you see?" \
  -s | python -m json.tool
```

**Expected response:**
```json
{
  "pet_id": "jelly",
  "user_id": "anonymous",
  "analysis": "I see a wooden floor...",
  "reply": "I see a wooden floor...",
  "confidence": 0.75,
  "timestamp": "2026-02-01T...",
  "model": "claude-sonnet-4-20250514"
}
```

### Test 3: Cost Monitoring

Check API logs for token usage:
```bash
tail -f logs/api.log | grep "tokens"
```

## Example

**Complete integration example:**

```python
# 1. Create vision engine
from vision_engine import create_vision_engine

persona = {
    "pet_name": "Jelly",
    "personality_traits": ["playful", "curious"],
    "species": "cat"
}

vision_engine = create_vision_engine("jelly", persona)

# 2. Analyze image
result = vision_engine.analyze_image(
    image_path="photo.jpg",
    user_question="Do you recognize this?"
)

print(result["reply"])
# Output: "Oh! That's my favorite blanket! So comfy 😺"
```

## Notes

### When Vision Adds Value

✅ **Use Vision when:**
- User uploads photos of pets/places/objects
- Need to identify items in images
- Want context-aware responses (e.g., "Do you see food?")
- Creating multimodal chatbots

❌ **Don't use Vision when:**
- Pure text conversation is sufficient
- Cost is critical concern
- Low-quality/blurry images (won't work well)

### Common Pitfalls

**1. Forgetting tempfile cleanup**
```python
# ❌ Bad: temp file never deleted
temp_path = save_file(upload)
result = analyze(temp_path)
return result

# ✅ Good: always cleanup
try:
    result = analyze(temp_path)
    return result
finally:
    os.unlink(temp_path)
```

**2. Wrong media type**
```python
# ❌ Bad: hardcoded type
"media_type": "image/jpeg"  # Fails for PNG!

# ✅ Good: detect from file extension
"media_type": self._get_media_type(image_path)
```

**3. No retry logic**
```python
# ❌ Bad: fails on first error
response = client.messages.create(...)

# ✅ Good: exponential backoff retry
for attempt in range(3):
    try:
        response = client.messages.create(...)
        break
    except Exception as e:
        if attempt < 2:
            time.sleep(2 ** attempt)
```

### Indentation Bug (Python linter)

**Symptom:** `SyntaxError: invalid syntax` on line with `response.content[0].text`

**Cause:** Python linters (like Ruff) auto-fix indentation, breaking nested `messages.create()` call

**Fix:** Ensure proper 4-space indentation inside `messages` list:
```python
response = self.client.messages.create(
    model=settings.claude_model,  # ← 4 spaces
    max_tokens=settings.max_tokens,  # ← 4 spaces
    messages=[  # ← 4 spaces
        {  # ← 8 spaces (nested in list)
            "role": "user",  # ← 12 spaces
            ...
        }
    ]
)  # ← Close at same level as method call
```

### Environment Variables

Required `.env` settings:
```bash
ANTHROPIC_API_KEY=sk-ant-...  # Required
SECRET_KEY=your-32-char-key   # Required (FastAPI security)
GAIA_DATA_PATH=/path/to/data  # Optional (auto-detect if missing)
VISION_ENABLED=true           # Optional (default: true)
```

## References

- [Anthropic Claude Vision API](https://docs.anthropic.com/claude/docs/vision)
- [FastAPI File Uploads](https://fastapi.tiangolo.com/tutorial/request-files/)
- [Claude API Pricing](https://www.anthropic.com/pricing)
- Related skill: `fastapi-development-production-dual-mode` (in-memory caching for agents)
- Related skill: `llm-api-cost-optimization` (prompt caching strategies)

## See Also

- **fastapi-development-production-dual-mode**: Base pattern for modular engine architecture
- **llm-api-cost-optimization**: Cost reduction strategies (Batch API, Prompt Caching)
- **llm-model-version-migration-2026**: Model version updates
