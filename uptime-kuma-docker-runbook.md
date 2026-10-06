# Uptime Kuma – Cài đặt, vận hành và cấu hình Monitor bằng Docker

## 1. Mục đích

Tài liệu hướng dẫn triển khai **Uptime Kuma** bằng Docker, cấu hình monitor, notification, backup/restore, upgrade/rollback và troubleshooting.

Uptime Kuma phù hợp cho lớp **availability monitoring**:

- HTTP/HTTPS
- TCP port
- Ping / ICMP
- DNS
- Keyword/health endpoint
- Push monitor
- Docker container

> Uptime Kuma nên được xem là một lớp availability monitoring. Trong hệ thống doanh nghiệp lớn, nên kết hợp với Zabbix/Prometheus cho metrics và hệ thống log/APM cho observability chuyên sâu.

---

# 2. Kiến trúc

## 2.1. Kiến trúc cơ bản

```text
                    ┌──────────────────────┐
                    │      User / Admin    │
                    └──────────┬───────────┘
                               │ HTTP :3001
                               ▼
                    ┌──────────────────────┐
                    │     Uptime Kuma      │
                    │      Container       │
                    └──────────┬───────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
              ▼                ▼                ▼
          HTTP/HTTPS         TCP Port          ICMP
          Service/API       Database          Server
```

## 2.2. Vai trò trong Central Monitoring

```text
                         CENTRAL MONITORING
                                │
             ┌──────────────────┼──────────────────┐
             │                  │                  │
             ▼                  ▼                  ▼
        Availability          Metrics             Logs
        Uptime Kuma        Zabbix/Prometheus     Loki/ELK
             │                  │                  │
             └──────────────────┼──────────────────┘
                                ▼
                           Alerting
                                │
                    ┌───────────┼───────────┐
                    ▼           ▼           ▼
                 Alerta      Telegram      Email
```

### Phân biệt

| Thành phần | Câu hỏi chính |
|---|---|
| Uptime Kuma | Service có reachable/available không? |
| Zabbix | Server/device/service đang sử dụng tài nguyên thế nào? |
| Prometheus | Metrics thay đổi thế nào theo thời gian? |
| Loki/ELK | Chuyện gì đã xảy ra trong log? |
| APM | Request/application đang chậm ở đâu? |

---

# 3. Yêu cầu hệ thống

## 3.1. Server

Khuyến nghị tối thiểu:

| Thành phần | Giá trị |
|---|---|
| OS | Ubuntu 22.04/24.04 |
| CPU | >= 2 vCPU |
| RAM | >= 2 GB |
| Disk | >= 20 GB |
| Docker | >= 24.x |
| Docker Compose | >= 2.x |
| Port | 3001/TCP |

Kiểm tra OS:

```bash
hostnamectl
```

Kiểm tra CPU/RAM:

```bash
lscpu
free -h
```

Kiểm tra disk:

```bash
df -h
```

Kiểm tra Docker:

```bash
docker --version
docker compose version
```

---

# 4. Cài đặt Docker

Nếu server chưa có Docker:

```bash
sudo apt update
sudo apt install -y ca-certificates curl
```

Cài Docker:

```bash
curl -fsSL https://get.docker.com | sudo sh
```

Kiểm tra:

```bash
docker --version
docker compose version
```

Cho user hiện tại sử dụng Docker không cần `sudo`:

```bash
sudo usermod -aG docker $USER
```

Logout/login lại hoặc:

```bash
newgrp docker
```

Kiểm tra:

```bash
docker run hello-world
```

---

# 5. Tạo thư mục triển khai

Tạo thư mục:

```bash
sudo mkdir -p /opt/uptime-kuma/data
```

Phân quyền:

```bash
sudo chown -R $USER:$USER /opt/uptime-kuma
```

Di chuyển vào thư mục:

```bash
cd /opt/uptime-kuma
```

Cấu trúc:

```text
/opt/uptime-kuma/
├── docker-compose.yml
└── data/
```

---

# 6. Tạo Docker Compose

Tạo file:

```bash
vim /opt/uptime-kuma/docker-compose.yml
```

Nội dung:

```yaml
services:

  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    restart: unless-stopped

    ports:
      - "3001:3001"

    volumes:
      - ./data:/app/data

    environment:
      - TZ=Asia/Ho_Chi_Minh
```

## 6.1. Giải thích

### Image

