#!/bin/bash

# 同步项目源代码到远程服务器
# 使用SSH Token认证和SCP协议

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
    if ssh -q -o ConnectTimeout=5 "$REMOTE_HOST" exit; then
        print_success "SSH连接正常"
        return 0
    else
        print_error "无法连接到 $REMOTE_HOST"
        print_info "请确保:"
        print_info "  1. SSH密钥已正确配置"
        print_info "  2. ~/.ssh/config 中已配置 $REMOTE_HOST 主机"
        print_info "  3. 远程服务器可访问"
        return 1
    fi
}

check_remote_dir() {
    print_info "检查远程目录 $REMOTE_DIR..."
    if ssh "$REMOTE_HOST" test -d "$REMOTE_DIR"; then
        print_success "远程目录存在"
        return 0
    else
        print_warn "远程目录不存在，将创建..."
        ssh "$REMOTE_HOST" mkdir -p "$REMOTE_DIR" || {
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
    ssh "$REMOTE_HOST" mkdir -p "$backup_dir" || {
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
    ssh "$REMOTE_HOST" bash -c "
        cd \"$REMOTE_DIR\" && \
        tar -czf \"$backup_path\" \
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
        ls -lh \"$backup_path\" && \
        echo 'Backup completed successfully'
    "
    
    if [ $? -eq 0 ]; then
        print_success "远程备份完成"
        print_success "备份文件: $backup_file"
        
        # 显示备份目录内容
        print_info "备份目录内容:"
        ssh "$REMOTE_HOST" ls -lh "$backup_dir" | tail -10
        
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
    
    ssh "$REMOTE_HOST" bash -c "
        find \"$backup_dir\" -name 'backup_*.tar.gz' -type f -mtime +$keep_days -delete 2>/dev/null
        echo '旧备份清理完成'
    "
}

sync_files() {
    print_info "开始同步文件..."
    print_info "源: $LOCAL_DIR"
    print_info "目标: $REMOTE_HOST:$REMOTE_DIR"
    
    # 构建排除列表 (不同步的目录/文件)
    local exclude_opts=""
    local exclude_patterns=(
        ".git"
        ".github"
        "node_modules"
        ".vscode"
        ".idea"
        "dist"
        "build"
        "bin"
        ".DS_Store"
        "*.log"
        ".env"
        ".env.local"
        "vendor"
        ".next"
        "coverage"
        ".nyc_output"
        "tmp"
        "temp"
    )
    
    for pattern in "${exclude_patterns[@]}"; do
        exclude_opts="$exclude_opts --exclude='$pattern'"
    done
    
    # 执行SCP同步
    # 使用rsync而不是scp可能更高效，但这里保持用scp + tar的方式
    eval "scp $SCP_OPTS $exclude_opts \"$LOCAL_DIR/\" \"$REMOTE_HOST:$REMOTE_DIR/\""
    
    if [ $? -eq 0 ]; then
        print_success "文件同步完成"
        return 0
    else
        print_error "文件同步失败"
        return 1
    fi
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
    rsync -avz \
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
    $0                      备份后同步所有文件
    $0 --check-only         检查连接
    $0 --use-rsync          使用rsync同步
    $0 --backup-only        仅备份，不同步
    $0 --skip-backup        跳过备份，直接同步
    $0 --remote-host myhost 同步到指定主机

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
    
    if [ $? -eq 0 ]; then
        print_success "======================================================="
        print_success "同步完成！"
        print_success "远程地址: $REMOTE_HOST:$REMOTE_DIR"
        print_success "======================================================="
        exit 0
    else
        print_error "同步过程中出现错误"
        exit 1
    fi
}

# 运行主程序
main "$@"
