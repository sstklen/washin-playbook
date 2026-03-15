---
name: apify-actor-intelligence
description: |
  Apify Store Top 200 Actor 完整踩坑知識庫。200 個 Actor 全部實測，記錄了 27 個坑、
  83 個通過的 Actor 的正確 input、30 個 input_error 的 requiredField、價格比較、
  隱藏寶石、家族分析、爬取深度目錄。任何涉及 Apify Actor 呼叫的任務都應載入此 Skill。
  觸發條件：(1) 呼叫 Apify Actor API，(2) 規劃爬蟲任務（L4 Task Engine），
  (3) 選擇 Actor（價格/品質比較），(4) 除錯 Apify 400/403/timeout 錯誤，
  (5) 向客戶展示爬取深度能力（銷售用）。
version: 2.0.0
date: 2026-02-19
---

# Apify Actor Intelligence — 200 Actor 實戰踩坑知識庫

> **2026-02-19 完成第一輪深度盤點**：Top 200 全部測試，花費 $165.32
> **帳戶：** classic_fascination（SCALE $199/月）
> **資料來源：** Day 1-3 手動測試（26 個）+ 批量掃描（176 個）+ 重測補正（41 個通過 → 共 83 個通過）
> **機器可讀資料：** `src/data/apify-actor-registry.json`（200 筆完整記錄）
> **爬取深度目錄：** [`references/scraping-depth-catalog.md`](references/scraping-depth-catalog.md)（銷售用，按平台分類欄位深度）

---

## 一、API 呼叫鐵律（每次都要遵守！）

### 1. Actor ID 格式
- **API 呼叫用 `~`**：`compass~crawler-google-places`
- **Store URL 用 `/`**：`apify.com/compass/crawler-google-places`
- **搞混就 404！** 這是最常見的錯誤

### 2. 三階段呼叫模式
```
POST /v2/acts/{actorId}/runs  →  啟動
GET  /v2/actor-runs/{runId}   →  輪詢（等 SUCCEEDED/FAILED）
GET  /v2/datasets/{id}/items  →  取結果
```

### 3. Input 格式通用規則
| 規則 | 說明 |
|------|------|
| **不確定就用 Array** | 80% 的 Actor 要 `["value"]` 不是 `"value"` |
| **Facebook 系列** | startUrls 一律 `[{url: "..."}]`（RequestList 格式） |
| **YouTube 例外** | `searchKeywords` 是字串 `"keyword"` 不是陣列 |
| **LinkedIn 各家不同** | 每個開發者的欄位名都不一樣，必須查 |
| **maxItems 未必有效** | Lead Gen Actor 常忽略 maxItems，設 3 筆抓 500 筆 |

### 4. 計費查詢
```bash
# 查月額度
curl -H "Authorization: Bearer $TOKEN" https://api.apify.com/v2/users/me/limits
# → current.monthlyUsageUsd / limits.maxMonthlyUsageUsd

# 查單次花費 → run response 的 usageTotalUsd 欄位
```

---

## 二、22 個踩坑百科（P-01 ~ P-22）

### 致命坑（會 404 或完全失敗）

| # | 坑 | 影響 | 正確做法 |
|---|-----|------|---------|
| P-01 | Actor 名字不是你想的 | GMaps、TikTok | `crawler-google-places` 非 `google-maps-scraper` |
| P-02 | 403 需租用 | 53 個 FLAT Actor | 去 Console 租用，或換免費替代品 |
| P-03 | Input 欄位名錯 | LinkedIn 系列 | 每家開發者不同，必須查 schema |
| P-04 | IG 留言 URL 限制 | instagram-comment-scraper | directUrls 必須是 `/p/` 或 `/reel/` |
| P-05 | FB 廣告 startUrls 必填 | facebook-ads-scraper | search+country 不能單獨用 |

### 格式坑（Input 格式錯但可修）

| # | 坑 | 影響 | 正確做法 |
|---|-----|------|---------|
| P-06 | username 要 Array | IG Reels/Posts/TikTok | `["natgeo"]` 非 `"natgeo"` |
| P-07 | YT searchKeywords 是字串 | youtube-scraper | `"keyword"` 非 `["keyword"]` |
| P-08 | FB startUrls 格式 | 所有 FB Actor | `[{url: "..."}]` 非 `["url"]` |
| P-09 | TikTok maxProfilesPerQuery | free-tiktok-scraper | 最小值 1，設 0 會 400 |

### 成本坑（不小心就爆預算）

