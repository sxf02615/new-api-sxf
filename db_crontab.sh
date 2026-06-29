#!/bin/bash

# ========== 配置区域 ==========
BACKUP_SCRIPT="/www/apps/new-api/db_back.sh"
BACKUP_DIR="/www/back"       # 备份文件所在目录
# ==================================

set -e

echo "[$(date)] 开始执行备份..."

# 1、执行备份
bash "${BACKUP_SCRIPT}"

echo "[$(date)] 备份完成"

# 2、清理7天前的备份
echo "[$(date)] 清理7天前的备份文件..."
find "${BACKUP_DIR}" -name "*.sql.gz" -type f -mtime +7 -delete

echo "[$(date)] 清理完成"
