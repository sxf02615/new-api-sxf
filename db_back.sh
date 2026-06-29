#!/bin/bash

# ========== 配置区域 ==========
DB_PASSWORD="muWHAcaeavU7K78CcQX6"
DB_NAME="new-api"
DB_USER="root"
CONTAINER_NAME="postgres"        # PostgreSQL 容器名称
REMOTE_HOST="tokenxg"  # 远程服务器 IP 或域名
REMOTE_USER="root"               # 远程服务器用户名
REMOTE_PATH="/www/back"          # 远程备份目录
LOCAL_BACKUP_DIR="/www/back"     # 本地临时备份目录
# ==================================

set -e

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${LOCAL_BACKUP_DIR}/${DB_NAME}_${DATE}.sql.gz"
REMOTE_FILE="${DB_NAME}_${DATE}.sql.gz"

echo "[$(date)] 开始备份数据库..."

# 备份并压缩
docker exec -t "${CONTAINER_NAME}" pg_dump -U "${DB_USER}" -d "${DB_NAME}" | gzip > "${BACKUP_FILE}"

echo "[$(date)] 备份完成: ${BACKUP_FILE}"

# 传输到远程服务器
echo "[$(date)] 开始传输到远程服务器..."
scp -o StrictHostKeyChecking=no "${BACKUP_FILE}" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/${REMOTE_FILE}"

echo "[$(date)] 传输完成，清理本地文件..."
rm -f "${BACKUP_FILE}"

echo "[$(date)] 全部完成"