| # | 坑 | 影響 | 說明 |
|---|-----|------|------|
| P-10 | Twitter 最慢最貴 | tweet-scraper | ~$1.50/次、180s+ |
| P-13 | Leads Finder 過度抓取 | leads-finder 系列 | 設 3 筆抓 500 筆，$0.91~$8.00 |
| P-18 | Lead Gen 忽略 maxItems | pipelinelabs | 單次 $8！三思而後行 |
| P-19 | 同功能價差巨大 | Twitter | apidojo $1.50 vs gentle_cloud $0.00 |

### 環境坑

| # | 坑 | 影響 | 說明 |
|---|-----|------|------|
| P-11 | Google Search 回傳少 | google-search-scraper | 設 10 回 1，Actor 限制 |
| P-12 | FB Pages 要 proxy | facebook-pages-scraper | `{useApifyProxy: true}` |
| P-14 | Article Extractor 要文章 URL | article-extractor | 列表頁 0 筆 |
| P-15 | API `~` vs Store `/` | 所有 Actor | 混用就 404 |
| P-20 | Framework Actor 要 pageFunction | web-scraper/puppeteer/cheerio | 開發工具，非即用型 |
| P-21 | apimaestro LinkedIn 最划算 | 7 個 Actor 全 $0.00 | 免 cookie |
| P-22 | 批量掃描 output 覆蓋 | 並行執行 | 不同批次要用不同檔名 |

### 重測補正新坑（P-23 ~ P-27）

| # | 坑 | 影響 | 說明 |
|---|-----|------|------|
| P-23 | 需要 openaiApiKey | extended-gpt-scraper, ai-web-agent | 這些 Actor 內部呼叫 OpenAI，必須提供自己的 Key |
| P-24 | 需要 cookies | amr-mando lead-finder | 無法自動化測試，需手動提供登入 cookie |
| P-25 | 級聯必填欄位 | social-media-finder, backlink-agent | 修完 A 欄位才發現 B 也必填（profileNames→socials, keywords→businessName）|
| P-26 | freshdata URL 是 string 非 array | freshdata linkedin | `linkedin_url: "url"` 非 `["url"]`，反一般慣例 |
| P-27 | IG Tagged Scraper 成本爆炸 | instagram-tagged-scraper | 20 items 花 $0.56！事先查 `pricingInfo` 定價 |

---

## 三、平台家族速查卡

### Instagram 家族（8 個通過，全部 Apify 出品）

| Actor | 用途 | 花費 | 耗時 | Input 重點 |
|-------|------|------|------|-----------|
| `apify~instagram-scraper` | 搜尋 | $0.02 | 45s | `{search: "keyword", resultsLimit: N}` |
| `apify~instagram-hashtag-scraper` | Hashtag | $0.005 | 5s | `{hashtags: ["tag"], resultsLimit: N}` |
| `apify~instagram-reel-scraper` | Reels | $0.005 | 14s | `{username: ["name"], resultsLimit: N}` ← Array! |
| `apify~instagram-profile-scraper` | 個人檔案 | $0.002 | 10s | `{usernames: ["name"]}` 或 `"name"` 都行 |
| `apify~instagram-post-scraper` | 貼文列表 | $0.018 | 90s | `{username: ["name"]}` ← Array! |
| `apify~instagram-comment-scraper` | 留言 | $0.002 | 8s | `{directUrls: ["https://.../p/xxx"]}` ← 只接受貼文 URL |
| `apify~instagram-api-scraper` | API 版 | $0.00 | 4s | 品質 4.99，最快 |
| `apify~instagram-search-scraper` | 搜尋 v2 | $0.00 | 17s | bulk scan 通過 |

### LinkedIn 家族（apimaestro 最強，全免費免 cookie）

| Actor | 用途 | 花費 | 耗時 | 品質 |
|-------|------|------|------|------|
| `apimaestro~linkedin-profile-detail` | 個人檔案 | $0.00 | 7s | 4.73 |
| `apimaestro~linkedin-profile-batch-scraper-*` | 批量個人 | $0.00 | 8s | 4.87 |
| `apimaestro~linkedin-posts-search-scraper-*` | 搜尋貼文 | $0.00 | 8s | 4.59 |
| `apimaestro~linkedin-company-posts` | 公司貼文 | $0.00 | 7s | 4.80 |
| `apimaestro~linkedin-jobs-scraper-api` | 職缺搜尋 | $0.00 | 11s | 4.50 |
| `apimaestro~linkedin-job-detail` | 職缺詳情 | $0.00 | 4s | 5.00 |
| `apimaestro~linkedin-company-detail` | 公司詳情 | $0.00 | 4s | 4.50 |

