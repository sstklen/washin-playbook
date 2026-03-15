---
name: l4-task-engine-iterative-tuning
description: |
  Iteratively tune multi-step LLM task engines (L4/orchestration systems) through cascading bug discovery.
  Trigger: (1) Building LLM-orchestrated task systems with planner + executor, (2) Task engine produces
  wrong/hallucinated results, (3) Multi-dependency data flow bugs, (4) Need systematic quality improvement
  for complex agent workflows. Includes: run-review-fix loop, multi-dependency data overwrite detection,
  anti-hallucination prompt patterns, planner prompt engineering rules.
version: 1.0.0
date: 2026-02-18
author: Washin Village + Claude
---

# L4 Task Engine Iterative Tuning

> Systematically improve multi-step LLM orchestration systems through cascading bug discovery

## Problem

When building L4 task engines (systems where an LLM planner creates a multi-step execution plan, then executors run each step), quality issues emerge in layers:

1. **Invisible bugs**: Later bugs hide behind earlier bugs — you can't see them until previous issues are fixed
2. **Multi-dependency data loss**: When a step depends on multiple prior steps, naive implementations lose all but the last dependency's data
3. **Cheap LLM hallucination**: Budget models (Groq, Haiku) will confidently fabricate data unless explicitly instructed not to
4. **Planner prompt gaps**: Generic planner prompts produce low-quality plans for specialized domains (research, pricing analysis, etc.)

## Context / Trigger Conditions

Use this methodology when:

- Building or debugging LLM task orchestration systems (planner + multi-step executor)
- Task engine returns plausible but incorrect results (especially hallucinated data)
- Steps with multiple dependencies mysteriously "forget" earlier data
- Quality plateaus despite fixing individual bugs
- Research/analysis tasks need domain-specific planning rules

**Not needed for:**
- Simple single-step LLM calls
- Deterministic pipelines without LLM decision-making
- Systems where all bugs are immediately visible

## Solution

### Core Methodology: Run → Review → Fix → Rerun

```
Round 1: Run task → Opus reviews all outputs → Find 3 bugs → Fix
         ↓
Round 2: Rerun → Review → Find 1 NEW bug (was hidden before) → Fix
         ↓
Round 3: Rerun → Review → Quality passes ✅
```

**Key insight**: Each round reveals bugs that were INVISIBLE until the previous round's bugs were fixed. This is **cascading discovery**.

### Discovery 1: Multi-Dependency Data Overwrite Bug

**Symptom**: Step depends on steps 1-6, but only uses data from step 6.

**Root cause**: Naive `fillStepParams()` loops through dependencies and overwrites `params.prompt` on each iteration:

```typescript
// ❌ BAD: Each loop overwrites params.prompt
for (const depNum of step.dependsOn) {
    const depResult = await getStepResult(depNum);
    params.prompt = `${depResult.content}\n\nAnalyze: ${goal}`;
}
// Only step 6's data survives!
```

**Fix pattern**: Accumulate-then-assemble

```typescript
// ✅ GOOD: Accumulate data in loop, assemble after
for (const depNum of step.dependsOn) {
    const depResult = await getStepResult(depNum);
    const existing = (params._accumulatedData as string) || '';
    const newData = `\n--- Step ${depNum} (${depResult.toolId}) ---\n${content}`;
    params._accumulatedData = existing + newData;
}

// AFTER loop: assemble final prompt from all accumulated data
if (step.toolId === 'smart-llm' && params._accumulatedData) {
    params.prompt = `Data:\n${params._accumulatedData}\n\nAnalyze: ${originalGoal}`;
    delete params._accumulatedData;
}
```

**Detection**: If a step has `dependsOn: [1,2,3,4,5,6]` but output only references step 6's data, you have this bug.

### Discovery 2: Anti-Hallucination in Synthesize Prompts

**Symptom**: Final synthesis step fabricates pricing/numbers not found in prior steps.

**Root cause**: Cheap LLMs will confidently invent data to "complete" the answer.

**Fix**: Add explicit anti-hallucination instruction to synthesize prompts:

```typescript
// ❌ BAD: Generic synthesize prompt
params.prompt = `Summarize the research findings.`;

// ✅ GOOD: Explicit anti-fabrication instruction
params.prompt = `Summarize the research findings.

CRITICAL: Only use data that actually appears in the step results above.
If any data is missing, write "Not found" — DO NOT fabricate numbers or facts!`;
```

**Effect**: Reduces hallucination dramatically, especially with Groq/Flash models.

### Discovery 3: Planner Prompt Engineering for Domains

**Problem**: Generic planner prompts produce low-quality plans for specialized tasks (research, pricing analysis, technical comparison).

**Solution**: Add domain-specific rules to planner system prompt:

