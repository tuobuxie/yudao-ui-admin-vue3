#!/bin/bash

# ===================== 配置区 只改这4处！！！ =====================
SERVER_IP="47.105.43.107"       # 你的业务服务器IP
SERVER_USER="root"              # 你的业务服务器登录用户名
SERVER_DIR="/root/admin"            # 业务服务器的部署根目录
GIT_REPO="git@github.com:tuobuxie/yudao-ui-admin-vue3.git"  # Git仓库地址 需要服务器有ssh密钥，并且配置了免密登录
# =================================================================

echo "========================================"
echo "开始远程部署 $SERVER_USER@$SERVER_IP ..."
echo "========================================"

# 一次性 SSH 执行所有操作 
ssh $SERVER_USER@$SERVER_IP "bash -s" <<DEPLOY_SCRIPT
    SERVER_DIR="$SERVER_DIR"
    GIT_REPO="$GIT_REPO"
    APP_NAME="admin"
    APP_PORT="8080"
    DIST_DIR="dist-prod"
    
    # 1. 检查并拉取代码
    echo "\n1. 检查并拉取代码..."
    if [ -d "\$SERVER_DIR/.git" ]; then
        echo '📦 检测到 Git 仓库，执行 git pull...'
        cd \$SERVER_DIR && git pull
        if [ \$? -ne 0 ]; then
            echo '❌ git pull 失败'
            exit 1
        fi
        echo '✅ git pull 成功'
    
    fi
    
    # 进入项目目录
    cd \$SERVER_DIR
    
    # 2. 执行部署脚本
    echo "\n2. 执行部署脚本..."
    # 2.1 检查Node.js环境
    echo "\n2.1 检查Node.js环境..."
    NODE_VERSION_REQUIRED=18
    
    if ! command -v node &> /dev/null
    then
        echo "❌ 错误：未安装Node.js，请先安装Node.js 18+"
        echo "💡 注意：Linux服务器默认的Node.js可能使用较老的OpenSSL 1.1版本，这会导致支付宝SDK出现兼容性问题"
        echo "💡 解决方案：请使用以下命令安装支持OpenSSL 3.x的Node.js版本："
        echo "   curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -"
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
        echo "   sudo yum install -y nodejs"
        sudo yum install -y nodejs
        echo "   node -p process.versions.openssl  # 确保输出的是3.x版本"
        node -p process.versions.openssl
    
    fi

    echo "✅ Node.js版本：\$(node -v)"
    echo "✅ npm版本：\$(npm -v)"
    echo "💡 注意：请确保Node.js使用的OpenSSL版本为3.x，否则支付宝SDK可能出现兼容性问题"

    # 2.2 检查pnpm环境
    echo "\n2.2 检查pnpm环境..."
    if ! command -v pnpm &> /dev/null
    then
        echo "⚠️ pnpm未安装，正在安装..."
        npm install -g pnpm --registry=https://registry.npmmirror.com
        if [ \$? -ne 0 ]; then
            echo "❌ 错误：pnpm安装失败"
            exit 1
        fi
    fi
    echo "✅ pnpm版本：\$(pnpm -v)"

    # 2.3 安装依赖
    echo "\n2.3 安装项目依赖..."
    pnpm install --registry=https://registry.npmmirror.com
    if [ \$? -ne 0 ]; then
        echo "❌ 错误：依赖安装失败"
        exit 1
    fi
    echo "✅ 依赖安装成功"

    # 2.4 构建项目
    echo "\n2.4 构建项目..."
    pnpm build:prod
    if [ \$? -ne 0 ]; then
        echo "❌ 错误：项目构建失败"
        exit 1
    fi
    echo "✅ 项目构建成功"

    # 2.5 检查PM2环境
    echo "\n2.5 检查PM2环境..."
    if ! command -v pm2 &> /dev/null
    then
        echo "⚠️ PM2未安装，正在安装..."
        pnpm add -g pm2 --registry=https://registry.npmmirror.com
        if [ \$? -ne 0 ]; then
            echo "❌ 错误：PM2安装失败"
            exit 1
        fi
    fi
    echo "✅ PM2版本：\$(pm2 -v)"

    # 2.6 检查http-server是否安装
    echo "\n2.6 检查http-server是否安装..."
    if ! command -v http-server &> /dev/null
    then
        echo "⚠️ http-server未安装，正在安装..."
        pnpm add -g http-server --registry=https://registry.npmmirror.com
        if [ \$? -ne 0 ]; then
            echo "❌ 错误：http-server安装失败"
            exit 1
        fi
    fi
    echo "✅ http-server已安装"

    # 2.7 启动/重启服务
    echo "\n2.7 启动/重启服务..."

    # 检查服务是否已存在
    if pm2 list | grep -q \$APP_NAME; then
        echo "⚠️ 服务已存在，正在重启..."
        pm2 restart \$APP_NAME
    else
        echo "⚠️ 服务不存在，正在启动..."
        pm2 start "http-server -p \$APP_PORT -d false \$DIST_DIR " --name \$APP_NAME
    fi

    if [ \$? -ne 0 ]; then
        echo "❌ 错误：服务启动失败"
        exit 1
    fi
    echo "✅ 服务启动成功"

    # 2.8 设置开机自启
    echo "\n2.8 设置开机自启..."
    pm2 startup
    echo "✅ 开机自启配置成功"

    # 2.9 保存当前进程列表
    echo "\n2.9 保存当前进程列表..."
    pm2 save
    echo "✅ 进程列表保存成功"

    # 2.10 显示服务状态
    echo "\n2.10 服务状态："
    pm2 status \$APP_NAME

    # 2.11 显示访问地址
    echo "\n2.11 访问地址："
    echo "   - 前端应用：http://localhost:\$APP_PORT"

    # 2.12 显示日志
    echo "\n2.12 查看实时日志："
    echo "    pm2 logs \$APP_NAME"

    # 2.13 完成提示
    echo "\n========================================"
    echo "🎉 部署完成！\$APP_NAME 前端服务已成功启动"
    echo "========================================"
    echo "\n常用命令："
    echo "  - 查看状态：pm2 status"
    echo "  - 查看日志：pm2 logs \$APP_NAME"
    echo "  - 重启服务：pm2 restart \$APP_NAME"
    echo "  - 停止服务：pm2 stop \$APP_NAME"
    echo "\n"
DEPLOY_SCRIPT
if [ $? -ne 0 ]; then
    echo "❌ 错误：部署脚本执行失败"
    exit 1
fi

echo "\n========================================"
echo "🎉 远程部署完成！"
echo "========================================"
echo "服务器：$SERVER_USER@$SERVER_IP"
echo "部署目录：$SERVER_DIR"
echo "\n"