**其他 LinkedIn 選項：**
- `harvestapi~linkedin-profile-posts`：$0.00，7s，品質 4.28（貼文）
- `harvestapi~linkedin-post-search`：品質 4.74（搜尋貼文）
- `anchor~linkedin-profile-enrichment`：$0.001，7s，品質 4.71（含 Email）
- `dev_fusion~Linkedin-Profile-Scraper`：7s，品質 4.62（含 Email）

### Twitter/X 家族（價差巨大！）

| Actor | 用途 | 花費 | 耗時 | 品質 |
|-------|------|------|------|------|
| `gentle_cloud~twitter-tweets-scraper` | 推文 | N/A | 4s | 4.85 |
| `apidojo~twitter-scraper-lite` | 推文 | $0.00 | 8s | 3.62 |
| `kaitoeasyapi~twitter-x-data-tweet-scraper-*` | 推文 | N/A | 17s | 4.31 |
| `apidojo~tweet-scraper` | 推文 v2 | $1.50 | 182s | 4.35 |

**建議：** 先用 gentle_cloud（免費+最快），不行再用 apidojo lite

### YouTube 家族

| Actor | 用途 | 花費 | 耗時 | 品質 |
|-------|------|------|------|------|
| `streamers~youtube-scraper` | 影片搜尋 | $0.02 | 24s | 4.66 |
| `streamers~youtube-channel-scraper` | 頻道 | $0.001 | 7s | 4.89 |
| `streamers~youtube-comments-scraper` | 留言 | N/A | 14s | 4.95 |
| `dz_omar~youtube-transcript-metadata-extractor` | 字幕 | $0.0001 | 8s | 5.00 |
| `topaz_sharingan~Youtube-Transcript-Scraper-1` | 字幕 v2 | $0.00 | 11s | 4.40 |

**注意：** searchKeywords 用**字串**不是陣列！

### TikTok 家族（Clockworks 出品）

| Actor | 用途 | 花費 | 耗時 | 品質 |
|-------|------|------|------|------|
| `clockworks~tiktok-scraper` | 影片搜尋 | $0.01 | 11s | 4.65 |
| `clockworks~free-tiktok-scraper` | 免費版 | $0.005 | 7s | 4.26 |
| `clockworks~tiktok-profile-scraper` | 個人檔案 | $0.00 | 14s | 4.93 |
| `clockworks~tiktok-hashtag-scraper` | Hashtag | N/A | 27s | 4.80 |
| `clockworks~tiktok-video-scraper` | 影片詳情 | N/A | 17s | 4.62 |
| `clockworks~tiktok-comments-scraper` | 留言 | N/A | 8s | 4.62 |

### Facebook 家族（全部 Apify，全部 $0.00）

| Actor | 用途 | 耗時 | Input 重點 |
|-------|------|------|-----------|
| `apify~facebook-posts-scraper` | 貼文 | 17s | `{startUrls: [{url: "..."}]}` |
| `apify~facebook-comments-scraper` | 留言 | 80s | `{startUrls: [{url: "..."}]}` |
| `apify~facebook-pages-scraper` | 粉專 | 17s | 可能需 proxy |
| `apify~facebook-groups-scraper` | 社團 | 7s | 公開社團限定 |
| `apify~facebook-ads-scraper` | 廣告庫 | 83s | startUrls 必填！ |
| `apify~facebook-search-scraper` | 搜尋 | 7s | 品質 4.92 |

### Google 家族

| Actor | 用途 | 花費 | 耗時 |
|-------|------|------|------|
| `compass~crawler-google-places` | GMaps 商家 | $0.02 | 30s |
| `compass~google-maps-reviews-scraper` | GMaps 評價 | $0.02 | 20s |
| `compass~google-maps-extractor` | GMaps 提取 | $0.01 | 14s |
| `apify~google-search-scraper` | 搜尋 | $0.005 | 20s |
| `scraperlink~google-search-results-serp-scraper` | SERP | N/A | 63s |

### Travel / Reviews

| Actor | 用途 | 花費 | 品質 |
|-------|------|------|------|
| `maxcopell~tripadvisor` | TripAdvisor | $0.0001 | 4.96 |
| `maxcopell~tripadvisor-reviews` | TA 評價 | $0.0001 | 4.79 |
| `voyager~booking-scraper` | Booking | N/A | 4.48 |
| `voyager~booking-reviews-scraper` | Booking 評價 | N/A | 4.73 |
| `tri_angle~airbnb-scraper` | Airbnb | $0.33 | 4.37 |

