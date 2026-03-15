---
name: nextjs-common-patterns
description: |
  Next.js 13+ 常見問題與解決方案。使用情境：(1) "params is a Promise" 錯誤，
  (2) 動態路由參數處理，(3) Image 組件遠端圖片配置，(4) Mock API 整合測試，
  (5) Next.js API route 做 backend proxy（避免 CORS、隱藏 API key），
  (6) React Hooks 條件式 return 前 hook 呼叫（"Rendered more hooks than during the previous render"）。
  整合原有 Next.js/React skills 為一體。
version: 2.1.0
date: 2026-02-10
---

# Next.js 13+ Common Patterns

## Quick Reference

| 問題 | 解法 | 詳細 |
|------|------|------|
| `params is a Promise` | `await params` 在 async function | [dynamic-routing](references/dynamic-routing.md) |
| Image hostname 未配置 | `next.config.js` → `images.remotePatterns` | [dynamic-routing](references/dynamic-routing.md) |
| API route params 錯誤 | 同上 + 注意 `{ params }` 解構 | [api-params](references/api-params.md) |
| Mock API 測試 | MSW + Next.js API routes | [mock-api](references/mock-api.md) |

---

## 1. Params is a Promise（最常見）

### 錯誤訊息
```
Error: params is a Promise and must be unwrapped with `await` or `React.use()`
```

### 解法

**Page/Layout（Server Component）**
```typescript
// app/pet/[name]/page.tsx
export default async function PetPage({
  params,
}: {
  params: Promise<{ name: string }>
}) {
  const { name } = await params;  // ✅ await!
  return <div>{name}</div>;
}
```

**API Route**
```typescript
// app/api/pets/[id]/route.ts
export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params;  // ✅ await!
  return Response.json({ id });
}
```

---

## 2. Image Remote Patterns

### 錯誤訊息
```
Error: hostname "example.com" is not configured under images in next.config.js
```

### 解法
```javascript
// next.config.js
module.exports = {
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: '**.supabase.co',
      },
      {
        protocol: 'https',
        hostname: 'images.unsplash.com',
      },
    ],
  },
};
```

---

## 3. Mock API Testing（MSW）

### 基本設置
```typescript
// mocks/handlers.ts
import { http, HttpResponse } from 'msw';

export const handlers = [
  http.get('/api/pets', () => {
    return HttpResponse.json([
      { id: 1, name: 'Jelly' },
      { id: 2, name: 'Gold' },
    ]);
  }),
];
```

### 測試中使用
```typescript
// __tests__/pets.test.tsx
import { server } from '@/mocks/server';

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

test('loads pets', async () => {
  // MSW 會攔截 /api/pets 請求
});
```

---

## References

- [dynamic-routing.md](references/dynamic-routing.md) - 動態路由 + Image 配置
- [api-params.md](references/api-params.md) - API route params 處理
- [mock-api.md](references/mock-api.md) - Mock API 測試流程

---

## Merged Skills (archived)

The following skills have been merged into this guide:
- **nextjs-backend-proxy-pattern** — Next.js API route 做 backend proxy（避免 CORS、隱藏 API key、rewrite 配置）
- **react-hooks-conditional-return-error** — React Hooks 規則錯誤修復（條件式 return 前不可呼叫 hooks、"Rendered more hooks" 錯誤）

---

*Part of 🥋 AI Dojo Series by [Washin Village](https://washinmura.jp)*
