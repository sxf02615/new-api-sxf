用下面两行就可以了

docker compose build --no-cache new-api
docker compose up -d new-api



#!/bin/bash
set -euo pipefail

# 工作目录
WORK_DIR="/www/apps/new-api"
cd "${WORK_DIR}" || { echo "错误：目录 ${WORK_DIR} 不存在，脚本退出"; exit 1; }

BACKUP_DIR="./docker-backup"
mkdir -p "${BACKUP_DIR}"

# ========== 前置：配置Docker阿里云镜像加速器（拉取基础镜像全部走阿里，无需改Dockerfile）==========
DAEMON_JSON="/etc/docker/daemon.json"
MIRROR_CFG='{"registry-mirrors": ["https://docker.mirrors.ustc.edu.cn","https://hub-mirror.c.163.com","https://mirror.baidubce.com"]}'
# 写入镜像加速配置并重启docker，仅当未配置时执行
if [ ! -f "${DAEMON_JSON}" ] || ! grep -q "registry-mirrors" "${DAEMON_JSON}"; then
    echo "配置Docker阿里云镜像加速器（拉取基础镜像加速）"
    echo "${MIRROR_CFG}" > "${DAEMON_JSON}"
    systemctl daemon-reload
    systemctl restart docker
    echo "Docker镜像加速配置完成"
fi

# 1. 备份现有镜像，自动清理7天前备份
if docker image inspect calciumion/new-api:latest > /dev/null 2>&1; then
    echo -e "\n===== 备份当前镜像 calciumion/new-api:latest ====="
    BACKUP_FILE="${BACKUP_DIR}/docker-image_$(date +%Y%m%d_%H%M%S).tar.gz"
    docker save calciumion/new-api:latest | gzip > "${BACKUP_FILE}"
    echo "备份文件：${BACKUP_FILE}"
    find "${BACKUP_DIR}" -name 'docker-image_*.tar.gz' -type f -mtime +7 -delete 2>/dev/null
    echo "已清理7天前旧备份"
fi

# 2. 停止容器
echo -e "\n===== 停止运行中的容器 ====="
docker compose down 2>/dev/null || true

# 3. 构建镜像（仅保留原有的2个阿里源build-arg，不新增任何参数，不修改Dockerfile）
echo -e "\n==================================================="
echo "构建镜像 calciumion/new-api:latest"
echo "基础镜像拉取：Docker全局阿里加速器"
echo "Go模块代理：goproxy.cn"
echo "系统APT源：阿里云mirrors.aliyun.com"
echo "==================================================="
docker build \
  --build-arg GOPROXY=https://goproxy.cn,direct \
  --build-arg APT_MIRROR=mirrors.aliyun.com \
  -t calciumion/new-api:latest .

# 校验构建结果
if [ $? -ne 0 ]; then
    echo "镜像构建失败，终止脚本，不启动容器！"
    exit 1
fi
echo "镜像构建成功"

# 4. 启动服务
echo -e "\n==================================================="
echo "启动 Docker Compose 服务"
echo "==================================================="
docker compose up -d

# 5. 等待启动并输出状态
echo "等待3秒容器初始化..."
sleep 3

echo -e "\n===== 容器运行状态 ====="
docker compose ps

echo -e "\n===== 本地new-api镜像列表 ====="
docker images | grep calciumion/new-api