### Lead Gen（小心花費！）

| Actor | 花費 | 品質 | 危險等級 |
|-------|------|------|---------|
| `anchor~linkedin-profile-enrichment` | $0.001 | 4.71 | 安全 |
| `olympus~b2b-leads-finder` | $0.01 | 3.16 | 中等 |
| `worldunboxer~rapid-linkedin-scraper` | $0.03 | 4.36 | 中等 |
| `peakydev~leads-scraper-ppe` | $0.62 | 2.62 | 危險 |
| `code_crafter~leads-finder` | $0.91 | 3.19 | 危險 |
| `x_guru~Leads-Scraper-apollo-zoominfo` | $1.38 | 3.82 | 很危險 |
| `pipelinelabs~lead-scraper-*` | **$8.00** | 2.82 | 極危險 |

---

## 四、隱藏寶石 Top 10（品質高、價格低、排名靠後）

| Rank | Actor | 品質 | 花費 | 用途 |
|------|-------|------|------|------|
| #156 | `dz_omar~youtube-transcript-*` | **5.00** | $0.00 | YT 字幕 |
| #172 | `apimaestro~linkedin-job-detail` | **5.00** | $0.00 | LinkedIn 職缺 |
| #54 | `apify~instagram-api-scraper` | 4.99 | $0.00 | IG API |
| #69 | `maxcopell~tripadvisor` | 4.96 | $0.00 | TripAdvisor |
| #52 | `streamers~youtube-comments-scraper` | 4.95 | N/A | YT 留言 |
| #100 | `apify~facebook-search-scraper` | 4.92 | $0.00 | FB 搜尋 |
| #34 | `streamers~youtube-channel-scraper` | 4.89 | $0.00 | YT 頻道 |
| #114 | `gentle_cloud~twitter-tweets-scraper` | 4.85 | N/A | 推文（免費！） |
| #111 | `apimaestro~linkedin-profile-batch-*` | 4.87 | $0.00 | LinkedIn 批量 |
| #115 | `anchor~linkedin-profile-enrichment` | 4.71 | $0.00 | LinkedIn+Email |

---

## 五、30 個仍待解的 input_error（原 48 個，18 個已重測通過）

> 原本 48 個 input_error，經過重測補正後 18 個通過，30 個仍然失敗。
> 失敗原因：需 openaiApiKey(2)、需 cookies(1)、級聯欄位(2)、格式仍錯(25)。
> 已通過的 18 個已更新到 registry JSON，含完整 knownInput 和 fields。

**常見的 requiredField 模式：**

| requiredField | 出現次數 | 典型 Actor |
|---------------|---------|-----------|
| `urls` | 8 | linkedin-jobs, linkedin-post, youtube-transcripts |
| `startUrls` | 6 | contact-info, gpt-scraper, instagram-scraper |
| `pageFunction` | 4 | web-scraper, puppeteer, cheerio, playwright |
| `profileUrls` / `profileNames` | 3 | linkedin-company, social-media-finder |
| `usernames` | 3 | ig-followers-count, ig-following |
| `companyUrls` | 2 | linkedin-employees |
| `videoUrl` / `videoUrls` | 2 | youtube-transcript |
| `searchUrls` / `zipCodes` | 2 | zillow |
| `query` | 1 | facebook-search-ppr |
| `cookie` | 1 | crunchbase-scraper |
| `hashtags` | 1 | social-media-hashtag-research |
| `keywords` | 1 | backlink-building-agent |
| `reelLinks` | 1 | instagram-reel-downloader |
| `postIds` | 1 | linkedin-post-comments |

**完整清單：** 見 `src/data/apify-actor-registry.json` 的 `testResult.requiredField`

---

## 六、L4 Task Engine 規劃用能力矩陣

