#!/bin/bash
set -e

# 1. 设置时区为东八区
echo ">>> 设置时区为 Asia/Shanghai (东八区)..."
timedatectl set-timezone Asia/Shanghai
timedatectl

# 2. 自动识别 CPU 架构
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)   MOSDNS_PKG="mosdns-linux-amd64.zip" ;;
    aarch64)  MOSDNS_PKG="mosdns-linux-arm64.zip" ;;
    armv7l)   MOSDNS_PKG="mosdns-linux-arm.zip" ;;
    *) echo "不支持的架构: $ARCH"; exit 1 ;;
esac
echo ">>> 检测到系统架构: $ARCH -> 使用安装包: $MOSDNS_PKG"

# 3. 获取最新版本号
LATEST_VERSION=$(curl -s https://api.github.com/repos/pmkol/mosdns-x/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
if [ -z "$LATEST_VERSION" ]; then
    echo "获取 mosdns 最新版本失败，请检查网络！"
    exit 1
fi
echo ">>> 最新版本: $LATEST_VERSION"

# 4. 拼接下载地址
URL="https://github.com/pmkol/mosdns-x/releases/download/${LATEST_VERSION}/${MOSDNS_PKG}"
ZIP_FILE="/tmp/mosdns.zip"
INSTALL_DIR="/etc/mosdns"
CONFIG_FILE="$INSTALL_DIR/config.yaml"

# 5. 安装 unzip
echo ">>> 安装 unzip..."
apt update -y && apt install unzip -y

# 6. 创建安装目录
mkdir -p "$INSTALL_DIR"

# 7. 下载并解压 mosdns
echo ">>> 下载 mosdns: $URL"
wget -O "$ZIP_FILE" "$URL"
echo ">>> 解压 mosdns 到 $INSTALL_DIR..."
unzip -o "$ZIP_FILE" -d "$INSTALL_DIR"
rm -f "$ZIP_FILE"

# 8. 备份旧配置并写入新配置
if [ -f "$CONFIG_FILE" ]; then
    BACKUP_FILE="${CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    echo "已备份旧配置为 $BACKUP_FILE"
fi

echo ">>> 写入新的配置文件 $CONFIG_FILE..."
cat > "$CONFIG_FILE" <<EOF
log:
    file: "/etc/mosdns/mosdns.log"
    level: info
plugins:
    - args:
        upstream:
            - addr: https://1.1.1.1/dns-query
            - addr: https://8.8.8.8/dns-query
      tag: forward_google
      type: fast_forward
servers:
    - exec: forward_google
      listeners:
        - addr: 0.0.0.0:5533
          protocol: udp
        - addr: 0.0.0.0:5533
          protocol: tcp
EOF

# 9. 确保 mosdns 可执行
chmod +x "$INSTALL_DIR/mosdns"

# 10. 安装 systemd 服务
echo ">>> 安装 systemd 服务..."
cd "$INSTALL_DIR"
./mosdns service install -d "$INSTALL_DIR" -c "$CONFIG_FILE" || echo "服务已存在，跳过安装。"

# 11. 更新 PATH
if ! grep -q "/etc/mosdns" /etc/profile; then
    echo 'export PATH=\$PATH:/etc/mosdns' >> /etc/profile
    export PATH=$PATH:/etc/mosdns
fi

# 12. 启动服务
systemctl daemon-reload
systemctl enable mosdns
systemctl restart mosdns

echo ">>> 安装完成！"
echo "查看服务状态: systemctl status mosdns"
echo "查看日志: journalctl -u mosdns -f"
