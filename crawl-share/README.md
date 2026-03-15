<p align="center">
  <h1 align="center">🦞 crawl-share</h1>
  <p align="center"><strong>Community-powered web intelligence. Battle-tested crawlers. Shared results.</strong></p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Apify_Actors-200+_Tested-blue?style=for-the-badge" alt="200+ Tested"/>
  <img src="https://img.shields.io/badge/Platforms-IG_·_TikTok_·_YouTube-green?style=for-the-badge" alt="Platforms"/>
  <img src="https://img.shields.io/badge/Status-Production-orange?style=for-the-badge" alt="Status"/>
</p>

<p align="center">
  <a href="https://api.washinmura.jp/crawl-cache">🔍 Live Tool Reviews</a> ·
  <a href="https://api.washinmura.jp/social">📊 Trend Analytics</a> ·
  <a href="#why-this-exists">💡 Why This Exists</a>
</p>

---

## Why This Exists

We needed web data to run an [animal sanctuary](https://washinmura.jp). Social media trends for awareness campaigns. Competitor pricing for our API marketplace. Event data for community outreach.

So we tested **every Apify actor we could find**. 200+ of them. Most documentation lies. Actors that claim 99% success rate fail on real URLs. "Free tier" actors that silently charge $2/run. Instagram scrapers that return 3-month-old cached data.

**We wrote down everything.** Every success, every failure, every hidden gotcha.

Then we thought: *why should everyone repeat these same expensive lessons?*

**crawl-share** = our crawl intelligence, open to everyone.

---

## What's Inside

### 1. 🔧 Apify Actor Intelligence (200+ actors tested)

Every actor rated with our honest system:

| Rating | Meaning | Count |
|--------|---------|-------|
| ✅ Recommended | Works reliably, free or cheap | ~83 |
| ⚠️ Caution | Works but has hidden costs or limits | ~30 |
| 🚫 Avoid | High failure rate or unstable | ~27 |
| 🤷 Untested | Documented but not battle-tested yet | ~60+ |

**What we track per actor:**
- Success rate (real, not claimed)
- Cost per run (including hidden platform fees)
- Data freshness (some return cached/stale data)
- Rate limits and anti-bot detection
- Actual output format vs documented format

→ [Browse the full database](https://api.washinmura.jp/crawl-cache)

### 2. 📊 Social Media Trend Analytics

Real-time analysis of crawled social data:

**Instagram:**
- Hashtag performance rankings (posts, avg likes, avg comments)
- Content type comparison (photo vs carousel vs reel)
- Top engagement posts with full metadata

**TikTok:**
- View count distribution analysis
- Small account breakout detection (viral potential)
- Optimal video length analysis
- Trending sounds/music rankings
- Hashtag performance (top 20)

→ [See live analytics](https://api.washinmura.jp/social)

### 3. 🦞 Community Bug Intelligence (via YanHui)

Every bug we hit while building crawlers feeds into [YanHui CI](https://github.com/sstklen/yanhui-ci) — our debug AI that remembers every bug ever solved. The crawl-share community benefits from instant fixes.

---

## The Vision: Community-Powered Crawling

```
Phase 1 (NOW):     Open-source tool reviews + analytics methods
Phase 2 (NEXT):    Community members contribute crawl results
Phase 3 (FUTURE):  Distributed crawling network — SETI@home for web data
```

**The problem:** Web crawling is expensive, fragile, and everyone duplicates the same work. 100 people scraping the same Instagram hashtag = 100x the cost, 100x the rate limit hits.

**The solution:** Share crawl results. One person crawls, everyone benefits. Contributors get priority access to the shared pool.

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Crawler A   │     │  Crawler B   │     │  Crawler C   │
│  (IG data)   │     │ (TikTok)     │     │ (YouTube)    │
└──────┬───────┘     └──────┬───────┘     └──────┬───────┘
       │                    │                    │
       └────────────────────┼────────────────────┘
                            │
                    ┌───────▼───────┐
                    │  Shared Pool   │
                    │  (crawl-share) │
                    └───────┬───────┘
                            │
       ┌────────────────────┼────────────────────┐
       │                    │                    │
┌──────▼───────┐     ┌──────▼───────┐     ┌──────▼───────┐
│  User A gets │     │  User B gets │     │  User C gets │
│  ALL data    │     │  ALL data    │     │  ALL data    │
└──────────────┘     └──────────────┘     └──────────────┘
```

---

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /api/v2/crawl-cache/browse` | Browse all tested actors & crawled data |
| `GET /api/v2/crawl-cache/search?q=instagram` | Search by keyword |
| `GET /api/v2/crawl-cache/stats` | Platform statistics |
| `GET /api/v2/crawl-cache/social-stats` | Social media trend analytics |

**Base URL:** `https://api.washinmura.jp`

---

## Key Findings (from 200+ actor tests)

### Instagram Scraping — What Actually Works

| Actor | Our Rating | Why |
|-------|-----------|-----|
| Apify/instagram-scraper | ✅ | Reliable, good free tier |
| Apify/instagram-post-scraper | ⚠️ | Works but returns stale data (2-4 weeks old) |
| Some "premium" actors | 🚫 | $2-5/run, same data quality as free ones |

### TikTok Scraping — The Minefield

| Actor | Our Rating | Why |
|-------|-----------|-----|
| Clockworks/tiktok-scraper | ✅ | Best balance of speed and cost |
| Many "fast" scrapers | 🚫 | Break every 2-3 weeks when TikTok changes API |

### General Patterns

1. **"Success rate" in docs is always inflated** — Test with YOUR URLs, not demo URLs
2. **Free tier ≠ free** — Platform compute fees add up ($0.25-2.00 per run)
3. **Actors break silently** — No error, just returns empty or cached data
4. **Author activity matters** — Actors not updated in 3+ months = probably broken

→ Full database: [Browse all 200+ actors](https://api.washinmura.jp/crawl-cache)

---

## How to Contribute

### Share Your Crawl Results
```
Coming soon — contributor guide + data format spec
```

### Report an Actor Issue
Found an actor that's broken, overpriced, or misleading?
→ [Open an issue](https://github.com/sstklen/crawl-share/issues)

### Add Your Actor Review
Tested an Apify actor we haven't covered?
→ [Submit a PR](https://github.com/sstklen/crawl-share/pulls) with your findings

---

## Related Projects

| Project | What it does |
|---------|-------------|
| [YanHui CI](https://github.com/sstklen/yanhui-ci) | Debug AI that remembers every bug — feeds crawl-share's bug intelligence |
| [112 Claude Code Skills](https://github.com/sstklen/washin-claude-skills) | Production skills including `apify-actor-intelligence` and `playwright-anti-ai-detection-bypass` |
| [Zero Engineer](https://github.com/sstklen/zero-engineer) | The full story of building this platform with zero engineering background |

---

## Background

Built at [Washin Village](https://washinmura.jp) (和心村) — an animal sanctuary on Japan's Boso Peninsula, caring for 28 cats & dogs. We needed web data for our sanctuary operations and ended up building tools that benefit everyone.

**The crawling community shouldn't keep re-learning the same expensive lessons.** That's why we share.

---

<p align="center">
  <i>「一隻龍蝦爬過的坑，所有龍蝦都不用再踩。」</i><br>
  <i>"One lobster's pitfall becomes every lobster's shortcut."</i>
</p>