```yaml
image: louislam/uptime-kuma:latest
```

Sử dụng image chính thức của Uptime Kuma.

Trong Production, có thể pin version cụ thể thay vì sử dụng `latest` để tránh việc upgrade ngoài dự kiến.

Ví dụ:

```yaml
image: louislam/uptime-kuma:<VERSION>
```

### Container name

```yaml
container_name: uptime-kuma
```

Tên container cố định để dễ quản trị:

```bash
docker logs uptime-kuma
docker stats uptime-kuma
docker restart uptime-kuma
```

### Restart policy

```yaml
restart: unless-stopped
```

Docker sẽ tự động khởi động lại container khi:

- Docker daemon restart
- Server reboot
- Container bị crash

Container không tự động start nếu admin chủ động stop container.

### Port

```yaml
ports:
  - "3001:3001"
```

Mapping:

```text
Server TCP 3001
       │
       ▼
Container TCP 3001
```

### Volume

```yaml
volumes:
  - ./data:/app/data
```

Đây là phần rất quan trọng.

Dữ liệu Uptime Kuma được lưu bên ngoài container:

```text
/opt/uptime-kuma/data
        │
        ▼
/app/data
        │
        ▼
Uptime Kuma
```

Khi recreate container, dữ liệu vẫn còn.

### Timezone

```yaml
environment:
  - TZ=Asia/Ho_Chi_Minh
```

Đảm bảo thời gian trong container sử dụng timezone Việt Nam.

---

# 7. Khởi động Uptime Kuma

Tại thư mục:

```bash
cd /opt/uptime-kuma
```

Start:

```bash
docker compose up -d
```

Kiểm tra:

```bash
docker compose ps
```

Hoặc:

```bash
docker ps
```

Kết quả mong muốn:

```text
NAME          STATUS
uptime-kuma   Up
```

---

# 8. Kiểm tra log

Xem log:

```bash
docker logs uptime-kuma
```

Theo dõi realtime:

```bash
docker logs -f uptime-kuma
```

Hoặc:

```bash
docker compose logs -f uptime-kuma
```

Thoát log:

```text
Ctrl + C
```

---

# 9. Kiểm tra port

Trên server:

```bash
ss -lntp | grep 3001
```

Kiểm tra local:

```bash
curl http://127.0.0.1:3001
```

Từ máy khác:

```bash
nc -zv <KUMA_IP> 3001
```

Hoặc:

```bash
curl http://<KUMA_IP>:3001
```

---

# 10. Truy cập Web UI

Truy cập:

```text
http://<KUMA_IP>:3001
```

Ví dụ:

```text
http://<KUMA_IP>:3001
```

Lần đầu truy cập:

1. Tạo tài khoản admin.
2. Đặt password.
3. Login.
4. Kiểm tra Dashboard.

---

# 11. Firewall

Kiểm tra UFW:

```bash
sudo ufw status
```

Cho phép port 3001:

```bash
sudo ufw allow 3001/tcp
```

Kiểm tra:

```bash
sudo ufw status
```

Trong Production nên giới hạn source IP nếu Web UI chỉ phục vụ mạng quản trị.

Ví dụ:

```bash
sudo ufw allow from <ADMIN_NETWORK> to any port 3001 proto tcp
```

---

# 12. Cấu hình Reverse Proxy

Nếu cần public bằng domain:

```text
https://monitor.<DOMAIN>
```

không nên expose trực tiếp port `3001` ra Internet nếu không cần.

Mô hình:

```text
                    Internet / Internal Network
                              │
                              │ HTTPS :443
                              ▼
                    ┌───────────────────┐
                    │ Reverse Proxy     │
                    │ Nginx / HAProxy   │
                    └─────────┬─────────┘
                              │ HTTP :3001
                              ▼
                    ┌───────────────────┐
                    │   Uptime Kuma     │
                    │   Docker :3001    │
                    └───────────────────┘
```

Nếu sử dụng reverse proxy, cần cấu hình TLS và access control phù hợp với chính sách của công ty.

---

# 13. Add Monitor

Sau khi đăng nhập:

```text
Dashboard
    ↓
Add New Monitor
```

Chọn loại monitor phù hợp.

Các loại thường sử dụng:

| Monitor | Mục đích |
|---|---|
| HTTP(s) | Kiểm tra website/API |
| HTTP(s) - Keyword | Kiểm tra HTTP + nội dung response |
| TCP Port | Kiểm tra port dịch vụ |
| Ping | Kiểm tra server/network |
| DNS | Kiểm tra DNS |
| Push | Kiểm tra job/script |
| Docker Container | Kiểm tra container |

---

# 14. Monitor HTTP/HTTPS

## 14.1. Mục đích

Dùng để kiểm tra website hoặc API có trả HTTP response hay không.

Ví dụ:

```text
https://<HOST_NAME>/health
```

Cấu hình:

```text
Monitor Type:
HTTP(s)

Friendly Name:
<APPLICATION_NAME>

URL:
https://<HOST_NAME>/health

Heartbeat Interval:
60 seconds

Retries:
2
```

Mô hình:

```text
Uptime Kuma
      │
      │ HTTPS
      ▼
Application / API
```

---

# 15. Monitor HTTP Health Endpoint

Đây là cách nên ưu tiên cho application nếu hệ thống có health endpoint.

Ví dụ:

```text
https://<HOST_NAME>/health
```

Response:

```json
{
  "status": "UP"
}
```

Có thể cấu hình:

```text
Monitor Type:
HTTP(s)

URL:
https://<HOST_NAME>/health

Expected Status:
200
```

Nếu ứng dụng có health endpoint riêng, việc monitor endpoint thường có giá trị hơn chỉ kiểm tra TCP port.

---

# 16. Monitor Keyword

HTTP `200` chưa chắc application thực sự healthy.

Ví dụ API trả:

```json
{
  "status": "UP"
}
```

Có thể kiểm tra keyword:

```text
Monitor Type:
HTTP(s) - Keyword

URL:
https://<HOST_NAME>/health

Keyword:
UP
```

Logic:

```text
HTTP 200
   +
Response chứa "UP"
   =
Healthy
```

Ngược lại:

```text
HTTP 200
   +
Response không chứa "UP"
   =
Có khả năng application đang lỗi
```

---

# 17. Monitor TCP Port

Dùng để kiểm tra service có listen port và có thể kết nối TCP hay không.

Ví dụ PostgreSQL:

```text
Monitor Type:
TCP Port

Hostname:
<HOST_NAME>

Port:
5432
```

Kiểm tra:

```text
Uptime Kuma
      │
      │ TCP 5432
      ▼
PostgreSQL
```

Test từ command line:

```bash
nc -zv <HOST_NAME> 5432
```

## Lưu ý

TCP `5432` UP chỉ chứng minh port có thể kết nối.

Nó không chứng minh:

- Database query được.
- Replication bình thường.
- Connection pool bình thường.
- Disk còn đủ.
- WAL không phình.
- Database không bị lock.
- Application transaction hoạt động.

Với database quan trọng, nên kết hợp Uptime Kuma với database monitoring.

---

# 18. Monitor Ping

Dùng để kiểm tra server/network reachability.

Cấu hình:

```text
Monitor Type:
Ping

Hostname:
<SERVER_IP>
```

Command tương ứng:

```bash
ping -c 4 <SERVER_IP>
```

Ping UP không có nghĩa service/application đang hoạt động.

Ví dụ:

```text
Server
  │
  ├── Ping UP
  │
  ├── TCP 5432 DOWN
  │
  └── Application DOWN
```

---

# 19. Monitor DNS

Dùng để kiểm tra DNS resolution.

Ví dụ:

```text
Monitor Type:
DNS

Hostname:
<HOST_NAME>

Port:
53
```

Có thể dùng để phát hiện:

- DNS server không phản hồi.
- Domain không resolve.
- Record sai.
- Internal DNS có vấn đề.

---

# 20. Monitor Push

Push monitor phù hợp với:

- Cron job
- Backup job
- Batch job
- ETL
- Script
- Scheduled task

Mô hình:

```text
Cron / Script
     │
     │ Push
     ▼
Uptime Kuma
     │
     ├── Last successful execution
     └── Timeout → DOWN
```

Ví dụ:

```bash
#!/bin/bash

# Execute backup
/path/to/backup.sh

if [ $? -eq 0 ]; then
    curl -fsS "<PUSH_URL>"
fi
```

Nếu job không gọi Push endpoint trong thời gian cấu hình, Uptime Kuma sẽ cảnh báo.

---

# 21. Cấu hình Retry

Không nên đánh DOWN ngay lập tức chỉ vì một request thất bại.

