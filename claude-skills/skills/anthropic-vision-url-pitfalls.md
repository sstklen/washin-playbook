---
name: anthropic-vision-url-pitfalls
description: |
  Fix Anthropic Vision API failures when using URL-based images. Covers two critical pitfalls:
  (1) "Unable to download the file" error — certain image hosts (Wikipedia, etc.) block
  Anthropic's servers from downloading images, even if the URL works in a browser.
  (2) "anthropic-version is not a valid version" error — only TWO valid values exist
  (2023-01-01, 2023-06-01), the string 2025-04-14 is a Files API beta header, NOT a version.
  Use when: Vision API returns 400, empty responses, or "Unable to download" errors.
  Covers: source.type:'url' image format, anthropic-version header, image host compatibility.
author: Claude Code
version: 1.0.0
date: 2026-02-19
---

# Anthropic Vision API URL Pitfalls

## Problem

Anthropic's Vision API with URL-based images (`source.type: 'url'`) can fail silently or with
misleading errors due to two independent issues:

1. **Image host blocking**: Anthropic's servers get blocked by certain image hosts
2. **Version header confusion**: Mixing up `anthropic-version` with beta feature headers

## Context / Trigger Conditions

**Trigger 1 — Image URL blocked:**
```json
{
  "type": "error",
  "error": {
    "type": "invalid_request_error",
    "message": "Unable to download the file. Please verify the URL and try again."
  }
}
```
- The URL works fine in a browser
- The URL is publicly accessible (no auth required)
- HTTP status: 400

**Trigger 2 — Invalid version header:**
```json
{
  "type": "error",
  "error": {
    "type": "invalid_request_error",
    "message": "anthropic-version: \"2025-04-14\" is not a valid version"
  }
}
```

**Trigger 3 — Silent failure (empty responses):**
- Vision API returns `200` but the text content is empty (`""`, `"..."`)
- This may indicate the image was "downloaded" but couldn't be processed

## Solution

### Fix 1: Image URL Accessibility

**Root cause:** Anthropic's servers fetch the image server-side. Many image hosts block
non-browser User-Agents or specific IP ranges (cloud provider IPs).

**Known blocked hosts:**
- `upload.wikimedia.org` (especially `/thumb/` URLs)
- Wikipedia thumbnail servers (Thumbor-based, aggressive bot blocking)
- Some social media CDNs (Instagram, Facebook)

**Known working hosts:**
- Pexels CDN (`images.pexels.com`)
- Unsplash CDN (`images.unsplash.com`)
- Raw GitHub content (`raw.githubusercontent.com`)
- AWS S3 / CloudFront (public buckets)
- Google Cloud Storage (public objects)
- Your own domain's CDN

**Fix:**
```typescript
// BAD: Wikipedia thumbnail URL (blocked by Anthropic)
const url = 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4d/Cat.jpg/220px-Cat.jpg';

// GOOD: Pexels CDN (permissive, stable)
const url = 'https://images.pexels.com/photos/45201/kitty-cat-kitten-pet-45201.jpeg?auto=compress&cs=tinysrgb&w=400';
```

**Alternative: Use base64 encoding to bypass URL issues entirely:**
```typescript
// If URL accessibility is uncertain, use base64
const imageBuffer = await fetch(imageUrl).then(r => r.arrayBuffer());
const base64 = Buffer.from(imageBuffer).toString('base64');
const mediaType = 'image/jpeg'; // or image/png, image/webp, image/gif

content: [
  { type: 'image', source: { type: 'base64', media_type: mediaType, data: base64 } },
  { type: 'text', text: 'Describe this image.' },
]
```

### Fix 2: Correct anthropic-version Header

**Root cause:** The string `2025-04-14` appears in Anthropic's documentation as a **Files API
beta header** (`anthropic-beta: files-api-2025-04-14`), NOT as an `anthropic-version` value.

**Only TWO valid `anthropic-version` values exist (as of 2026-02):**
- `2023-01-01` (older, limited features)
- `2023-06-01` (current recommended, supports URL images)

**Fix:**
```typescript
// BAD: This is a beta feature identifier, NOT a version!
headers: { 'anthropic-version': '2025-04-14' }  // ERROR: not a valid version

// GOOD: Use the correct version
headers: { 'anthropic-version': '2023-06-01' }

// If you need Files API beta features, add a SEPARATE header:
headers: {
  'anthropic-version': '2023-06-01',           // Version (required)
  'anthropic-beta': 'files-api-2025-04-14',     // Beta feature (optional)
}
```

### Fix 3: Add Error Logging

Always log non-200 responses for faster diagnosis:
```typescript
const res = await fetch('https://api.anthropic.com/v1/messages', { ... });
const json = await res.json();

if (!res.ok) {
  console.log(`Vision API HTTP ${res.status}:`, JSON.stringify(json));
}

const text = json?.content?.[0]?.text || '';
if (text.length < 5) {
  console.log('Vision API returned empty/short response:', JSON.stringify(json));
}
```

## Verification

After applying fixes, verify:
1. API returns HTTP 200 (not 400)
2. Response contains `content[0].text` with meaningful text (> 10 chars)
3. Text content correctly describes the image (e.g., mentions "cat" for a cat image)

## Example

**Before (3 cascading failures):**
```
1. Used Wikipedia /thumb/ URL → "Unable to download the file" (400)
2. Changed anthropic-version to 2025-04-14 → "not a valid version" (400)
3. Got empty responses with correct version → image host was the real issue
```

**After (all fixed):**
```typescript
const headers = {
  'x-api-key': apiKey,
  'anthropic-version': '2023-06-01',  // Correct version
  'Content-Type': 'application/json',
};

const body = {
  model: 'claude-sonnet-4-20250514',
  max_tokens: 200,
  messages: [{
    role: 'user',
    content: [
      {
        type: 'image',
        source: {
          type: 'url',
          // Use Pexels CDN instead of Wikipedia
          url: 'https://images.pexels.com/photos/45201/kitty-cat-kitten-pet-45201.jpeg?auto=compress&cs=tinysrgb&w=400',
        },
      },
      { type: 'text', text: 'Describe this image in one sentence.' },
    ],
  }],
};

const res = await fetch('https://api.anthropic.com/v1/messages', {
  method: 'POST', headers, body: JSON.stringify(body),
});
// Result: "A small tabby kitten with wide eyes..." (100/100 A+)
```

## Notes

- The `source.type: 'url'` feature works with `anthropic-version: 2023-06-01` — no beta
  header needed for basic URL image support
- Wikipedia's `/thumb/` URLs go through Thumbor (image processing proxy) which has
  stricter bot blocking than the main file URLs
- When testing Vision API in automated scripts, prefer CDN-hosted images over
  user-generated content hosts
- If building a production service, consider downloading images yourself and sending
  them as base64 to avoid dependency on third-party URL accessibility
- The `anthropic-beta` header is for opt-in beta features (like Files API, computer use,
  prompt caching), and is completely separate from the `anthropic-version` header

## See Also

- `vision-api-fastapi-integration` — Claude Vision in FastAPI (base64 approach)
- `llm-model-version-migration-2026` — Model name migration (related version issues)

## References

- [Anthropic Vision API Docs](https://docs.anthropic.com/en/docs/build-with-claude/vision)
- [Anthropic API Versioning](https://docs.anthropic.com/en/api/versioning)
- [Anthropic Beta Features](https://docs.anthropic.com/en/docs/about-claude/models#beta-features)
