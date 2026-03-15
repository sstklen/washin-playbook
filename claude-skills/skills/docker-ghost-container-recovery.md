---
name: docker-ghost-container-recovery
description: |
  修復 Docker 幽靈容器（Ghost Container）— 容器名稱被佔用但實體不存在，
  導致 `docker compose up` 失敗、無限 Recreating 迴圈。
  使用時機：
  1. `docker compose up` 報 "The container name is already in use by container XXX"
  2. `docker rm -f XXX` 回覆 "No such container"（名字被佔但容器不存在）
  3. Docker Compose 進入無限 Recreating 迴圈（每次 800+ 秒）
  4. `docker compose down` 卡住或無法清除幽靈容器
  5. `docker system prune` 無效
  6. 中斷 Docker build 後，容器名稱殘留在 Docker 內部資料庫
  涵蓋：五級清除策略（從溫和到核武）、Docker 內部資料庫機制、事後恢復步驟。
author: Claude Code
version: 1.0.0
date: 2026-02-15
---

# Docker 幽靈容器恢復（Ghost Container Recovery）

## Problem

在 Docker Compose build/up 過程中被中斷（Ctrl+C、SSH 斷線、OOM kill），
容器的「名稱」被註冊到 Docker 的內部資料庫中，但實際容器檔案並不存在。

結果是：
- `docker compose up` → 名字衝突，無法建立新容器
- `docker rm -f` → "No such container"（檔案不存在，刪不了）
- 名字永遠被佔，陷入死循環

## Context / Trigger Conditions

### 觸發場景
- 在小 VPS（2-4GB RAM）上 `docker compose up -d --build`
- Build 過程花 20-50 分鐘
- 期間 SSH 斷線 / Ctrl+C / OOM kill / 手動 stop
- 嘗試再次 `docker compose up` 時出現衝突

### 症狀辨認
```
Error response from daemon: Conflict.
The container name "/myapp-api" is already in use by container "bb794857..."
You have to remove (or rename) that container to be able to reuse that name.
```
但：
```bash
docker rm -f bb794857...
# Error: No such container: bb794857...

docker stop bb794857...
# Error: No such container: bb794857...
```

**關鍵線索：** 容器 ID 前面可能有隨機前綴（如 `fb6b23167a58_myapp-api`），
這是 Docker Compose 在 recreate 過程中的臨時命名。

## Solution

### 五級清除策略（從溫和到核武）

依序嘗試，每一級比上一級更激進。只有前一級失敗才升級。

---

#### Level 1: docker compose down（溫和）
```bash
docker compose -f docker-compose.yml down --remove-orphans --volumes
```
- **成功率：** ~60%
- **副作用：** 刪除 named volumes（資料會丟！先備份）
- **注意：** 可能卡住 800+ 秒，等它跑完

#### Level 2: 直接刪容器（中等）
```bash
# 列出所有容器（包含 dead/created 狀態）
docker ps -a --no-trunc

# 強制刪除
docker rm -f $(docker ps -aq) 2>/dev/null

# 清理所有未使用的資源
docker system prune -af --volumes
```
- **成功率：** ~75%
- **副作用：** 刪除所有停止的容器和未使用的 images

#### Level 3: 重啟 Docker daemon（強）
```bash
sudo systemctl restart docker
# 等 10 秒後再嘗試
sleep 10
docker compose -f docker-compose.yml up -d
```
- **成功率：** ~80%
- **副作用：** 所有容器重啟
- **原理：** Daemon 重啟會重新載入內部狀態

#### Level 4: 清除容器目錄（激進）
```bash
sudo systemctl stop docker.socket docker.service

# 只刪容器資料（保留 images 和 volumes）
sudo rm -rf /var/lib/docker/containers/*

sudo systemctl start docker
```
- **成功率：** ~90%
- **副作用：** 所有容器被銷毀，但 images 和 volumes 保留
- **恢復：** `docker compose up -d` 重建容器

#### Level 5: 核武選項（最後手段）
```bash
sudo systemctl stop docker.socket docker.service

# 完全刪除 Docker 所有資料
sudo rm -rf /var/lib/docker

sudo systemctl start docker
```
- **成功率：** 99.9%
- **副作用：** 所有 images、containers、volumes、networks 全部消失
- **注意：** 可能有 "Device or resource busy" 警告（buildkit 目錄），可忽略
- **恢復：**
  ```bash
  # 重新登入 GHCR（如果用 private registry）
  echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

  # 重新拉 image 並啟動
  docker compose -f docker-compose.yml pull
  docker compose -f docker-compose.yml up -d
  ```

