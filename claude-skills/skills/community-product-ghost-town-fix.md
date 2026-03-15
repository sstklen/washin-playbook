---
name: community-product-ghost-town-fix
description: |
  Fix the "Ghost Town" anti-pattern in community/marketplace products before beta launch.
  Use when: (1) Admin-seeded data shows 0 contributors because admin keys lack user attribution,
  (2) Status thresholds designed for scale show "urgent/critical" when only 1 item exists per category,
  (3) Leaderboards and dashboards are empty despite the product being functional,
  (4) Planning beta test and realizing new users will see a dead-looking product.
  Covers: status threshold adjustment, admin-as-founder attribution, user-perspective QA checklist.
  Core insight: Engineers plan beta from infrastructure view (monitoring, alerts, capacity)
  but users experience the product from emotional view (is this alive? is anyone here? what do I do?).
version: 1.0.0
date: 2026-02-13
---

# Community Product Ghost Town Fix

## Problem

When launching a community/marketplace product for beta testing, the initial state
often looks dead — even when the system is fully functional. This creates a terrible
first impression: new users walk in, see emptiness, and leave.

**Root cause:** Thresholds, metrics, and UI were designed for scale (100+ users),
not for the seed state (1 admin + 0 users).

## Context / Trigger Conditions

You should apply this skill when:

- About to invite beta testers (10-100 people) to a community product
- Dashboard shows "0 contributors" despite admin having seeded data
- All status indicators show negative states (red/urgent/critical) with small data
- Leaderboards are empty
- The product works perfectly but *looks* broken or abandoned
- You catch yourself planning beta prep as "monitoring + alerts" instead of
  thinking about what users actually see and feel

## Solution

### 1. Fix Status Thresholds (The Red Light Problem)

**Anti-pattern:** Thresholds designed for scale show everything as "urgent"

```
BAD:  if (activeKeys < 3) → "urgent" 🔴     // 1 key = red = looks broken
GOOD: if (activeKeys === 0) → "recruiting" 🔴  // 0 keys = actually needs help
      if (activeKeys >= 1) → "running" 🟢      // 1+ keys = it works!
```

**Rule:** In seed state, "functional" should look positive, not desperate.

| Items | Seed-friendly status | Scale status (later) |
|-------|---------------------|---------------------|
| 0     | Recruiting / Needed | Critical |
| 1     | Running / Active    | Low |
| 2-4   | Running / Active    | Moderate |
| 5+    | Healthy             | Healthy |

### 2. Count Admin as Founder (The Zero Contributor Problem)

**Anti-pattern:** Admin-seeded data has no `contributor_user_id`, so metrics show 0

```sql
-- BAD: Only counts user-contributed items
SELECT COUNT(DISTINCT contributor_user_id) FROM items
WHERE contributor_user_id IS NOT NULL

-- GOOD: Admin items count as 1 founder
SELECT COUNT(DISTINCT contributor_user_id) FROM items
WHERE contributor_user_id IS NOT NULL  -- user contributors
UNION
SELECT CASE WHEN EXISTS(
  SELECT 1 FROM items WHERE contributor_user_id IS NULL
) THEN 1 ELSE 0 END  -- admin = 1 founder
```

**Result:** "1 founder" instead of "0 contributors" — completely different feeling.

### 3. User-Perspective QA Checklist (Before Inviting Anyone)

Walk through the product as a brand new user and check:

| Check | Question | Red flag |
|-------|----------|----------|
| First screen | Does it look alive or dead? | Empty lists, all-red statuses |
| Value prop | Do I understand what this is in 10 seconds? | Jargon, developer-speak |
| First action | Can I DO something immediately? | Only "read docs" as option |
| Social proof | Do I see other humans here? | "0 users", empty leaderboard |
| Fun factor | Is there anything engaging right now? | Only serious/technical features |
| Return hook | Why would I come back tomorrow? | No daily/recurring activities |

### 4. The "What Do Non-Technical Friends Do?" Test

If your beta testers include non-developers:
- Are there activities that don't require coding? (Games, voting, social)
- Is the navigation label meaningful? ("Festival" > "API Docs")
- Can they earn/spend/interact within 2 minutes of signing up?

## Verification

After applying fixes:
1. Load the public dashboard/pool page — should show mostly green, not red
2. Check contributor count — should be >= 1 (admin/founder)
3. Walk through signup flow as new user — should feel alive, not empty
4. Ask yourself: "Would I stay if I just arrived?"

## Example (Real Case)

**Before fix:**
```
Pool Status: 17 services, ALL showing 🔴 "urgent"
Contributors: 0
Leaderboard: empty
First impression: "Nobody uses this"
```

**After fix (3 code changes):**
```
Pool Status: 13 🟢 "running" + 4 🔴 "recruiting"
Contributors: 1 (founder)
Leaderboard: still empty, but status feels alive
First impression: "Most things work, some need help"
```

**Changes made:**
1. Status threshold: `activeKeys < 3` → `activeKeys === 0` for red status
2. Contributor count: include admin-seeded items as 1 founder
3. Status labels: "urgent" → "recruiting" (inviting tone vs panic tone)

## Notes

- This is a **seed-state optimization** — as real users join, the thresholds
  naturally become irrelevant
- Don't fake data (fake users, fake activity) — just make real data look accurate
- The emotional difference between "0" and "1" is infinite; "1" and "2" is minimal
- Engineers naturally think "monitoring + capacity" for beta prep;
  force yourself to think "what does the user SEE and FEEL" first
- Consider adding fun/engagement features (games, daily activities) prominently
  in navigation — they're more important than docs for non-developer beta testers

See also: `supply-side-honeymoon-incentive` (related: incentivizing early contributors)