Ví dụ:

```text
Heartbeat Interval:
60 seconds

Retries:
2
```

Có thể hiểu:

```text
Request #1
   │
   ├── Success → UP
   │
   └── Failed
        │
        ▼
     Retry #1
        │
        ├── Success → UP
        │
        └── Failed
             │
             ▼
          Retry #2
             │
             └── Failed → DOWN
```

Mục tiêu:

- Giảm false positive.
- Tránh cảnh báo do packet loss ngắn.
- Tránh cảnh báo do service restart trong vài giây.
- Giảm noise.

---

# 22. Notification

Vào:

```text
Settings
    ↓
Notifications
```

Có thể cấu hình các notification provider được Uptime Kuma hỗ trợ, ví dụ:

- Telegram
- Email
- Slack
- Discord
- Webhook

Workflow:

```text
Monitor
   │
   │ DOWN
   ▼
Uptime Kuma
   │
   ▼
Notification
   │
   ├── Telegram
   ├── Email
   └── Webhook
```

Sau khi cấu hình notification nên thực hiện test notification.

---

# 23. Naming Convention

Khi số lượng monitor tăng lên hàng trăm/hàng nghìn, naming convention rất quan trọng.

Đề xuất:

```text
<ENV>-<SERVICE>-<COMPONENT>-<CHECK>
```

Ví dụ:

```text
PROD-PHBC-WEB-HTTPS
PROD-PHBC-API-HEALTH
PROD-PHBC-DB-TCP5432
PROD-EMS-API-HEALTH
PROD-QTHT-POSTGRES-TCP5432
```

Không nên đặt:

```text
test
server1
api
database
```

vì khó xác định monitor thuộc hệ thống nào.

---

# 24. Tag

Nên sử dụng tag để phân loại.

Ví dụ:

```text
environment=Production
team=QTHT
service=Database
criticality=Critical
```

Hoặc:

```text
environment=Production
service=API
team=Application
```

Các nhóm tag đề xuất:

```text
environment
team
service
system
criticality
owner
```

---

# 25. Ví dụ hệ thống Production

Giả sử hệ thống:

```text
PHBC
├── Web
├── API
├── PostgreSQL
└── Redis
```

Có thể tạo:

```text
PROD-PHBC-WEB-HTTPS
PROD-PHBC-API-HEALTH
PROD-PHBC-POSTGRES-TCP5432
PROD-PHBC-REDIS-TCP6379
```

Mô hình:

```text
                     PROD-PHBC
                         │
          ┌──────────────┼──────────────┐
          │              │              │
          ▼              ▼              ▼
         Web             API           DB/Redis
          │              │              │
       HTTPS           /health       TCP Port
```

---

# 26. Kiểm tra Monitor

Sau khi tạo monitor:

```text
Dashboard
    ↓
Monitor
```

Kiểm tra:

- Status
- Response time
- Uptime
- Heartbeat
- Notification

Có thể chủ động test bằng cách stop service trong môi trường được phép.

Ví dụ:

```bash
sudo systemctl stop <SERVICE_NAME>
```

Theo dõi:

```text
UP
 ↓
PENDING / RETRY
 ↓
DOWN
```

Khôi phục:

```bash
sudo systemctl start <SERVICE_NAME>
```

Kết quả:

```text
DOWN
 ↓
UP
```

---

# 27. Kiểm tra bằng command line

## HTTP

```bash
curl -I https://<HOST_NAME>
```

Health endpoint:

```bash
curl -v https://<HOST_NAME>/health
```

## TCP

```bash
nc -zv <HOST_NAME> <PORT>
```

Ví dụ:

```bash
nc -zv <HOST_NAME> 5432
```

## Ping

```bash
ping -c 4 <HOST_NAME>
```

## DNS

```bash
nslookup <HOST_NAME>
```

Hoặc:

```bash
dig <HOST_NAME>
```

Các command này giúp phân biệt:

```text
Uptime Kuma
    │
    ├── Kuma issue
    ├── Network issue
    ├── DNS issue
    ├── Firewall issue
    ├── Target server issue
    └── Target service issue
```

---

# 28. Backup

Dữ liệu Uptime Kuma nằm tại:

```text
/opt/uptime-kuma/data
```

Kiểm tra dung lượng:

```bash
du -sh /opt/uptime-kuma/data
```

Backup:

