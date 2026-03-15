---
name: llm-api-cost-optimization
description: |
  Claude API 成本優化完整策略（官方驗證 ✅）。使用情境：(1) 想節省 API 成本，
  (2) 批量任務處理，(3) 設計 API 定價策略，(4) 需要成本公式計算，
  (5) 基於帳單數據創建案例研究，(6) 系統提示重複使用想省 90%，
  (7) AI API 開放收費方案設計，(8) Token 成本導向定價，(9) 訂閱制 vs 按次計費。
  包含 Batch API 50%、Prompt Caching 90%（cache_control 實現、緩存命中率監控）、
  三階段進程（基礎→規模化→本地化）、API 定價公式（成本×加成倍數）、毛利計算、
  隱私保護最佳實踐（GDPR 2026）。所有數據經官方文檔 + 實測驗證（294 影片 Batch 測試）。
argument-hint: [batch|cache|pricing|calculate|case-study]
version: 1.2.0
date: 2026-02-10
---

# Claude API Cost Optimization 💰

> **官方驗證 ✅** — 省 50-90% API 成本的完整策略

## Quick Reference

| Technique | Savings | Use When |
|-----------|---------|----------|
| **Batch API** | 50% | Tasks can wait up to 24h |
| **Prompt Caching** | 90% | Repeated system prompts (>1K tokens) |
| **Extended Thinking** | ~80% | Complex reasoning tasks |
| **Batch + Cache** | ~95% | Bulk tasks with shared context |

## Key Discoveries (Not in Official Docs)

