#!/bin/bash
# =================================────────────────
# 第三方依赖初始化脚本
# 用法: ./scripts/init-third-party.sh
#
# 功能: 自动克隆项目所需的 C++ 依赖库
# 优先级: GitHub > Gitee 镜像（如果配置了）
# =========================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
THIRD_PARTY="$PROJECT_ROOT/third_party"

# 创建第三方依赖目录
mkdir -p "$THIRD_PARTY"

# 定义所有依赖
# 格式: "仓库名:GitHub URL:Gitee 镜像 URL"
declare -A DEPS=(
    ["llama.cpp"]="https://github.com/ggml-org/llama.cpp.git:https://gitee.com/你的用户名/llama.cpp.git"
)

# 日志颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# 尝试克隆一个仓库，失败时尝试 fallback
clone_with_fallback() {
    local name="$1"
    local github_url="$2"
    local gitee_url="$3"
    local dir="$THIRD_PARTY/$name"
    
    # 如果已经存在，跳过
    if [ -d "$dir" ]; then
        log_success "$name already exists"
        return 0
    fi
    
    # 尝试 GitHub
    echo "Cloning $name from GitHub..."
    if git clone --depth 1 "$github_url" "$dir" 2>/dev/null; then
        log_success "$name cloned from GitHub"
        return 0
    fi
    
    log_warn "GitHub clone failed, trying Gitee fallback..."
    
    # 尝试 Gitee
    if [ -n "$gitee_url" ]; then
        if git clone --depth 1 "$gitee_url" "$dir" 2>/dev/null; then
            log_success "$name cloned from Gitee"
            return 0
        fi
    fi
    
    # 都失败了
    log_error "$name clone failed from all sources"
    return 1
}

# 主流程
echo "=========================================="
echo "初始化第三方依赖"
echo "=========================================="
echo ""

FAILED=()

for name in "${!DEPS[@]}"; do
    # 分割 GitHub URL 和 Gitee URL
    IFS=':' read -r github_url gitee_url <<< "${DEPS[$name]}"
    
    if ! clone_with_fallback "$name" "$github_url" "$gitee_url"; then
        FAILED+=("$name")
    fi
done

echo ""
echo "=========================================="

# 报告结果
if [ ${#FAILED[@]} -gt 0 ]; then
    echo ""
    log_error "以下依赖获取失败，请手动处理："
    echo ""
    for name in "${FAILED[@]}"; do
        github_url="${DEPS[$name]%%:*}"
        echo "  - $name"
        echo "    GitHub: $github_url"
        echo ""
    done
    echo "手动克隆示例："
    echo "  git clone --depth 1 ${DEPS[llama.cpp]%%:*} third_party/llama.cpp"
    echo ""
    echo "如果是网络问题，可以："
    echo "  1. 配置 Git 代理: git config --global http.proxy http://127.0.0.1:7890"
    echo "  2. 或使用 Gitee 镜像（需要自行创建）"
    echo "=========================================="
    exit 1
fi

log_success "所有依赖获取成功！"
echo ""
echo "依赖目录: $THIRD_PARTY"
echo "=========================================="