```bash
tar -czf \
    /opt/uptime-kuma-backup-$(date +%Y%m%d_%H%M%S).tar.gz \
    /opt/uptime-kuma/data
```

Ví dụ:

```text
uptime-kuma-backup-20261006_020000.tar.gz
```

## 28.1. Khuyến nghị

Không nên chỉ lưu backup trên chính Uptime Kuma server.

Mô hình:

```text
Uptime Kuma Server
       │
       ▼
Backup
       │
       ▼
Backup Server / NAS / Object Storage
```

---

# 29. Restore

## 29.1. Stop container

```bash
cd /opt/uptime-kuma
docker compose down
```

## 29.2. Backup data hiện tại

```bash
mv data data.old
```

## 29.3. Restore

Giải nén backup vào filesystem:

```bash
tar -xzf <BACKUP_FILE> -C /
```

Kiểm tra:

```bash
ls -lah /opt/uptime-kuma/data
```

## 29.4. Start

```bash
docker compose up -d
```

Kiểm tra:

```bash
docker compose ps
```

Log:

```bash
docker compose logs -f uptime-kuma
```

Sau restore kiểm tra:

- Login.
- Dashboard.
- Monitor.
- Historical data.
- Notification.
- Configuration.

---

# 30. Upgrade

Trước khi upgrade luôn backup.

## 30.1. Backup

```bash
cd /opt/uptime-kuma

tar -czf \
    /opt/uptime-kuma-backup-before-upgrade-$(date +%Y%m%d).tar.gz \
    data
```

## 30.2. Pull image

```bash
docker compose pull
```

## 30.3. Recreate

```bash
docker compose up -d
```

## 30.4. Kiểm tra

```bash
docker compose ps
```

```bash
docker images | grep uptime-kuma
```

```bash
docker compose logs --tail 200 uptime-kuma
```

Sau upgrade kiểm tra:

- Login.
- Dashboard.
- Monitor status.
- Historical data.
- Notification.
- Response time.
- Container restart.

---

# 31. Pin Version trong Production

Để tránh upgrade ngoài dự kiến, có thể sử dụng version cụ thể:

```yaml
services:

  uptime-kuma:
    image: louislam/uptime-kuma:<VERSION>
    container_name: uptime-kuma
    restart: unless-stopped

    ports:
      - "3001:3001"

    volumes:
      - ./data:/app/data

    environment:
      - TZ=Asia/Ho_Chi_Minh
```

Quy trình:

```text
New Version
    │
    ▼
Backup
    │
    ▼
Test
    │
    ▼
Upgrade
    │
    ▼
Validate
    │
    ├── OK → Keep
    │
    └── Error → Rollback
```

---

# 32. Rollback

Nếu version mới có vấn đề:

1. Stop container.
2. Đưa image về version cũ.
3. Restore data nếu cần.
4. Start container.
5. Kiểm tra monitor.

Ví dụ:

```yaml
services:

  uptime-kuma:
    image: louislam/uptime-kuma:<OLD_VERSION>
```

Sau đó:

```bash
docker compose down
docker compose up -d
```

Kiểm tra:

```bash
docker compose ps
docker compose logs --tail 200 uptime-kuma
```

> Không nên rollback database/data blindly. Nếu version mới đã thực hiện migration dữ liệu, cần kiểm tra compatibility của version cũ trước khi restore/rollback.

---

# 33. Docker Health / Resource

Kiểm tra container:

```bash
docker ps
```

Chi tiết:

```bash
docker inspect uptime-kuma
```

Resource:

```bash
docker stats uptime-kuma
```

Disk:

```bash
df -h
```

Docker disk usage:

```bash
docker system df
```

Kiểm tra restart count:

```bash
docker inspect uptime-kuma \
    --format='{{.RestartCount}}'
```

Nếu restart count tăng liên tục, kiểm tra log:

```bash
docker logs --tail 200 uptime-kuma
```

---

# 34. Troubleshooting – Không truy cập Web UI

## Bước 1: Kiểm tra container

```bash
docker ps
```

## Bước 2: Kiểm tra port

```bash
ss -lntp | grep 3001
```

## Bước 3: Kiểm tra local

```bash
curl http://127.0.0.1:3001
```

## Bước 4: Kiểm tra log

```bash
docker logs --tail 200 uptime-kuma
```

## Bước 5: Kiểm tra firewall

