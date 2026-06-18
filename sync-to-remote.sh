#!/bin/bash

################################################################################
#
#  新-API 项目同步脚本 (new-api Project Sync Script)
#
#  功能: 从本地 macOS 同步源代码到远程 Ubuntu 服务器，支持备份和同步
#
#  使用方法:
#    ./sync-to-remote.sh [选项]
#
################################################################################
#
#  可选项列表:
#
#  通用选项:
#    -h, --help                显示帮助信息
#
#  连接检查:
#    --check-only              仅检查SSH连接，不执行任何同步操作
#
#  备份选项:
#    --backup-only             仅执行备份，不同步文件
#    --skip-backup             跳过备份操作，直接进行同步
#
#  同步选项:
#    --use-rsync               使用 rsync 方式同步（推荐，增量同步，速度快）
#                              默认使用 tar + scp 方式
#
#  配置选项:
#    --remote-host HOST        指定远程服务器（默认值: token）
#    --remote-dir DIR          指定远程项目目录（默认值: /www/apps/new-api）
#
################################################################################
#
#  使用示例:
#
#    1. 备份 + 同步（推荐）:
#       ./sync-to-remote.sh --use-rsync
#
#    2. 仅检查连接:
#       ./sync-to-remote.sh --check-only
#
#    3. 同步并跳过备份:
#       ./sync-to-remote.sh --skip-backup --use-rsync
#
#    4. 仅备份，不同步:
#       ./sync-to-remote.sh --backup-only
#
#    5. 使用 tar + scp 方式同步（网络不稳定时）:
#       ./sync-to-remote.sh
#
################################################################################
#
#  前置条件:
#
#    本地:
#      - macOS 环境
#      - SSH 密钥已配置到 ~/.ssh/config，服务器别名为 token
#      - SSH 密钥已加载到 ssh-agent: ssh-add ~/.ssh/id_rsa_pi
#
#    远程:
#      - Ubuntu 服务器，SSH 可访问
#      - Docker 已安装
#      - Docker Compose 已安装
#      - 项目目录: /www/apps/new-api
#      - Dockerfile 和 docker-compose.yml 存在
#
################################################################################

set -e

# ============================================================================
# 配置部分
# ============================================================================

# 远程服务器配置 (SSH别名或 user@host 格式)
REMOTE_HOST="token"

# 远程项目目录
REMOTE_DIR="/www/apps/new-api"

# 本地源目录 (当前脚本所在项目目录)
LOCAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# SCP选项 (递归、保留权限、显示进度)
SCP_OPTS="-r -p -v"

# Docker 镜像名称
DOCKER_IMAGE="calciumion/new-api"

# Docker 镜像保留天数
IMAGE_KEEP_DAYS=7

# ============================================================================
# 颜色定义
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# 函数定义
# ============================================================================

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_ssh_connection() {
    print_info "检查SSH连接到 $REMOTE_HOST..."
    # 增加连接超时到20秒，启用keep-alive
    if ssh -q -o ConnectTimeout=20 -o BatchMode=yes -o ServerAliveInterval=10 "$REMOTE_HOST" exit 2>/dev/null; then
        print_success "SSH连接正常"
        return 0
    else
        print_error "无法连接到 $REMOTE_HOST"
        print_info "排查步骤："
        print_info "  1. 检查网络: ping 47.103.129.229"
        print_info "  2. 检查SSH密钥: ssh-add -l"
        print_info "  3. 测试SSH连接: ssh -vv token"
        print_info "  4. 验证配置: ssh -G token"
        return 1
    fi
}

check_remote_dir() {
    print_info "检查远程目录 $REMOTE_DIR..."
    if ssh -o ConnectTimeout=20 -o BatchMode=yes "$REMOTE_HOST" test -d "$REMOTE_DIR"; then
        print_success "远程目录存在"
        return 0
    else
        print_warn "远程目录不存在，将创建..."
        ssh -o ConnectTimeout=20 -o BatchMode=yes "$REMOTE_HOST" mkdir -p "$REMOTE_DIR" || {
            print_error "创建远程目录失败"
            return 1
        }
        print_success "远程目录已创建"
        return 0
    fi
}