| Discovery | Details |
|-----------|---------|
| **Bigger batches = Faster** | 294 requests finished before 10 requests! |
| **22x efficiency gap** | Large batch: 0.45 min/req vs Small: 9.84 min/req |
| **Not FIFO** | Anthropic prioritizes bigger batches |
| **Image cache = only 14%** | Not 90%! (Images can't be cached) |

## TL;DR

```
Want to save money? → Batch 100+ requests together
Want to save time?  → Also batch 100+ (they finish first!)
Working with images? → Batch API is enough (cache doesn't help much)
Working with text?   → Use both Batch + Cache (up to 95% savings)
```

## Code Examples

### Prompt Caching (90% off)
```python
response = client.messages.create(
    model="claude-sonnet-4-5",
    system=[{
        "type": "text",
        "text": "Your long system prompt (>1024 tokens)...",
        "cache_control": {"type": "ephemeral"}  # ← This saves 90%!
    }],
    messages=[{"role": "user", "content": "Hello"}]
)
```

### Batch API (50% off)
```python
batch = client.messages.batches.create(
    requests=[
        {"custom_id": "task-001", "params": {...}},
        # Add up to 100,000 requests!
    ]
)
```

## Additional Resources

- For Batch API details, see [references/batch-api.md](references/batch-api.md)
- For Prompt Caching, see [references/prompt-caching.md](references/prompt-caching.md)
- For Extended Thinking, see [references/extended-thinking.md](references/extended-thinking.md)
- For real case study (294 videos), see [examples/batch-294-videos-case-study.md](examples/batch-294-videos-case-study.md)

## Pricing Reference (2026)

| Model | Input | Output | Batch Input | Batch Output |
|-------|-------|--------|-------------|--------------|
| Opus 4.5 | $5/MTok | $25/MTok | $2.50/MTok | $12.50/MTok |
| Sonnet 4.5 | $3/MTok | $15/MTok | $1.50/MTok | $7.50/MTok |
| Haiku 4.5 | $1/MTok | $5/MTok | $0.50/MTok | $2.50/MTok |

| Cache Type | Price | vs Normal |
|------------|-------|-----------|
| Cache write | $3.75/MTok | +25% (first time) |
| **Cache read** | **$0.30/MTok** | **-90%** ✅ |

## 🎯 三階段成本優化進程

```
╔═══════════════════════════════════════════════════════════════════╗
║  Phase 1: 打基礎（Day 1）→ 成本降至 ~20%                            ║
║  ├── Prompt Caching → 輸入省 90%（>1K tokens 的 System Prompt）      ║
║  ├── Haiku 智能分流 → 簡單任務用便宜模型（省 12x）                     ║
║  └── 立即可用，無需等待                                              ║
╠═══════════════════════════════════════════════════════════════════╣
║  Phase 2: 規模化（有流量後）→ 成本降至 ~5%                           ║
║  ├── Batch API → 批量任務再省 50%（可等 24h 的任務）                  ║
║  ├── Response Caching → 重複問題 0 成本（500+ 對話後有意義）           ║
║  └── 需要累積足夠流量才能發揮效果                                     ║
╠═══════════════════════════════════════════════════════════════════╣
║  Phase 3: 自主化（終極目標）→ 成本趨近 0                              ║
║  ├── Fine-tuned 小模型（用自己數據訓練）                              ║
║  ├── 本地部署（Llama 3、Mistral 等開源模型）                          ║
║  └── 需要大量數據 + 技術投入                                          ║
╚═══════════════════════════════════════════════════════════════════╝
```

### 進程核心理念

> **基礎打好 → 成本越來越便宜 → 最後本地化**

這不是選擇題，而是漸進式的成本優化旅程：
- 每個階段都建立在前一階段的基礎上
- 數據累積越多，可解鎖的優化越多
- 最終目標是擁有自己的本地方案

## 🐾 Real-world API Application Example

### 成本結構

| 階段 | 成本/次 | 售價/次 | 毛利 |
|------|--------|--------|------|
| 無優化 | ¥2.3 | ¥10 | 77% |
| +Caching | ¥0.75 | ¥5 | 85% |
| +Batch | ¥0.38 | ¥5 | 92% |

### 定價公式

```python
售價 = API成本 × 加成倍數（建議 4x）

# 現在（Sonnet + Caching）
cost = 0.75  # ¥
price = cost * 4  # ¥3 → 取整 ¥5/次
margin = (5 - 0.75) / 5  # 85%

# 未來（Opus 或更強模型）
# 成本上升 → 售價跟著調整 → 毛利維持 60%+
```

### 詳細定價方案

見：[Jelly AI API 定價策略](../../../Desktop/Antigravity/00Antigravity%20+%20Claude%20Code%20超強工作台/0和心動物村/03-specs/jelly-ai-api-pricing-plan.md)

## 📝 Creating Case Studies from Billing Data

### When to Create Case Studies

Create case studies when you have:
- Real API billing data (CSV exports from Anthropic Console)
- Significant cost savings (>50%) worth documenting
- A compelling story (project context, challenges, solutions)
- Permission to share (privacy-compliant data)

### Privacy & Anonymization Best Practices (GDPR 2026)

**DO:**
- ✅ Use **aggregated statistics** (total tokens, total cost, percentages)
- ✅ **Remove all identifiers**: API keys, batch IDs, organization names
- ✅ Use **generic descriptions**: "video tagging task" not "customer X project"
- ✅ **Anonymize or obtain consent** before sharing any customer data
- ✅ Apply **data minimization**: only include data necessary for the case study

**DON'T:**
- ❌ Include API keys, tokens, or authentication credentials
- ❌ Share batch IDs or request IDs (can be used to identify accounts)
- ❌ Reveal internal system names or proprietary workflows
- ❌ Include personally identifiable information (PII)

### Case Study Structure (Technical Writing 2026)

Based on [Pronovix developer portal best practices](https://pronovix.com/blog/function-api-use-cases-case-studies-developer-portals):

```markdown
# [Project Name] - [Task Type] Case Study

> **Date**: YYYY-MM-DD
> **Source**: [Organization/Project] - [Brief context]

## 📊 Executive Summary
- Task description (what was processed)
- Key results (cost, time, success rate)
- Technical approach (APIs/features used)

## 🎯 Challenge
- Problem statement
- Why standard approach was insufficient
- Budget/time constraints

## 💡 Solution
- Technical strategy (Batch API + Prompt Caching, etc.)
- Implementation details (split batching, cache structure)
- Code examples (Python/TypeScript snippets)

## 📈 Results
- Cost breakdown table (input/output/cache tokens)
- Savings calculation (vs standard API)
- Time to completion
- Success rate

## 🔍 Key Findings
- Non-obvious discoveries
- Optimization insights
- Lessons learned

## 📦 Code Example
```python
# Complete, runnable example
# (anonymized but functional)
```

## ✅ Verification
- How to reproduce results
- What to measure
- Expected outcomes

## 🎓 Takeaways
- Who should use this approach
- When to apply these techniques
- Next optimization steps
```

### From CSV to Case Study: Workflow

**Step 1: Extract Data**
```python
import pandas as pd

# Load billing CSV
df = pd.read_csv('claude_api_cost_2026_02_02.csv')

# Aggregate by category
summary = df.groupby('cache_type').agg({
    'input_tokens': 'sum',
    'output_tokens': 'sum',
    'cost_usd': 'sum'
})

# Calculate percentages
summary['cost_pct'] = summary['cost_usd'] / summary['cost_usd'].sum() * 100
```

**Step 2: Calculate Savings**
```python
# Actual cost (from CSV)
actual_cost = df['cost_usd'].sum()

# Standard API cost (without optimization)
standard_input = df['input_tokens'].sum() * 3.00 / 1_000_000
standard_output = df['output_tokens'].sum() * 15.00 / 1_000_000
standard_cost = standard_input + standard_output

# Savings
savings = standard_cost - actual_cost
savings_pct = (savings / standard_cost) * 100
```

**Step 3: Anonymize**
```python
# Replace identifiers
batch_ids = df['batch_id'].unique()
anonymized = {bid: f"batch_{i+1}" for i, bid in enumerate(batch_ids)}

# Remove sensitive columns
safe_df = df.drop(columns=['api_key', 'org_id', 'project_name'])
```

**Step 4: Create Narrative**
- Add project context (what/why)
- Explain technical decisions
- Share key findings
- Include brand story (if public/open-source)

### Brand Integration (Non-Commercial)

For open-source/non-profit projects, case studies can include:
- **Mission statement**: Brief description of organization/project
- **Why this matters**: How cost savings enable the mission
- **Open-source contributions**: Links to related tools/skills
- **Community value**: How others can benefit

**Example** (Washin Village):
```markdown
> **From**: [Washin Village](https://washinmura.jp) -
> Animal sanctuary in Boso Peninsula, Japan

**Mission**: AI behavior tagging for 28 rescue cats & dogs

**Why this matters**: As a non-profit, budget constraints
meant we couldn't afford $714/batch. This optimization
($5.32) made AI analysis accessible.
```

### Tools & Formats

**Documentation formats:**
- Markdown (`.md`) - for GitHub repos, developer portals
- Jupyter Notebook (`.ipynb`) - for interactive analysis
- PDF - for formal reports, presentations

**Visualization:**
```python
import matplotlib.pyplot as plt

# Cost breakdown pie chart
plt.pie(summary['cost_usd'], labels=summary.index, autopct='%1.1f%%')
plt.title('Cost Distribution: Input vs Output vs Cache')
plt.savefig('cost_breakdown.png')
```

### Multi-Document Strategy

**For comprehensive updates:**
1. **Standalone case study** (`examples/project-name-case-study.md`)
   - Complete technical details
   - Full code examples
   - Reproducible workflow

2. **README update** (summary section)
   - Key metrics table
   - Link to full case study
   - Quick takeaways

3. **STORY update** (narrative)
   - Human-readable story
   - Context and motivation
   - Lessons learned

### Quality Checklist

Before publishing:
- [ ] All API keys/credentials removed
- [ ] Batch IDs anonymized or removed
- [ ] Cost calculations verified (match CSV)
- [ ] Code examples are runnable
- [ ] Links work (internal references)
- [ ] Privacy compliance (GDPR/CCPA)
- [ ] Value proposition clear (who benefits?)

## Related Skills

- **agentic-coding-complete** — Foundation for AI coding agents
- **ai-api-cost-based-pricing** — API 成本導向定價策略

## References

**Official Documentation:**
- [Claude API Pricing (Official)](https://www.anthropic.com/pricing)
- [Prompt Caching Guide](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching)
- [Batch API Guide](https://docs.anthropic.com/en/docs/build-with-claude/batch-processing)
- [和心村 294 影片實測報告](examples/batch-294-videos-case-study.md)

**Case Study Best Practices (2026):**
- [API Use Cases & Case Studies on Developer Portals](https://pronovix.com/blog/function-api-use-cases-case-studies-developer-portals) - Pronovix
- [API Monetization Strategies: Best Practices & Billing Guide](https://www.digitalapi.ai/blogs/api-monetization-strategies-best-practices-billing-guide)
- [How To Write API Documentation: Examples & Best Practices](https://devcom.com/tech-blog/how-to-write-api-documentation/) - Devcom

**Privacy & Compliance (GDPR 2026):**
- [10 Essential Consumer Data Protection Practices for 2026](https://www.cookieyes.com/blog/consumer-data-protection/) - CookieYes
- [Customer Data Privacy: A CX Guide for 2026](https://www.zendesk.com/blog/customer-data-privacy/) - Zendesk
- [Global Privacy Trends and Best Practices for Compliance in 2026](https://www.schellman.com/blog/privacy/global-privacy-compliance-trends-in-2026) - Schellman

---

## Merged Skills (archived)

The following skills have been merged into this guide:
- **prompt-caching-cost-optimization** — Prompt Caching 實現細節、cache_control 配置、緩存命中率監控、多層緩存策略
- **ai-api-cost-based-pricing** — AI API 定價公式、訂閱方案設計、毛利計算、動態定價機制、B2B vs B2C 策略

---

*Part of 🥋 AI Dojo Series by [Washin Village](https://washinmura.jp) 🐾*