```bash
sudo ufw status
```

## Bước 6: Kiểm tra từ client

```bash
nc -zv <KUMA_IP> 3001
```

Nếu:

```text
localhost:3001    → OK
client:3001       → FAIL
```

thì tập trung kiểm tra:

```text
Firewall
Network ACL
Routing
Security Group
Load Balancer
```

---

# 35. Troubleshooting – Monitor báo DOWN

Không nên kết luận ngay target service bị lỗi.

Kiểm tra theo thứ tự:

```text
1. Uptime Kuma
       ↓
2. Network
       ↓
3. DNS
       ↓
4. Firewall
       ↓
5. Target Server
       ↓
6. Target Service
       ↓
7. Application
```

## HTTP

```bash
curl -v https://<HOST_NAME>/<PATH>
```

## TCP

```bash
nc -zv <HOST_NAME> <PORT>
```

## Ping

```bash
ping -c 4 <HOST_NAME>
```

## DNS

```bash
nslookup <HOST_NAME>
```

---

# 36. Troubleshooting – Monitor UP nhưng Application lỗi

Đây là một tình huống thường gặp.

Ví dụ:

```text
TCP 5432 = UP
```

không có nghĩa:

```text
PostgreSQL = Healthy
```

Tương tự:

```text
HTTP 200 = UP
```

không nhất thiết:

```text
Business Function = Healthy
```

Nên thiết kế monitoring theo nhiều lớp:

```text
                    Monitoring
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
   Availability      Service         Business
        │               │               │
    Ping/TCP         Health API      Business KPI
```

---

# 37. Database Monitoring

Ví dụ PostgreSQL:

```text
Layer 1:
TCP 5432
```

```text
Layer 2:
Database connection
```

```text
Layer 3:
Query / health check
```

```text
Layer 4:
Replication / WAL / connection pool
```

Uptime Kuma phù hợp nhất với Layer 1 và một phần Layer 2.

Các metric chuyên sâu nên đưa vào Zabbix/Prometheus.

Ví dụ:

```text
PostgreSQL
├── Connections
├── Active sessions
├── Long running queries
├── Locks
├── Replication lag
├── WAL
├── Disk
├── Cache hit ratio
└── Transaction rate
```

---

# 38. Central Monitoring cho doanh nghiệp lớn

Khi số lượng service tăng:

```text
100 Servers
1000 Servers
10000 Services
10000+ Monitors
```

không nên quản lý thủ công thiếu chuẩn hóa.

Nên có metadata:

```text
environment
team
service
system
owner
criticality
location
```

Ví dụ:

```text
environment=Production
team=QTHT
system=PHBC
service=PostgreSQL
owner=Database Team
criticality=Critical
```

Mô hình:

```text
                         Central Monitoring
                                  │
             ┌────────────────────┼────────────────────┐
             │                    │                    │
             ▼                    ▼                    ▼
        Availability           Metrics               Logs
        Uptime Kuma        Zabbix/Prometheus        ELK/Loki
             │                    │                    │
             └────────────────────┼────────────────────┘
                                  ▼
                              Alerting
                                  │
                     ┌────────────┼────────────┐
                     ▼            ▼            ▼
                  Alerta       Telegram       Email
```

---

# 39. Checklist triển khai Monitor mới

## Trước khi tạo

- [ ] Xác định service owner.
- [ ] Xác định environment.
- [ ] Xác định hostname/IP.
- [ ] Xác định port.
- [ ] Xác định health endpoint.
- [ ] Xác định criticality.
- [ ] Xác định notification.
- [ ] Xác định retry/interval.

## Sau khi tạo

- [ ] Monitor UP.
- [ ] Response time bình thường.
- [ ] Notification hoạt động.
- [ ] Test DOWN.
- [ ] Test recovery.
- [ ] Gắn tag.
- [ ] Đặt tên đúng convention.
- [ ] Ghi nhận owner.

---

# 40. Checklist vận hành

## Daily

- [ ] Kiểm tra Uptime Kuma container.
- [ ] Kiểm tra monitor DOWN.
- [ ] Kiểm tra notification.
- [ ] Kiểm tra disk.
- [ ] Kiểm tra container restart.

Commands:

```bash
docker ps
```

```bash
docker stats uptime-kuma
```

```bash
df -h
```

---

## Weekly