backup_remote_project() {
    local backup_dir="$REMOTE_DIR/back"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="backup_${timestamp}.tar.gz"
    local backup_path="$backup_dir/$backup_file"
    
    print_info "======================================================="
    print_info "开始备份远程项目..."
    print_info "======================================================="
    
    # 创建备份目录
    print_info "创建备份目录 $backup_dir..."
    ssh -o ConnectTimeout=20 -o BatchMode=yes "$REMOTE_HOST" mkdir -p "$backup_dir" || {
        print_error "创建备份目录失败"
        return 1
    }
    print_success "备份目录已就绪"
    
    # 执行远程备份命令
    print_info "备份文件名: $backup_file"
    print_info "备份路径: $backup_path"
    print_info "正在压缩项目文件..."
    
    # 使用tar命令在远程服务器上创建压缩包
    # 排除back目录本身和其他不必要的文件
    ssh -o ConnectTimeout=20 -o BatchMode=yes "$REMOTE_HOST" bash << BASHEOF
        cd "$REMOTE_DIR" && \
        tar -czf "$backup_path" \
            --exclude='back' \
            --exclude='.git' \
            --exclude='.github' \
            --exclude='node_modules' \
            --exclude='.vscode' \
            --exclude='.idea' \
            --exclude='dist' \
            --exclude='build' \
            --exclude='.DS_Store' \
            --exclude='*.log' \
            --exclude='.env.local' \
            --exclude='vendor' \
            --exclude='.next' \
            --exclude='coverage' \
            --exclude='tmp' \
            . && \
        ls -lh "$backup_path" && \
        echo 'Backup completed successfully'
BASHEOF
    
    if [ $? -eq 0 ]; then
        print_success "远程备份完成"
        print_success "备份文件: $backup_file"
        
        # 显示备份目录内容
        print_info "备份目录内容:"
        ssh -o ConnectTimeout=20 -o BatchMode=yes "$REMOTE_HOST" ls -lh "$backup_dir" | tail -10
        
        return 0
    else
        print_error "远程备份失败"
        return 1
    fi
}

cleanup_old_backups() {
    local backup_dir="$REMOTE_DIR/back"
    local keep_days=7
    
    print_info "清理 $keep_days 天前的旧备份..."
    
    ssh -o ConnectTimeout=20 -o BatchMode=yes "$REMOTE_HOST" bash << BASHEOF
        find "$backup_dir" -name 'backup_*.tar.gz' -type f -mtime +$keep_days -delete 2>/dev/null
        echo '旧备份清理完成'
BASHEOF
}

backup_remote_docker_image() {
    print_info "======================================================="
    print_info "开始备份远程Docker镜像..."
    print_info "======================================================="
    
    local image_backup_dir="$REMOTE_DIR/docker-backup"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local image_backup_file="docker-image_${timestamp}.tar.gz"
    local image_backup_path="$image_backup_dir/$image_backup_file"
    
    # 创建镜像备份目录
    print_info "创建镜像备份目录..."
    ssh -o ConnectTimeout=20 -o BatchMode=yes "$REMOTE_HOST" mkdir -p "$image_backup_dir" || {
        print_warn "无法创建镜像备份目录，继续执行..."
        return 0
    }
    
    print_info "备份Docker镜像: $DOCKER_IMAGE:latest"
    print_info "备份文件: $image_backup_file"
    
    # 备份镜像
    ssh -o ConnectTimeout=20 -o BatchMode=yes "$REMOTE_HOST" bash << BASHEOF
        if docker image inspect '$DOCKER_IMAGE:latest' > /dev/null 2>&1; then
            echo '正在保存镜像到文件...'
            docker save '$DOCKER_IMAGE:latest' | gzip > "$image_backup_path"
            
            if [ -f "$image_backup_path" ]; then
                ls -lh "$image_backup_path"
                echo '镜像备份完成'
            else
                echo '警告: 镜像备份失败，但继续执行'
            fi
        else
            echo '镜像不存在，跳过备份'
        fi
BASHEOF
    
    # 清理旧镜像备份
    print_info "清理 $IMAGE_KEEP_DAYS 天前的旧镜像备份..."
    ssh -o ConnectTimeout=20 -o BatchMode=yes "$REMOTE_HOST" bash << BASHEOF
        find "$image_backup_dir" -name 'docker-image_*.tar.gz' -type f -mtime +$IMAGE_KEEP_DAYS -delete 2>/dev/null
        echo '旧镜像备份清理完成'
BASHEOF
    
    return 0
}


