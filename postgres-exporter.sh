#!/bin/bash
set -e

EXPORTER_VERSION="0.17.0"
EXPORTER_USER="postgres_exporter"
EXPORTER_DIR="/opt/postgres_exporter"
EXPORTER_BIN="/usr/local/bin/postgres_exporter"
ENV_FILE="/etc/postgres_exporter.env"
SERVICE_FILE="/etc/systemd/system/postgres_exporter.service"

echo "==> 1. Tạo thư mục"
sudo mkdir -p $EXPORTER_DIR
cd $EXPORTER_DIR

echo "==> 2. Tải và giải nén postgres_exporter v$EXPORTER_VERSION"
wget -q https://github.com/prometheus-community/postgres_exporter/releases/download/v${EXPORTER_VERSION}/postgres_exporter-${EXPORTER_VERSION}.linux-amd64.tar.gz
tar -xzf postgres_exporter-${EXPORTER_VERSION}.linux-amd64.tar.gz

echo "==> 3. Copy binary và phân quyền"
sudo cp postgres_exporter-${EXPORTER_VERSION}.linux-amd64/postgres_exporter $EXPORTER_BIN

# Tạo user nếu chưa có
if id "$EXPORTER_USER" &>/dev/null; then
    echo "User $EXPORTER_USER đã tồn tại, bỏ qua"
else
    sudo useradd -rs /bin/false $EXPORTER_USER
fi

sudo chown $EXPORTER_USER:$EXPORTER_USER $EXPORTER_BIN

echo "==> 4. Tạo file env"
sudo bash -c "cat > $ENV_FILE" <<EOF
export DATA_SOURCE_NAME="postgresql://user:password@localhost:5432/postgres?sslmode=disable"
EOF
sudo chmod 600 $ENV_FILE
sudo chown $EXPORTER_USER:$EXPORTER_USER $ENV_FILE

echo "==> 5. Tạo systemd service"
sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=Prometheus PostgreSQL Exporter
After=network.target

[Service]
Type=simple
Restart=always
User=$EXPORTER_USER
Group=$EXPORTER_USER
EnvironmentFile=$ENV_FILE
ExecStart=$EXPORTER_BIN

[Install]
WantedBy=multi-user.target
EOF

echo "==> 6. Reload và start service"
sudo systemctl daemon-reload
sudo systemctl enable --now postgres_exporter

echo "==> 7. Mở firewall port 9187 (nếu dùng ufw)"
if command -v ufw &>/dev/null; then
    sudo ufw allow 9187/tcp || true
fi

echo "==> Hoàn tất cài đặt. Kiểm tra bằng:"
echo "    curl http://localhost:9187/metrics"