- [ ] Kiểm tra backup.
- [ ] Test notification.
- [ ] Review monitor DOWN.
- [ ] Review monitor không còn sử dụng.
- [ ] Review response time.
- [ ] Kiểm tra disk growth.

---

## Monthly

- [ ] Test restore backup.
- [ ] Review danh sách monitor.
- [ ] Xóa/disable monitor không còn sử dụng.
- [ ] Review notification.
- [ ] Review resource usage.
- [ ] Review Uptime Kuma version.
- [ ] Review security/access.

---

# 41. Security Checklist

- [ ] Không expose trực tiếp Uptime Kuma ra Internet nếu không cần.
- [ ] Hạn chế source IP truy cập Web UI.
- [ ] Sử dụng HTTPS khi truy cập qua network không tin cậy.
- [ ] Sử dụng password mạnh.
- [ ] Phân quyền admin phù hợp.
- [ ] Không lưu credential trực tiếp trong script public.
- [ ] Backup dữ liệu ra storage khác.
- [ ] Theo dõi disk usage.
- [ ] Theo dõi container restart.
- [ ] Quản lý version image.
- [ ] Backup trước upgrade.

---

# 42. Các command vận hành thường dùng

## Start

```bash
cd /opt/uptime-kuma
docker compose up -d
```

## Stop

```bash
docker compose down
```

## Restart

```bash
docker compose restart
```

## Xem trạng thái

```bash
docker compose ps
```

## Xem log

```bash
docker compose logs -f uptime-kuma
```

## Xem resource

```bash
docker stats uptime-kuma
```

## Xem container

```bash
docker inspect uptime-kuma
```

## Pull image

```bash
docker compose pull
```

## Recreate

```bash
docker compose up -d
```

---

# 43. Quick Recovery Runbook

Trong trường hợp Uptime Kuma không hoạt động:

```text
1. Check server
      ↓
2. Check disk
      ↓
3. Check Docker
      ↓
4. Check container
      ↓
5. Check logs
      ↓
6. Check port 3001
      ↓
7. Restart container
      ↓
8. Validate Web UI
      ↓
9. Validate monitors
      ↓
10. Validate notification
```

Commands:

```bash
hostnamectl
```

```bash
df -h
```

```bash
docker info
```

```bash
docker ps -a
```

```bash
docker logs --tail 200 uptime-kuma
```

```bash
ss -lntp | grep 3001
```

Nếu cần restart:

```bash
cd /opt/uptime-kuma
docker compose restart
```

Kiểm tra lại:

```bash
docker compose ps
```

---

# 44. Kết luận

Uptime Kuma phù hợp để xây dựng lớp **availability monitoring** đơn giản, trực quan và dễ triển khai bằng Docker.

Mô hình triển khai khuyến nghị:

```text
                        Service
                           │
            ┌──────────────┼──────────────┐
            │              │              │
            ▼              ▼              ▼
          HTTPS           TCP            Ping
            │              │              │
            └──────────────┼──────────────┘
                           ▼
                      Uptime Kuma
                           │
                           ▼
                      Notification
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
           Alerta       Telegram       Email
```

Đối với hệ thống doanh nghiệp lớn, kiến trúc nên mở rộng:

```text
                         CENTRAL MONITORING
                                │
       ┌────────────────────────┼────────────────────────┐
       │                        │                        │
       ▼                        ▼                        ▼
 Availability                Metrics                   Logs
 Uptime Kuma              Zabbix/Prometheus           Loki/ELK
       │                        │                        │
       └────────────────────────┼────────────────────────┘
                                ▼
                           Alert Engine
                                │
                    ┌───────────┼───────────┐
                    ▼           ▼           ▼
                 Alerta      Telegram      Email
```

Trong mô hình này:

- **Uptime Kuma**: kiểm tra availability/reachability.
- **Zabbix/Prometheus**: thu thập metrics.
- **Loki/ELK**: tập trung log.
- **Alerta/Alertmanager**: tập trung xử lý alert.
- **Telegram/Email/Webhook**: notification tới người vận hành.

Mục tiêu cuối cùng không phải chỉ là có thật nhiều monitor, mà là xây dựng được monitoring có:

1. Chuẩn hóa.
2. Có owner.
3. Có severity/criticality.
4. Có notification phù hợp.
5. Có khả năng truy nguyên sự cố.
6. Có backup/restore.
7. Có quy trình vận hành và review định kỳ.
