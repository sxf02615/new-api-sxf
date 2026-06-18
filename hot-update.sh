#!/bin/bash
#
# hot-update.sh — 热更新脚本
# 将最新代码更新到运行中的容器，重新编译 Go 并重启容器生效，无需重新构建 Docker 镜像。
#
# 原理：
#   1. 在宿主机（或临时 Go 容器）中编译 Go 二进制
#   2. 将编译产物通过 docker cp 复制到运行中的容器
#   3. 重启容器使新二进制生效
#
# 前置条件：
#   - Docker 已安装且当前用户有权限执行 docker 命令
#   - 目标容器正在运行
#
# 用法：
#   ./hot-update.sh                          # 默认：使用 Docker 构建，仅编译 Go，容器名 new-api
#   ./hot-update.sh -c my-api                # 指定容器名称
#   ./hot-update.sh -b host                  # 使用宿主机 Go 编译（需本地安装 Go）
#   ./hot-update.sh -f                       # 同时构建前端（默认跳过前端构建）
#   ./hot-update.sh -h                       # 查看帮助
#

set -euo pipefail

# ==================== 配置 ====================

CONTAINER_NAME="new-api"
BUILD_METHOD="docker"      # docker | host
BUILD_FRONTEND=false
GO_IMAGE="golang:1.26.1-alpine"
APP_PATH="/new-api"
WORK_DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY_NAME="new-api"
GO_MODULE="github.com/QuantumNous/new-api"
GO_FLAGS="-ldflags \"-s -w -X '${GO_MODULE}/common.Version=$(cat ${WORK_DIR}/VERSION 2>/dev/null || echo unknown)'\""

# ==================== 颜色输出 ====================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC}   $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERR]${NC}  $1"; }

# ==================== 帮助 ====================

usage() {
    cat <<EOF
用法: $0 [选项]

选项:
  -c <name>    容器名称 (默认: ${CONTAINER_NAME})
  -b <method>  构建方式: docker (默认) | host (使用宿主机 Go)
  -f           同时构建前端 (默认: 仅编译 Go)
  -h           显示此帮助

示例:
  $0                        # 默认方式更新
  $0 -c my-api -b host      # 使用宿主机 Go 编译，指定容器
  $0 -f                     # 同时更新前端
EOF
    exit 0
}

# ==================== 参数解析 ====================

while getopts "c:b:fh" opt; do
    case "$opt" in
        c) CONTAINER_NAME="$OPTARG" ;;
        b) BUILD_METHOD="$OPTARG" ;;
        f) BUILD_FRONTEND=true ;;
        h) usage ;;
        *) usage ;;
    esac
done

# ==================== 前置检查 ====================

