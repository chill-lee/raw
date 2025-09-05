#!/bin/bash
set -e

# 配置变量
URL="https://github.com/pmkol/mosdns-x/releases/download/v25.09.03/mosdns-linux-amd64.zip"
ZIP_FILE="/tmp/mosdns.zip"
INSTALL_DIR="/etc/mosdns"
CONFIG_FILE="$INSTALL_DIR/config.yaml"

# 安装 unzip
echo "安装 unzip..."
apt update -y && apt install unzip -y

# 创建安装目录
mkdir -p "$INSTALL_DIR"

# 下载并解压 mosdns
echo "下载 mosdns..."
wget -O "$ZIP_FILE" "$URL"
echo "解压 mosdns 到 $INSTALL_DIR..."
unzip -o "$ZIP_FILE" -d "$INSTALL_DIR"
rm -f "$ZIP_FILE"

# 写入 config.yaml
echo "写入配置文件 $CONFIG_FILE..."
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

# 确保可执行权限
chmod +x "$INSTALL_DIR/mosdns"

# 安装 systemd 服务
echo "安装 systemd 服务..."
cd "$INSTALL_DIR"
./mosdns service install -d "$INSTALL_DIR" -c "$CONFIG_FILE" || echo "服务已存在，跳过安装。"

# 更新 PATH
if ! grep -q "/etc/mosdns" /etc/profile; then
    echo 'export PATH=\$PATH:/etc/mosdns' >> /etc/profile
    export PATH=$PATH:/etc/mosdns
fi

# 启动服务
systemctl daemon-reload
systemctl enable mosdns
systemctl restart mosdns

echo "安装完成！使用命令查看状态： systemctl status mosdns"