| 平台 | 能爬 | 不能爬 | 速度 | 成本 | 推薦 Actor |
|------|------|--------|------|------|-----------|
| Instagram | 貼文/Reels/留言/Hashtag/檔案/搜尋 | DM/私人/Stories | 4-90s | 低 | apify~instagram-api-scraper |
| Facebook | 粉專/貼文/留言/社團/廣告/搜尋 | 個人帳號/Messenger | 7-83s | 低 | apify~facebook-search-scraper |
| TikTok | 搜尋/檔案/影片/Hashtag/留言 | DM/私人/直播 | 7-27s | 低 | clockworks~tiktok-scraper |
| Twitter/X | 搜尋推文/用戶 | DM/私人/Spaces | 4-182s | 低~高 | gentle_cloud~twitter-tweets-scraper |
| YouTube | 搜尋/頻道/留言/字幕 | 付費/直播聊天 | 7-24s | 低 | streamers~youtube-scraper |
| LinkedIn | 個人/公司/職缺/貼文 | DM/付費 InMail | 4-11s | 免費 | apimaestro 全家族 |
| Google Maps | 商家/評價/聯絡 | 即時人流 | 14-30s | 低 | compass~crawler-google-places |
| Google Search | SERP 結果 | 回傳量偏少 | 20-63s | 低 | apify~google-search-scraper |
| Web 通用 | 任何公開網頁→Markdown | 需登入頁 | 60-126s | 低 | apify~website-content-crawler |
| Travel | TripAdvisor/Booking/Airbnb | 即時價格 | 8-63s | 低~中 | maxcopell~tripadvisor |
| Ecommerce | Amazon 評價/商品 | 帳戶資料 | 14s | 低 | junglee~amazon-reviews-scraper |

---

## 七、53 個 FLAT_PRICE_PER_MONTH Actor（全部需月租）

**不要嘗試呼叫它們！** 會收到 403 `actor-is-not-rented`。

這些 Actor 佔了 Top 200 的 26.5%，全部需要額外月租費才能使用。
目前帳戶未租用任何 FLAT Actor。如需使用，去 Apify Console 租用。

---

## 八、成本控制建議

| 策略 | 說明 |
|------|------|
| **選免費替代品** | 同功能常有免費版（Twitter $1.50 → $0.00） |
| **Lead Gen 三思** | 單次可能 $0.62~$8.00，先確認 maxItems 有效 |
| **用 apimaestro** | LinkedIn 全家族 $0.00，品質 4.5+ |
| **查 usageTotalUsd** | 每次 run 後檢查實際花費 |
| **設 timeout** | 60s 足夠大部分 Actor（Twitter 需 180s+） |
| **月底查額度** | `GET /users/me/limits` 避免用超 |

---

## 九、除錯速查

| 錯誤 | 原因 | 修復 |
|------|------|------|
| 404 Actor not found | Actor ID 用了 `/` 或名字錯 | 改用 `~`，查正確 actorId |
| 400 invalid-input | 缺必填欄位或格式錯 | 看 error message 的 Field 提示 |
| 403 actor-is-not-rented | FLAT_PRICE Actor 未租用 | 去 Console 租用或換 Actor |
| SUCCEEDED 但 0 items | Input URL 不對或 Actor 限制 | 換測試 URL/關鍵字 |
| RUNNING 超時 | Actor 慢（Twitter 正常） | 加長 timeout 或取部分結果 |
| $8 帳單 | Lead Gen Actor 過度抓取 | 改用 anchor 或 apimaestro |

---

## 十、爬取深度目錄（銷售用）

> **用途：** 向客戶展示「我們能爬多深」，不暴露技術細節。
> **檔案：** [`references/scraping-depth-catalog.md`](references/scraping-depth-catalog.md)

**亮點數據（給客戶看的）：**

| 平台 | 最深 | 獨家欄位 | 定價建議 |
|------|------|---------|---------|
| LinkedIn | 28 欄位 | 薪資、技能、學歷、公司營收 | 極深 +150% |
| Instagram | 26 欄位 | 分享數、Tagged 用戶、帳號驗證 | 極深 +150% |
| YouTube | 含毫秒時間軸字幕 | startMs/duration/text | 深度 +80% |
| Zillow | **41 欄位** | 降價歷史、稅單、鄰居房價 | 極深 +150% |
| Amazon | 14 欄位 | 排名、評價分佈 | 深度 +80% |
| Facebook Marketplace | 26 欄位 | 賣家位置、交易偏好 | 極深 +150% |

**Day 1-3 缺口：** 最早 26 個手動測試的 Actor 沒有記錄 field depth，下月重跑補上（~$5-10）。

---

*v2.0.0 — 2026-02-19 第一輪深度盤點完成*
*Total cost: $165.32 / $199 (83% of monthly quota)*
*Passed: 83/200 (41.5%) | FLAT need rental: 53 | Still failing: 30 | Other: 34*
*Pitfalls: 27 (P-01 ~ P-27)*
*Data registry: `src/data/apify-actor-registry.json`*
*Depth catalog: `references/scraping-depth-catalog.md`*
*Memory graph: `Apify-深度盤點-2026-02` + `Apify-深度盤點-SOP` + `Apify-新坑-P23-P27`*
