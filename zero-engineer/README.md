<p align="center">
  <h1 align="center">Zero Engineer</h1>
  <p align="center"><strong>How an animal sanctuary owner in rural Japan — zero engineering background, 28 cats and dogs — built a production API platform using only AI agents.</strong></p>
  <p align="center">30+ API integrations. Token economy. Docker deployment. Multi-language support.<br>Zero hired developers. Every lesson learned the hard way.</p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Engineers_Hired-Zero-red?style=for-the-badge" alt="Zero Engineers"/>
  <img src="https://img.shields.io/badge/APIs_Shipped-30+-green?style=for-the-badge" alt="30+ APIs"/>
  <img src="https://img.shields.io/badge/Built_With-AI_Agents-blue?style=for-the-badge" alt="AI Agents"/>
</p>

<p align="center">
  <a href="https://github.com/sstklen/zero-engineer/stargazers"><img src="https://img.shields.io/github/stars/sstklen/zero-engineer?style=social" alt="Stars"/></a>
</p>

<p align="center">
  <img src="images/sanctuary-cats.jpg" alt="Washin Village — 28 cats and dogs at the sanctuary cat cafeteria" width="600"/>
  <br>
  <sub>Where this was built: the cat cafeteria at <a href="https://washinmura.jp">Washin Village</a>, rural Japan.</sub>
</p>

---

## This is not a tutorial.

This is a real story. Every number is real. Every failure happened. Every lesson cost hours.

I run an animal sanctuary in rural Japan. 28 cats and dogs. My background is in business, not code. I'd never written a line of JavaScript before 2025.

In 7 months, I built a production API platform — live, serving real users, handling real money — using AI coding agents as my entire engineering team.

**This document is exactly how.**

---

## The Numbers