check_docker_status() {
    print_info "检查远程Docker环境..."
    
    ssh -o ConnectTimeout=20 -o BatchMode=yes "$REMOTE_HOST" bash << 'BASHEOF'
        # 检查Docker是否安装
        if ! command -v docker &> /dev/null; then
            echo 'Docker 未安装'
            exit 1
        fi
        
        # 检查Docker服务是否运行
        if ! docker ps &>/dev/null; then
            echo 'Docker 服务未运行或当前用户权限不足'
            exit 1
        fi
        
        # 检查Docker Compose是否安装
        if ! command -v docker-compose &> /dev/null; then
            echo 'Docker Compose 未安装'
            exit 1
        fi
        
        echo 'Docker 环境检查完成'
        docker --version
        docker-compose --version
BASHEOF
    
    if [ $? -eq 0 ]; then
        print_success "Docker环境检查通过"
        return 0
    else
        print_error "Docker环境检查失败"
        return 1
    fi
}

sync_files() {
    print_info "开始同步文件..."
    print_info "源: $LOCAL_DIR"
    print_info "目标: $REMOTE_HOST:$REMOTE_DIR"
    print_info "本地系统: $(uname)"
    
    local temp_tar="/tmp/new-api-sync-$$.tar.gz"
    
    print_info "打包本地文件..."
    
    # 在本地目录中打包所有内容 (macOS和Linux兼容)
    # 使用 -C 进入目录，然后打包 .，这样包中的内容是相对路径
    cd "$LOCAL_DIR" || {
        print_error "无法进入本地目录"
        return 1
    }
    
    tar -czf "$temp_tar" \
        --exclude=".git" \
        --exclude=".github" \
        --exclude="node_modules" \
        --exclude=".vscode" \
        --exclude=".idea" \
        --exclude="dist" \
        --exclude="build" \
        --exclude="bin" \
        --exclude=".DS_Store" \
        --exclude="*.log" \
        --exclude=".env" \
        --exclude=".env.local" \
        --exclude="vendor" \
        --exclude=".next" \
        --exclude="coverage" \
        --exclude=".nyc_output" \
        --exclude="tmp" \
        --exclude="temp" \
        --exclude="back" \
        --exclude="sync-to-remote.sh" \
        . 2>/dev/null
    
    if [ $? -ne 0 ] || [ ! -f "$temp_tar" ]; then
        print_error "打包文件失败"
        rm -f "$temp_tar"
        return 1
    fi
    
    local tar_size=$(du -h "$temp_tar" | cut -f1)
    print_info "压缩包大小: $tar_size"
    print_info "传输压缩包到远程服务器..."
    
    # 转回原始目录
    cd - > /dev/null || true
    
    # 传输到远程 (增加连接超时到20秒)
    scp -o ConnectTimeout=20 -o BatchMode=yes -p "$temp_tar" "$REMOTE_HOST:/tmp/" || {
        print_error "传输压缩包失败"
        rm -f "$temp_tar"
        return 1
    }
    
    # 在远程解压
    print_info "在远程服务器解压..."
    local tar_filename=$(basename "$temp_tar")
    ssh -o ConnectTimeout=20 -o BatchMode=yes "$REMOTE_HOST" bash << BASHEOF
        mkdir -p "$REMOTE_DIR" && \
        cd "$REMOTE_DIR" && \
        tar -xzf /tmp/$tar_filename && \
        rm -f /tmp/$tar_filename && \
        echo '解压完成'
BASHEOF
    
    if [ $? -ne 0 ]; then
        print_error "远程解压失败"
        rm -f "$temp_tar"
        return 1
    fi
    
    # 清理本地临时文件
    rm -f "$temp_tar"
    
    print_success "文件同步完成"
    return 0
}

