#!/usr/bin/env node

// washin-claude-skills — 112 生產級 Claude Code Skills 一鍵安裝
// 用法: npx washin-claude-skills [--list | --categories | --category <name>]

const { execSync } = require('child_process');
const path = require('path');

const installScript = path.join(__dirname, 'install.sh');
const args = process.argv.slice(2).join(' ');

try {
  execSync(`bash "${installScript}" ${args}`, { stdio: 'inherit' });
} catch (err) {
  process.exit(err.status || 1);
}
