#!/bin/bash
set -euo pipefail

# ====== Config mặc định ======
EXPORTER_VERSION="0.17.2"
DB_USER="exporter"
DB_PASS="secret" #nhớ thay nhé
DB_HOST="localhost"
LISTEN_PORT="9104"
MYSQL_OPTS="-u root -p"  # Hoặc --defaults-extra-file=/root/.my.cnf nếu muốn
# ============================

# ====== Hàm hỗ trợ ======
log() { echo -e "\033[1;32m[INFO]\033[0m $*"; }
err() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; }
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        err "Script này yêu cầu quyền sudo"
        exit 1
    fi
}
check_port() {
    if lsof -Pi :"${LISTEN_PORT}" -sTCP:LISTEN -t >/dev/null 2>&1; then
        err "Port ${LISTEN_PORT} đang được sử dụng. Chọn port khác."
        exit 1
    fi
}
check_mysql() {
    if ! mysql ${MYSQL_OPTS} -e "SELECT 1;" >/dev/null 2>&1; then
        err "Không kết nối được MariaDB/MySQL với ${MYSQL_OPTS}"
        exit 1
    fi
}
# ========================

# ====== Main script ======
check_sudo
check_port
check_mysql

log "1/8 - Tải mysqld_exporter v${EXPORTER_VERSION}"
cd /tmp
BIN_FILE="mysqld_exporter-${EXPORTER_VERSION}.linux-amd64.tar.gz"
CHECKSUM_FILE="sha256sums.txt"

curl -sSLO "https://github.com/prometheus/mysqld_exporter/releases/download/v${EXPORTER_VERSION}/${BIN_FILE}"
curl -sSLO "https://github.com/prometheus/mysqld_exporter/releases/download/v${EXPORTER_VERSION}/${CHECKSUM_FILE}"

log "Xác minh checksum..."
if ! grep "${BIN_FILE}" "${CHECKSUM_FILE}" | sha256sum -c -; then
    err "Checksum không khớp, dừng cài đặt."
    exit 1
fi

tar xvf "${BIN_FILE}"
sudo mv mysqld_exporter-${EXPORTER_VERSION}.linux-amd64/mysqld_exporter /usr/local/bin/
rm -rf mysqld_exporter-${EXPORTER_VERSION}.linux-amd64* "${BIN_FILE}" "${CHECKSUM_FILE}"

log "2/8 - Tạo system user mysqld_exporter"
if ! id mysqld_exporter >/dev/null 2>&1; then
    sudo useradd --system --no-create-home --shell /usr/sbin/nologin mysqld_exporter
else
    log "User mysqld_exporter đã tồn tại, bỏ qua..."
fi

log "3/8 - Tạo user MySQL/MariaDB cho exporter"
mysql ${MYSQL_OPTS} -e "
CREATE USER IF NOT EXISTS '${DB_USER}'@'${DB_HOST}' IDENTIFIED BY '${DB_PASS}';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO '${DB_USER}'@'${DB_HOST}';
FLUSH PRIVILEGES;
"

log "4/8 - Tạo file cấu hình /etc/mysqld_exporter.cnf"
sudo bash -c "cat > /etc/mysqld_exporter.cnf <<EOF
[client]
user=${DB_USER}
password=${DB_PASS}
host=${DB_HOST}
EOF"

log "5/8 - Chmod file cấu hình"
sudo chown mysqld_exporter:mysqld_exporter /etc/mysqld_exporter.cnf
sudo chmod 640 /etc/mysqld_exporter.cnf

log "6/8 - Tạo systemd service"
sudo bash -c "cat > /etc/systemd/system/mysqld_exporter.service <<EOF
[Unit]
Description=Prometheus MySQL Exporter
After=network.target

[Service]
User=mysqld_exporter
Group=mysqld_exporter
ExecStart=/usr/local/bin/mysqld_exporter \
  --config.my-cnf=/etc/mysqld_exporter.cnf \
  --web.listen-address=:${LISTEN_PORT}
Restart=always
ProtectSystem=full
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF"

log "7/8 - Bật và khởi động service"
sudo systemctl daemon-reload
sudo systemctl enable mysqld_exporter
sudo systemctl start mysqld_exporter

log "8/8 - Kiểm tra service"
if systemctl is-active --quiet mysqld_exporter; then
    log "mysqld_exporter đang chạy. Test: curl http://localhost:${LISTEN_PORT}/metrics | head -n 10"
else
    err "mysqld_exporter không khởi động thành công."
    exit 1
fi

log "✅ Hoàn tất cài đặt mysqld_exporter!"