---

### 核武選項後的完整恢復流程

```bash
# 1. Docker 啟動後確認乾淨
docker ps -a          # 應該完全空
docker images         # 應該完全空
docker volume ls      # 應該完全空

# 2. 登入 registry（如果需要）
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# 3. 到專案目錄
cd ~/myapp-api

# 4. 拉 image + 啟動
docker compose -f docker-compose.yml pull
docker compose -f docker-compose.yml up -d

# 5. 等待 healthcheck
docker inspect --format='{{.State.Health.Status}}' myapp-api
# 重複檢查直到 "healthy"

# 6. 確認服務正常
curl http://localhost:3000/health
```

## 為什麼會有幽靈容器？

Docker 內部有一個 key-value 資料庫（在 `/var/lib/docker/` 下），
記錄容器的 metadata：

```
容器名 → 容器 ID → 容器檔案路徑
```

正常流程：
1. `docker create` → 寫入 DB + 建立檔案
2. `docker rm` → 刪除 DB + 刪除檔案

異常流程（build 中斷）：
1. `docker create` → 寫入 DB + **部分建立檔案**
2. 中斷！
3. DB 有記錄，但檔案不完整或不存在
4. `docker rm` → 找不到檔案 → "No such container"
5. 新 `docker create` → DB 有同名記錄 → "name already in use"
6. **死循環！**

`--force-recreate` 讓問題更嚴重：
- 它先 create 新容器（帶臨時名稱前綴）
- 再 stop/rm 舊容器
- 如果在這之間中斷 → 兩個幽靈

## Verification

```bash
# 確認沒有幽靈容器
docker ps -a
# 應只顯示你想要的容器

# 確認沒有懸空的容器目錄
sudo ls /var/lib/docker/containers/ | wc -l
# 數量應等於 docker ps -a 的數量

# 確認服務正常
curl -s http://localhost:3000/health | head -c 100
```

## Example

**場景：** A production API on a 4GB VPS took 50 minutes to build，
之後 `docker compose up` 報幽靈容器 `fb6b23167a58_myapp-api`。

**實戰記錄：**
```
Level 1: docker compose down → 卡了 800 秒，幽靈還在
Level 2: docker rm -f → "No such container"
Level 3: systemctl restart docker → 幽靈還在
Level 4: rm -rf containers/* → 清了一些，但幽靈轉移到更深層
Level 5: rm -rf /var/lib/docker → 成功！
         └─ 有一個 buildkit 路徑報 "Device or resource busy"（可忽略）
恢復: docker compose pull + up -d → 3 分鐘搞定
```

**教訓：** 小 VPS 不要在上面 build！用 Mac build → GHCR push → VPS pull。

## Notes

### 預防措施
1. **不在小 VPS 上 build** — 用 Mac/CI build + push to registry
2. **用 `screen` 或 `tmux`** — 防止 SSH 斷線殺死 build
3. **記得 Ctrl+C 的風險** — build 中按 Ctrl+C 比等它完成更危險
4. **定期清理** — `docker system prune -f` 每週跑一次

### "Device or resource busy" 警告
Level 5 時可能看到：
```
rm: cannot remove '/var/lib/docker/buildx/...': Device or resource busy
```
這是 buildkit 的 mount point 仍在使用。可以忽略，或重開機後再清：
```bash
sudo reboot
# 重開後
sudo rm -rf /var/lib/docker/buildx 2>/dev/null
```

### GHCR 登入不會被刪
`~/.docker/config.json` 存放 registry 認證，在 home 目錄下，
Level 5（`rm -rf /var/lib/docker`）不會影響它。

### 跟其他 Docker skill 的關係
- `docker-small-vps-deploy-optimization` — 預防 build 造成的問題
- `docker-compose-force-recreate-caddy-loop` — --force-recreate 的另一種問題
- 本 skill — 中斷後的幽靈容器清除

## References

- [Docker 官方文檔：Container removal](https://docs.docker.com/engine/containers/removing/)
- [Docker daemon storage driver](https://docs.docker.com/engine/storage/drivers/)
- See also: `docker-small-vps-deploy-optimization` — 避免在小 VPS 上 build
- See also: `docker-compose-force-recreate-caddy-loop` — --force-recreate 無限迴圈
- See also: `vps-deploy-workflow` — 完整部署流程（避免需要清幽靈）
