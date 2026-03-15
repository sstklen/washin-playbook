---
name: erc8004-blockchain-identity
description: |
  ERC-8004 區塊鏈身份完整指南 — 為動物、人、AI Agent 建立去中心化可驗證身份。
  使用時機：
  1. 為寵物或庇護所動物建立不可竄改的區塊鏈身份（醫療紀錄、領養歷史）
  2. 設計跨機構可攜式身份系統 — 動物轉移庇護所時身份跟著走
  3. 規劃三鏈上鏈策略：Bitcoin OTS（時間戳證明）+ Ethereum（智能合約）+ Solana（低成本高速）
  4. AI Agent 身份驗證 — 讓 AI 操作具有可追溯的鏈上身份
  5. 需要多組織共同驗證的去中心化身份架構（DID + Verifiable Credentials）
  觸發條件與症狀：
  - 動物在不同機構間轉移時身份資料遺失或不一致
  - 需要防偽造的身份證明（區塊鏈不可竄改特性）
  - 傳統中心化資料庫的單點故障風險
  - AI Agent 需要可驗證的操作身份（非匿名操作）
  工具：Solidity、ERC-721/ERC-8004、OpenTimestamps、DID、Verifiable Credentials
  整合原有 3 個 ERC-8004 skills（animal-identity、implementation、triple-chain）為一體。
version: 2.0.0
date: 2026-02-02
---

# ERC-8004 Blockchain Identity

## Quick Reference

| 用途 | 方案 | 詳細 |
|------|------|------|
| 動物身份 | ERC-8004 + 跨鏈信譽橋 | [animal-identity](references/animal-identity.md) |
| 實現指南 | 完整合約 + 多組織驗證 | [implementation](references/implementation.md) |
| 三鏈策略 | Bitcoin OTS + ETH + Solana | [triple-chain](references/triple-chain.md) |

## References

- [animal-identity.md](references/animal-identity.md)
- [implementation.md](references/implementation.md)
- [triple-chain.md](references/triple-chain.md)