| Metric | Value |
|--------|-------|
| **APIs integrated** | 30+ (translation, vision, search, social media) |
| **Lines of code** | ~50,000 |
| **Engineers hired** | 0 |
| **Monthly AI subscription cost** | ~$500 |
| **Time to build** | 7 months |
| **Production uptime** | 99.5%+ |
| **Skills extracted** | [112 reusable patterns](https://github.com/sstklen/washin-claude-skills) |
| **Bugs survived** | 200+ (each one became a skill) |
| **3am outages** | More than I'd like to admit |

---

## Chapter 1: The Naive Beginning

**Month 1 — "How hard can it be?"**

I wanted to build an API marketplace. Something that would let AI agents access various services through a single platform. I'd seen enough tech Twitter to know the tools existed.

My plan was simple:
1. Tell Claude what I want
2. It writes the code
3. I deploy it
4. Profit

Here's what actually happened:

```
Day 1:  "Build me an API server"
        → Claude writes beautiful code
        → I have no idea how to run it

Day 2:  "How do I run this?"
        → Learn about npm, bun, node
        → Pick bun because Claude said it's fast

Day 3:  "It works on my laptop!"
        → Try to deploy
        → What's a VPS? What's Docker? What's SSH?

Day 7:  First endpoint goes live
        → It crashes under first real request
        → The error message means nothing to me
```

**Lesson learned:** AI can write code. But code is only 20% of shipping software. The other 80% is everything nobody tells you about — deployment, monitoring, error handling, security, databases, DNS, SSL, Docker networking...

---

## Chapter 2: The AI Team

**Month 3-4 — "One agent isn't enough"**

Claude Code is incredible at thinking and planning. But it can't see images. It can't search the web in real-time. And it gets expensive if you ask it to do bulk mechanical work.

So I built a team:

```
┌─────────────────────────────────────────────┐
│              Claude Code (Boss)              │
│   Plans, architects, writes complex logic    │
└──────────┬────────────────────┬──────────────┘
           │                    │
    ┌──────▼──────┐     ┌──────▼──────┐
    │  Codex CLI  │     │ Gemini CLI  │
    │  "Muscle"   │     │   "Eyes"    │
    │  Bulk work  │     │  Vision +   │
    │  Background │     │  Research   │
    └─────────────┘     └─────────────┘
```

| Agent | What it does | What it can't do |
|-------|-------------|-----------------|
| **Claude Code** | Architecture, complex logic, debugging | See images, search web |
| **Codex CLI** | Rename 20 files in 2 min, run tests | Make judgment calls |
| **Gemini CLI** | Read PDFs, analyze screenshots, web search | Write reliable code (hallucinates) |

The key insight: **the human doesn't decide which agent to use.** Claude Code (the Boss) decides. I just say what I want. The Boss dispatches.

> Full orchestration details: [multi-agent-coding](https://github.com/sstklen/multi-agent-coding)

---

## Chapter 3: The 3am Bugs

**Month 4-5 — "Everything breaks at night"**

Here's something nobody warns you about: production bugs don't happen during office hours. They happen at 3am when your VPS runs out of memory during a Docker build. Or when your SQLite database corrupts because you used `await` inside a synchronous transaction. Or when your auth middleware silently stops working because of a route registration order.

Some real incidents:

### The OOM Kill (Month 3)

```
2:47 AM — Docker build starts on 2GB VPS
2:52 AM — Linux OOM killer activates
2:52 AM — SSH connection drops
2:52 AM — Website goes down
2:53 AM — All Docker containers killed
3:30 AM — Finally get SSH back via cloud console
4:15 AM — Service restored
```

**What I learned:** Never run `docker build` on a small VPS with running containers. Build locally, push images.

### The Auth Bypass (Month 4)

```
Discovered that mounting two Hono sub-routers at similar paths
(/api/v1 and /api/v1/admin) caused auth middleware to silently
skip on certain routes.

Translation: anyone could access admin endpoints.

We caught it in testing. Barely.
```

**What I learned:** Framework routing order matters more than documentation suggests. Always test auth from the outside.

### The Phantom Refund (Month 4)

```
Pre-deduct billing system: charge first, then call API.
If API fails, refund.

Bug: the refund code was inside a try/catch that also covered
the validation step. Validation failure → refund → user gets
free credits they never had.

Lost: not much (caught early)
Could have lost: everything
```

**What I learned:** A billing bug that gives users free money will drain your treasury before you notice.

---

## Chapter 4: What Actually Works

**Month 6-7 — "The system starts to work"**

After 200+ bugs, something remarkable happened: **the bugs started repeating.** Not exactly — but the patterns did. Docker issues. Auth issues. Database issues. Billing edge cases.

So I started extracting every bug fix into a reusable "skill" — a markdown file that Claude Code automatically loads when it encounters a similar problem.

```
Month 1: Every bug = 2-4 hours of panic
Month 3: Every bug = 30-60 minutes of debugging
Month 6: Most bugs = instant fix from skill library
```

The result: [112 battle-tested skills](https://github.com/sstklen/washin-claude-skills) covering:

- 🐛 **10 production bug patterns** (each one cost hours so it won't cost you)
- 🔒 **5 security patterns** (auth bypass, brute-force, API audit)
- 🐳 **7 Docker/DevOps patterns** (OOM, ghost containers, WAL traps)
- 🏗️ **9 API architecture patterns** (multi-provider gateway, quota enforcement)
- 💰 **5 billing/token patterns** (phantom refunds, rounding traps)
- ⚡ **7 Hono/Bun patterns** (framework-specific gotchas)

---

## Chapter 5: The Honest Truth

### What AI is good at

- Writing code from clear specifications
- Debugging with good error messages
- Refactoring mechanical changes across many files
- Explaining what code does
- Finding security issues when asked to look

### What AI is bad at

- **Knowing what to build.** AI will build exactly what you ask for. If you ask for the wrong thing, you get the wrong thing fast.
- **Ops knowledge.** AI writes great code but doesn't feel the pain of 3am outages. You have to teach it through skills.
- **Saying "I don't know."** Especially Gemini. It will confidently tell you it's fixed everything when it hasn't even found the right file.
- **Understanding your business.** AI doesn't know that the `/translate` endpoint makes money and the `/health` endpoint doesn't. You provide the judgment.

### The real skill

The real skill of being a "zero engineer" isn't prompting. It's **judgment**.

- When to trust the AI's output vs. when to verify
- When to build vs. when to buy
- When to fix a bug vs. when to redesign the system
- When to stay up fixing the 3am outage vs. when to let it wait

AI handles the *how*. You handle the *what* and the *why*.

---

## The Stack

For anyone wanting to follow a similar path:

| Layer | Choice | Why |
|-------|--------|-----|
| Runtime | Bun | Fast, built-in SQLite, TypeScript native |
| Framework | Hono | Lightweight, great middleware system |
| Database | SQLite (via Bun) | Zero config, embedded, good enough for most things |
| Reverse proxy | Caddy | Auto-HTTPS, simple config |
| Deployment | Docker on VPS | Full control, predictable costs |
| AI (Boss) | Claude Code | Best at architecture and complex reasoning |
| AI (Muscle) | Codex CLI | Best at bulk mechanical work |
| AI (Eyes) | Gemini CLI | Best at vision and research |

**Total monthly cost:** ~$500 AI subscriptions + ~$50 VPS = **$550/month** for a full "engineering team."

For context, that's a fraction of what a single engineering hire would cost.

---

## FAQ

**Q: Do I need to know how to code?**

You need to learn to *read* code. Not write it — AI does that. But you need to understand what you're looking at well enough to spot when something is wrong. This takes about 2-3 months of daily practice.

**Q: Which AI should I start with?**

Claude Code. Just Claude Code. Don't start with multiple agents — it's like trying to manage a team before you've done the job yourself. Add Codex and Gemini later when you hit specific limitations.

**Q: How much does it cost?**

~$500/month for AI subscriptions (Claude Max + ChatGPT Pro + Google AI). You can start with just Claude Max (~$200/month) and add others as needed.

**Q: What's the hardest part?**

Deployment. Writing code is the easy part. Getting it to run reliably on a server, with HTTPS, with proper auth, with monitoring, with backups — that's where 80% of the struggle is.

**Q: Is the code quality good?**

Honestly? It's inconsistent. Some parts are elegant. Some parts are held together with duct tape. But it works, it's secure (after many security audits), and it serves real users. That's what matters.

**Q: Would you hire a real engineer now?**

If I could afford one, yes — for architecture review and the stuff AI consistently gets wrong (complex distributed systems, performance optimization). But for 80% of features? AI handles it.

---

## Timeline

```
2025 Aug — First "hello world" API endpoint
2025 Sep — First paying user
2025 Oct — First 3am outage (OOM kill)
2025 Nov — Multi-agent system established
2025 Dec — 10 API integrations live
2026 Jan — Token economy launched
2026 Feb — 30+ APIs, 112 skills extracted, this story written
```

---

## Resources

Everything I built and learned is open source:

| Project | What it is |
|---------|-----------|
| [**112 Claude Code Skills**](https://github.com/sstklen/washin-claude-skills) | Every pattern we extracted — install in 10 seconds |
| [**Multi-Agent Coding**](https://github.com/sstklen/multi-agent-coding) | How to orchestrate Claude + Codex + Gemini |
| [**AI Prompt Mastery**](https://github.com/sstklen/ai-prompt-mastery) | One prompt to make any AI respond like an expert |
| [**AI API Benchmark**](https://github.com/sstklen/washin-api-benchmark) | Monthly tests of 30+ AI APIs from Tokyo |
| [**YanHui Debug AI**](https://github.com/sstklen/yanhui-ci) | CI debug tool — shared knowledge base |
| [**AEO Page**](https://github.com/sstklen/aeo-page) | Make AI recommend your business |
| [**Auto-Tidy**](https://github.com/sstklen/auto-tidy) | Say "goodnight" and your project cleans itself |

---

## One Last Thing

I still can't write a for-loop from memory. I still Google what `async` means sometimes. I still panic when I see a stack trace. (Though I can now read a stack trace faster than most people read a menu.)

But I shipped a production API platform that real people use and real money flows through.

The tools exist. The barrier isn't technical skill anymore. **It's the willingness to stay up at 3am when Docker kills your containers and figure out why.**

If I can do it from an animal sanctuary in rural Japan with 28 cats and dogs, you can probably do it from wherever you are.

⭐ **If this story helped you, a star helps others find it too.**

---

<p align="center">
  <img src="images/sanctuary-aerial.jpg" alt="Aerial view of Washin Village in the mountains of rural Japan" width="600"/>
  <br>
  <sub>
    Built at <a href="https://washinmura.jp">Washin Village</a> — an animal sanctuary in the mountains of Japan where 28 cats & dogs and 3 AI agents work together.
  </sub>
</p>
