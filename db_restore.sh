#!/bin/bash


# ========== 配置区域 ==========
DB_PASSWORD="muWHAcaeavU7K78CcQX6"
DB_NAME="new-api"
DB_USER="root"
CONTAINER_NAME="postgres"        # PostgreSQL 容器名称

BACKUP_FILE="backup_20260629.sql.gz"  # 备份文件名（放在当前目录）
# ==================================

set -e

echo "[$(date)] 开始恢复数据库: ${DB_NAME}"

gunzip -c "${BACKUP_FILE}" | docker exec -i "${CONTAINER_NAME}" psql -U "${DB_USER}" -d "${DB_NAME}"

echo "[$(date)] 恢复完成"