```typescript
// Example: Research task rules
const plannerSystemPrompt = `You are a task planner...

For research tasks, follow these rules:
1. params.query must be in English (even if goal is in Chinese) — search engines work better
2. Read official pricing pages directly (search → read → extract), don't just search
3. Search GitHub stars as a separate step (star counts need dedicated search)
4. Use exa_search for technical content, perplexity_search for recent news/events
5. Always end with a synthesize step that combines all findings
`;
```

**Key rules that work**:
- Language specification (English queries for better search results)
- Multi-step decomposition (search → read → extract, not just search)
- Tool selection guidance (when to use which search tool)
- Mandatory synthesis step

**Effect**: Plan quality improves immediately, fewer "search-only" plans that miss critical data.

### Discovery 4: Iterative Review Protocol

**Process**:

1. **Run**: Execute full task, save all step outputs
2. **Review**: Use Opus in NEW context to review (fresh eyes)
   ```
   Review this task execution:
   - Goal: [original goal]
   - Plan: [steps]
   - Outputs: [all step results]

   Check for:
   1. Missing data in synthesize (hallucination?)
   2. Steps with multiple dependencies — do they use ALL dependency data?
   3. Search queries in wrong language?
   4. Planner chose wrong tools?
   ```
3. **Fix**: Address bugs in order of severity (data loss > hallucination > inefficiency)
4. **Rerun**: Same task, measure quality improvement

**Stopping criteria**:
- Quality score (manual or automated) passes threshold (e.g., 0.70)
- No new bugs found in 2 consecutive rounds
- Diminishing returns (round N finds <20% bugs of round N-1)

## Verification

After implementing fixes:

1. **Multi-dependency test**: Create task with step that depends on 3+ prior steps, verify output references ALL dependencies
2. **Hallucination test**: Run research task, check if synthesis fabricates data not in sources
3. **Plan quality test**: Run 5 domain tasks, verify planner follows domain rules (English queries, multi-step extraction, etc.)
4. **Cascading discovery**: Round 1 should find 3+ bugs, Round 2 should find new bugs, Round 3 should pass

Expected outcomes:
- Round 1: 3-5 bugs (timeout, hallucination, planner gaps)
- Round 2: 1-2 bugs (data overwrite, edge cases)
- Round 3: Quality 0.70+ passes

## Example: L4 Task Engine 3-Round Tuning

**Task**: Research AI API pricing + GitHub stars

### Round 1: Initial Run

**Bugs found**:
1. Timeout (15s too short for multi-step)
2. Hallucination (fabricated prices not in sources)
3. Planner used Chinese queries (poor search results)

**Fixes**:
- Increase timeout to 180s
- Add anti-hallucination instruction to synthesize
- Add "queries must be English" to planner rules

### Round 2: After Round 1 Fixes

**New bugs revealed** (were hidden behind Round 1 bugs):
1. Data overwrite bug: Synthesize step depended on steps 1-6 but only got step 6's data

**Fixes**:
- Implement accumulate-then-assemble pattern in `fillStepParams()`

### Round 3: After Round 2 Fixes

**Result**: Quality 0.70, all pricing data accurate, no fabrication ✅

**Key learning**: The data overwrite bug was INVISIBLE in Round 1 because hallucination masked it — we thought synthesis was making up data, but actually it just didn't have the data!

## Notes

### Why Cascading Discovery Works

Bugs hide behind other bugs:
- Round 1: Fix timeout → can now see outputs → discover hallucination
- Round 2: Fix hallucination → can now trust outputs → discover data loss
- Round 3: Fix data loss → quality passes

You CANNOT see all bugs in Round 1 because later bugs are masked by earlier bugs.

### Cost Optimization

- Use cheap executors (Groq, Haiku) for speed
- Use Opus ONLY for review (new context = fresh perspective)
- Review is cheap (~1K tokens) vs rewriting entire system

### When to Stop Tuning

- Quality threshold met (0.70+)
- Diminishing returns (<1 bug per round)
- Cost exceeds benefit (if each bug saves $X, stop when fix cost > $X)

### Common Pitfalls

1. **Skipping review step**: Trusting "it looks good" without systematic review
2. **Fixing in wrong order**: Fix data loss BEFORE optimizing query language
3. **Single-round mentality**: Expecting all bugs visible in Round 1
4. **Over-tuning**: Chasing 0.95 when 0.70 is sufficient

## References

- [Building agents with the Claude Agent SDK](https://claude.com/blog/building-agents-with-the-claude-agent-sdk)
- Related skill: `multi-agent-workflow-design` — for parallel agent patterns
- Related skill: `ai-prompt-mastery` — for anti-hallucination techniques

---

*Made with 🐾 by [Washin Village](https://washinmura.jp)*