preflight_check() {
    info "运行前置检查..."

    # 检查 Docker
    if ! command -v docker &>/dev/null; then
        err "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    ok "Docker 已安装"

    # 检查容器是否运行
    if ! docker inspect "$CONTAINER_NAME" &>/dev/null; then
        err "容器 '$CONTAINER_NAME' 不存在"
        exit 1
    fi

    local status
    status=$(docker inspect --format '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null)
    if [ "$status" != "running" ]; then
        err "容器 '$CONTAINER_NAME' 当前状态为 '$status'，需要容器处于 running 状态"
        exit 1
    fi
    ok "容器 '$CONTAINER_NAME' 运行中"

    # 检查容器内是否有目标路径
    if ! docker exec "$CONTAINER_NAME" test -e "$APP_PATH" 2>/dev/null; then
        warn "容器内 $APP_PATH 不存在，将复制新二进制"
    fi

    # 检查构建方式
    if [ "$BUILD_METHOD" = "host" ]; then
        if ! command -v go &>/dev/null; then
            err "宿主机未安装 Go，无法使用 host 模式构建"
            err "请安装 Go 或使用默认的 docker 构建方式 (无需安装 Go)"
            exit 1
        fi
        ok "宿主机 Go 可用: $(go version)"
    fi
}

# ==================== 构建 Go 二进制 ====================

build_backend() {
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local output="${tmp_dir}/${BINARY_NAME}"

    info "开始编译 Go 后端..."

    if [ "$BUILD_METHOD" = "docker" ]; then
        # 使用临时 Go 容器编译，匹配 Dockerfile 的编译环境
        info "使用 Docker 容器 ($GO_IMAGE) 编译..."

        # 先检查前端 dist 是否存在，如果不存在则创建占位
        if [ ! -d "${WORK_DIR}/web/default/dist" ]; then
            mkdir -p "${WORK_DIR}/web/default/dist"
            echo '<!doctype html><html><head><title>dev</title></head><body>placeholder</body></html>' > "${WORK_DIR}/web/default/dist/index.html"
        fi
        if [ ! -d "${WORK_DIR}/web/classic/dist" ]; then
            mkdir -p "${WORK_DIR}/web/classic/dist"
            echo '<!doctype html><html><head><title>dev</title></head><body>placeholder</body></html>' > "${WORK_DIR}/web/classic/dist/index.html"
        fi

        docker run --rm \
            -v "${WORK_DIR}:/build" \
            -w /build \
            -e GO111MODULE=on \
            -e CGO_ENABLED=0 \
            -e GOEXPERIMENT=greenteagc \
            -e GOPROXY=https://goproxy.cn,direct \
            "$GO_IMAGE" \
            sh -c "go mod download && go build -ldflags '-s -w -X ${GO_MODULE}/common.Version=$(cat ${WORK_DIR}/VERSION 2>/dev/null || echo unknown)' -o ${output} ."
    else
        # 使用宿主机 Go 编译
        info "使用宿主机 Go 编译..."
        (
            cd "$WORK_DIR"
            CGO_ENABLED=0 GOEXPERIMENT=greenteagc \
                go build -ldflags "-s -w -X '${GO_MODULE}/common.Version=$(cat VERSION 2>/dev/null || echo unknown)'" \
                -o "$output" .
        )
    fi

    if [ ! -f "$output" ]; then
        err "编译失败，未生成二进制文件"
        exit 1
    fi

    local size
    size=$(ls -lh "$output" | awk '{print $5}')
    ok "Go 后端编译完成: ${output} (${size})"

    # 复制到容器
    info "将二进制文件复制到容器 '${CONTAINER_NAME}':${APP_PATH} ..."
    docker cp "$output" "${CONTAINER_NAME}:${APP_PATH}"
    ok "二进制文件已复制到容器"

    # 清理临时文件
    rm -f "$output"
    rmdir "$tmp_dir" 2>/dev/null || true
}

# ==================== 构建前端（可选） ====================

build_frontend() {
    info "开始构建前端..."

    # 检查前端目录
    if [ ! -f "${WORK_DIR}/web/default/package.json" ]; then
        warn "未找到 web/default/package.json，跳过前端构建"
        return
    fi

    # 使用 bun 容器构建前端
    docker run --rm \
        -v "${WORK_DIR}:/build" \
        -w /build/web \
        oven/bun:1 \
        sh -c "bun install --frozen-lockfile && cd default && DISABLE_ESLINT_PLUGIN='true' VITE_REACT_APP_VERSION=$(cat ${WORK_DIR}/VERSION 2>/dev/null || echo unknown) bun run build"

    local dist_dir="${WORK_DIR}/web/default/dist"
    if [ -d "$dist_dir" ]; then
        docker cp "$dist_dir/." "${CONTAINER_NAME}:/data/web/default/dist/"
        ok "前端已构建并复制到容器"
    else
        warn "前端构建产物不存在，跳过复制"
    fi
}

# ==================== 重启容器 ====================

restart_container() {
    info "重启容器 '${CONTAINER_NAME}'..."
    docker restart "$CONTAINER_NAME" > /dev/null
    ok "容器已重启"

    # 等待容器就绪
    info "等待容器就绪..."
    local retries=10
    local delay=2
    local ready=false

    for i in $(seq 1 "$retries"); do
        if docker exec "$CONTAINER_NAME" test -x "$APP_PATH" 2>/dev/null; then
            ready=true
            break
        fi
        sleep "$delay"
    done

    if [ "$ready" = true ]; then
        # 额外等待进程启动
        sleep 2
        if docker inspect --format '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null | grep -q "running"; then
            ok "容器 '$CONTAINER_NAME' 已就绪，正运行新版本"
        else
            warn "容器已重启但状态异常，请检查日志: docker logs $CONTAINER_NAME"
        fi
    else
        warn "容器未及时响应，请检查日志: docker logs $CONTAINER_NAME"
    fi
}

# ==================== 主流程 ====================

main() {
    echo ""
    echo "======================================"
    echo "  new-api 热更新脚本"
    echo "======================================"
    echo ""

    preflight_check
    echo ""

    build_backend
    echo ""

    if [ "$BUILD_FRONTEND" = true ]; then
        build_frontend
        echo ""
    fi

    restart_container
    echo ""

    echo "======================================"
    ok "热更新完成！"
    echo ""
    echo "  查看日志: docker logs -f ${CONTAINER_NAME}"
    echo "======================================"
}

main "$@"
