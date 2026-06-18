#!/bin/bash

cd /www/apps/new-api

# 1. 备份当前镜像 (可选)
mkdir -p docker-backup
if docker image inspect calciumion/new-api:latest > /dev/null 2>&1; then
    echo "正在备份镜像..."
    docker save calciumion/new-api:latest | gzip > docker-backup/docker-image_$(date +%Y%m%d_%H%M%S).tar.gz
    # 清理7天前的旧镜像备份
    find docker-backup -name 'docker-image_*.tar.gz' -type f -mtime +7 -delete 2>/dev/null
fi

# 2. 停止现有容器
echo "停止现有容器..."
docker-compose down 2>/dev/null || true

# 3. 构建新镜像
echo "==================================================="
echo "构建镜像: calciumion/new-api:latest"
echo "==================================================="
# 使用阿里云源加速 (GOPROXY=https://goproxy.cn 用于 Go 模块，APT 用于系统包)
docker build \
  --build-arg GOPROXY=https://goproxy.cn,direct \
  --build-arg APT_MIRROR=mirrors.aliyun.com \
  -t calciumion/new-api:latest .

# 4. 启动容器
echo ""
echo "==================================================="
echo "启动 Docker Compose 服务"
echo "==================================================="
docker compose up -d

# 5. 等待服务启动
echo "等待服务启动..."
sleep 3

# 6. 显示状态
echo ""
echo "容器状态:"
docker compose ps

echo ""
echo "镜像信息:"
docker images | grep calciumion/new-api