sync_files_with_rsync() {
    # 使用rsync (如果可用) - 更高效
    print_info "开始同步文件 (使用rsync)..."
    print_info "源: $LOCAL_DIR"
    print_info "目标: $REMOTE_HOST:$REMOTE_DIR"
    
    if ! command -v rsync &> /dev/null; then
        print_warn "rsync 未安装，将使用scp方式"
        sync_files
        return $?
    fi
    
    # rsync 同步 (删除远端多余文件)
    rsync -avz --rsh='ssh -o ConnectTimeout=20 -o BatchMode=yes' \
        --delete \
        --exclude='.git' \
        --exclude='.github' \
        --exclude='node_modules' \
        --exclude='.vscode' \
        --exclude='.idea' \
        --exclude='dist' \
        --exclude='build' \
        --exclude='bin' \
        --exclude='.DS_Store' \
        --exclude='*.log' \
        --exclude='.env' \
        --exclude='.env.local' \
        --exclude='vendor' \
        --exclude='.next' \
        --exclude='coverage' \
        --exclude='.nyc_output' \
        --exclude='tmp' \
        --exclude='temp' \
        "$LOCAL_DIR/" \
        "$REMOTE_HOST:$REMOTE_DIR/"
    
    if [ $? -eq 0 ]; then
        print_success "文件同步完成"
        return 0
    else
        print_error "文件同步失败"
        return 1
    fi
}

show_usage() {
    cat << EOF
用法: $0 [选项]

选项:
    -h, --help              显示帮助信息
    --check-only            仅检查连接，不同步文件
    --dry-run               显示将要同步的文件，但不实际同步
    --use-rsync             使用rsync替代scp进行同步(更高效)
    --skip-backup           跳过备份操作，直接同步
    --backup-only           仅执行备份，不同步文件
    --remote-host HOST      指定远程服务器 (默认: $REMOTE_HOST)
    --remote-dir DIR        指定远程目录 (默认: $REMOTE_DIR)

示例:
    $0                           备份后同步所有文件
    $0 --check-only              检查连接
    $0 --use-rsync               使用rsync同步
    $0 --backup-only             仅备份，不同步
    $0 --skip-backup             跳过备份，直接同步

EOF
}

# ============================================================================
# 主程序
# ============================================================================

main() {
    local check_only=false
    local use_rsync=false
    local dry_run=false
    local skip_backup=false
    local backup_only=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            --check-only)
                check_only=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --use-rsync)
                use_rsync=true
                shift
                ;;
            --skip-backup)
                skip_backup=true
                shift
                ;;
            --backup-only)
                backup_only=true
                shift
                ;;
            --remote-host)
                REMOTE_HOST="$2"
                shift 2
                ;;
            --remote-dir)
                REMOTE_DIR="$2"
                shift 2
                ;;
            *)
                print_error "未知选项: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    print_info "==============================================="
    print_info "项目源代码同步脚本"
    print_info "==============================================="
    
    # 检查SSH连接
    if ! check_ssh_connection; then
        exit 1
    fi
    
    # 仅检查模式
    if [ "$check_only" = true ]; then
        print_success "连接检查完成，脚本退出"
        exit 0
    fi
    
    # 检查远程目录
    if ! check_remote_dir; then
        exit 1
    fi
    
    # 执行备份 (除非跳过)
    if [ "$skip_backup" = false ]; then
        if ! backup_remote_project; then
            print_error "备份失败，停止同步"
            exit 1
        fi
        
        # 清理旧备份
        cleanup_old_backups
    fi
    
    # 仅备份模式
    if [ "$backup_only" = true ]; then
        print_success "==============================================="
        print_success "备份完成，脚本退出"
        print_success "==============================================="
        exit 0
    fi
    
    # 同步文件
    print_info "======================================================="
    print_info "开始同步源代码..."
    print_info "======================================================="
    
    if [ "$use_rsync" = true ]; then
        sync_files_with_rsync
    else
        sync_files
    fi
    
    if [ $? -ne 0 ]; then
        print_error "同步过程中出现错误"
        exit 1
    fi
    
    print_success "======================================================="
    print_success "所有操作完成！"
    print_success "远程地址: $REMOTE_HOST:$REMOTE_DIR"
    print_success "======================================================="
    exit 0
}

# 运行主程序
main "$@"
